# Recommendation Service

The Recommendation service provides product recommendations based on the current shopping context. It suggests products from the catalog while excluding items already in the user's cart.

## Overview

- **Language**: Python 3.10.8
- **Framework**: gRPC
- **Port**: 8080
- **Algorithm**: Random sampling (demo implementation)
- **Dependencies**:
  - grpcio 1.59.0
  - grpcio-health-checking 1.59.0
  - OpenTelemetry for tracing
  - Google Cloud Profiler
  - python-json-logger 2.0.7

## Service Details

- **Service Name**: RecommendationService
- **RPC Methods**:
  - `ListRecommendations` - Returns up to 5 product recommendations
- **Health Check**: Supports gRPC health checking protocol
- **Dependencies**: Requires Product Catalog Service connection

### Recommendation Logic

The service uses a simple filtering and random selection algorithm:

1. **Fetch All Products**: Calls Product Catalog Service to get full product list
2. **Filter Exclusions**: Removes products already in user's cart/current view
3. **Random Selection**: Randomly samples up to 5 products from remaining items
4. **Return Results**: Returns list of recommended product IDs

**Note**: This is a demo implementation. Production systems would use:
- Machine learning models
- Collaborative filtering
- Content-based filtering
- Purchase history analysis
- User preferences

## Building Locally

### Prerequisites
- Python 3.10 or higher
- pip
- Docker (for containerization)
- Access to Product Catalog Service

### Create Virtual Environment

```bash
cd src/recommendationservice
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
# Set required environment variables
export PORT=8080
export PRODUCT_CATALOG_SERVICE_ADDR="localhost:3550"

# Disable profiler for local development
export DISABLE_PROFILER=1

# Run the service
python recommendation_server.py
```

The service will start on port 8080.

### Run Tests

```bash
python -m pytest tests/
```

## Building Docker Image

From the `src/recommendationservice/` directory:

```bash
docker build -t recommendationservice .
```

Run the container:

```bash
docker run -p 8080:8080 \
  -e PORT=8080 \
  -e PRODUCT_CATALOG_SERVICE_ADDR="productcatalog:3550" \
  -e DISABLE_PROFILER=1 \
  recommendationservice
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
| `PRODUCT_CATALOG_SERVICE_ADDR` | Product catalog service address | None | Yes |
| `DISABLE_PROFILER` | Disable Google Cloud Profiler | Not set | No |
| `ENABLE_TRACING` | Enable OpenTelemetry tracing | `0` | No |
| `COLLECTOR_SERVICE_ADDR` | OTLP collector address | `localhost:4317` | If tracing enabled |
| `GCP_PROJECT_ID` | Google Cloud project for profiler | None | For GCP profiling |
| `PYTHONUNBUFFERED` | Disable Python output buffering | `1` | No |

## CI/CD Pipeline

This service is automatically built and deployed using GitHub Actions.

### Workflow: RecommendationService CI/CD

**Trigger**: Push to `main` branch with changes in `src/recommendationservice/**`

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
- **Repository**: `recommendationservice`
- **Tags**: 
  - `latest` - Always points to the most recent build
  - `<build-number>` - Specific version tag

## Deployment to Kubernetes

The service is deployed to EKS cluster using the manifest in `deployments/recommendationservice.yml`.

### Manual Deployment

```bash
kubectl apply -f deployments/recommendationservice.yml
```

### Verify Deployment

```bash
kubectl get pods -l app=recommendationservice
kubectl logs -l app=recommendationservice
kubectl describe svc recommendationservice
```

## Development

### Project Structure

```
src/recommendationservice/
├── Dockerfile                  # Container image definition
├── requirements.in             # Top-level dependencies
├── requirements.txt            # Pinned dependencies (auto-generated)
├── recommendation_server.py    # Main service implementation
├── logger.py                   # JSON logger utility
├── client.py                   # gRPC client for testing
├── demo_pb2.py                # Generated protobuf code
├── demo_pb2_grpc.py           # Generated gRPC code
└── genproto.sh                # Script to regenerate protobuf
```

### Service Implementation

#### ListRecommendations Method

```python
def ListRecommendations(self, request, context):
    max_responses = 5
    
    # Fetch all products from catalog
    cat_response = product_catalog_stub.ListProducts(demo_pb2.Empty())
    product_ids = [x.id for x in cat_response.products]
    
    # Filter out products already shown/in cart
    filtered_products = list(set(product_ids) - set(request.product_ids))
    num_products = len(filtered_products)
    num_return = min(max_responses, num_products)
    
    # Random sample
    indices = random.sample(range(num_products), num_return)
    prod_list = [filtered_products[i] for i in indices]
    
    # Build response
    response = demo_pb2.ListRecommendationsResponse()
    response.product_ids.extend(prod_list)
    return response
```

#### Request Format

```python
{
  "user_id": "user-123",
  "product_ids": ["OLJCESPC7Z", "66VCHSJNUP"]  # Products to exclude
}
```

#### Response Format

```python
{
  "product_ids": ["1YMWWN1N4O", "L9ECAV7KIM", "9SIQT8TOJO", "2ZYFJ3GM2N", "6E92ZMYYFZ"]
}
```

### Custom JSON Logging

Uses structured JSON logging for better observability:

```python
from logger import getJSONLogger
logger = getJSONLogger('recommendationservice-server')

logger.info('[Recv ListRecommendations] product_ids=["PROD1", "PROD2"]')
# Output: {"timestamp": 1234567890, "severity": "INFO", "name": "recommendationservice-server", "message": "..."}
```

### Generating Protobuf Code

```bash
./genproto.sh
```

Regenerates:
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
python client.py
```

### Using grpcurl

Get recommendations:
```bash
grpcurl -plaintext -d '{
  "user_id": "user-123",
  "product_ids": ["OLJCESPC7Z", "66VCHSJNUP"]
}' localhost:8080 hipstershop.RecommendationService/ListRecommendations
```

Health check:
```bash
grpcurl -plaintext localhost:8080 grpc.health.v1.Health/Check
```

### Test Scenarios

#### Empty Cart (No Exclusions)
```bash
grpcurl -plaintext -d '{
  "user_id": "user-123",
  "product_ids": []
}' localhost:8080 hipstershop.RecommendationService/ListRecommendations
```
Returns 5 random products from full catalog.

#### Full Cart (All Products Excluded)
```bash
grpcurl -plaintext -d '{
  "user_id": "user-123",
  "product_ids": ["OLJCESPC7Z", "66VCHSJNUP", "1YMWWN1N4O", "L9ECAV7KIM", "9SIQT8TOJO", "2ZYFJ3GM2N", "6E92ZMYYFZ", "0PUK6V6EV0", "LS4PSXUNUM"]
}' localhost:8080 hipstershop.RecommendationService/ListRecommendations
```
Returns empty list if all products are excluded.

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
  "name": "recommendationservice-server",
  "message": "[Recv ListRecommendations] product_ids=['PROD1', 'PROD2', 'PROD3']"
}
```

### Tracing
- OpenTelemetry OTLP integration
- gRPC client and server instrumentation
- Distributed tracing across services
- Enable with `ENABLE_TRACING=1`

Traces include:
- Outbound call to Product Catalog Service
- Recommendation processing time
- Response generation

### Profiling
- Google Cloud Profiler support
- Stackdriver integration
- Retry logic for profiler initialization (3 attempts)
- Service: `recommendation_server`, Version: `1.0.0`
- Disable with `DISABLE_PROFILER=1`

### Health Checks
- Implements gRPC health checking protocol
- Status: SERVING
- Endpoint: `grpc.health.v1.Health/Check`

## Troubleshooting

### Port Already in Use
```bash
export PORT=8081
python recommendation_server.py
```

Or find what's using the port:
```bash
lsof -i :8080
netstat -an | grep 8080
```

### Product Catalog Connection Failed
```bash
# Check if product catalog is running
curl http://productcatalog:3550/_healthz

# Or verify with grpcurl
grpcurl -plaintext productcatalog:3550 grpc.health.v1.Health/Check

# Test connectivity
telnet productcatalog 3550
```

### Missing Dependencies
```bash
pip install --upgrade pip
pip install -r requirements.txt
```

### Profiler Initialization Failures
```bash
export DISABLE_PROFILER=1
python recommendation_server.py
```

### Python Version Issues
```bash
python --version
# Should be 3.10.x or higher
```

### Import Errors
```bash
# Ensure virtual environment is activated
source venv/bin/activate
pip list  # Verify packages are installed
```

### gRPC Connection Errors
```bash
# Verify service is running
netstat -an | grep 8080

# Enable verbose gRPC logging
export GRPC_VERBOSITY=DEBUG
export GRPC_TRACE=all
python recommendation_server.py
```

### Empty Recommendations
Check if:
1. Product Catalog Service is running and has products
2. Not all products are excluded in request
3. Network connectivity to Product Catalog Service

```bash
# Test product catalog directly
grpcurl -plaintext productcatalog:3550 hipstershop.ProductCatalogService/ListProducts
```

## Improving Recommendations

The current implementation uses random selection. Here are ways to improve it:

### 1. Collaborative Filtering

```python
def get_recommendations_collaborative(user_id, exclude_products):
    # Find similar users based on purchase history
    similar_users = find_similar_users(user_id)
    
    # Get products they purchased
    recommended_products = []
    for similar_user in similar_users:
        products = get_user_purchases(similar_user)
        recommended_products.extend(products)
    
    # Filter and return top N
    filtered = [p for p in recommended_products if p not in exclude_products]
    return Counter(filtered).most_common(5)
```

### 2. Content-Based Filtering

```python
def get_recommendations_content_based(product_ids, exclude_products):
    # Get categories of current products
    current_categories = get_product_categories(product_ids)
    
    # Find products in same categories
    similar_products = []
    for category in current_categories:
        products = get_products_by_category(category)
        similar_products.extend(products)
    
    # Filter and return
    filtered = [p for p in similar_products if p not in exclude_products]
    return filtered[:5]
```

### 3. Machine Learning Model

```python
import tensorflow as tf

def get_recommendations_ml(user_id, product_ids, exclude_products):
    # Load trained model
    model = tf.keras.models.load_model('recommendation_model.h5')
    
    # Prepare features
    user_features = get_user_features(user_id)
    product_features = get_product_features(product_ids)
    
    # Get predictions
    predictions = model.predict([user_features, product_features])
    
    # Get top 5 products
    top_products = get_top_n_products(predictions, n=5, exclude=exclude_products)
    return top_products
```

### 4. Hybrid Approach

```python
def get_recommendations_hybrid(user_id, product_ids, exclude_products):
    # Combine multiple strategies
    collab_recs = get_recommendations_collaborative(user_id, exclude_products)
    content_recs = get_recommendations_content_based(product_ids, exclude_products)
    ml_recs = get_recommendations_ml(user_id, product_ids, exclude_products)
    
    # Weighted combination
    combined = combine_recommendations([
        (collab_recs, 0.4),
        (content_recs, 0.3),
        (ml_recs, 0.3)
    ])
    
    return combined[:5]
```

## Performance Considerations

- **External Dependency**: Calls Product Catalog Service on every request
- **No Caching**: Products fetched fresh each time
- **Random Algorithm**: O(n) time complexity
- **Stateless**: No user session or history storage
- **ThreadPool**: Max 10 workers for concurrent requests

### Optimization Strategies

#### 1. Cache Product Catalog

```python
import time
from functools import lru_cache

@lru_cache(maxsize=1)
def get_cached_products():
    cat_response = product_catalog_stub.ListProducts(demo_pb2.Empty())
    return [x.id for x in cat_response.products]

# Invalidate cache periodically
def invalidate_cache_periodically():
    while True:
        time.sleep(300)  # 5 minutes
        get_cached_products.cache_clear()
```

#### 2. Connection Pooling

```python
from grpc import channel_ready_future

# Reuse gRPC channel
channel = grpc.insecure_channel(
    catalog_addr,
    options=[
        ('grpc.keepalive_time_ms', 10000),
        ('grpc.keepalive_timeout_ms', 5000)
    ]
)
```

#### 3. Async Processing

```python
import asyncio
import grpc.aio

async def get_recommendations_async(request):
    async with grpc.aio.insecure_channel(catalog_addr) as channel:
        stub = demo_pb2_grpc.ProductCatalogServiceStub(channel)
        response = await stub.ListProducts(demo_pb2.Empty())
        # Process recommendations
        return recommendations
```

## Security

- No authentication required (handled at gateway level)
- Input validation for product IDs
- No sensitive data stored
- Stateless operation
- Runs as non-root user in container

## Production Considerations

### Data Storage

For production, store user data and recommendation models:

```python
# User preferences
import redis
r = redis.Redis(host='redis', port=6379)

def get_user_preferences(user_id):
    prefs = r.get(f'user:{user_id}:preferences')
    return json.loads(prefs) if prefs else {}

# Recommendation cache
def cache_recommendations(user_id, recommendations):
    r.setex(
        f'user:{user_id}:recommendations',
        300,  # 5 minutes TTL
        json.dumps(recommendations)
    )
```

### A/B Testing

```python
import hashlib

def get_recommendation_strategy(user_id):
    # Consistent hashing for A/B testing
    hash_val = int(hashlib.md5(user_id.encode()).hexdigest(), 16)
    
    if hash_val % 100 < 50:
        return 'random'  # Control group
    else:
        return 'ml_based'  # Test group
```

### Metrics and Monitoring

```python
from prometheus_client import Counter, Histogram

recommendation_counter = Counter('recommendations_total', 'Total recommendations served')
recommendation_latency = Histogram('recommendation_latency_seconds', 'Recommendation latency')

@recommendation_latency.time()
def ListRecommendations(self, request, context):
    recommendation_counter.inc()
    # ... implementation
```

## Contributing

1. Make changes to the source code
2. Update requirements if needed: `pip-compile requirements.in`
3. Run tests: `python -m pytest`
4. Format code: `black recommendation_server.py`
5. Commit and push to trigger CI/CD pipeline

## Related Services

- **Product Catalog Service**: Source of product data (required)
- **Frontend**: Displays recommendations to users
- **Cart Service**: Provides excluded product IDs

## License

Apache License 2.0 - See LICENSE file for details.
