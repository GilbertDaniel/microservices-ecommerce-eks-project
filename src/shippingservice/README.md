# Shipping Service

The Shipping service provides shipping cost quotes and generates tracking IDs for order fulfillment. It simulates the shipping process without integrating with actual shipping carriers.

## Overview

- **Language**: Go 1.19+
- **Framework**: gRPC
- **Port**: 50051
- **Mode**: Mock/Demo implementation
- **Dependencies**:
  - gRPC 1.58.3
  - Google Cloud Profiler
  - Logrus for structured logging

## Service Details

- **Service Name**: ShippingService
- **RPC Methods**:
  - `GetQuote` - Returns shipping cost estimate
  - `ShipOrder` - Generates tracking ID for shipment
- **Health Check**: Supports gRPC health checking protocol
- **Pricing**: Fixed $8.99 USD (demo mode)

### Shipping Quote Logic

Currently uses a fixed price model:
- **Flat Rate**: $8.99 USD regardless of:
  - Number of items
  - Destination address
  - Package weight
  - Shipping speed

**Note**: This is a demo implementation. Production systems would integrate with:
- UPS, FedEx, USPS APIs
- Real-time rate calculation
- Multiple shipping options
- Weight-based pricing
- Distance-based pricing

### Tracking ID Generation

Generates unique tracking IDs using:
- Random letter codes (A-Z)
- Address-based salt
- Random number sequences

**Format**: `XX-NNN-NMMMMMMM`
- `XX` - Two random capital letters
- `N` - Address string length
- `NNN` - Random 3-digit number
- `M` - Half of address length
- `MMMMMMM` - Random 7-digit number

**Example**: `AB-34567-17890123`

## Building Locally

### Prerequisites
- Go 1.19 or higher
- Docker (for containerization)

### Restore Dependencies

```bash
cd src/shippingservice
go mod download
```

### Build the Application

```bash
go build -o shippingservice .
```

### Run Locally

```bash
# Set the port (default: 50051)
export PORT=50051

# Disable profiler for local development
export DISABLE_PROFILER=1

# Run the service
./shippingservice
```

The service will start on port 50051.

### Run Tests

```bash
go test ./...
```

Test with coverage:
```bash
go test -cover ./...
```

## Building Docker Image

From the `src/shippingservice/` directory:

```bash
docker build -t shippingservice .
```

Run the container:

```bash
docker run -p 50051:50051 \
  -e PORT=50051 \
  -e DISABLE_PROFILER=1 \
  shippingservice
```

### Multi-stage Build

The Dockerfile uses a multi-stage build:
1. **Builder stage**: `golang:1.21.3-alpine` with build tools (ca-certificates, git, build-base)
2. **Release stage**: `alpine:3.18.4` with only runtime dependencies and compiled binary

**Benefits**:
- Reduces image size by ~500MB
- Removes build tools from final image
- Faster container startup

**Build Arguments**:
- `SKAFFOLD_GO_GCFLAGS` - Compiler flags for debugging

## Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `PORT` | gRPC server port | `50051` | No |
| `APP_PORT` | Alternative port variable | `50051` | No |
| `DISABLE_PROFILER` | Disable Google Cloud Profiler | Not set | No |
| `DISABLE_TRACING` | Disable OpenTelemetry tracing | Not set | No |
| `DISABLE_STATS` | Disable statistics collection | Not set | No |
| `GOTRACEBACK` | Go runtime traceback level | `single` | No |

## CI/CD Pipeline

This service is automatically built and deployed using GitHub Actions.

### Workflow: ShippingService CI/CD

**Trigger**: Push to `main` branch with changes in `src/shippingservice/**`

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
- **Repository**: `shippingservice`
- **Tags**: 
  - `latest` - Always points to the most recent build
  - `<build-number>` - Specific version tag

## Deployment to Kubernetes

The service is deployed to EKS cluster using the manifest in `deployments/shippingservice.yml`.

### Manual Deployment

```bash
kubectl apply -f deployments/shippingservice.yml
```

### Verify Deployment

```bash
kubectl get pods -l app=shippingservice
kubectl logs -l app=shippingservice
kubectl describe svc shippingservice
```

## Development

### Project Structure

```
src/shippingservice/
├── Dockerfile               # Container image definition
├── go.mod                   # Go module dependencies
├── go.sum                   # Dependency checksums
├── main.go                  # Main server implementation
├── quote.go                 # Shipping quote logic
├── tracker.go               # Tracking ID generation
├── shippingservice_test.go # Unit tests
├── genproto/               # Generated protobuf code
└── genproto.sh            # Script to regenerate protobuf
```

### RPC Method Implementations

#### GetQuote

```go
func (s *server) GetQuote(ctx context.Context, in *pb.GetQuoteRequest) (*pb.GetQuoteResponse, error) {
    // Generate quote (currently fixed at $8.99)
    quote := CreateQuoteFromCount(0)
    
    return &pb.GetQuoteResponse{
        CostUsd: &pb.Money{
            CurrencyCode: "USD",
            Units:        int64(quote.Dollars),
            Nanos:        int32(quote.Cents * 10000000)
        },
    }, nil
}
```

**Request Format**:
```json
{
  "address": {
    "street_address": "1600 Amphitheatre Parkway",
    "city": "Mountain View",
    "state": "CA",
    "country": "United States",
    "zip_code": "94043"
  },
  "items": [
    {
      "product_id": "OLJCESPC7Z",
      "quantity": 1
    }
  ]
}
```

**Response Format**:
```json
{
  "cost_usd": {
    "currency_code": "USD",
    "units": 8,
    "nanos": 990000000
  }
}
```

#### ShipOrder

```go
func (s *server) ShipOrder(ctx context.Context, in *pb.ShipOrderRequest) (*pb.ShipOrderResponse, error) {
    // Create tracking ID from address
    baseAddress := fmt.Sprintf("%s, %s, %s", 
        in.Address.StreetAddress, 
        in.Address.City, 
        in.Address.State)
    id := CreateTrackingId(baseAddress)
    
    return &pb.ShipOrderResponse{
        TrackingId: id,
    }, nil
}
```

**Request Format**:
```json
{
  "address": {
    "street_address": "1600 Amphitheatre Parkway",
    "city": "Mountain View",
    "state": "CA",
    "country": "United States",
    "zip_code": "94043"
  },
  "items": [
    {
      "product_id": "OLJCESPC7Z",
      "quantity": 1
    }
  ]
}
```

**Response Format**:
```json
{
  "tracking_id": "AB-34567-17890123"
}
```

### Quote Logic

The `quote.go` file contains pricing logic:

```go
type Quote struct {
    Dollars uint32
    Cents   uint32
}

func CreateQuoteFromCount(count int) Quote {
    return CreateQuoteFromFloat(8.99)
}

func CreateQuoteFromFloat(value float64) Quote {
    units, fraction := math.Modf(value)
    return Quote{
        uint32(units),
        uint32(math.Trunc(fraction * 100)),
    }
}
```

### Tracking ID Logic

The `tracker.go` file generates unique tracking IDs:

```go
func CreateTrackingId(salt string) string {
    return fmt.Sprintf("%c%c-%d%s-%d%s",
        getRandomLetterCode(),
        getRandomLetterCode(),
        len(salt),
        getRandomNumber(3),
        len(salt)/2,
        getRandomNumber(7),
    )
}
```

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
- Fields: timestamp, severity, message
- RFC3339Nano timestamp format
- Request-level logging

Example log:
```json
{
  "timestamp": "2025-11-17T10:30:45.123456789Z",
  "severity": "info",
  "message": "[GetQuote] received request"
}
```

### Tracing
- OpenTelemetry tracing (placeholder implementation)
- Currently disabled pending full implementation
- Enable by NOT setting `DISABLE_TRACING`

### Profiling
- Google Cloud Profiler support
- Stackdriver integration
- Retry logic for profiler initialization (3 attempts)
- Service: `shippingservice`, Version: `1.0.0`
- Disable with `DISABLE_PROFILER=1`

### Health Checks
- gRPC health checking protocol
- Status: SERVING
- Endpoint: `grpc.health.v1.Health/Check`

### Stats
- Statistics collection (placeholder)
- Currently disabled pending implementation
- Enable by NOT setting `DISABLE_STATS`

## Testing the Service

### Using grpcurl

Get shipping quote:
```bash
grpcurl -plaintext -d '{
  "address": {
    "street_address": "1600 Amphitheatre Parkway",
    "city": "Mountain View",
    "state": "CA",
    "country": "United States",
    "zip_code": "94043"
  },
  "items": [
    {
      "product_id": "OLJCESPC7Z",
      "quantity": 2
    }
  ]
}' localhost:50051 hipstershop.ShippingService/GetQuote
```

Ship order and get tracking ID:
```bash
grpcurl -plaintext -d '{
  "address": {
    "street_address": "1600 Amphitheatre Parkway",
    "city": "Mountain View",
    "state": "CA",
    "country": "United States",
    "zip_code": "94043"
  },
  "items": [
    {
      "product_id": "OLJCESPC7Z",
      "quantity": 1
    }
  ]
}' localhost:50051 hipstershop.ShippingService/ShipOrder
```

Health check:
```bash
grpcurl -plaintext localhost:50051 grpc.health.v1.Health/Check
```

### Unit Tests

The service includes unit tests in `shippingservice_test.go`:

```bash
# Run tests
go test -v

# Run with coverage
go test -v -cover

# Generate coverage report
go test -coverprofile=coverage.out
go tool cover -html=coverage.out
```

## Troubleshooting

### Port Already in Use
```bash
export PORT=50052
./shippingservice
```

Or find what's using the port:
```bash
lsof -i :50051
netstat -an | grep 50051
```

### Build Errors
```bash
go clean
go mod download
go build -o shippingservice .
```

### gRPC Connection Errors
```bash
# Check if service is running
netstat -an | grep 50051

# Enable debug logging
export GRPC_GO_LOG_VERBOSITY_LEVEL=99
export GRPC_GO_LOG_SEVERITY_LEVEL=info
./shippingservice
```

### Profiler Errors
```bash
# Disable profiler for local development
export DISABLE_PROFILER=1
./shippingservice
```

### Tracking ID Issues
Tracking IDs should be unique. If you see duplicates:
```bash
# The random seed is based on time.Now()
# Ensure system time is correct
date
```

## Implementing Real Shipping Integration

For production use, integrate with actual shipping carriers:

### UPS Integration

```go
import "github.com/ups/go-ups"

func GetQuoteUPS(address Address, items []Item) (Quote, error) {
    client := ups.NewClient(os.Getenv("UPS_API_KEY"))
    
    // Calculate package weight
    weight := calculateWeight(items)
    
    // Get rate quote
    rate, err := client.GetRate(ups.RateRequest{
        FromZip: "12345",
        ToZip:   address.ZipCode,
        Weight:  weight,
        Service: ups.Ground,
    })
    
    if err != nil {
        return Quote{}, err
    }
    
    return CreateQuoteFromFloat(rate.TotalCost), nil
}
```

### FedEx Integration

```go
import "github.com/fedex/fedex-go"

func GetQuoteFedEx(address Address, items []Item) (Quote, error) {
    client := fedex.NewClient(
        os.Getenv("FEDEX_KEY"),
        os.Getenv("FEDEX_PASSWORD"),
    )
    
    rate, err := client.GetRates(fedex.RateRequest{
        ShipperZip:  "12345",
        RecipientZip: address.ZipCode,
        Weight:      calculateWeight(items),
        ServiceType: fedex.GroundHomeDelivery,
    })
    
    if err != nil {
        return Quote{}, err
    }
    
    return CreateQuoteFromFloat(rate.TotalNetCharge), nil
}
```

### Multi-Carrier Comparison

```go
func GetBestQuote(address Address, items []Item) (Quote, string, error) {
    var quotes []struct {
        carrier string
        quote   Quote
    }
    
    // Get quotes from multiple carriers
    if upsQuote, err := GetQuoteUPS(address, items); err == nil {
        quotes = append(quotes, struct{carrier string; quote Quote}{"UPS", upsQuote})
    }
    
    if fedexQuote, err := GetQuoteFedEx(address, items); err == nil {
        quotes = append(quotes, struct{carrier string; quote Quote}{"FedEx", fedexQuote})
    }
    
    // Find cheapest
    best := quotes[0]
    for _, q := range quotes {
        if q.quote.Dollars < best.quote.Dollars {
            best = q
        }
    }
    
    return best.quote, best.carrier, nil
}
```

## Advanced Features

### Weight-Based Pricing

```go
func CreateQuoteFromWeight(weightLbs float64) Quote {
    baseRate := 5.00
    perPoundRate := 0.50
    
    total := baseRate + (weightLbs * perPoundRate)
    return CreateQuoteFromFloat(total)
}
```

### Distance-Based Pricing

```go
import "github.com/umahmood/haversine"

func CreateQuoteFromDistance(from, to Address) Quote {
    // Calculate distance
    dist := haversine.Distance(
        haversine.Coord{Lat: from.Latitude, Lon: from.Longitude},
        haversine.Coord{Lat: to.Latitude, Lon: to.Longitude},
    )
    
    // $0.10 per mile
    cost := dist.Miles * 0.10
    return CreateQuoteFromFloat(cost)
}
```

### Shipping Speed Options

```go
type ShippingSpeed int

const (
    Standard ShippingSpeed = iota
    Expedited
    Overnight
)

func CreateQuoteFromSpeed(speed ShippingSpeed) Quote {
    switch speed {
    case Standard:
        return CreateQuoteFromFloat(8.99)
    case Expedited:
        return CreateQuoteFromFloat(15.99)
    case Overnight:
        return CreateQuoteFromFloat(29.99)
    default:
        return CreateQuoteFromFloat(8.99)
    }
}
```

### Package Dimensions

```go
type Package struct {
    Length float64
    Width  float64
    Height float64
    Weight float64
}

func CreateQuoteFromPackage(pkg Package) Quote {
    // Calculate dimensional weight
    dimWeight := (pkg.Length * pkg.Width * pkg.Height) / 166
    
    // Use greater of actual or dimensional weight
    billableWeight := math.Max(pkg.Weight, dimWeight)
    
    return CreateQuoteFromWeight(billableWeight)
}
```

## Performance Considerations

- **Stateless**: No database or persistent storage
- **Fast**: Fixed pricing = sub-millisecond response times
- **No External Dependencies**: All calculations done locally
- **Concurrent**: Go's goroutine model handles multiple requests efficiently
- **Memory**: ~30MB per instance

### For Production

When integrating real shipping APIs:
- **Caching**: Cache rates for same route/weight combinations
- **Timeouts**: Set reasonable timeouts for carrier API calls
- **Retries**: Implement retry logic with exponential backoff
- **Fallbacks**: Have backup carriers if primary is unavailable
- **Rate Limiting**: Respect carrier API rate limits

## Security

- No authentication required (handled at gateway level)
- Input validation for addresses
- No sensitive data stored
- Stateless operation
- Runs as non-root user in container

## Contributing

1. Make changes to the source code
2. Run tests: `go test ./...`
3. Format code: `go fmt ./...`
4. Build locally to verify
5. Commit and push to trigger CI/CD pipeline

## Related Services

- **Checkout Service**: Calls shipping service to calculate shipping costs
- **Frontend**: Displays shipping costs to users
- **Email Service**: May include tracking IDs in confirmation emails

## License

Apache License 2.0 - See LICENSE file for details.

From `src/shippingservice`, run:

```
docker build ./
```

## Test

```
go test .
```
