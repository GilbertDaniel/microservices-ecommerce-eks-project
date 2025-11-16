# Cart Service

The Cart service manages user shopping carts with support for both Redis-backed and in-memory storage.

## Overview

- **Language**: C# / .NET 8.0
- **Framework**: ASP.NET Core with gRPC
- **Port**: 7070
- **Storage**: Redis or In-Memory
- **Dependencies**:
  - Grpc.AspNetCore 2.57.0
  - Microsoft.Extensions.Caching.StackExchangeRedis 8.0.0
  - Google.Cloud.Spanner.Data 4.6.0
  - Npgsql 8.0.0

## Service Details

- **Service Name**: CartService
- **RPC Methods**:
  - `AddItem` - Add item to user's cart
  - `GetCart` - Retrieve user's cart
  - `EmptyCart` - Clear all items from cart
- **Health Check**: Supports gRPC health checking protocol
- **Storage Options**: 
  - Redis (production)
  - In-Memory (development/testing)

## Building Locally

### Prerequisites
- .NET 8.0 SDK or higher
- Docker (for containerization)
- Redis (optional, for local testing with Redis)

### Restore Dependencies

```bash
cd src/cartservice/src
dotnet restore
```

### Build the Application

```bash
dotnet build cartservice.csproj
```

### Run Locally

**With In-Memory Store (No Redis):**
```bash
dotnet run --project cartservice.csproj
```

**With Redis:**
```bash
export REDIS_ADDR="localhost:6379"
dotnet run --project cartservice.csproj
```

The service will start on port 7070.

### Run Tests

```bash
cd ../tests
dotnet test
```

## Building Docker Image

From the `src/cartservice/src/` directory:

```bash
docker build -t cartservice .
```

Run the container:

```bash
# With in-memory store
docker run -p 7070:7070 cartservice

# With Redis
docker run -p 7070:7070 -e REDIS_ADDR="redis:6379" cartservice
```

### Multi-stage Build

The Dockerfile uses a multi-stage build for optimization:
1. **Builder stage**: Uses `mcr.microsoft.com/dotnet/sdk:8.0` to build and publish
2. **Runtime stage**: Uses `mcr.microsoft.com/dotnet/runtime-deps:8.0-alpine` for minimal image size
3. **Optimizations**: 
   - Single-file deployment
   - Self-contained
   - Trimmed for reduced size

## Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `REDIS_ADDR` | Redis server address (host:port) | None | No (uses in-memory if not set) |
| `ASPNETCORE_HTTP_PORTS` | HTTP ports for the service | `7070` | No |
| `DOTNET_EnableDiagnostics` | Enable .NET diagnostics | `0` | No |

## CI/CD Pipeline

This service is automatically built and deployed using GitHub Actions.

### Workflow: CartService CI/CD

**Trigger**: Push to `main` branch with changes in `src/cartservice/**`

**Pipeline Stages**:
1. **Checkout**: Clone the repository
2. **Build**: Build Docker image with .NET 8.0
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
- **Repository**: `cartservice`
- **Tags**: 
  - `latest` - Always points to the most recent build
  - `<build-number>` - Specific version tag

## Deployment to Kubernetes

The service is deployed to EKS cluster using the manifest in `deployments/cartservice.yml`.

### Manual Deployment

```bash
kubectl apply -f deployments/cartservice.yml
```

### Verify Deployment

```bash
kubectl get pods -l app=cartservice
kubectl logs -l app=cartservice
kubectl describe svc cartservice
```

## Development

### Project Structure

```
src/cartservice/
├── cartservice.sln        # Solution file
├── src/
│   ├── cartservice.csproj # Project configuration
│   ├── Dockerfile         # Production container image
│   ├── Dockerfile.debug   # Debug container image
│   ├── Program.cs         # Application entry point
│   ├── Startup.cs         # Service configuration
│   ├── appsettings.json   # Configuration settings
│   ├── cartstore/         # Cart storage implementations
│   ├── protos/            # gRPC protocol definitions
│   └── services/          # gRPC service implementations
└── tests/                 # Unit and integration tests
```

### Redis Integration

The service automatically detects Redis availability:
- If `REDIS_ADDR` is set → Uses Redis for persistent storage
- If `REDIS_ADDR` is not set → Uses in-memory storage (data lost on restart)

### Adding New Dependencies

Edit `cartservice.csproj` and add package references:

```xml
<PackageReference Include="PackageName" Version="x.x.x" />
```

Then restore:
```bash
dotnet restore
```

## Troubleshooting

### Port Already in Use
If port 7070 is already in use:
```bash
export ASPNETCORE_HTTP_PORTS=7071
dotnet run
```

### Redis Connection Issues
Check Redis connectivity:
```bash
# Test Redis connection
redis-cli -h <redis-host> -p 6379 ping
```

Verify environment variable:
```bash
echo $REDIS_ADDR
```

### Build Issues
Clean and rebuild:
```bash
dotnet clean
dotnet build --no-incremental
```

### Container Issues
Check container logs:
```bash
docker logs <container-id>
```

Verify Redis connection from container:
```bash
docker exec -it <container-id> sh
# Inside container, check if Redis is accessible
```

## Performance

The service uses several optimizations:
- **Single-file deployment**: Faster startup
- **Self-contained**: No .NET runtime dependency
- **Trimmed**: Reduced image size
- **Alpine Linux**: Minimal base image
- **Redis caching**: Fast cart retrieval

## Security

- Runs as non-root user (UID 1000)
- Minimal runtime dependencies
- Diagnostics disabled in production
- No sensitive data in environment variables

## Contributing

1. Make changes to the source code
2. Test locally using `dotnet test`
3. Build Docker image to verify containerization
4. Commit and push to trigger CI/CD pipeline

## License

Apache License 2.0 - See source files for details.
