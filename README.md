# Docker Layer Caching in AWS CodeBuild Using Docker BuildKit (Docker 23)

This documentation provides a comprehensive guide to optimizing Docker builds in AWS CodeBuild using Docker BuildKit (Docker version 23+), explaining core concepts, configuration, and best practices. It covers how to achieve efficient, cross-host Docker layer caching with clear examples and explanations.

## 1. What is Docker BuildKit?

**Docker BuildKit** is a modern, advanced builder toolkit integrated within newer versions of Docker (including Docker 23). It enhances the traditional `docker build` process with the following key features:

- **Faster builds:** Supports parallel build steps and automatic skipping of unchanged layers.
- **Advanced caching:** Allows remote (registry-based) and inline cache metadata, making cross-host caching possible.
- **Better output:** More informative and consistent build logs.
- **Secret management and security:** Supports passing build-time secrets without leaking them into images.
- **Flexibility:** More control over build arguments, outputs, and cache import/export.

_Traditional Docker build only supports local, host-based cache, which is lost between CodeBuild runs. BuildKit solves this by enabling persistent, image-based cache._

## 2. Why Use Docker BuildKit in AWS CodeBuild?

- **Faster builds, even on fresh hosts:** Unlike classic Docker caching, which persists only if builds land on the same build VM, BuildKit allows cache reuse through your pushed image in a Docker registry (like Amazon ECR).
- **Cost efficiency:** Reduces build time and resources by avoiding redundant installation of dependencies.
- **Repeatability:** Ensures consistent builds regardless of CI/CD host assignment.

**Typical challenge:**  
AWS CodeBuild runs on fresh, ephemeral hosts, losing Docker's default local cache. Without BuildKit, your builds **always** start from scratch. BuildKit enables restoring cache from previously pushed images, speeding up every build.

## 3. How Docker BuildKit Caching Works

**BuildKit caching enables:**

- Storing layer metadata (“cache”) **inside** the image manifest pushed to ECR.
- Importing that cache on subsequent builds through `--cache-from`.
- Skipping unchanged build steps at the registry layer (not just on the local disk).

**Concept diagram:**

1. **First build:**
   - Full image is built with cache metadata.
   - Image and its cache are pushed to ECR.

2. **Later builds:**
   - Image is pulled from ECR with inline cache metadata.
   - Docker BuildKit matches layers, skipping all unchanged steps.
   - Only new or changed steps/layers are rebuilt.

## 4. Step-by-Step: Setting Up BuildKit-Based Docker Caching in CodeBuild

### Prerequisites

- **CodeBuild with Docker 23+ runtime.**
- **Privileged mode enabled** (required for Docker-in-Docker).
- **Amazon ECR** repository (for image storage and caching).

### Example buildspec.yml

```yaml
version: 0.2

phases:
  install:
    runtime-versions:
      docker: 23
    commands:
      - echo "Enabling BuildKit"
      - export DOCKER_BUILDKIT=1
  pre_build:
    commands:
      - echo "Moving into build phase"
      - echo "Build Host:" && uname -n
      - docker login -u "$DOCKER_USERNAME" -p "$DOCKER_PASSWORD"
      - aws ecr get-login-password --region  | docker login --username AWS --password-stdin $AWS_REGISTRY_URL
  build:
    commands:
      - echo Build started on `date`
      - echo Pulling remote layer cache
      - docker pull $AWS_REGISTRY_URL:latest || true
      - echo Building Docker image with BuildKit cache...
      - docker build --build-arg BUILDKIT_INLINE_CACHE=1 --cache-from type=registry,ref=$AWS_REGISTRY_URL:latest --progress=plain -t $AWS_REGISTRY_URL:${CODEBUILD_RESOLVED_SOURCE_VERSION} -f  .
      - echo Build completed on `date`
      - docker push $AWS_REGISTRY_URL:${CODEBUILD_RESOLVED_SOURCE_VERSION}
      - MANIFEST=$(aws ecr batch-get-image --repository-name $ECR_REPO_NAME --image-ids imageTag="${CODEBUILD_RESOLVED_SOURCE_VERSION}" --output json | jq --raw-output --join-output '.images[0].imageManifest')
      - aws ecr put-image --repository-name $ECR_REPO_NAME --image-tag latest --image-manifest "$MANIFEST"
  post_build:
    commands:
      - '[ ${CODEBUILD_BUILD_SUCCEEDING:-0} -eq 1 ] || exit 1'
      - echo "Successfully Finished Pushing the Image with Cache to ECR!!"
```

**Notes:**
- Replace `$AWS_REGISTRY_URL`, `$CODEBUILD_RESOLVED_SOURCE_VERSION`, ``, and `` with your actual values.
- `BUILDKIT_INLINE_CACHE=1` tells Docker to embed cache information in the image manifest.
- `--cache-from type=registry,ref=...` pulls cache from the ECR registry image.
- `--progress=plain` provides detailed step-by-step build logs.

### Minimal Example Dockerfile (pinned base for best caching)

```dockerfile
FROM amazonlinux@sha256:
# Combine RUNs for best caching
RUN dnf update -y && \
    dnf install -y php8.4 ... && \
    dnf clean all

# App/extension install, config, etc.
```
**Tip:** Pin your base image by digest (`@sha256:...`) so Docker can always match the image base.

## 5. Explanation of Key Options and Concepts

### **BUILDKIT_INLINE_CACHE**

- Instructs Docker to record layer cache metadata *inside* the image.
- Required for registry-based cache imports because this metadata is what lets future builds reuse cache on any build host.

### **--cache-from type=registry,ref=...**

- Tells BuildKit to import cache metadata from a given image tag in a registry (ECR).
- If a previous build already pushed an image with inline cache, the current build will skip unchanged steps.

### **docker push**

- Uploads both the built image and its embedded cache metadata.
- Necessary after every build, so the next build has your latest cache.

### **docker pull ...:latest**

- Ensures the most recently cached layers are present before starting the build (in environments with no persisted local cache).

### **Pinning the base image**

- Use a base image with an explicit digest (`FROM amazonlinux@sha256:...`), not just a tag.
- This prevents Docker from rebuilding layers if the remote `latest` tag is updated by its maintainers.

### **Verbose logs (--progress=plain)**

- Use this to get full build output in CI for easy troubleshooting and to see exactly when cache is used.

## 6. Best Practices for Maximizing Cache Efficiency

- **Order Dockerfile layers smartly.**  
  Add long-running, rarely changed tasks (OS, global dependencies) first; copy app code AFTER those instructions.
- **Pin all base images.**  
  Prevents cache invalidation due to upstream image updates.
- **Build and push on every main branch commit.**  
  Ensures cache stays warm for everyone.
- **Test cache hits.**  
  Run two builds in a row; the first is full, the second should be fast.
- **Review logs for cache miss/hit clues.**

## 7. Table: Classic Docker vs. BuildKit-based Caching in CodeBuild

| Feature                              | Classic Docker Cache         | Docker BuildKit + Inline Cache  |
|--------------------------------------|-----------------------------|---------------------------------|
| Per-build host cache persistence     | No                          | Yes, from remote image manifest |
| Cross-host CI cache re-use           | No                          | Yes                             |
| Faster builds after first run        | Rarely (only on reused host) | Yes, always                     |
| Needs base image pinning?            | No, but strongly recommended | Yes, crucial for effectiveness  |
| Supported in CodeBuild Docker 23+    | Yes                         | Yes                             |

## 8. Troubleshooting and Common Issues

- **Build cache not reused?**
  - Check if base image changed (digest vs tag).
  - Ensure prior image was pushed with `BUILDKIT_INLINE_CACHE=1`.
  - Confirm use of `--cache-from type=registry,ref=...`.
- **Error: duplicate cache exports [inline]**
  - Don’t use both `--build-arg BUILDKIT_INLINE_CACHE=1` and `--cache-to type=inline`; use only the former with standard Docker CLI.
- **BuildKit features not enabled?**
  - Set `DOCKER_BUILDKIT=1` in your environment before all build commands.

## 9. Summary

- **Docker BuildKit** is required for persistent, cross-host Docker layer caching in CodeBuild, enabling much faster repeated builds and dramatic reduction in dependency install times.
- **Always push images with `BUILDKIT_INLINE_CACHE=1` and build with `--cache-from type=registry` for cache reuse.**
- **Pin your base images for stable and effective cache usage.**
- **Order your Dockerfile for optimal caching, and monitor the build logs for cache utilization.**
