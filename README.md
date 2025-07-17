# CodeBuild
## 1. What Are CodeBuild Artifacts?

* **Definition**
  Artifacts are simply the **built output** of your CodeBuild project. Anything your build produces—binaries, static website files, archives, container images—can be an artifact.

* **Purpose**

  1. **Distribution**: Share the build result with downstream services (deploy, test, or Lambda).
  2. **Versioning & Storage**: Keep a record of each build’s output for auditing or rollback.
  3. **Integration**: Other AWS services (CodeDeploy, ECS, S3 hosts) can automatically pull from your artifact store.

---

## 2. Artifact **Types** & When to Use Them

| Artifact Type | Destination      | Use Case                                                 |
| ------------- | ---------------- | -------------------------------------------------------- |
| **S3**        | Amazon S3 bucket | – Zipped code bundles (Node.js, Java JARs, static sites), Artifacts for CodeDeploy, CloudFormation |
| **ECR**       | Amazon ECR repo | – Docker images for ECS, Kubernetes, Batch, or on‑prem.|


---

### 2.1 S3 Artifacts

#### Why S3?

* **Universal storage**: Almost any AWS service or CI/CD tool can fetch a .zip/.tar from S3.
* **Fine‑grained access control** via IAM & bucket policies.
* **Lifecycle rules** to automatically archive or delete old builds.

#### Anatomy of an S3 Artifact Configuration

```yaml
artifacts:
  # 1. What files to include (relative to your build’s working directory)
  files:
    - dist/**/*         # include everything under “dist/”
    - config/database.yml
  # 2. (Optional) Flatten directory structure
  discard-paths: yes

  # 3. The “override” name for the zip in S3
  name: my-app-$(date +%Y%m%d)-build.zip

  # 4. Encryption (default is true)
  encryption-disabled: false

  # 5. (In Console) Target S3 bucket
  #      – bucket “codebuild-artifacts-us-east-1”
  #      – path “my-app/builds/”
```

* **Example Explanation**

  * After the build, everything under `dist/` plus the `database.yml` gets zipped.
  * `discard-paths: yes` means if you had `dist/css/style.css`, inside the zip it’ll be at `css/style.css` rather than `dist/css/style.css`.
  * The zip is named like `my-app-20250717-build.zip`.
  * CodeBuild uploads it to `s3://codebuild-artifacts-us-east-1/my-app/builds/`.

---

### 2.2 ECR Artifacts (Docker Images)

#### Why ECR?

* **Private Docker registry** fully managed by AWS.
* **Tight IAM integration**: control who can push/pull images.
* **Integrated caching**: faster layer pull/push when building.

#### Anatomy of an ECR Artifact Configuration

```yaml
artifacts:
  type: NO_ARTIFACTS           # skip S3 zip
cache:
  # enable Docker layer cache locally
  modes:
    - LOCAL_DOCKER_LAYER_CACHE
```

And in your buildspec, you handle the push:

```yaml
phases:
  build:
    commands:
      - $(aws ecr get-login-password --region $AWS_DEFAULT_REGION) \
          | docker login --username AWS --password-stdin 123456789012.dkr.ecr.us-east-1.amazonaws.com
      - docker build -t my-app:$CODEBUILD_RESOLVED_SOURCE_VERSION .
      - docker tag my-app:$CODEBUILD_RESOLVED_SOURCE_VERSION \
          123456789012.dkr.ecr.us-east-1.amazonaws.com/my-app:latest
      - docker push 123456789012.dkr.ecr.us-east-1.amazonaws.com/my-app:latest
artifacts:
  # no S3 artifact because we’re pushing images
  files: []
```

* **Example Explanation**

  * We disable S3 artifacts (`type: NO_ARTIFACTS`) because our “artifact” is the Docker image in ECR.
  * We log in to ECR, build & tag the image, then push it.
  * Downstream (ECS, Kubernetes) can now pull `my-app:latest` directly.

---

## 3. Why Use S3 **and** ECR?

Sometimes a build produces **both**:

1. **Code bundle** for a Lambda function (zip → S3).
2. **Docker image** for ECS (image → ECR).

Your `buildspec.yml` can orchestrate both:

```yaml
version: 0.2

phases:
  install:
    runtime-versions:
      nodejs: 18
  build:
    commands:
      # 1. Build Lambda package
      - npm ci && npm run build:lambda
      - zip -r lambda.zip dist/lambda

      # 2. Build Docker image
      - $(aws ecr get-login-password) | docker login --username AWS --password-stdin 111111111111.dkr.ecr.us-west-2.amazonaws.com
      - docker build -t webapp:$CODEBUILD_RESOLVED_SOURCE_VERSION webapp/
      - docker push 111111111111.dkr.ecr.us-west-2.amazonaws.com/webapp:latest

artifacts:
  files:
    - lambda.zip
  base-directory: .   # where lambda.zip lives
cache:
  modes:
    - LOCAL_DOCKER_LAYER_CACHE
```

* At the end you get:

  * `lambda.zip` in **S3** (for your Lambda deployment action).
  * `webapp:latest` pushed to **ECR** (for your ECS service).

---

## 4. Advanced Artifact Parameters

| Parameter                   | Details                                                                                        |
| --------------------------- | ---------------------------------------------------------------------------------------------- |
| **files**                   | Glob patterns of what to include in the artifact.                                              |
| **base-directory**          | Directory to `cd` into before zipping.                                                         |
| **discard-paths** (boolean) | Flatten paths inside the zip (remove parent directories).                                      |
| **name**                    | Override the default artifact filename. Useful for human‑readable names or versioning.         |
| **encryption-disabled**     | When `false`, uses AWS-managed S3‑SSE; when `true`, stores unencrypted.                        |
| **packaging**               | `ZIP` (default) or `NONE` (if you just want to upload raw folder structure).                   |
| **override-artifact-name**  | In the Console UI: lets you pick a static file name rather than the generated one.             |
| **artifact-identifier**     | In Console UI: if you have multiple artifacts in a single project, this is how you label them. |
| **cache.type**              | `NO_CACHE` vs. `LOCAL` vs. `S3`.                                                               |
| **cache.location**          | For S3 cache, which bucket/prefix to use.                                                      |
| **encryption-key**          | (Optional) KMS key ARN for custom encryption of your S3 artifacts or cache.                    |

---

## 5. Putting It All Together: Visual Example

**Console “Artifacts” panel** maps to these fields:

| Console Label               | buildspec.yml Key               | Notes                                                                              |
| --------------------------- | ------------------------------- | ---------------------------------------------------------------------------------- |
| Artifact identifier         | N/A (Console only)              | Friendly label if you have >1 artifact                                             |
| Artifacts upload location   | `artifacts.location`            | Your S3 bucket name                                                                |
| Disable artifact encryption | `artifacts.encryption-disabled` | `true` or `false`                                                                  |
| Override artifact name      | `artifacts.name`                | Overrides the default zip name                                                     |
| Cache type                  | `cache.type`                    | `NO_CACHE` / `LOCAL` / `S3`                                                        |
| Cache location              | `cache.location`                | Bucket (for S3) or ignored (for LOCAL)                                             |
| Encryption key              | (Console only)                  | KMS key ARN—buildspec doesn’t natively expose it, but you can script with AWS CLI. |

---

### **Key Takeaways**

1. **Choose S3** for code bundles, static sites, Lambda packages, CodeDeploy.
2. **Choose ECR** for Docker images.
3. You can—and often will—produce **both** in one build.
4. **Caching** (S3 or LOCAL) speeds up repeat builds (e.g. reusing `node_modules` or Docker layers).
5. Use descriptive **artifact names** and **paths** to keep your pipeline organized and easy to debug.

>  - With these building blocks—globs, packaging, encryption, and cache—you can tailor CodeBuild artifacts from a simple “zip my code” to a sophisticated multi‑artifact, container‑based workflow. Once comfortable with the basics, you can add versioning, dynamic names (with environment variables), even post‑build scripts to invoke KMS or Lifecycle rules on your S3 bucket.

Below is a deep‑dive on **every field** you see in the **Artifacts & Cache** section of the CodeBuild console—what it means, why you’d use it, how to set it (in the Console or in your `buildspec.yml`), and simple examples for each.

---

## Artifacts Section

When your build completes, CodeBuild can collect files (or images) you’ve produced and send them somewhere for later use. That “somewhere” is defined here.

| **Console Field**               | **What It Means**                                                                                                                  | **How to Define**                                                                                   | **Why / Advantages**                                                                                                            | **Example**                                                                                                                          |
| ------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| **Artifact identifier**         | A **friendly name** you give this artifact configuration.  Useful only if you define **multiple** artifact bundles in one project. | Console Only. No direct buildspec key.                                                              | Helps you reference “frontend‑zip” vs. “lambda‑bundle” within one CodeBuild project.                                            | In Console, click **Add artifact**, then set **Artifact identifier** = `frontend-zip`.                                               |
| **Artifacts upload location**   | The **S3 bucket** (and optional path/prefix) where CodeBuild will upload your artifact ZIP or bundle.                              | In Console: bucket + path.  In buildspec:  <br> `yaml<br>artifacts:<br>  location: my-bucket/path/` | Central, durable storage. Any service (CodeDeploy, CloudFormation, your CD pipeline) can pull from it.                          | `yaml<br>artifacts:<br>  location: my-app-builds-us-east-1/releases/<br>`<br>→ Files go to `s3://my-app-builds-us-east-1/releases/…` |
| **Disable artifact encryption** | Turn **off** S3 server‑side encryption (SSE‑S3 or SSE‑KMS) for this artifact.                                                      | Console: toggle.  In buildspec:  <br> `yaml<br>artifacts:<br>  encryption-disabled: true`           | Only disable if you need public, unencrypted uploads for debugging or hosting. Otherwise, leave **encryption on** for security. | `yaml<br>artifacts:<br>  encryption-disabled: false  # recommended default<br>`                                                      |
| **Override artifact name**      | Force a **fixed, human‑readable filename** (instead of CodeBuild’s default random‑UUID zip).                                       | Console: enter name.  In buildspec:  <br> `yaml<br>artifacts:<br>  name: release-v1.2.3.zip`        | Makes it easier to spot “v1.2.3” in S3—useful for tagging releases.                                                             | `yaml<br>artifacts:<br>  name: webapp-$(date +%Y%m%d)-build.zip<br>`                                                                 |
| **Packaging**                   | ZIP up everything (`ZIP`) or upload raw files/folders (`NONE`).                                                                    | Console dropdown.  In buildspec:  <br> `yaml<br>artifacts:<br>  packaging: NONE`                    | `ZIP` (default) is best for code bundles; `NONE` if you want to preserve folder layout in S3.                                   | `yaml<br>artifacts:<br>  packaging: NONE  # files land as-is under the S3 prefix<br>`                                                |

### Complete S3‑Artifact Example

```yaml
version: 0.2

artifacts:
  files:
    - dist/**/*              # Include all built front-end files
    - config/production.yml  # Include config file
  base-directory: dist       # Zip root is “dist/” (not “dist/dist/…”)
  discard-paths: yes         # Flattens file paths inside the zip
  name: website-$(git rev-parse --short HEAD).zip
  location: my-static-bucket/releases/
  encryption-disabled: false
  packaging: ZIP
```

> **Result**: A file named like
> `website-a1b2c3d.zip`
> containing your built site, uploaded to
> `s3://my-static-bucket/releases/website-a1b2c3d.zip`
> with server‑side encryption turned on.

---

## Cache Section

Caching re‑uses previously downloaded or built artifacts (like `node_modules` or Docker layers) so **your builds run faster**.

| **Console Field**  | **What It Means**                                                                                                                           | **How to Define**                                                                                            | **Why / Advantages**                                                                               | **Example**                                                                                                        |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| **Cache type**     | Where to store your cache: <br> • **No cache** (fresh build each time) <br> • **Local** (on the CodeBuild host) <br> • **S3** (centralized) | Console dropdown.  In buildspec:  <br> `yaml<br>cache:<br>  type: LOCAL`                                     | Speeds up `npm install`, `pip install`, or `docker build` by re‑using prior layers/dependencies.   | `cache: { type: NO_CACHE }` <br>or <br>`cache: { type: LOCAL }`                                                    |
| **No cache**       | **Equivalent** to `cache.type: NO_CACHE`—every build starts completely fresh.                                                               | Default; no buildspec needed.                                                                                | Ideal for debugging “clean‑state” issues or security‑sensitive builds.                             | (Nothing to define; leave as default.)                                                                             |
| **Cache location** | If you choose **S3** cache, this is the **S3 bucket** (and prefix) to store your cached archives.                                           | Console: bucket + path. <br> buildspec:  <br> `yaml<br>cache:<br>  location: my-cache-bucket/docker-layers/` | Persists cache **between** build hosts—great for large teams or long‑lived cache.                  | `yaml<br>cache:<br>  type: S3<br>  location: my-ci-cache-bucket/node-modules/`                                     |
| **Encryption key** | *(Console only)* A **KMS key ARN** to encrypt your **S3 cache** or **artifacts** with your own customer‑managed key instead of SSE‑S3.      | Console: paste the ARN of your KMS key.  Not exposed directly in buildspec.                                  | Use your own KMS key for compliance; gives you full control over key rotation and access policies. | In Console, set **Encryption key** = `arn:aws:kms:us-east-1:123456789012:key/abcdef00-1111-2222-3333-444455556666` |

---

### Complete Cache Examples

1. **Local cache** (fast Docker builds + dependencies on same host):

   ```yaml
   cache:
     type: LOCAL
     modes:
       - LOCAL_SOURCE_CACHE          # caches your source code checkout
       - LOCAL_DOCKER_LAYER_CACHE    # caches docker layers between runs
   ```

   > **Advantage**: Next build re‑uses layers for any unchanged `RUN` steps in your Dockerfile.

2. **S3 cache** (shared cache across hosts/builds):

   ```yaml
   cache:
     type: S3
     location: my-shared-cache-bucket/ci-cache/
   ```

   > **Advantage**: All builds—regardless of host—can reuse the same `node_modules`, speeding up installs across your team.

---

## Key Takeaways

* **Artifact identifier** only matters when you have **more than one** artifact target.
* **Upload location**, **packaging**, **encryption**, and **name** control **how** and **where** your build outputs are stored.
* **No cache** vs. **Local** vs. **S3** lets you trade off between **clean builds** and **faster builds**.
* **Encryption key** (KMS) is all about compliance—use it if you need strict control over at‑rest encryption.

Once you’ve defined these settings—either in the Console or in `buildspec.yml`—CodeBuild will automatically handle the rest: packaging your outputs, uploading them, and/or pulling and pushing cache layers to accelerate your next build.
