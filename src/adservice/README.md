# Ad Service

The Ad service provides advertisements based on context keys. If no context keys are provided, it returns random ads.

## Overview

- **Language**: Java 19
- **Framework**: gRPC
- **Build Tool**: Gradle 7.x
- **Port**: 9555
- **Dependencies**: 
  - gRPC 1.58.0
  - Protocol Buffers 3.24.4
  - Log4j 2.20.0
  - Stackdriver Profiler (for monitoring)

## Service Details

- **Service Name**: AdService
- **RPC Methods**:
  - `GetAds(AdRequest)` - Returns contextual advertisements
- **Health Check**: Supports gRPC health checking protocol
- **Monitoring**: Integrated with Google Cloud Profiler

## Building Locally

The Ad service uses Gradle wrapper to compile, install, and distribute. The Gradle wrapper is included in the source code.

### Prerequisites
- Java 19 or higher
- Docker (for containerization)

### Build the Application

```bash
./gradlew installDist
```

This will create an executable script at:
```
src/adservice/build/install/hipstershop/bin/AdService
```

### Run Locally

```bash
./build/install/hipstershop/bin/AdService
```

The service will start on port 9555 (configurable via `PORT` environment variable).

### Run Tests

```bash
./gradlew test
```

### Format Code

```bash
./gradlew googleJavaFormat
```

## Building Docker Image

From the `src/adservice/` directory:

```bash
docker build -t adservice .
```

Run the container:

```bash
docker run -p 9555:9555 adservice
```

### Multi-stage Build

The Dockerfile uses a multi-stage build:
1. **Builder stage**: Uses `eclipse-temurin:19` to compile the application
2. **Runtime stage**: Uses `eclipse-temurin:19-jre-alpine` for a smaller image

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `PORT` | gRPC server port | `9555` |

## CI/CD Pipeline

This service is automatically built and deployed using GitHub Actions:

### Workflow: AdService CI/CD

**Trigger**: Push to `main` branch with changes in `src/adservice/**`

**Pipeline Stages**:
1. **Checkout**: Clone the repository
2. **Build**: Build Docker image
3. **Push to ECR**: Tag and push to Amazon ECR
4. **Update Manifests**: Update Kubernetes deployment with new image tag
5. **Commit**: Commit and push updated manifests

### Required Secrets

Configure these in GitHub repository settings:
- `AWS_ACCESS_KEY_ID` - AWS credentials for ECR access
- `AWS_SECRET_ACCESS_KEY` - AWS secret key
- `GH_PAT` - GitHub Personal Access Token for pushing changes

### ECR Configuration

- **Registry**: `242201296943.dkr.ecr.us-east-1.amazonaws.com`
- **Repository**: `adservice`
- **Tags**: 
  - `latest` - Always points to the most recent build
  - `<build-number>` - Specific version tag

## Deployment to Kubernetes

The service is deployed to EKS cluster using the manifest in `kubernetes-files/adservice.yaml`.

### Manual Deployment

```bash
kubectl apply -f kubernetes-files/adservice.yaml
```

### Verify Deployment

```bash
kubectl get pods -l app=adservice
kubectl logs -l app=adservice
```

## Development

### Project Structure

```
src/adservice/
├── build.gradle           # Gradle build configuration
├── Dockerfile            # Container image definition
├── gradlew              # Gradle wrapper script
├── settings.gradle      # Gradle settings
└── src/
    └── main/
        └── java/
            └── hipstershop/
                ├── AdService.java        # Main service implementation
                └── AdServiceClient.java  # Test client
```

### Upgrading Gradle Version

```bash
./gradlew wrapper --gradle-version <new-version>
```

### Upgrading Dependencies

Edit `build.gradle` to update versions:
- `grpcVersion` - gRPC framework version
- `protocVersion` - Protocol Buffers version
- `jacksonCoreVersion` - Jackson JSON library

Then run:
```bash
./gradlew build --refresh-dependencies
```

## Troubleshooting

### Port Already in Use
If port 9555 is already in use, set a different port:
```bash
PORT=9556 ./build/install/hipstershop/bin/AdService
```

### Gradle Build Issues
Clean and rebuild:
```bash
./gradlew clean build
```

### Docker Build Fails
Ensure you have sufficient disk space and Docker is running:
```bash
docker system prune -f
docker build -t adservice .
```

## Contributing

1. Make changes to the source code
2. Test locally using `./gradlew test`
3. Format code using `./gradlew googleJavaFormat`
4. Commit and push to trigger CI/CD pipeline

## License

Apache License 2.0 - See source files for details.


