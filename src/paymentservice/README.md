# Payment Service

The Payment service handles credit card payment processing. It validates card information and simulates payment transactions by generating unique transaction IDs.

## Overview

- **Language**: Node.js 20.8.0
- **Framework**: gRPC with @grpc/grpc-js
- **Port**: 50051
- **Dependencies**:
  - @grpc/grpc-js 1.9.5
  - @grpc/proto-loader 0.7.10
  - simple-card-validator 1.1.0 - Card validation
  - uuid 9.0.0 - Transaction ID generation
  - OpenTelemetry for tracing
  - Google Cloud Profiler
  - Pino for structured logging

## Service Details

- **Service Name**: PaymentService
- **RPC Methods**:
  - `Charge` - Validates credit card and processes payment
- **Health Check**: Supports gRPC health checking protocol
- **Accepted Cards**: VISA and MasterCard only

### Payment Processing Flow

1. **Validate Card Number**: Check if card number is valid
2. **Check Card Type**: Accept only VISA or MasterCard
3. **Verify Expiration**: Ensure card is not expired
4. **Generate Transaction ID**: Return unique UUID as transaction identifier
5. **Log Transaction**: Record payment details

### Card Validation Rules

- **Card Format**: Validates using Luhn algorithm
- **Accepted Types**: 
  - ✅ VISA
  - ✅ MasterCard
  - ❌ AMEX (rejected)
  - ❌ Diners Club (rejected)
  - ❌ Other types (rejected)
- **Expiration Check**: Must be valid through current month/year

## Building Locally

### Prerequisites
- Node.js 20.8.0 or higher
- npm 9.x or higher
- Docker (for containerization)

### Install Dependencies

```bash
cd src/paymentservice
npm install
```

### Run Locally

```bash
# Set the port (default: 50051)
export PORT=50051

# Disable profiler for local development
export DISABLE_PROFILER=1

# Run the service
node index.js
```

The service will start on port 50051.

### Run Tests

```bash
npm test
```

## Building Docker Image

From the `src/paymentservice/` directory:

```bash
docker build -t paymentservice .
```

Run the container:

```bash
docker run -p 50051:50051 \
  -e PORT=50051 \
  -e DISABLE_PROFILER=1 \
  paymentservice
```

### Multi-stage Build

The Dockerfile uses a multi-stage build:
1. **Base stage**: Node.js 20.8.0-alpine image
2. **Builder stage**: Installs build dependencies (python3, make, g++) and npm packages
3. **Final stage**: Copies only production dependencies and source code

**Benefits**:
- Reduces image size by removing build tools (~100MB savings)
- Faster container startup
- Smaller attack surface

## Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `PORT` | gRPC server port | `50051` | Yes |
| `DISABLE_PROFILER` | Disable Google Cloud Profiler | Not set | No |
| `ENABLE_TRACING` | Enable OpenTelemetry tracing | `0` | No |
| `COLLECTOR_SERVICE_ADDR` | OTLP collector address | None | If tracing enabled |

## CI/CD Pipeline

This service is automatically built and deployed using GitHub Actions.

### Workflow: PaymentService CI/CD

**Trigger**: Push to `main` branch with changes in `src/paymentservice/**`

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
- **Repository**: `paymentservice`
- **Tags**: 
  - `latest` - Always points to the most recent build
  - `<build-number>` - Specific version tag

## Deployment to Kubernetes

The service is deployed to EKS cluster using the manifest in `deployments/paymentservice.yml`.

### Manual Deployment

```bash
kubectl apply -f deployments/paymentservice.yml
```

### Verify Deployment

```bash
kubectl get pods -l app=paymentservice
kubectl logs -l app=paymentservice
kubectl describe svc paymentservice
```

## Development

### Project Structure

```
src/paymentservice/
├── Dockerfile          # Container image definition
├── package.json        # Node.js dependencies
├── package-lock.json   # Locked dependency versions
├── index.js           # Main entry point (profiler, tracing setup)
├── server.js          # gRPC server implementation
├── charge.js          # Payment processing logic
├── proto/             # Protocol buffer definitions
│   └── demo.proto     # Service definition
└── genproto.sh       # Script to generate protobuf code
```

### Code Architecture

#### index.js
- Entry point for the application
- Initializes profiler and tracing
- Creates and starts HipsterShopServer

#### server.js
- Implements HipsterShopServer class
- Handles gRPC server setup
- Defines RPC method handlers
- Implements health check

#### charge.js
- Contains payment processing logic
- Validates credit cards using simple-card-validator
- Checks card expiration
- Generates transaction IDs

### Payment Request Format

```javascript
{
  amount: {
    currency_code: 'USD',
    units: 100,        // Dollars
    nanos: 500000000   // Cents (0.50)
  },
  credit_card: {
    credit_card_number: '4432-8015-6152-0454',
    credit_card_cvv: 672,
    credit_card_expiration_year: 2025,
    credit_card_expiration_month: 12
  }
}
```

### Payment Response Format

```javascript
{
  transaction_id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
}
```

### Error Handling

The service throws specific errors for different validation failures:

#### InvalidCreditCard
```javascript
throw new InvalidCreditCard();
// "Credit card info is invalid"
```

#### UnacceptedCreditCard
```javascript
throw new UnacceptedCreditCard('amex');
// "Sorry, we cannot process amex credit cards. Only VISA or MasterCard is accepted."
```

#### ExpiredCreditCard
```javascript
throw new ExpiredCreditCard('4432-8015-6152-0454', 11, 2023);
// "Your credit card (ending 0454) expired on 11/2023"
```

All errors have `code: 400` (Invalid argument).

### Card Validation

Uses `simple-card-validator` library:

```javascript
const cardValidator = require('simple-card-validator');
const cardInfo = cardValidator('4432-8015-6152-0454');
const { card_type, valid } = cardInfo.getCardDetails();

// card_type: 'visa', 'mastercard', 'amex', etc.
// valid: true/false (Luhn algorithm check)
```

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
- Log levels: info, warn, error
- Google Cloud-compatible severity field
- Transaction logging with card details (masked)

Example log output:
```json
{
  "level": "info",
  "message": "Transaction processed: visa ending 0454 Amount: USD100.50",
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
- Service context: `paymentservice` version `1.0.0`
- CPU and heap profiling
- Disable with `DISABLE_PROFILER=1`

### Health Check

```bash
grpcurl -plaintext localhost:50051 grpc.health.v1.Health/Check
```

## Testing the Service

### Using grpcurl

Successful charge:
```bash
grpcurl -plaintext -d '{
  "amount": {
    "currency_code": "USD",
    "units": 100,
    "nanos": 500000000
  },
  "credit_card": {
    "credit_card_number": "4432-8015-6152-0454",
    "credit_card_cvv": 672,
    "credit_card_expiration_year": 2025,
    "credit_card_expiration_month": 12
  }
}' localhost:50051 hipstershop.PaymentService/Charge
```

### Test Cases

#### Valid VISA Card
```javascript
{
  credit_card_number: "4532-1488-0343-6467",
  credit_card_cvv: 123,
  credit_card_expiration_year: 2025,
  credit_card_expiration_month: 12
}
```

#### Valid MasterCard
```javascript
{
  credit_card_number: "5425-2334-3010-9903",
  credit_card_cvv: 456,
  credit_card_expiration_year: 2026,
  credit_card_expiration_month: 6
}
```

#### Invalid Card (Should Fail)
```javascript
{
  credit_card_number: "1234-5678-9012-3456",  // Invalid
  credit_card_cvv: 123,
  credit_card_expiration_year: 2025,
  credit_card_expiration_month: 12
}
```

#### Expired Card (Should Fail)
```javascript
{
  credit_card_number: "4532-1488-0343-6467",
  credit_card_cvv: 123,
  credit_card_expiration_year: 2020,  // Expired
  credit_card_expiration_month: 1
}
```

#### AMEX Card (Should Fail)
```javascript
{
  credit_card_number: "3782-822463-10005",  // AMEX - not accepted
  credit_card_cvv: 1234,
  credit_card_expiration_year: 2025,
  credit_card_expiration_month: 12
}
```

## Troubleshooting

### Port Already in Use
If port 50051 is already in use:
```bash
export PORT=50052
node index.js
```

Or check what's using the port:
```bash
lsof -i :50051
netstat -an | grep 50051
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
node index.js
```

### Build Issues with Native Modules
If you encounter build errors (especially on Apple Silicon):
```bash
# Install build tools
apk add python3 make g++

# Or use Docker
docker build -t paymentservice .
```

### Invalid Card Errors
Verify card number with Luhn algorithm:
```javascript
const cardValidator = require('simple-card-validator');
console.log(cardValidator('4532-1488-0343-6467').isValid());
```

### gRPC Connection Errors
Check if the service is running:
```bash
netstat -an | grep 50051
```

Enable gRPC debug logging:
```bash
export GRPC_TRACE=all
export GRPC_VERBOSITY=DEBUG
node index.js
```

### Transaction ID Generation Issues
Verify UUID generation:
```bash
node -e "console.log(require('uuid').v4())"
```

## Security Considerations

### PCI Compliance Note
⚠️ **Important**: This is a demo service and does NOT meet PCI-DSS requirements.

**For production use**:
- Never log full credit card numbers
- Use tokenization services (Stripe, PayPal, etc.)
- Implement proper encryption at rest and in transit
- Follow PCI-DSS compliance guidelines
- Use payment gateway APIs instead of direct card processing

### Current Security Features
- No data persistence (stateless)
- Card numbers masked in logs (last 4 digits only)
- Input validation
- gRPC transport security (configure TLS in production)
- Runs as non-root user in container

### Recommended Production Improvements
```javascript
// Use payment gateway instead
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

async function charge(request) {
  const paymentIntent = await stripe.paymentIntents.create({
    amount: request.amount.units * 100 + Math.floor(request.amount.nanos / 10000000),
    currency: request.amount.currency_code.toLowerCase(),
    payment_method: request.payment_token, // Use token, not raw card
    confirm: true
  });
  
  return { transaction_id: paymentIntent.id };
}
```

## Performance Considerations

- **Synchronous Processing**: Each charge is processed synchronously
- **No Database**: Stateless operation (fast response times)
- **Lightweight Validation**: Card validation is CPU-bound but fast
- **UUID Generation**: Very fast (microseconds)
- **No External API Calls**: All processing is local (demo mode)

### Expected Performance
- **Latency**: < 10ms per transaction
- **Throughput**: 1000+ TPS per instance
- **Memory**: ~50MB per instance
- **CPU**: Minimal (validation only)

## Payment Gateway Integration

For production, integrate with real payment processors:

### Stripe
```bash
npm install stripe
```

```javascript
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

async function charge(request) {
  const charge = await stripe.charges.create({
    amount: request.amount.units * 100,
    currency: request.amount.currency_code.toLowerCase(),
    source: request.payment_token
  });
  return { transaction_id: charge.id };
}
```

### PayPal
```bash
npm install @paypal/checkout-server-sdk
```

### Square
```bash
npm install square
```

### Braintree
```bash
npm install braintree
```

## Extending the Service

### Add Support for More Card Types

```javascript
// In charge.js
const acceptedCards = ['visa', 'mastercard', 'discover', 'jcb'];
if (!acceptedCards.includes(cardType)) {
  throw new UnacceptedCreditCard(cardType);
}
```

### Add Fraud Detection

```javascript
function detectFraud(request) {
  const { amount, credit_card } = request;
  
  // Check for suspicious patterns
  if (amount.units > 10000) {
    logger.warn('Large transaction detected');
  }
  
  // Implement velocity checks, IP verification, etc.
}
```

### Add Refund Support

```javascript
class HipsterShopServer {
  static RefundServiceHandler(call, callback) {
    const { transaction_id, amount } = call.request;
    logger.info(`Refund requested for transaction ${transaction_id}`);
    callback(null, { refund_id: uuidv4() });
  }
}
```

## Contributing

1. Make changes to the source code
2. Run tests: `npm test`
3. Format code: `npm run lint` (if configured)
4. Build locally to verify
5. Commit and push to trigger CI/CD pipeline

## Related Services

- **Checkout Service**: Calls payment service to charge cards
- **Currency Service**: Converts amounts to USD if needed

## License

Apache License 2.0 - See LICENSE file for details.
