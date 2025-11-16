# Currency Service

The Currency service provides currency conversion capabilities, converting between different currencies using exchange rates based on European Central Bank data.

## Overview

- **Language**: Node.js 20.8.0
- **Framework**: gRPC with @grpc/grpc-js
- **Port**: 7000
- **Dependencies**:
  - @grpc/grpc-js 1.9.5
  - @grpc/proto-loader 0.7.10
  - OpenTelemetry for tracing
  - Google Cloud Profiler
  - Pino for structured logging
  - xml2js for data parsing

## Service Details

- **Service Name**: CurrencyService
- **RPC Methods**:
  - `GetSupportedCurrencies` - Returns list of supported currency codes
  - `Convert` - Converts an amount from one currency to another
- **Health Check**: Supports gRPC health checking protocol
- **Currency Data**: Uses European Central Bank exchange rates (EUR as base)

### Supported Currencies

The service supports 30+ currencies including:
- EUR, USD, JPY, GBP, CHF, CAD, AUD
- BGN, CZK, DKK, HUF, PLN, RON, SEK
- ISK, NOK, HRK, RUB, TRY, BRL
- CNY, HKD, IDR, ILS, INR, KRW, MXN
- MYR, NZD, PHP, SGD, THB, ZAR

## Building Locally

### Prerequisites
- Node.js 20.8.0 or higher
- npm 9.x or higher
- Docker (for containerization)

### Install Dependencies

```bash
cd src/currencyservice
npm install
```

### Run Locally

```bash
# Set the port (default: 7000)
export PORT=7000

# Disable profiler for local development
export DISABLE_PROFILER=1

# Run the service
node server.js
```

The service will start on port 7000.

### Run Tests

```bash
npm test
```

## Building Docker Image

From the `src/currencyservice/` directory:

```bash
docker build -t currencyservice .
```

Run the container:

```bash
docker run -p 7000:7000 \
  -e PORT=7000 \
  -e DISABLE_PROFILER=1 \
  currencyservice
```

### Multi-stage Build

The Dockerfile uses a multi-stage build for optimization:
1. **Base stage**: Node.js 20.8.0-alpine image
2. **Builder stage**: Installs build dependencies (python3, make, g++) and npm packages
3. **Final stage**: Copies only production dependencies and source code

**Image Size Benefits**: Multi-stage build removes build tools from final image, reducing size by ~100MB.

## Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `PORT` | gRPC server port | `7000` | Yes |
| `DISABLE_PROFILER` | Disable Google Cloud Profiler | `false` | No |
| `ENABLE_TRACING` | Enable OpenTelemetry tracing | `0` | No |
| `COLLECTOR_SERVICE_ADDR` | OTLP collector address for traces | None | If tracing enabled |

## CI/CD Pipeline

This service is automatically built and deployed using GitHub Actions.

### Workflow: CurrencyService CI/CD

**Trigger**: Push to `main` branch with changes in `src/currencyservice/**`

**Pipeline Stages**:
1. **Checkout**: Clone the repository
2. **Build**: Build Docker image with Node.js 20.8
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
- **Repository**: `currencyservice`
- **Tags**: 
  - `latest` - Always points to the most recent build
  - `<build-number>` - Specific version tag

## Deployment to Kubernetes

The service is deployed to EKS cluster using the manifest in `deployments/currencyservice.yml`.

### Manual Deployment

```bash
kubectl apply -f deployments/currencyservice.yml
```

### Verify Deployment

```bash
kubectl get pods -l app=currencyservice
kubectl logs -l app=currencyservice
kubectl describe svc currencyservice
```

## Development

### Project Structure

```
src/currencyservice/
├── Dockerfile              # Container image definition
├── package.json            # Node.js dependencies
├── package-lock.json       # Locked dependency versions
├── server.js               # Main service implementation
├── client.js               # gRPC client for testing
├── proto/                  # Protocol buffer definitions
│   └── demo.proto          # Service definition
├── data/                   # Currency exchange rate data
│   └── currency_conversion.json
└── genproto.sh            # Script to generate protobuf code
```

### Currency Conversion Logic

The service uses a two-step conversion process through EUR as base:

1. **From Currency → EUR**: Divide by the exchange rate
2. **EUR → To Currency**: Multiply by the exchange rate

```javascript
// Example: USD to JPY
// 1. USD → EUR: amount / 1.1305
// 2. EUR → JPY: result * 126.40
```

### Money Representation

Currency amounts use the `Money` protobuf type:
- `units` - Integer part of the amount
- `nanos` - Fractional part (9 decimal places)
- `currency_code` - ISO 4217 currency code

The `_carry()` function handles decimal overflow between units and nanos.

### Updating Exchange Rates

Exchange rates are stored in `data/currency_conversion.json`:

```json
{
  "EUR": "1.0",
  "USD": "1.1305",
  "JPY": "126.40"
}
```

To update rates:
1. Edit the JSON file with new rates
2. Restart the service
3. No code changes required

### Generating Protobuf Code

```bash
./genproto.sh
```

### Adding New Dependencies

```bash
npm install <package-name>
```

## Observability

### Logging
- Structured JSON logging with Pino
- Log levels: info, error
- Severity field for Google Cloud compatibility
- Request/response logging for all conversions

Example log output:
```json
{
  "level": "info",
  "message": "conversion request successful",
  "severity": "info"
}
```

### Tracing
- OpenTelemetry OTLP integration
- gRPC instrumentation automatically enabled
- Distributed tracing across services
- Enable with `ENABLE_TRACING=1`

### Profiling
- Google Cloud Profiler support
- CPU and heap profiling
- Service context: `currencyservice` version `1.0.0`
- Disable with `DISABLE_PROFILER=1`

## Testing the Service

### Using the Client

```bash
node client.js
```

### Using grpcurl

List supported currencies:
```bash
grpcurl -plaintext localhost:7000 hipstershop.CurrencyService/GetSupportedCurrencies
```

Convert currency:
```bash
grpcurl -plaintext -d '{
  "from": {
    "currency_code": "USD",
    "units": 100,
    "nanos": 0
  },
  "to_code": "EUR"
}' localhost:7000 hipstershop.CurrencyService/Convert
```

### Health Check

```bash
grpcurl -plaintext localhost:7000 grpc.health.v1.Health/Check
```

## Troubleshooting

### Port Already in Use
If port 7000 is already in use:
```bash
export PORT=7001
node server.js
```

Or check what's using the port:
```bash
lsof -i :7000
```

### Missing Dependencies
Reinstall dependencies:
```bash
rm -rf node_modules package-lock.json
npm install
```

### Profiler Errors
Disable profiler for local development:
```bash
export DISABLE_PROFILER=1
node server.js
```

### Build Issues with Native Modules
If you encounter build errors (especially on Apple Silicon):
```bash
# Install build tools
apk add python3 make g++

# Or use Docker
docker build -t currencyservice .
```

### Currency Data Not Loading
Verify the JSON file exists and is valid:
```bash
cat data/currency_conversion.json | json_pp
```

### gRPC Connection Errors
Check if the service is running:
```bash
netstat -an | grep 7000
```

Enable gRPC debug logging:
```bash
export GRPC_TRACE=all
export GRPC_VERBOSITY=DEBUG
node server.js
```

## Performance Considerations

- **In-Memory Data**: Exchange rates loaded from JSON at startup (fast lookups)
- **Lightweight Operations**: Simple arithmetic conversions (microsecond latency)
- **No External Dependencies**: No database or external API calls
- **Connection Pooling**: gRPC reuses connections efficiently
- **Async I/O**: Node.js event loop handles concurrent requests

## Accuracy Notes

- Exchange rates are static (loaded from JSON file)
- Based on European Central Bank data
- EUR is the base currency (rate = 1.0)
- Precision: 9 decimal places (nanos field)
- Rounding: Applied to final result

For production use, consider:
- Regular exchange rate updates
- Real-time rate APIs
- Rate caching strategies
- Historical rate versioning

## Security

- No authentication required (handled at gateway level)
- Input validation for currency codes
- No data persistence (stateless)
- Runs as non-root user in container
- Minimal attack surface (only gRPC endpoints)

## Contributing

1. Make changes to the source code
2. Run tests: `npm test`
3. Format code: `npm run lint` (if configured)
4. Build locally to verify
5. Commit and push to trigger CI/CD pipeline

## License

Apache License 2.0 - See LICENSE file for details.
