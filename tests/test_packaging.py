#!/usr/bin/env python3
"""Regression tests for apply-time synthetic package construction.

These deliberately inspect the HCL as Terraform's plan cannot execute local-exec.
The custom-package commands are additionally run in a temporary directory to prove
that they create a fresh ZIP containing only the current script.
"""
from __future__ import annotations

import os
import re
import shutil
import subprocess
import tempfile
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def resource_body(source: str, kind: str, name: str) -> str:
    """Return one HCL resource body (sufficient for the module's simple blocks)."""
    match = re.search(rf'resource\s+"{re.escape(kind)}"\s+"{re.escape(name)}"\s*\{{', source)
    if not match:
        raise AssertionError(f"missing resource {kind}.{name}")
    start = match.end()
    depth = 1
    in_quote = False
    escaped = False
    for index in range(start, len(source)):
        char = source[index]
        if in_quote:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_quote = False
            continue
        if char == '"':
            in_quote = True
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return source[start:index]
    raise AssertionError(f"unterminated resource {kind}.{name}")


def heredoc_command(body: str) -> str:
    """Extract the sole heredoc local-exec command from a resource body."""
    match = re.search(r"command\s*=\s*<<-?(?P<tag>[A-Z][A-Z0-9_]*)\n(?P<command>.*?)(?:\n)?(?P=tag)(?:\n|$)", body, re.DOTALL)
    if not match:
        raise AssertionError("expected a heredoc local-exec command")
    return match.group("command")


class PackagingWiringTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.node = (ROOT / "scripts-node.tf").read_text(encoding="utf-8")
        cls.python = (ROOT / "scripts-python.tf").read_text(encoding="utf-8")

    def test_staging_replacements_keep_unique_random_id_paths(self) -> None:
        for runtime, source in (("nodejs", self.node), ("python", self.python)):
            with self.subTest(runtime=runtime):
                self.assertRegex(
                    source,
                    rf'{runtime}_staging_directory\s*=\s*"/tmp/cloudopsworks-synthetics-{runtime}-\$\{{random_id\.{runtime}_staging\.hex\}}"',
                )
                body = resource_body(source, "terraform_data", f"stage_{runtime}")
                self.assertRegex(
                    body,
                    rf"staging_directory\s*=\s*local\.{runtime}_staging_directory",
                )

    def test_staging_uses_runtime_provided_aws_sdks(self) -> None:
        self.assertNotIn("@aws-sdk/", self.node)
        self.assertNotRegex(self.python, r"\b(?:boto3|botocore)\b")
        requirements = (ROOT / "sources/standard/requirements.txt").read_text()
        packages = [line.strip() for line in requirements.splitlines()
                    if line.strip() and not line.lstrip().startswith("#")]
        self.assertFalse(any(re.match(r"(?:boto3|botocore)\b", package, re.I)
                             for package in packages))

    def test_every_archive_and_custom_package_rebuilds_at_apply(self) -> None:
        for resource, source in (
            ("archive_url_nodejs", self.node),
            ("script_custom_node", self.node),
            ("archive_url_python", self.python),
            ("script_custom_python", self.python),
        ):
            with self.subTest(resource=resource):
                body = resource_body(source, "terraform_data", resource)
                self.assertRegex(body, r"triggers_replace\s*=\s*timestamp\(\)")

    def test_standard_archives_are_fresh_and_created_from_staging_root(self) -> None:
        for runtime, source in (("nodejs", self.node), ("python", self.python)):
            with self.subTest(runtime=runtime):
                body = resource_body(source, "terraform_data", f"archive_url_{runtime}")
                self.assertRegex(body, rf"working_dir\s*=\s*local\.{runtime}_staging_directory")
                command = heredoc_command(body)
                self.assertIn('mkdir -p "$(dirname \"$ZIP_FILE\")"', command)
                self.assertIn('rm -f "$ZIP_FILE"', command)
                self.assertRegex(command, r"zip\s+-q\s+-r\s+\"\$ZIP_FILE\"\s+\.")
                # No canary directory may be copied: the runtime's staged directory is
                # the archive root, keeping AWS handler paths stable.
                self.assertNotIn("cp -rf", body)

    def test_custom_scripts_are_written_and_zipped_entirely_at_apply(self) -> None:
        for runtime, resource, source in (
            ("nodejs", "script_custom_node", self.node),
            ("python", "script_custom_python", self.python),
        ):
            with self.subTest(runtime=runtime):
                body = resource_body(source, "terraform_data", resource)
                self.assertNotIn('resource "local_file"', source)
                self.assertRegex(body, r"environment\s*=\s*\{")
                for variable in ("SCRIPT_CONTENT", "SCRIPT_PATH", "ZIP_FILE"):
                    self.assertRegex(body, rf"\b{variable}\s*=")
                command = heredoc_command(body)
                self.assertIn("set -eu", command)
                self.assertIn("mktemp -d", command)
                self.assertRegex(command, r"trap\s+.*rm -rf")
                self.assertIn('mkdir -p "$staging_directory/$(dirname \"$SCRIPT_PATH\")"', command)
                self.assertIn('printf', command)
                self.assertIn('"$SCRIPT_CONTENT"', command)
                self.assertIn('"$staging_directory/$SCRIPT_PATH"', command)
                self.assertIn('rm -f "$ZIP_FILE"', command)
                self.assertRegex(command, r"zip\s+-q\s+-r\s+\"\$ZIP_FILE\"\s+\.")

    def test_custom_command_rebuilds_a_zip_without_stale_members(self) -> None:
        if shutil.which("zip") is None:
            self.skipTest("zip executable is required to exercise local-exec packaging")
        for runtime, resource, source, script_path in (
            ("nodejs", "script_custom_node", self.node, "nodejs/node_modules/current_handler.js"),
            ("python", "script_custom_python", self.python, "python/current_handler.py"),
        ):
            with self.subTest(runtime=runtime), tempfile.TemporaryDirectory() as directory:
                zip_file = Path(directory) / "packages" / f"{runtime}.zip"
                command = heredoc_command(resource_body(source, "terraform_data", resource))
                # Use a deterministic mktemp shim to prove the shell trap removes the
                # apply-time staging directory, not just that the ZIP is valid.
                bin_directory = Path(directory) / "bin"
                bin_directory.mkdir()
                temporary_root = Path(directory) / "custom-staging"
                mktemp = bin_directory / "mktemp"
                mktemp.write_text(
                    "#!/bin/sh\nmkdir -p \"$TMP_TRACK/staging\"\nprintf '%s\\n' \"$TMP_TRACK/staging\"\n",
                    encoding="utf-8",
                )
                mktemp.chmod(0o755)
                base_environment = os.environ | {
                    "ZIP_FILE": str(zip_file),
                    "SCRIPT_PATH": script_path,
                    "TMP_TRACK": str(temporary_root),
                    "PATH": f"{bin_directory}{os.pathsep}{os.environ['PATH']}",
                }
                for content in ("first revision", "second revision"):
                    result = subprocess.run(
                        command,
                        shell=True,
                        executable="/bin/sh",
                        cwd=directory,
                        env=base_environment | {"SCRIPT_CONTENT": content},
                        capture_output=True,
                        text=True,
                        check=False,
                    )
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertFalse((temporary_root / "staging").exists(), "custom staging directory leaked")
                self.assertTrue(zip_file.is_file())
                with zipfile.ZipFile(zip_file) as archive:
                    members = [member.filename for member in archive.infolist() if not member.is_dir()]
                    self.assertEqual(members, [script_path])
                    self.assertEqual(archive.read(script_path).decode(), "second revision")

    def test_standard_command_rebuilds_a_zip_without_stale_members(self) -> None:
        if shutil.which("zip") is None:
            self.skipTest("zip executable is required to exercise local-exec packaging")
        for runtime, source in (("nodejs", self.node), ("python", self.python)):
            with self.subTest(runtime=runtime), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                staging = root / "staging"
                staging.mkdir()
                zip_file = root / "packages" / f"{runtime}.zip"
                command = heredoc_command(resource_body(source, "terraform_data", f"archive_url_{runtime}"))
                environment = os.environ | {"ZIP_FILE": str(zip_file)}

                (staging / "old-member.txt").write_text("first", encoding="utf-8")
                first = subprocess.run(
                    command, shell=True, executable="/bin/sh", cwd=staging, env=environment,
                    capture_output=True, text=True, check=False,
                )
                self.assertEqual(first.returncode, 0, first.stderr)
                (staging / "old-member.txt").unlink()
                (staging / "current-member.txt").write_text("second", encoding="utf-8")
                second = subprocess.run(
                    command, shell=True, executable="/bin/sh", cwd=staging, env=environment,
                    capture_output=True, text=True, check=False,
                )
                self.assertEqual(second.returncode, 0, second.stderr)
                with zipfile.ZipFile(zip_file) as archive:
                    members = [member.filename for member in archive.infolist() if not member.is_dir()]
                    self.assertEqual(members, ["current-member.txt"])
                    self.assertEqual(archive.read("current-member.txt").decode(), "second")

    def test_s3_hashes_follow_rebuilt_terraform_data_resources(self) -> None:
        node_standard = resource_body(self.node, "aws_s3_object", "script_url_nodejs")
        python_standard = resource_body(self.python, "aws_s3_object", "script_url_python")
        self.assertRegex(node_standard, r"source_hash\s*=\s*terraform_data\.archive_url_nodejs\[each\.key\]\.id")
        self.assertRegex(python_standard, r"source_hash\s*=\s*terraform_data\.archive_url_python\[each\.key\]\.id")

        custom = resource_body(self.python, "aws_s3_object", "script_custom")
        self.assertRegex(
            custom,
            r"source_hash\s*=\s*try\(\s*terraform_data\.script_custom_node\[each\.key\]\.id\s*,\s*terraform_data\.script_custom_python\[each\.key\]\.id\s*\)",
        )


if __name__ == "__main__":
    unittest.main()
