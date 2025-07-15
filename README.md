# terraform-module-template
Terraform Module Template, this templates makes use of GitHub actions in order to perform publishing on Terraform Registry
# AWS Synthetics Canary with Python and Selenium

This project implements an AWS Synthetics canary script using Python and Selenium that processes a YAML configuration file to perform web monitoring and testing.

## Features

- Processes YAML configuration for defining canary test requests
- Supports various HTTP methods (GET, POST, PUT, DELETE)
- Configurable headers and request body
- Custom assertions for status code, response time, etc.
- Retry mechanism with configurable attempts and intervals
- Comprehensive error handling and logging
- Screenshot capture on success, failure, and errors

## Configuration Format

The canary expects a YAML configuration file with the following structure:

```yaml
requests:
  - url: "https://example.com"    # (optional) URL for the canary, required if type is URL
    script: "path/to/script.js"   # (optional) Path to the script for the canary, required if type is SCRIPT
    timeout: 30                   # (optional) Timeout in seconds for the request, defaults to 30 seconds
    method: GET | POST | PUT | DELETE # (optional) HTTP method for the request, defaults to GET
    headers:                     # (optional) Headers for the request, defaults to empty map
      Content-Type: "application/json"
      User-Agent: "AWS Synthetics Canary"  # Will be replaced with actual canary user agent string
    body: "request body"         # (optional) Body for the request, required if method is POST or PUT
    assertions:                # (optional) Assertions for the canary, defaults to empty list
      - type: STATUS_CODE # (required) Type of assertion, e.g., STATUS_CODE, RESPONSE_TIME, etc.
        operator: EQUALS | NOT_EQUALS | GREATER_THAN | LESS_THAN # (required) Operator for the assertion
        value: 200 # (required) Value for the assertion, e.g., expected status code
    retry:
      count: 3 # (optional) Number of retry attempts, defaults to 3
      interval: 5 # (optional) Interval in seconds between retries, defaults to 5 seconds
```

## Deployment

### Prerequisites

- AWS account with appropriate permissions
- AWS CLI configured with your credentials
- Terraform (if using the included Terraform configuration)

### Setup

1. Create a YAML configuration file with your canary test requests
2. Upload the Python script to an S3 bucket or use AWS Synthetic's inline code capability
3. Deploy the canary using AWS CloudFormation, Terraform, or the AWS Management Console

### Environment Variables

- `CONFIG_PATH`: Path to the YAML configuration file (default: `/tmp/config.yaml`)

## Monitoring and Alerting

The canary automatically sends metrics to Amazon CloudWatch. You can set up alarms based on these metrics to be notified of failures.

## Development

### Testing Locally

To test the script locally before deploying to AWS:

1. Install the dependencies:
   ```
   pip install selenium pyyaml
   ```

2. Create a wrapper script that emulates the AWS Synthetics environment

## License

This project is licensed under the Apache License 2.0 - see the LICENSE file for details.