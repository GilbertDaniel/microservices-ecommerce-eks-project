# Load Generator Service

The Load Generator service simulates realistic user traffic to the e-commerce application using Locust. It continuously generates load by performing common user actions like browsing products, adding items to cart, and completing checkouts.

## Overview

- **Language**: Python 3.11.1
- **Framework**: Locust 2.17.0 (Load Testing Framework)
- **Target**: Frontend HTTP service
- **Mode**: Headless (no UI, continuous load generation)
- **Dependencies**:
  - locust 2.17.0 - Load testing framework
  - gevent 23.9.1 - Async networking
  - flask 2.3.3 - Web framework (for Locust web UI)
  - requests 2.31.0 - HTTP client

## Service Details

- **Service Type**: Load Testing Tool
- **Operating Mode**: Headless continuous load generation
- **Default Users**: 10 concurrent users
- **User Behavior**: Simulated shopping patterns with weighted tasks
- **Wait Time**: Random delay between 1-10 seconds per user action

### Simulated User Actions

The load generator simulates realistic e-commerce user behavior:

| Action | Weight | Description |
|--------|--------|-------------|
| `index` | 1 | Visit homepage |
| `setCurrency` | 2 | Change currency preference |
| `browseProduct` | 10 | View random product details (most common) |
| `addToCart` | 2 | Add random product to cart |
| `viewCart` | 3 | View shopping cart |
| `checkout` | 1 | Complete full checkout process |

**Note**: Higher weight = more frequent execution

### Test Products

Simulates browsing 9 different products:
- 0PUK6V6EV0
- 1YMWWN1N4O
- 2ZYFJ3GM2N
- 66VCHSJNUP
- 6E92ZMYYFZ
- 9SIQT8TOJO
- L9ECAV7KIM
- LS4PSXUNUM
- OLJCESPC7Z

## Building Locally

### Prerequisites
- Python 3.11 or higher
- pip
- Docker (for containerization)
- Access to frontend service

### Create Virtual Environment

```bash
cd src/loadgenerator
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

### Run Locally (Headless Mode)

```bash
# Set frontend address
export FRONTEND_ADDR="localhost:8080"

# Set number of concurrent users (optional)
export USERS=10

# Run in headless mode
locust --host="http://${FRONTEND_ADDR}" --headless -u "${USERS}"
```

### Run with Web UI (Interactive Mode)

```bash
locust --host="http://localhost:8080"
```

Then open http://localhost:8089 to access Locust web interface.

## Building Docker Image

From the `src/loadgenerator/` directory:

```bash
docker build -t loadgenerator .
```

Run the container:

```bash
docker run \
  -e FRONTEND_ADDR="frontend:80" \
  -e USERS=10 \
  loadgenerator
```

### Multi-stage Build

The Dockerfile uses a multi-stage build:
1. **Base stage**: Python 3.11.1-slim image
2. **Builder stage**: Installs Python packages to `/install` prefix
3. **Final stage**: Copies only installed packages and application code

**Benefits**:
- Smaller final image size (~150MB savings)
- Faster container startup
- Cleaner runtime environment

## Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `FRONTEND_ADDR` | Frontend service address (host:port) | None | Yes |
| `USERS` | Number of concurrent simulated users | `10` | No |
| `GEVENT_SUPPORT` | Enable gevent support in debugger | `True` | No |

## CI/CD Pipeline

This service is automatically built and deployed using GitHub Actions.

### Workflow: LoadGenerator CI/CD

**Trigger**: Push to `main` branch with changes in `src/loadgenerator/**`

**Pipeline Stages**:
1. **Checkout**: Clone the repository
2. **Build**: Build Docker image with Python 3.11
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
- **Repository**: `loadgenerator`
- **Tags**: 
  - `latest` - Always points to the most recent build
  - `<build-number>` - Specific version tag

## Deployment to Kubernetes

The service is deployed to EKS cluster using the manifest in `deployments/loadgenerator.yml`.

### Deployment Features

- **Init Container**: Waits for frontend service to be available before starting load generation
- **Security Context**: Runs as non-root user (UID/GID 1000)
- **Resource Limits**: 
  - Requests: 300m CPU, 256Mi memory
  - Limits: 500m CPU, 512Mi memory
- **Restart Policy**: Always (continuous load generation)

### Manual Deployment

```bash
kubectl apply -f deployments/loadgenerator.yml
```

### Verify Deployment

```bash
kubectl get pods -l app=loadgenerator
kubectl logs -l app=loadgenerator
kubectl describe deployment loadgenerator
```

### View Load Generator Logs

```bash
# Follow logs
kubectl logs -f deployment/loadgenerator

# View recent logs
kubectl logs --tail=100 deployment/loadgenerator
```

### Scale Load Generation

```bash
# Increase concurrent users
kubectl set env deployment/loadgenerator USERS=50

# Scale number of pods (for even more load)
kubectl scale deployment/loadgenerator --replicas=3
```

## Development

### Project Structure

```
src/loadgenerator/
├── Dockerfile          # Container image definition
├── requirements.in     # Top-level dependencies
├── requirements.txt    # Pinned dependencies (auto-generated)
└── locustfile.py      # Locust test scenarios
```

### Locust File Structure

```python
# Product catalog
products = ['0PUK6V6EV0', '1YMWWN1N4O', ...]

# Task functions
def index(l): ...
def browseProduct(l): ...
def addToCart(l): ...
def checkout(l): ...

# User behavior class
class UserBehavior(TaskSet):
    tasks = {index: 1, browseProduct: 10, ...}

# User class
class WebsiteUser(HttpUser):
    tasks = [UserBehavior]
    wait_time = between(1, 10)
```

### Adding New User Actions

```python
# 1. Define the action function
def newAction(l):
    l.client.get("/new-endpoint")

# 2. Add to UserBehavior tasks with weight
class UserBehavior(TaskSet):
    tasks = {
        index: 1,
        newAction: 5,  # Weight 5
        # ... other tasks
    }
```

### Customizing User Behavior

#### Adjust Task Weights
```python
tasks = {
    index: 1,          # Low frequency
    browseProduct: 20, # Increase browsing
    checkout: 5        # More checkouts
}
```

#### Change Wait Time
```python
# Faster users (0.5-2 seconds between actions)
wait_time = between(0.5, 2)

# Slower users (5-30 seconds)
wait_time = between(5, 30)

# Constant wait time
wait_time = constant(3)
```

#### Add New Products
```python
products = [
    '0PUK6V6EV0',
    'NEW_PRODUCT_1',
    'NEW_PRODUCT_2',
]
```

### Testing Specific Scenarios

#### High Traffic Load Test
```python
# Modify for stress testing
class WebsiteUser(HttpUser):
    wait_time = between(0.1, 0.5)  # Minimal delay
    tasks = [UserBehavior]
```

#### Checkout-Heavy Load
```python
tasks = {
    checkout: 10,      # Primary focus
    addToCart: 5,
    browseProduct: 3,
}
```

### Adding New Dependencies

```bash
# Add to requirements.in
echo "new-package==1.0.0" >> requirements.in

# Recompile
pip-compile requirements.in

# Install
pip install -r requirements.txt
```

## Locust Web UI (Development)

For interactive load testing during development:

### Start with Web UI

```bash
locust --host="http://localhost:8080"
```

### Access Dashboard

Open browser to: http://localhost:8089

### Features Available
- Start/stop load tests dynamically
- Adjust user count in real-time
- View request statistics (RPS, response times)
- See failure rates and error messages
- Export test results
- View charts and graphs

### Web UI Configuration

```bash
# Custom port
locust --host="http://localhost:8080" --web-port 8090

# Enable basic auth
locust --host="http://localhost:8080" \
  --web-auth username:password
```

## Monitoring Load Generation

### Locust Statistics

When running, Locust outputs statistics:
```
Type     Name                          # reqs   # fails  Avg    Min    Max  Median  req/s failures/s
GET      /                             100      0        45     12     234  43      10.5   0.0
GET      /product/0PUK6V6EV0           250      1        89     23     456  87      26.3   0.1
POST     /cart                         50       0        123    45     567  120     5.3    0.0
POST     /cart/checkout                10       0        456    234    890  450     1.1    0.0
```

### Key Metrics

- **# reqs**: Total requests made
- **# fails**: Failed requests
- **Avg/Min/Max**: Response times (ms)
- **req/s**: Requests per second
- **failures/s**: Failures per second

### Viewing Logs

```bash
# Kubernetes
kubectl logs -f deployment/loadgenerator

# Docker
docker logs -f <container-id>

# Local
# Logs to stdout automatically
```

## Troubleshooting

### Frontend Not Accessible

```bash
# Check if frontend is running
curl http://frontend:80/_healthz

# Or from loadgenerator pod
kubectl exec deployment/loadgenerator -- wget -qO- http://frontend:80/_healthz
```

### Init Container Fails

The init container checks frontend availability:
```bash
# View init container logs
kubectl logs -f deployment/loadgenerator -c frontend-check

# Common issues:
# - Frontend not deployed yet
# - Incorrect FRONTEND_ADDR
# - Network policies blocking traffic
```

### High Failure Rates

```bash
# Check frontend logs
kubectl logs deployment/frontend

# Check backend service logs
kubectl logs deployment/productcatalog
kubectl logs deployment/cart

# Verify resource limits
kubectl top pods
```

### Memory Issues

```bash
# Increase memory limits in deployment
kubectl set resources deployment/loadgenerator \
  --limits=memory=1Gi --requests=memory=512Mi

# Or reduce concurrent users
kubectl set env deployment/loadgenerator USERS=5
```

### Connection Timeouts

```bash
# Increase Locust timeout (in locustfile.py)
class WebsiteUser(HttpUser):
    connection_timeout = 30  # seconds
    network_timeout = 30
```

### Python Errors

```bash
# Check Python version
python --version  # Should be 3.11+

# Reinstall dependencies
pip install --force-reinstall -r requirements.txt

# Check for syntax errors
python -m py_compile locustfile.py
```

### Docker Build Issues

```bash
# Clear Docker cache
docker build --no-cache -t loadgenerator .

# Check base image
docker pull python:3.11.1-slim
```

## Performance Testing Best Practices

### Gradual Ramp-Up

Don't start with maximum load:
```bash
# Start with 10 users
locust --host="http://frontend" --headless -u 10

# After stabilization, increase
# Adjust USERS env var in Kubernetes
```

### Monitor Backend Services

While load testing, monitor:
- Frontend response times
- Backend service CPU/memory
- Database connections (if applicable)
- Network throughput
- Error rates

### Realistic Scenarios

Current scenarios are realistic for e-commerce:
- 10x more browsing than purchasing
- Multiple products viewed per session
- Cart abandonment (view cart without checkout)

### Load Test Duration

For meaningful results:
- **Smoke test**: 5-10 minutes, low users (5-10)
- **Load test**: 30-60 minutes, expected load
- **Stress test**: 1-2 hours, 2-3x expected load
- **Soak test**: 4-8 hours, normal load

## Advanced Configuration

### Custom Locust Options

Edit Dockerfile ENTRYPOINT to add options:
```dockerfile
ENTRYPOINT locust \
  --host="http://${FRONTEND_ADDR}" \
  --headless \
  -u "${USERS:-10}" \
  --spawn-rate 2 \              # Add 2 users per second
  --run-time 1h \               # Run for 1 hour then stop
  --csv results \               # Export CSV results
  --html report.html            # Generate HTML report
```

### Distributed Load Generation

For massive load, run multiple Locust workers:

```bash
# Master node
locust --master --host="http://frontend"

# Worker nodes (multiple pods/machines)
locust --worker --master-host=<master-ip>
```

### Custom Success Criteria

```python
# In locustfile.py
from locust import events

@events.request.add_listener
def on_request(request_type, name, response_time, response_length, **kwargs):
    if response_time > 2000:  # 2 second threshold
        print(f"Slow request: {name} took {response_time}ms")
```

## CI/CD Integration

### Automated Load Tests

Add to your pipeline:
```yaml
# Run load test after deployment
- name: Load Test
  run: |
    kubectl apply -f deployments/loadgenerator.yml
    sleep 300  # Run for 5 minutes
    kubectl logs deployment/loadgenerator > load-test-results.log
    kubectl delete -f deployments/loadgenerator.yml
```

### Performance Regression Testing

Compare results between deployments:
```bash
# Save baseline
locust --host="http://frontend" --headless -u 50 \
  --run-time 10m --csv baseline

# Compare after changes
locust --host="http://frontend" --headless -u 50 \
  --run-time 10m --csv current

# Analyze differences
diff baseline_stats.csv current_stats.csv
```

## Security Considerations

- **Non-root User**: Runs as UID 1000 (non-privileged)
- **Read-only Filesystem**: Security context enforces read-only root filesystem
- **No Privileges**: All capabilities dropped
- **Resource Limits**: Prevents resource exhaustion
- **Network Isolation**: Only needs access to frontend service

## Contributing

1. Make changes to `locustfile.py`
2. Test locally: `locust --host="http://localhost:8080"`
3. Update dependencies if needed: `pip-compile requirements.in`
4. Build and test Docker image
5. Commit and push to trigger CI/CD pipeline

## Related Services

- **Frontend**: Target service for load generation
- **All Backend Services**: Indirectly tested through frontend

## License

Apache License 2.0 - See LICENSE file for details.
