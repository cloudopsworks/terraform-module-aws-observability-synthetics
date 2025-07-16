import os
import yaml
import time
import json
import urllib3
import certifi
from typing import Dict, Any, Tuple
import traceback

# AWS Synthetics imports
from aws_synthetics.common import synthetics_logger as logger

# Configure urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
http = urllib3.PoolManager(cert_reqs='CERT_REQUIRED', ca_certs=certifi.where())

def load_yaml_config(file_path: str) -> Dict[str, Any]:
    """
    Load and parse the YAML configuration file.

    Args:
        file_path: Path to the YAML file

    Returns:
        Dictionary containing the parsed YAML data

    Raises:
        Exception: If the file cannot be found or parsed
    """
    try:
        logger.info(f"Loading configuration from {file_path}")
        with open(file_path, 'r') as file:
            config = yaml.safe_load(file)
            logger.info("Configuration loaded successfully")
            return config
    except FileNotFoundError:
        logger.error(f"Configuration file not found: {file_path}")
        raise
    except yaml.YAMLError as e:
        logger.error(f"Error parsing YAML file: {str(e)}")
        raise
    except Exception as e:
        logger.error(f"Unexpected error loading configuration: {str(e)}")
        raise

def validate_request_config(request: Dict[str, Any]) -> None:
    """
    Validate a single request configuration.

    Args:
        request: Dictionary containing the request configuration

    Raises:
        ValueError: If the request configuration is invalid
    """
    # Check for required fields based on request type
    if 'url' not in request and 'script' not in request:
        raise ValueError("Either 'url' or 'script' must be provided in request configuration")

    # Validate method and body requirements
    if 'method' in request:
        method = request['method']
        if method in ['POST', 'PUT'] and 'body' not in request:
            raise ValueError(f"Body is required for {method} requests")

    # Validate assertions
    if 'assertions' in request:
        for assertion in request['assertions']:
            if 'type' not in assertion:
                raise ValueError("Assertion must have a 'type'")
            if 'operator' not in assertion:
                raise ValueError("Assertion must have an 'operator'")
            if 'value' not in assertion:
                raise ValueError("Assertion must have a 'value'")

def evaluate_assertion(assertion: Dict[str, Any], actual_value: Any) -> bool:
    """
    Evaluate a single assertion against an actual value.

    Args:
        assertion: Dictionary containing the assertion configuration
        actual_value: The actual value to compare against

    Returns:
        Boolean indicating whether the assertion passed

    Raises:
        ValueError: If the assertion type or operator is not supported
    """
    assertion_type = assertion['type']
    operator = assertion['operator']
    expected_value = assertion['value']

    logger.info(f"Evaluating {assertion_type} assertion: {actual_value} {operator} {expected_value}")

    if operator == "EQUALS":
        return actual_value == expected_value
    elif operator == "NOT_EQUALS":
        return actual_value != expected_value
    elif operator == "GREATER_THAN":
        return actual_value > expected_value
    elif operator == "LESS_THAN":
        return actual_value < expected_value
    else:
        raise ValueError(f"Unsupported operator: {operator}")


def get_canary_user_agent_string() -> str:
    """
    Get the user agent string for the canary.
    Replaces webdriver.get_canary_user_agent_string().

    Returns:
        User agent string for the canary
    """
    try:
        # Try to get user agent from AWS Synthetics if available
        try:
            from aws_synthetics.selenium import synthetics_webdriver
            return synthetics_webdriver.get_canary_user_agent_string()
        except (ImportError, AttributeError):
            pass

        # Fallback to a default user agent string
        return "AWS-Synthetics/1.0 (Python/urllib3)"
    except Exception as e:
        logger.warning(f"Error getting canary user agent: {str(e)}")
        return "AWS-Synthetics/1.0 (Python/urllib3)"


def make_http_request(url: str, method: str, headers: Dict[str, str], body: str, timeout: int) -> Tuple[int, str, Dict[str, Any], float]:
    """
    Make an HTTP request using urllib3.

    Args:
        url: URL to request
        method: HTTP method (GET, POST, PUT, DELETE)
        headers: Dictionary of headers
        body: Request body as string
        timeout: Request timeout in seconds

    Returns:
        Tuple containing (status_code, response_body, response_time)

    Raises:
        Exception: If there is an error making the request
    """
    logger.info(f"Making {method} request to {url}")

    # Create request object
    request = urllib3.request.Request(url, method=method)

    # Add headers
    for key, value in headers.items():
        request.add_header(key, value)

    # Add body if needed
    data = None
    if body and method in ['POST', 'PUT']:
        data = body.encode('utf-8')

    start_time = time.time()

    try:
        # Make the request
        with urllib3.request.urlopen(request, data=data, timeout=timeout) as response:
            status_code = response.status
            response_body = response.read().decode('utf-8')
            response_headers = dict(response.getheaders())
    except urllib3.error.HTTPError as e:
        # Handle HTTP errors (e.g., 404, 500)
        status_code = e.code
        response_body = e.read().decode('utf-8')
    except urllib3.error.URLError as e:
        # Handle connection errors
        raise Exception(f"Connection error: {str(e)}")
    except Exception as e:
        # Handle other errors
        raise Exception(f"Error making request: {str(e)}")

    end_time = time.time()
    response_time = end_time - start_time

    logger.info(f"Request completed with status {status_code} in {response_time:.2f} seconds")

    return status_code, response_body, response_headers, response_time

def process_url_request(request: Dict[str, Any]) -> bool:
    """
    Process a URL-based request.

    Args:
        request: Dictionary containing the request configuration

    Returns:
        Boolean indicating whether the request was successful

    Raises:
        Exception: If there is an error processing the request
    """
    url = request['url']
    method = request.get('method', 'GET')
    timeout = request.get('timeout', 30)
    headers = request.get('headers', {})
    body = request.get('body', "")
    assertions = request.get('assertions', [])
    retry_config = request.get('retry', {'count': 3, 'interval': 5})

    retry_count = retry_config.get('count', 3)
    retry_interval = retry_config.get('interval', 5)

    # Get the Synthetics canary user agent string
    if 'User-Agent' in headers and headers['User-Agent'] == "AWS Synthetics Canary":
        try:
            canary_user_agent = get_canary_user_agent_string()
            logger.info(f"Using Synthetics canary user agent: {canary_user_agent}")
            headers['User-Agent'] = canary_user_agent
        except Exception as e:
            logger.warning(f"Failed to get canary user agent string: {str(e)}")

    success = False
    response_time = 0
    status_code = None
    response_body = None
    response_headers = None

    for attempt in range(retry_count):
        try:
            logger.info(f"Request attempt {attempt+1}/{retry_count}: {method} {url}")

            # Execute request using urllib3
            try:
                status_code, response_body, response_headers, response_time = make_http_request(
                    url=url,
                    method=method,
                    headers=headers,
                    body=body,
                    timeout=timeout
                )
            except Exception as e:
                logger.error(f"HTTP request failed: {str(e)}")
                raise

            logger.info(f"Response status: {status_code}")

            # Save response data for later analysis
            response_data = {
                'url': url,
                'method': method,
                'status_code': status_code,
                'response_time': response_time,
                'response_headers': response_headers,
                'response_size': len(response_body) if isinstance(response_body, str) else 'unknown',
                'timestamp': time.time()
            }

            # Don't include potentially large response body in artifact
            if len(response_body) < 10000 and isinstance(response_body, str):
                response_data['response_body'] = response_body[:10000]

            # Process assertions
            all_assertions_passed = True
            for assertion in assertions:
                assertion_type = assertion['type']

                if assertion_type == 'STATUS_CODE':
                    actual_value = status_code
                elif assertion_type == 'RESPONSE_TIME':
                    actual_value = response_time
                else:
                    logger.warning(f"Unsupported assertion type: {assertion_type}")
                    continue

                assertion_result = evaluate_assertion(assertion, actual_value)
                all_assertions_passed = all_assertions_passed and assertion_result

                if not assertion_result:
                    logger.warning(f"Assertion failed: {assertion_type} with value {actual_value}")

            if all_assertions_passed:
                success = True
                break
            else:
                logger.warning(f"Attempt {attempt+1}/{retry_count} failed due to assertion failures")

        except Exception as e:
            logger.error(f"Error processing request: {str(e)}")
            logger.error(traceback.format_exc())

        # If this wasn't the last attempt, wait before retrying
        if attempt < retry_count - 1 and not success:
            logger.info(f"Waiting {retry_interval} seconds before retry")
            time.sleep(retry_interval)

    # Report metrics
    if success:
        logger.info(f"Request to {url} succeeded")
    else:
        error_message = f"Request to {url} failed after {retry_count} attempts"
        logger.error(error_message)

    return success

def handler(event, context):
    """
    Main handler function for the AWS Synthetics canary.

    Args:
        event: AWS Lambda event object
        context: AWS Lambda context object

    Returns:
        Dictionary containing the result of the canary run
    """
    # Initialize the result
    result = {
        'success': False,
        'error': None
    }

    try:
        logger.info("Starting AWS Synthetics canary")

        # Get configuration file path from environment or use default
        config_path = os.environ.get('CONFIG_PATH', '/tmp/config.yaml')

        # Load configuration
        config = load_yaml_config(config_path)

        # Validate configuration
        if 'requests' not in config or not config['requests']:
            raise ValueError("No requests found in configuration")

        # Validate each request
        for request in config['requests']:
            validate_request_config(request)

        # Process each request
        all_requests_succeeded = True
        for i, request in enumerate(config['requests']):
            logger.info(f"Processing request {i+1}/{len(config['requests'])}")

            # Execute the appropriate request handler based on the request type
            if 'url' in request:
                request_success = process_url_request(request)
                all_requests_succeeded = all_requests_succeeded and request_success
            elif 'script' in request:
                logger.warning("Script-based requests are not implemented in this version")
                all_requests_succeeded = False

        result['success'] = all_requests_succeeded

    except Exception as e:
        error_message = f"Error in canary execution: {str(e)}"
        logger.error(error_message)
        logger.error(traceback.format_exc())
        result['error'] = error_message

    finally:
        logger.info("AWS Synthetics canary completed")

    return result
