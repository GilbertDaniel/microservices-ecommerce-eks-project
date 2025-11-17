# Product Catalog Service

The Product Catalog service provides the product inventory for the e-commerce application. It serves product listings, product details, and search functionality from a JSON-based catalog.

## Overview

- **Language**: Go 1.19+
- **Framework**: gRPC
- **Port**: 3550
- **Data Source**: `products.json` file
- **Dependencies**:
  - gRPC 1.58.3
  - OpenTelemetry for distributed tracing
  - Google Cloud Profiler
  - Logrus for structured logging

## Service Details

- **Service Name**: ProductCatalogService
- **RPC Methods**:
  - `ListProducts` - Returns all products in the catalog
  - `GetProduct` - Returns details for a specific product by ID
  - `SearchProducts` - Searches products by name or description
- **Health Check**: Supports gRPC health checking protocol
- **Product Count**: 9 products (configurable via products.json)

### Product Categories

- **Accessories**: Sunglasses, Watch
- **Clothing**: Tank Top, T-Shirt, Sweatshirt
- **Footwear**: Loafers, Sneakers
- **Home & Garden**: Air Plant, Terrarium

## Building Locally

### Prerequisites
- Go 1.19 or higher
- Docker (for containerization)

### Restore Dependencies

```bash
cd src/productcatalogservice
go mod download
```

Or use vendor directory:
```bash
go mod vendor
```

### Build the Application

```bash
go build -o productcatalogservice .
```

### Run Locally

```bash
# Set the port (default: 3550)
export PORT=3550

# Disable profiler for local development
export DISABLE_PROFILER=1

# Run the service
./productcatalogservice
```

The service will start on port 3550.

### Run Tests

```bash
go test ./...
```

## Building Docker Image

From the `src/productcatalogservice/` directory:

```bash
docker build -t productcatalogservice .
```

Run the container:

```bash
docker run -p 3550:3550 \
  -e PORT=3550 \
  -e DISABLE_PROFILER=1 \
  productcatalogservice
```

### Multi-stage Build

The Dockerfile uses a multi-stage build:
1. **Builder stage**: `golang:1.21.3-alpine` with build tools (ca-certificates, git, build-base)
2. **Release stage**: `alpine:3.18.4` with only runtime dependencies and compiled binary

**Benefits**:
- Reduces image size by ~500MB
- Removes build tools from final image
- Includes only necessary files (binary + products.json)

**Build Arguments**:
- `SKAFFOLD_GO_GCFLAGS` - Compiler flags for debugging

## Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `PORT` | gRPC server port | `3550` | No |
| `DISABLE_PROFILER` | Disable Google Cloud Profiler | Not set | No |
| `ENABLE_TRACING` | Enable OpenTelemetry tracing | `0` | No |
| `COLLECTOR_SERVICE_ADDR` | OTLP collector address | None | If tracing enabled |
| `EXTRA_LATENCY` | Inject artificial latency (e.g., "5.5s") | `0` | No |
| `GOTRACEBACK` | Go runtime traceback level | `single` | No |

## CI/CD Pipeline

This service is automatically built and deployed using GitHub Actions.

### Workflow: ProductCatalogService CI/CD

**Trigger**: Push to `main` branch with changes in `src/productcatalogservice/**`

**Pipeline Stages**:
1. **Checkout**: Clone the repository
2. **Build**: Build Docker image with Go 1.21
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
- **Repository**: `productcatalogservice`
- **Tags**: 
  - `latest` - Always points to the most recent build
  - `<build-number>` - Specific version tag

## Deployment to Kubernetes

The service is deployed to EKS cluster using the manifest in `deployments/productcatalogservice.yml`.

### Manual Deployment

```bash
kubectl apply -f deployments/productcatalogservice.yml
```

### Verify Deployment

```bash
kubectl get pods -l app=productcatalogservice
kubectl logs -l app=productcatalogservice
kubectl describe svc productcatalogservice
```

## Development

### Project Structure

```
src/productcatalogservice/
├── Dockerfile              # Container image definition
├── go.mod                  # Go module dependencies
├── go.sum                  # Dependency checksums
├── server.go              # Main server setup and initialization
├── product_catalog.go     # Service implementation
├── product_catalog_test.go # Unit tests
├── products.json          # Product catalog data
├── genproto/              # Generated protobuf code
└── genproto.sh           # Script to regenerate protobuf
```

### Product Data Structure

Each product in `products.json`:

```json
{
  "id": "OLJCESPC7Z",
  "name": "Sunglasses",
  "description": "Add a modern touch to your outfits...",
  "picture": "/static/img/products/sunglasses.jpg",
  "priceUsd": {
    "currencyCode": "USD",
    "units": 19,
    "nanos": 990000000
  },
  "categories": ["accessories"]
}
```

### RPC Method Implementations

#### ListProducts
```go
func (p *productCatalog) ListProducts(context.Context, *pb.Empty) (*pb.ListProductsResponse, error)
```
Returns all products from the catalog.

#### GetProduct
```go
func (p *productCatalog) GetProduct(ctx context.Context, req *pb.GetProductRequest) (*pb.Product, error)
```
Returns a single product by ID. Returns `NotFound` error if product doesn't exist.

#### SearchProducts
```go
func (p *productCatalog) SearchProducts(ctx context.Context, req *pb.SearchProductsRequest) (*pb.SearchProductsResponse, error)
```
Searches products by name or description (case-insensitive substring match).

### Adding New Products

1. Edit `products.json`:
```json
{
  "products": [
    {
      "id": "NEW_PRODUCT_ID",
      "name": "Product Name",
      "description": "Product description...",
      "picture": "/static/img/products/product.jpg",
      "priceUsd": {
        "currencyCode": "USD",
        "units": 99,
        "nanos": 990000000
      },
      "categories": ["category1", "category2"]
    }
  ]
}
```

2. Restart the service or trigger catalog reload (see below)

### Generating Protobuf Code

```bash
./genproto.sh
```

### Adding New Dependencies

```bash
go get <package-name>
go mod tidy
```

## Dynamic Catalog Reloading

The service supports dynamic catalog reloading via Unix signals (for debugging/testing purposes).

### Enable Dynamic Reload

```bash
# In Kubernetes
kubectl exec deployment/productcatalogservice -- kill -USR1 1

# Local (get PID first)
kill -USR1 <pid>
```

**⚠️ Warning**: This feature is intentionally buggy for demonstration purposes. It reloads the catalog on every request, causing:
- Significant latency increase
- High CPU usage (80%+ in `parseCatalog`)
- Poor performance in frontend

### Disable Dynamic Reload

```bash
# In Kubernetes
kubectl exec deployment/productcatalogservice -- kill -USR2 1

# Local
kill -USR2 <pid>
```

### Use Case

This feature demonstrates:
- Performance profiling
- Observability tools
- Impact of inefficient code
- Debugging scenarios

## Latency Injection

For testing and observability demonstrations, you can inject artificial latency.

### Configuration

Set the `EXTRA_LATENCY` environment variable to a valid Go duration:

```bash
# 5.5 seconds delay
export EXTRA_LATENCY="5.5s"

# 500 milliseconds delay
export EXTRA_LATENCY="500ms"

# 2 minutes delay
export EXTRA_LATENCY="2m"
```

### In Kubernetes

```yaml
env:
- name: EXTRA_LATENCY
  value: "5.5s"
```

Or update running deployment:
```bash
kubectl set env deployment/productcatalogservice EXTRA_LATENCY=5.5s
```

### Use Cases

- **Load Testing**: Simulate slow backend responses
- **Timeout Testing**: Test client timeout behavior
- **Resilience Testing**: Test circuit breakers and retries
- **Performance Analysis**: Identify slow service dependencies

## Observability

### Logging
- Structured JSON logging with Logrus
- Fields: timestamp, severity, message
- RFC3339Nano timestamp format
- Request-level logging

Example log:
```json
{
  "timestamp": "2025-11-17T10:30:45.123456789Z",
  "severity": "info",
  "message": "Product catalog loaded with 9 products"
}
```

### Tracing
- OpenTelemetry OTLP integration
- gRPC instrumentation
- Distributed tracing support
- Enable with `ENABLE_TRACING=1`

### Profiling
- Google Cloud Profiler support
- CPU and memory profiling
- Service: `productcatalogservice`, Version: `1.0.0`
- Disable with `DISABLE_PROFILER=1`

### Health Checks
- gRPC health checking protocol
- Status: SERVING
- Endpoint: `grpc.health.v1.Health/Check`

## Testing the Service

### Using grpcurl

List all products:
```bash
grpcurl -plaintext localhost:3550 hipstershop.ProductCatalogService/ListProducts
```

Get specific product:
```bash
grpcurl -plaintext -d '{"id": "OLJCESPC7Z"}' \
  localhost:3550 hipstershop.ProductCatalogService/GetProduct
```

Search products:
```bash
grpcurl -plaintext -d '{"query": "sunglasses"}' \
  localhost:3550 hipstershop.ProductCatalogService/SearchProducts
```

Health check:
```bash
grpcurl -plaintext localhost:3550 grpc.health.v1.Health/Check
```

### Unit Tests

Run existing tests:
```bash
go test -v ./...
```

Test with coverage:
```bash
go test -cover ./...
```

## Troubleshooting

### Port Already in Use
```bash
export PORT=3551
./productcatalogservice
```

Or find what's using the port:
```bash
lsof -i :3550
```

### Products Not Loading
Check if `products.json` exists:
```bash
ls -la products.json
```

Validate JSON syntax:
```bash
cat products.json | jq .
```

### High CPU Usage
If CPU is high, check if dynamic reload is enabled:
```bash
# Disable it
kubectl exec deployment/productcatalogservice -- kill -USR2 1
```

### Build Errors
```bash
go clean
go mod download
go build -o productcatalogservice .
```

### gRPC Connection Errors
```bash
# Check if service is running
netstat -an | grep 3550

# Enable debug logging
export GRPC_GO_LOG_VERBOSITY_LEVEL=99
export GRPC_GO_LOG_SEVERITY_LEVEL=info
./productcatalogservice
```

### Memory Leaks
Check for goroutine leaks:
```bash
go tool pprof http://localhost:3550/debug/pprof/goroutine
```

## Performance Considerations

- **Catalog Caching**: Products loaded once at startup (unless dynamic reload enabled)
- **Search Efficiency**: O(n) linear search through products
- **Concurrent Requests**: Go's goroutine model handles concurrency efficiently
- **Memory Footprint**: ~50MB for 9 products
- **Response Time**: < 5ms (without extra latency or dynamic reload)

### Optimization Tips

For large catalogs (1000+ products):
- Implement indexing for faster search
- Use database instead of JSON file
- Add pagination to ListProducts
- Cache search results
- Use full-text search engine (Elasticsearch)

## Data Management

### Backup Products

```bash
kubectl cp productcatalogservice-<pod-id>:/src/products.json ./products-backup.json
```

### Update Products in Running Pod

```bash
# Edit locally
vim products.json

# Copy to pod
kubectl cp products.json productcatalogservice-<pod-id>:/src/products.json

# Trigger reload (if dynamic reload enabled)
kubectl exec deployment/productcatalogservice -- kill -USR1 1
```

### Migrate to Database

For production, consider migrating to a database:

```go
// Example with PostgreSQL
import "database/sql"

type productCatalog struct {
    db *sql.DB
}

func (p *productCatalog) GetProduct(ctx context.Context, req *pb.GetProductRequest) (*pb.Product, error) {
    var product pb.Product
    err := p.db.QueryRowContext(ctx, 
        "SELECT id, name, description, price_usd FROM products WHERE id = $1", 
        req.Id).Scan(&product.Id, &product.Name, &product.Description, &product.PriceUsd)
    if err == sql.ErrNoRows {
        return nil, status.Errorf(codes.NotFound, "product not found")
    }
    return &product, err
}
```

## Security

- No authentication required (handled at gateway level)
- Input validation for product IDs and search queries
- No sensitive data stored
- Read-only operations (no mutations)
- Runs as non-root user in container

## Contributing

1. Make changes to the source code
2. Update `products.json` if adding/modifying products
3. Run tests: `go test ./...`
4. Format code: `go fmt ./...`
5. Build locally to verify
6. Commit and push to trigger CI/CD pipeline

## Related Services

- **Frontend**: Displays products from this catalog
- **Recommendation Service**: Uses product data for recommendations
- **Cart Service**: References product IDs
- **Checkout Service**: Validates products in orders

## License

Apache License 2.0 - See LICENSE file for details.
