# Email Service

The Email service sends order confirmation emails to customers after successful checkout. Currently operates in dummy mode (logs email requests without sending actual emails).

## Overview

- **Language**: Python 3.10.8
- **Framework**: gRPC
- **Port**: 8080
- **Template Engine**: Jinja2
- **Dependencies**:
  - grpcio 1.59.0
  - grpcio-health-checking 1.59.0
  - Jinja2 3.1.2 for HTML templates
  - OpenTelemetry for tracing
  - Google Cloud Profiler
  - python-json-logger 2.0.7

## Service Details

- **Service Name**: EmailService
- **RPC Methods**:
  - `SendOrderConfirmation` - Sends order confirmation email
- **Health Check**: Supports gRPC health checking protocol
- **Operating Modes**:
  - **Dummy Mode** (current): Logs email requests without sending
  - **Production Mode**: Sends actual emails (not yet implemented)

## Building Locally

### Prerequisites
- Python 3.10 or higher
- pip
- Docker (for containerization)

### Create Virtual Environment

```bash
cd src/emailservice
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

### Install Dependencies

```bash
pip install -r requirements.txt
```

Or compile from requirements.in:
```bash
pip install pip-tools
pip-compile requirements.in
pip install -r requirements.txt
```

### Run Locally

```bash
# Set the port (default: 8080)
export PORT=8080

# Disable profiler for local development
export DISABLE_PROFILER=1

# Run the service in dummy mode
python email_server.py
```

The service will start on port 8080 in dummy mode.

### Run Tests

```bash
python -m pytest tests/
```

## Building Docker Image

From the `src/emailservice/` directory:

```bash
docker build -t emailservice .
```

Run the container:

```bash
docker run -p 8080:8080 \
  -e PORT=8080 \
  -e DISABLE_PROFILER=1 \
  emailservice
```

### Multi-stage Build

The Dockerfile uses a multi-stage build:
1. **Base stage**: Python 3.10.8-slim image
2. **Builder stage**: Installs system dependencies (wget, g++) and Python packages
3. **Final stage**: Copies only Python packages and application code

**Benefits**: 
- Removes build tools from final image (~200MB savings)
- Faster container startup
- Smaller attack surface

## Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `PORT` | gRPC server port | `8080` | No |
| `DISABLE_PROFILER` | Disable Google Cloud Profiler | Not set | No |
| `ENABLE_PROFILER` | Enable profiler (deprecated, use DISABLE_PROFILER) | `1` | No |
| `ENABLE_TRACING` | Enable OpenTelemetry tracing | `0` | No |
| `COLLECTOR_SERVICE_ADDR` | OTLP collector address | `localhost:4317` | If tracing enabled |
| `GCP_PROJECT_ID` | Google Cloud project for profiler | None | For GCP profiling |
| `PYTHONUNBUFFERED` | Disable Python output buffering | `1` | No |

## CI/CD Pipeline

This service is automatically built and deployed using GitHub Actions.

### Workflow: EmailService CI/CD

**Trigger**: Push to `main` branch with changes in `src/emailservice/**`

**Pipeline Stages**:
1. **Checkout**: Clone the repository
2. **Build**: Build Docker image with Python 3.10
3. **Push to ECR**: Tag and push to Amazon ECR
4. **Update Manifests**: Update Kubernetes deployment with new image tag
5. **Commit**: Commit and push updated manifests

### Required Secrets

Configure these in GitHub repository settings:
- `AWS_ACCESS_KEY_ID` - AWS credentials for ECR access
- `AWS_SECRET_ACCESS_KEY` - AWS secret key
- `GITHUB_TOKEN` - Automatically provided by GitHub Actions

### ECR Configuration

- **Registry**: `947985349339.dkr.ecr.us-east-1.amazonaws.com`
- **Repository**: `emailservice`
- **Tags**: 
  - `latest` - Always points to the most recent build
  - `<build-number>` - Specific version tag

## Deployment to Kubernetes

The service is deployed to EKS cluster using the manifest in `deployments/emailservice.yml`.

### Manual Deployment

```bash
kubectl apply -f deployments/emailservice.yml
```

### Verify Deployment

```bash
kubectl get pods -l app=emailservice
kubectl logs -l app=emailservice
kubectl describe svc emailservice
```

## Development

### Project Structure

```
src/emailservice/
├── Dockerfile              # Container image definition
├── requirements.in         # Top-level dependencies
├── requirements.txt        # Pinned dependencies (auto-generated)
├── email_server.py         # Main service implementation
├── email_client.py         # gRPC client for testing
├── logger.py               # JSON logger utility
├── demo_pb2.py            # Generated protobuf code
├── demo_pb2_grpc.py       # Generated gRPC code
├── genproto.sh            # Script to regenerate protobuf
└── templates/             # Email templates
    └── confirmation.html   # Order confirmation template
```

### Email Template

The service uses Jinja2 templates for email rendering. The confirmation email template includes:
- Order ID
- Shipping address
- Order items with quantities
- Formatted prices

Example template rendering:
```python
from jinja2 import Environment, FileSystemLoader

env = Environment(loader=FileSystemLoader('templates'))
template = env.get_template('confirmation.html')
html = template.render(order=order_data)
```

### Operating Modes

#### Dummy Mode (Current)
```python
class DummyEmailService(BaseEmailService):
  def SendOrderConfirmation(self, request, context):
    logger.info('Email request received for {}'.format(request.email))
    return demo_pb2.Empty()
```

Logs the request without sending actual emails. Useful for:
- Development and testing
- Demo environments
- Cost savings (no email service required)

#### Production Mode (Not Implemented)
```python
class EmailService(BaseEmailService):
  # Requires email client implementation
  # Could integrate with SendGrid, AWS SES, etc.
```

### Custom JSON Logging

The service uses structured JSON logging for better observability:

```python
from logger import getJSONLogger
logger = getJSONLogger('emailservice-server')

logger.info('Email sent successfully')
# Output: {"timestamp": 1234567890, "severity": "INFO", "name": "emailservice-server", "message": "Email sent successfully"}
```

### Generating Protobuf Code

```bash
./genproto.sh
```

This regenerates:
- `demo_pb2.py` - Message definitions
- `demo_pb2_grpc.py` - Service stubs

### Adding New Dependencies

1. Add to `requirements.in`:
```
new-package==1.0.0
```

2. Recompile:
```bash
pip-compile requirements.in
pip install -r requirements.txt
```

## Testing the Service

### Using the Client

```bash
python email_client.py
```

### Using grpcurl

Send order confirmation:
```bash
grpcurl -plaintext -d '{
  "email": "customer@example.com",
  "order": {
    "order_id": "ORD-12345",
    "shipping_tracking_id": "SHIP-67890",
    "shipping_cost": {
      "currency_code": "USD",
      "units": 5,
      "nanos": 990000000
    },
    "shipping_address": {
      "street_address": "123 Main St",
      "city": "San Francisco",
      "state": "CA",
      "country": "USA",
      "zip_code": "94105"
    },
    "items": [
      {
        "item": {
          "product_id": "PROD-001",
          "quantity": 2
        },
        "cost": {
          "currency_code": "USD",
          "units": 29,
          "nanos": 990000000
        }
      }
    ]
  }
}' localhost:8080 hipstershop.EmailService/SendOrderConfirmation
```

### Health Check

```bash
grpcurl -plaintext localhost:8080 grpc.health.v1.Health/Check
```

## Observability

### Logging
- Structured JSON logging with python-json-logger
- Log levels: INFO, WARNING, ERROR
- Google Cloud-compatible severity field
- Timestamp in Unix epoch format

Example log output:
```json
{
  "timestamp": 1700123456.789,
  "severity": "INFO",
  "name": "emailservice-server",
  "message": "A request to send order confirmation email to customer@example.com has been received."
}
```

### Tracing
- OpenTelemetry OTLP integration
- gRPC server instrumentation
- Distributed tracing support
- Enable with `ENABLE_TRACING=1`

### Profiling
- Google Cloud Profiler support
- Stackdriver integration
- Retry logic for profiler initialization (3 attempts)
- Disable with `DISABLE_PROFILER=1`

### Health Checks
- Implements gRPC health checking protocol
- Status: SERVING (always available in dummy mode)
- Endpoint: `grpc.health.v1.Health/Check`

## Troubleshooting

### Port Already in Use
If port 8080 is already in use:
```bash
export PORT=8081
python email_server.py
```

Or find what's using the port:
```bash
lsof -i :8080
netstat -an | grep 8080
```

### Missing Dependencies
Reinstall all dependencies:
```bash
pip install --upgrade pip
pip install -r requirements.txt
```

### Template Not Found Error
Ensure templates directory exists:
```bash
ls templates/confirmation.html
```

The templates directory must be in the working directory where you run the server.

### Profiler Initialization Failures
Disable profiler for local development:
```bash
export DISABLE_PROFILER=1
python email_server.py
```

### Python Version Issues
Check your Python version:
```bash
python --version
# Should be 3.10.x or higher
```

### Import Errors
Ensure virtual environment is activated:
```bash
source venv/bin/activate
pip list  # Verify packages are installed
```

### gRPC Connection Errors
Verify service is running:
```bash
netstat -an | grep 8080
```

Enable verbose gRPC logging:
```bash
export GRPC_VERBOSITY=DEBUG
export GRPC_TRACE=all
python email_server.py
```

## Email Template Customization

### Editing the Template

The confirmation email template is in `templates/confirmation.html`:

```html
<h2>Your Order Confirmation</h2>
<p>Thanks for shopping with us!<p>
<h3>Order ID</h3>
<p>{{ order.order_id }}</p>
```

### Available Variables

- `order.order_id` - Unique order identifier
- `order.shipping_tracking_id` - Shipping tracking number
- `order.shipping_cost` - Shipping cost (Money type)
- `order.shipping_address` - Complete address object
- `order.items` - List of order items with costs

### Template Testing

Test template rendering without running the full service:
```python
from jinja2 import Environment, FileSystemLoader

env = Environment(loader=FileSystemLoader('templates'))
template = env.get_template('confirmation.html')

# Test data
order = {
    'order_id': 'TEST-123',
    'items': [{'item': {'product_id': 'PROD-001'}}]
}

html = template.render(order=order)
print(html)
```

## Implementing Production Email Sending

To implement actual email sending, you can integrate with:

### AWS SES (Simple Email Service)
```python
import boto3

ses_client = boto3.client('ses', region_name='us-east-1')

def send_email(email_address, content):
    response = ses_client.send_email(
        Source='noreply@example.com',
        Destination={'ToAddresses': [email_address]},
        Message={
            'Subject': {'Data': 'Order Confirmation'},
            'Body': {'Html': {'Data': content}}
        }
    )
```

### SendGrid
```python
from sendgrid import SendGridAPIClient
from sendgrid.helpers.mail import Mail

def send_email(email_address, content):
    message = Mail(
        from_email='noreply@example.com',
        to_emails=email_address,
        subject='Order Confirmation',
        html_content=content
    )
    sg = SendGridAPIClient(os.environ.get('SENDGRID_API_KEY'))
    response = sg.send(message)
```

### SMTP
```python
import smtplib
from email.mime.text import MIMEText

def send_email(email_address, content):
    msg = MIMEText(content, 'html')
    msg['Subject'] = 'Order Confirmation'
    msg['From'] = 'noreply@example.com'
    msg['To'] = email_address
    
    with smtplib.SMTP('smtp.gmail.com', 587) as server:
        server.starttls()
        server.login('user', 'password')
        server.send_message(msg)
```

## Performance Considerations

- **ThreadPoolExecutor**: Max 10 workers for concurrent requests
- **Template Caching**: Jinja2 templates loaded once at startup
- **Dummy Mode**: Zero latency (no external API calls)
- **Production Mode**: Latency depends on email service provider

## Security

- No authentication required (handled at gateway level)
- Input validation for email addresses
- Template auto-escaping to prevent XSS
- Runs as non-root user in container
- No sensitive data logged

## Future Enhancements

- [ ] Implement production email sending
- [ ] Add email queue for retry logic
- [ ] Support multiple email templates
- [ ] Add email delivery tracking
- [ ] Implement rate limiting
- [ ] Add email validation
- [ ] Support attachments (receipts, invoices)
- [ ] Multi-language templates

## Contributing

1. Make changes to the source code
2. Update requirements if needed: `pip-compile requirements.in`
3. Run tests: `python -m pytest`
4. Format code: `black email_server.py`
5. Commit and push to trigger CI/CD pipeline

## License

Apache License 2.0 - See LICENSE file for details.
