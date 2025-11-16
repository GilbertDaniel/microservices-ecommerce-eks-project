# Checkout Service

The Checkout service orchestrates the order placement process by coordinating with multiple microservices including cart, payment, shipping, email, and product catalog services.

## Overview

- **Language**: Go 1.19+
- **Framework**: gRPC
- **Port**: 5050
- **Dependencies**:
  - gRPC 1.58.3
  - OpenTelemetry for tracing
  - Google Cloud Profiler
  - UUID generation
  - Logrus for structured logging

## Service Details

- **Service Name**: CheckoutService
- **RPC Methods**:
  - `PlaceOrder` - Process checkout and place order
- **Health Check**: Supports gRPC health checking protocol
- **Integrations**: 
  - Product Catalog Service
  - Cart Service
  - Currency Service
  - Shipping Service
  - Email Service
  - Payment Service

## Building Locally

### Prerequisites
- Go 1.19 or higher
- Docker (for containerization)

### Restore Dependencies

```bash
cd src/checkoutservice
go mod download
```

### Build the Application

```bash
go build -o checkoutservice .
```

### Run Locally

```bash
# Set required environment variables
export PRODUCT_CATALOG_SERVICE_ADDR="localhost:3550"
export CART_SERVICE_ADDR="localhost:7070"
export CURRENCY_SERVICE_ADDR="localhost:7000"
export SHIPPING_SERVICE_ADDR="localhost:50051"
export EMAIL_SERVICE_ADDR="localhost:8080"
export PAYMENT_SERVICE_ADDR="localhost:50051"

# Run the service
./checkoutservice
```

The service will start on port 5050.

### Run Tests

```bash
go test ./...
```

## Building Docker Image

From the `src/checkoutservice/` directory:

```bash
docker build -t checkoutservice .
```

Run the container:

```bash
docker run -p 5050:5050 \
  -e PRODUCT_CATALOG_SERVICE_ADDR="productcatalog:3550" \
  -e CART_SERVICE_ADDR="cart:7070" \
  -e CURRENCY_SERVICE_ADDR="currency:7000" \
  -e SHIPPING_SERVICE_ADDR="shipping:50051" \
  -e EMAIL_SERVICE_ADDR="email:8080" \
  -e PAYMENT_SERVICE_ADDR="payment:50051" \
  checkoutservice
```

### Multi-stage Build

The Dockerfile uses a multi-stage build:
1. **Builder stage**: Uses `golang:1.21.3-alpine` to compile the Go binary
2. **Runtime stage**: Uses `alpine:3.18.4` for minimal image size
3. **Dependencies**: go.mod and go.sum for dependency management

## Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `PORT` | gRPC server port | `5050` | No |
| `PRODUCT_CATALOG_SERVICE_ADDR` | Product catalog service address | None | Yes |
| `CART_SERVICE_ADDR` | Cart service address | None | Yes |
| `CURRENCY_SERVICE_ADDR` | Currency conversion service address | None | Yes |
| `SHIPPING_SERVICE_ADDR` | Shipping service address | None | Yes |
| `EMAIL_SERVICE_ADDR` | Email service address | None | Yes |
| `PAYMENT_SERVICE_ADDR` | Payment processing service address | None | Yes |
| `DISABLE_PROFILER` | Disable Google Cloud Profiler | `false` | No |
| `DISABLE_TRACING` | Disable OpenTelemetry tracing | `false` | No |
| `GOTRACEBACK` | Go runtime traceback level | `single` | No |

## CI/CD Pipeline

This service is automatically built and deployed using GitHub Actions.

### Workflow: CheckoutService CI/CD

**Trigger**: Push to `main` branch with changes in `src/checkoutservice/**`

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
- **Repository**: `checkoutservice`
- **Tags**: 
  - `latest` - Always points to the most recent build
  - `<build-number>` - Specific version tag

## Deployment to Kubernetes

The service is deployed to EKS cluster using the manifest in `deployments/checkoutservice.yml`.

### Manual Deployment

```bash
kubectl apply -f deployments/checkoutservice.yml
```

### Verify Deployment

```bash
kubectl get pods -l app=checkoutservice
kubectl logs -l app=checkoutservice
kubectl describe svc checkoutservice
```

## Development

### Project Structure

```
src/checkoutservice/
├── Dockerfile           # Container image definition
├── go.mod              # Go module dependencies
├── go.sum              # Dependency checksums
├── main.go             # Service implementation
├── genproto/           # Generated protobuf code
├── genproto.sh         # Script to generate protobuf
└── money/              # Money utility functions
```

### Order Processing Flow

1. **Validate Request**: Check user ID and address
2. **Get Cart**: Retrieve items from cart service
3. **Calculate Costs**: 
   - Get product prices from catalog
   - Calculate shipping cost
   - Convert currencies if needed
4. **Process Payment**: Charge payment via payment service
5. **Ship Order**: Request shipping
6. **Send Confirmation**: Email order confirmation
7. **Empty Cart**: Clear user's cart
8. **Return Order**: Generate order ID and return details

### Generating Protobuf Code

```bash
./genproto.sh
```

### Adding New Dependencies

```bash
go get <package-name>
go mod tidy
```

## Observability

### Logging
- Structured JSON logging with Logrus
- Log levels: Debug, Info, Warn, Error
- Timestamp in RFC3339Nano format

### Tracing
- OpenTelemetry integration
- Distributed tracing across services
- OTLP trace export

### Profiling
- Google Cloud Profiler support
- CPU and heap profiling
- Can be disabled via `DISABLE_PROFILER`

## Troubleshooting

### Port Already in Use
If port 5050 is already in use:
```bash
export PORT=5051
./checkoutservice
```

### Service Connection Issues
Check if dependent services are running:
```bash
# Test connectivity
telnet <service-host> <service-port>

# Example
telnet localhost 7070  # Cart service
```

### Build Issues
Clean and rebuild:
```bash
go clean
go mod download
go build -o checkoutservice .
```

### gRPC Errors
Check service addresses are correct:
```bash
echo $PRODUCT_CATALOG_SERVICE_ADDR
echo $CART_SERVICE_ADDR
# ... check all service addresses
```

Enable debug logging:
```bash
export GRPC_GO_LOG_VERBOSITY_LEVEL=99
export GRPC_GO_LOG_SEVERITY_LEVEL=info
```

## Performance Considerations

- **Connection Pooling**: Reuses gRPC connections to dependent services
- **Async Operations**: Some operations can be parallelized
- **Timeout Management**: Proper context timeouts for external calls
- **Error Handling**: Graceful degradation on service failures

## Security

- No authentication required (handled at gateway level)
- Input validation for user data
- Secure gRPC connections
- Runs as non-root user in container

## Contributing

1. Make changes to the source code
2. Run tests: `go test ./...`
3. Format code: `go fmt ./...`
4. Build locally to verify
5. Commit and push to trigger CI/CD pipeline

## License

Apache License 2.0 - See source files for details.

