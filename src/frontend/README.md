# Frontend Service

The Frontend service provides the web UI for the e-commerce application. It's an HTTP server that serves HTML pages and communicates with all backend microservices via gRPC.

## Overview

- **Language**: Go 1.19+
- **Framework**: Gorilla Mux (HTTP routing)
- **Port**: 8080
- **Architecture**: Monolithic web frontend with microservices backend
- **Dependencies**:
  - gorilla/mux 1.8.0 - HTTP routing
  - gRPC 1.58.3 - Backend communication
  - OpenTelemetry for distributed tracing
  - Google Cloud Profiler
  - Logrus for structured logging

## Service Details

- **Service Type**: HTTP Web Server
- **Endpoints**:
  - `GET /` - Home page with product catalog
  - `GET /product/{id}` - Product details page
  - `GET /cart` - View shopping cart
  - `POST /cart` - Add item to cart
  - `POST /cart/empty` - Empty cart
  - `POST /cart/checkout` - Place order
  - `POST /setCurrency` - Set currency preference
  - `GET /logout` - Clear session
  - `GET /_healthz` - Health check endpoint
  - `GET /static/*` - Static assets (CSS, JS, images)
  - `GET /robots.txt` - Robots file

- **Backend Services Used**:
  - Product Catalog Service
  - Currency Service
  - Cart Service
  - Recommendation Service
  - Checkout Service
  - Shipping Service
  - Ad Service

## Features

### User Features
- Browse product catalog
- View product details with images and descriptions
- Add/remove items from shopping cart
- Currency conversion (USD, EUR, CAD, JPY, GBP, TRY)
- Product recommendations
- Contextual advertisements
- Order checkout with shipping calculation
- Order confirmation

### Technical Features
- Session management via cookies
- Currency preference persistence
- Responsive web design
- Static file serving
- Error handling with user-friendly messages
- Health check endpoint
- Platform detection (GCP, AWS, Azure, Alibaba, On-prem)

## Building Locally

### Prerequisites
- Go 1.19 or higher
- Docker (for containerization)
- Access to backend microservices

### Restore Dependencies

```bash
cd src/frontend
go mod download
```

### Build the Application

```bash
go build -o frontend .
```

### Run Locally

```bash
# Set required environment variables
export PORT=8080
export PRODUCT_CATALOG_SERVICE_ADDR="localhost:3550"
export CURRENCY_SERVICE_ADDR="localhost:7000"
export CART_SERVICE_ADDR="localhost:7070"
export RECOMMENDATION_SERVICE_ADDR="localhost:8080"
export CHECKOUT_SERVICE_ADDR="localhost:5050"
export SHIPPING_SERVICE_ADDR="localhost:50051"
export AD_SERVICE_ADDR="localhost:9555"

# Optional: Enable features
export ENABLE_PROFILER=0
export ENABLE_TRACING=0

# Run the service
./frontend
```

The frontend will be available at http://localhost:8080

### Run Tests

```bash
go test ./...
```

## Building Docker Image

From the `src/frontend/` directory:

```bash
docker build -t frontend .
```

Run the container:

```bash
docker run -p 8080:8080 \
  -e PRODUCT_CATALOG_SERVICE_ADDR="productcatalog:3550" \
  -e CURRENCY_SERVICE_ADDR="currency:7000" \
  -e CART_SERVICE_ADDR="cart:7070" \
  -e RECOMMENDATION_SERVICE_ADDR="recommendation:8080" \
  -e CHECKOUT_SERVICE_ADDR="checkout:5050" \
  -e SHIPPING_SERVICE_ADDR="shipping:50051" \
  -e AD_SERVICE_ADDR="adservice:9555" \
  frontend
```

### Multi-stage Build

The Dockerfile uses a multi-stage build:
1. **Builder stage**: `golang:1.21.3-alpine` with build tools (ca-certificates, git, build-base)
2. **Release stage**: `alpine:3.18.4` with only runtime dependencies and compiled binary

**Benefits**:
- Reduces image size by ~500MB
- Removes build tools from final image
- Includes debugging tools (busybox-extras, net-tools, bind-tools)

**Build Arguments**:
- `SKAFFOLD_GO_GCFLAGS` - Compiler flags for debugging

## Environment Variables

### Required

| Variable | Description | Example |
|----------|-------------|---------|
| `PRODUCT_CATALOG_SERVICE_ADDR` | Product catalog gRPC address | `productcatalog:3550` |
| `CURRENCY_SERVICE_ADDR` | Currency service gRPC address | `currency:7000` |
| `CART_SERVICE_ADDR` | Cart service gRPC address | `cart:7070` |
| `RECOMMENDATION_SERVICE_ADDR` | Recommendation service gRPC address | `recommendation:8080` |
| `CHECKOUT_SERVICE_ADDR` | Checkout service gRPC address | `checkout:5050` |
| `SHIPPING_SERVICE_ADDR` | Shipping service gRPC address | `shipping:50051` |
| `AD_SERVICE_ADDR` | Ad service gRPC address | `adservice:9555` |

### Optional

| Variable | Description | Default |
|----------|-------------|---------|
| `PORT` | HTTP server port | `8080` |
| `LISTEN_ADDR` | Listen address | `""` (all interfaces) |
| `ENABLE_PROFILER` | Enable Google Cloud Profiler | `0` |
| `ENABLE_TRACING` | Enable OpenTelemetry tracing | `0` |
| `COLLECTOR_SERVICE_ADDR` | OTLP collector address | `localhost:4317` |
| `FRONTEND_MESSAGE` | Custom banner message | `""` |
| `CYMBAL_BRANDING` | Use Cymbal branding | `false` |
| `PLATFORM` | Deployment platform | Auto-detected |
| `GOTRACEBACK` | Go runtime traceback level | `single` |

## CI/CD Pipeline

This service is automatically built and deployed using GitHub Actions.

### Workflow: Frontend CI/CD

**Trigger**: Push to `main` branch with changes in `src/frontend/**`

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
- **Repository**: `frontend`
- **Tags**: 
  - `latest` - Always points to the most recent build
  - `<build-number>` - Specific version tag

## Deployment to Kubernetes

The service is deployed to EKS cluster using the manifest in `deployments/frontend.yml`.

### Manual Deployment

```bash
kubectl apply -f deployments/frontend.yml
```

### Verify Deployment

```bash
kubectl get pods -l app=frontend
kubectl logs -l app=frontend
kubectl describe svc frontend
```

### Access the Frontend

```bash
# Port forward for local access
kubectl port-forward svc/frontend 8080:8080

# Or get LoadBalancer URL
kubectl get svc frontend
```

## Development

### Project Structure

```
src/frontend/
├── Dockerfile              # Container image definition
├── go.mod                  # Go module dependencies
├── go.sum                  # Dependency checksums
├── main.go                 # Application entry point
├── handlers.go             # HTTP request handlers
├── middleware.go           # HTTP middleware (logging, sessions)
├── rpc.go                  # gRPC client functions
├── deployment_details.go   # Platform detection logic
├── genproto/              # Generated protobuf code
├── money/                 # Money utility functions
├── templates/             # HTML templates
│   ├── home.html          # Homepage
│   ├── product.html       # Product details
│   ├── cart.html          # Shopping cart
│   ├── order.html         # Order confirmation
│   ├── header.html        # Page header
│   ├── footer.html        # Page footer
│   ├── ad.html            # Advertisement component
│   ├── recommendations.html # Product recommendations
│   └── error.html         # Error page
└── static/                # Static assets
    ├── styles/            # CSS files
    ├── images/            # Product images
    ├── icons/             # UI icons
    └── favicon.ico        # Site favicon
```

### HTTP Handlers

#### Home Handler (`/`)
```go
func (fe *frontendServer) homeHandler(w http.ResponseWriter, r *http.Request)
```
- Lists all products with converted prices
- Shows shopping cart summary
- Displays ads and recommendations

#### Product Handler (`/product/{id}`)
```go
func (fe *frontendServer) productHandler(w http.ResponseWriter, r *http.Request)
```
- Shows product details
- Displays price in selected currency
- Shows product recommendations

#### Cart Handlers
```go
func (fe *frontendServer) viewCartHandler(w http.ResponseWriter, r *http.Request)
func (fe *frontendServer) addToCartHandler(w http.ResponseWriter, r *http.Request)
func (fe *frontendServer) emptyCartHandler(w http.ResponseWriter, r *http.Request)
```
- View cart contents
- Add items to cart
- Empty cart

#### Checkout Handler (`/cart/checkout`)
```go
func (fe *frontendServer) placeOrderHandler(w http.ResponseWriter, r *http.Request)
```
- Collects shipping information
- Calculates shipping costs
- Processes payment
- Sends order confirmation email

### Session Management

Sessions are managed via HTTP cookies:
- **Session ID**: `shop_session-id` - Unique user session identifier
- **Currency**: `shop_currency` - User's preferred currency
- **Max Age**: 48 hours
- **Auto-generation**: Session ID created on first visit

### Currency Support

Whitelisted currencies:
- USD - US Dollar
- EUR - Euro
- CAD - Canadian Dollar
- JPY - Japanese Yen
- GBP - British Pound
- TRY - Turkish Lira

Currency conversion handled by Currency Service.

### Template Rendering

Uses Go's `html/template` package with custom functions:
- `renderMoney` - Formats money amounts
- `renderCurrencyLogo` - Shows currency symbols

### Middleware Stack

Request processing order:
1. **OTel Handler** - Distributed tracing
2. **Session Handler** - Session ID management
3. **Log Handler** - Request/response logging
4. **Route Handler** - Application logic

### Generating Protobuf Code

```bash
./genproto.sh
```

Regenerates gRPC client code from proto definitions.

### Adding New Dependencies

```bash
go get <package-name>
go mod tidy
```

## Observability

### Logging
- Structured JSON logging with Logrus
- Fields: timestamp, severity, message
- Request-level logging with correlation
- RFC3339Nano timestamp format

Example log:
```json
{
  "timestamp": "2025-11-16T10:30:45.123456789Z",
  "severity": "info",
  "message": "home",
  "currency": "USD",
  "session": "abc-123-def"
}
```

### Tracing
- OpenTelemetry OTLP integration
- HTTP and gRPC instrumentation
- Trace propagation across services
- Enable with `ENABLE_TRACING=1`

### Profiling
- Google Cloud Profiler support
- CPU and memory profiling
- Service: `frontend`, Version: `1.0.0`
- Enable with `ENABLE_PROFILER=1`

### Health Checks
- Endpoint: `GET /_healthz`
- Response: `ok` (200 status)
- Kubernetes liveness/readiness probe compatible

## Testing

### Manual Testing

Access the frontend:
```bash
# Local
http://localhost:8080

# Kubernetes (port forward)
kubectl port-forward svc/frontend 8080:8080
```

Test endpoints:
```bash
# Health check
curl http://localhost:8080/_healthz

# Homepage
curl http://localhost:8080/

# Product page
curl http://localhost:8080/product/OLJCESPC7Z
```

### Load Testing

```bash
# Using Apache Bench
ab -n 1000 -c 10 http://localhost:8080/

# Using hey
hey -n 1000 -c 10 http://localhost:8080/
```

## Troubleshooting

### Port Already in Use
```bash
# Use different port
export PORT=8081
./frontend

# Or find what's using port 8080
lsof -i :8080
```

### Cannot Connect to Backend Services
```bash
# Check service addresses
echo $PRODUCT_CATALOG_SERVICE_ADDR

# Test connectivity
telnet productcatalog 3550
nc -zv productcatalog 3550
```

### Template Errors
```bash
# Ensure templates directory exists
ls templates/

# Check template syntax
go run main.go handlers.go middleware.go rpc.go deployment_details.go
```

### Static Files Not Loading
```bash
# Verify static directory
ls static/styles/

# Check file permissions
chmod -R 755 static/
```

### Session Issues
```bash
# Clear browser cookies
# Or use incognito mode

# Check cookie settings
curl -v http://localhost:8080/ 2>&1 | grep -i cookie
```

### gRPC Connection Errors
```bash
# Enable gRPC debug logging
export GRPC_GO_LOG_VERBOSITY_LEVEL=99
export GRPC_GO_LOG_SEVERITY_LEVEL=info
./frontend
```

### Build Errors
```bash
# Clean and rebuild
go clean
go mod download
go build -o frontend .
```

### Memory Issues
```bash
# Adjust Go garbage collection
export GOGC=80  # More aggressive GC

# Check memory usage
go tool pprof http://localhost:8080/debug/pprof/heap
```

## Performance Considerations

- **Connection Pooling**: gRPC connections reused across requests
- **Template Caching**: Templates parsed once at startup
- **Static File Serving**: Efficient HTTP file server
- **Concurrent Requests**: Goroutine per request (Go's concurrency model)
- **Session Storage**: Cookie-based (no server-side storage)

### Optimization Tips
- Enable HTTP/2 for better performance
- Use CDN for static assets in production
- Implement caching for product catalog
- Add rate limiting for checkout endpoint
- Use connection pooling for database (if added)

## Security

- **Input Validation**: User inputs sanitized
- **Template Auto-escaping**: XSS prevention
- **HTTPS**: Configure TLS in production
- **Session Security**: Secure cookie flags
- **Content Security Policy**: Recommended for production
- **Runs as non-root**: Container security best practice

### Security Recommendations
```bash
# Use secure cookies in production
# Set in deployment manifest:
# - COOKIE_SECURE=true
# - COOKIE_HTTPONLY=true
# - COOKIE_SAMESITE=strict
```

## Platform Detection

Automatically detects deployment platform:
- **Google Cloud Platform** (GCP)
- **Amazon Web Services** (AWS)
- **Microsoft Azure**
- **Alibaba Cloud**
- **On-premises**
- **Local Development**

Detection based on metadata services and environment variables.

## Branding

### Cymbal Branding
```bash
export CYMBAL_BRANDING=true
```
Switches to Cymbal brand theme (alternative branding).

### Custom Messages
```bash
export FRONTEND_MESSAGE="Welcome to our Holiday Sale!"
```
Displays custom banner on homepage.

## Contributing

1. Make changes to the source code
2. Update templates/static files as needed
3. Run tests: `go test ./...`
4. Format code: `go fmt ./...`
5. Build locally to verify
6. Commit and push to trigger CI/CD pipeline

## License

Apache License 2.0 - See LICENSE file for details.
