#!/usr/bin/env python3
"""Validate sanitized generic fixture intent without Terraform/AWS access."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "tests" / "fixtures"
PRIVATE_MARKERS = (
    "/users/",
    "\\users\\",
    "/work/",
    "terraform.tfvars",
    "secret-value",
)


def load(name: str) -> dict:
    with (FIXTURES / name).open(encoding="utf-8") as fh:
        return json.load(fh)


def walk_strings(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for item in value.values():
            yield from walk_strings(item)
    elif isinstance(value, list):
        for item in value:
            yield from walk_strings(item)


def canaries(fixture: dict):
    for group in fixture.get("groups", []):
        for canary in group.get("canaries", []):
            yield group, canary


def assert_no_private_markers(*fixtures: dict) -> None:
    for fixture in fixtures:
        for value in walk_strings(fixture):
            lowered = value.lower()
            for marker in PRIVATE_MARKERS:
                assert marker not in lowered, f"private marker leaked into fixture: {marker}"


def main() -> None:
    generic = load("generic-consumers.tfvars.json")
    strict_invalid = load("strict-invalid-assertion.tfvars.json")
    assert_no_private_markers(generic, strict_invalid)

    grouped = {group["name"]: group for group in generic["groups"]}
    assert set(grouped) == {"consumer-a", "consumer-b", "consumer-c"}

    consumer_a_types = {canary["requests_type"] for canary in grouped["consumer-a"]["canaries"]}
    assert {"BROWSER_SCRIPT", "SCRIPT"}.issubset(consumer_a_types)
    assert any("request_script_ref" in canary for canary in grouped["consumer-a"]["canaries"])
    assert any("request_script" in canary for canary in grouped["consumer-a"]["canaries"])
    assert any(canary.get("handler") == "inline_handler.handler" for canary in grouped["consumer-a"]["canaries"])

    consumer_b = grouped["consumer-b"]
    assert consumer_b["vpc"]["enabled"] is True
    assert consumer_b["default_run_config"]["tracing"] is True
    assert consumer_b["canaries"][0]["requests_type"] == "TRACEURL"

    consumer_c_canaries = {canary["name"]: canary for canary in grouped["consumer-c"]["canaries"]}
    post_request = consumer_c_canaries["private-post"]["requests"][0]
    assert consumer_c_canaries["private-post"]["requests_type"] == "HTTP_API"
    assert post_request["method"] == "POST"
    assert "REDACTED" in post_request["body"]

    legacy = consumer_c_canaries["legacy-invalid-assertion"]
    assert legacy["validation_mode"] == "legacy"
    assert legacy["requests"][0]["assertions"][0]["type"] == "HEADER_CONTAINS"

    strict_canary = next(canaries(strict_invalid))[1]
    assert strict_canary["requests_type"] == "HTTP"
    assert strict_canary["requests"][0]["assertions"][0]["type"] == "HEADER_CONTAINS"

    assert generic["artifact_output_prefix"] == "synthetics/artifacts"
    assert generic["code_package_prefix"] == "synthetics/packages"
    assert generic["canary_defaults"]["schedule_retry"]["max_retries"] == 1


if __name__ == "__main__":
    main()
