# Real Time Ruby On Rails Chat App, Creating Docker Image with AWS CodeBuild.
## Create `Dockerfile` in the root path of Repo
The Dockerfile specifies the steps to create the application’s Docker image. A typical Dockerfile for a RoR application might look like this which is provided below:

<details>
  <summary>Click to view Dockerfile</summary>

```dockerfile
# Dockerfile

FROM ruby:3.2.2
## This pulls the official Ruby 3.2.2 image from Docker Hub (Docker Hub),
## which includes Ruby and a Debian-based Linux environment.
## This is the foundation for the container, ensuring compatibility with the RoR applica                                                                                                tion.

# Set working directory
WORKDIR /app

## Sets the working directory inside the container to /app,
## where all subsequent commands will execute.
## This is where the application code will reside,
## following best practices for organization.

# Install packages
RUN apt-get update -qq && apt-get install -y build-essential libpq-dev nodejs curl redis

## Updates the package list quietly (-qq) and installs essential packages:
### build-essential: Provides compilers and libraries (e.g., gcc, make) needed for building software.
### libpq-dev: Development files for PostgreSQL, required for the pg gem used in Rails for database connectivity.
### nodejs: JavaScript runtime, necessary for asset compilation (e.g., Webpacker or Sprockets).
### curl: A tool for transferring data, used here for installing additional tools like Yarn.
## redis: Installs the Redis server, likely used for caching or real-time features like ActionCable.
## This step ensures the container has all system-level dependencies for the RoR app.

# Install Yarn
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
  && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
  && apt-get update && apt-get install -y yarn

## Installs Yarn, a package manager for JavaScript, which is often used in Rails for managing frontend dependencies:
### First, adds the Yarn GPG key for secure package verification.
### Adds the Yarn repository to the sources list.
### Updates the package list and installs Yarn.
## This is crucial for applications using JavaScript frameworks or asset pipelines.

# Install bundler
RUN gem install bundler

## Installs Bundler, the Ruby dependency manager,
## which reads the Gemfile to install gems.
## This ensures the RoR application has all required Ruby libraries.

# Copy Gemfiles and install dependencies
COPY Gemfile* ./
RUN bundle install

## Copies the Gemfile and Gemfile.lock to the container,
## then runs bundle install to install the gems specified.
## This step is done early to leverage Docker layer caching,
## improving build times if the Gemfile doesn't change.

# Copy rest of the application
COPY . .
## Copies the entire application code from the host to the container's /app directory.
## This includes all source files, configurations, and assets.

# Ensure tmp directories exist
RUN mkdir -p tmp/pids tmp/cache tmp/sockets log
## Creates directories for temporary files, cache, sockets, and logs.
## The -p flag ensures parent directories are created if they don't exist,
## preventing errors. These directories are standard for Rails applications,
## used by Puma and other processes.


# Precompile assets (optional for production)
RUN bundle exec rake assets:precompile

## Precompiles assets (CSS, JavaScript) for production using the rake
## assets:precompile task. This step is optional but recommended for production
## to improve performance by serving precompiled assets, reducing server load.

# Expose the app port
EXPOSE 3000

## Informs Docker that the container listens on port 3000 at runtime.
## This is the default port for Rails applications using Puma,
## making it accessible externally when mapped.

# Start the app with Puma
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]

## Specifies the default command to run when the container starts.
## It uses Bundler to execute Puma, the web server for Rails,
## with the configuration file config/puma.rb.
## This starts the application, listening on port 3000.
```

</details>

---

## Create `buildspec.yml` in the root path of Repo

<details>
  <summary>Click to view buildspec.yml</summary>

```yml
version: 0.2

env:
  variables:
    IMAGE_NAME: "chat-app"
    IMAGE_TAG: "latest"
  secrets-manager:
    RAILS_ENV: chat-app-secrets:RAILS_ENV
    DB_USER: chat-app-secrets:DB_USER
    DB_PASSWORD: chat-app-secrets:DB_PASSWORD
    DB_HOST: chat-app-secrets:DB_HOST
    DB_PORT: chat-app-secrets:DB_PORT
    DB_NAME: chat-app-secrets:DB_NAME
    REDIS_URL: chat-app-secrets:REDIS_URL
    RAILS_MASTER_KEY: chat-app-secrets:RAILS_MASTER_KEY
    SECRET_KEY_BASE: chat-app-secrets:SECRET_KEY_BASE

phases:
  pre_build:
    commands:
      - echo Logging in to Amazon ECR...
      - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $ECR_REPO_URI
      - echo "RAILS_ENV=$RAILS_ENV" > .env
      - echo "DB_USER=$DB_USER" >> .env
      - echo "DB_PASSWORD=$DB_PASSWORD" >> .env
      - echo "DB_HOST=$DB_HOST" >> .env
      - echo "DB_PORT=$DB_PORT" >> .env
      - echo "DB_NAME=$DB_NAME" >> .env
      - echo "REDIS_URL=$REDIS_URL" >> .env
      - echo "RAILS_MASTER_KEY=$RAILS_MASTER_KEY" >> .env
      - echo "SECRET_KEY_BASE=$SECRET_KEY_BASE" >> .env

  build:
    commands:
      - echo Building the Docker image...
      - docker build -t $IMAGE_NAME:$IMAGE_TAG .
      - docker tag $IMAGE_NAME:$IMAGE_TAG $ECR_REPO_URI:$IMAGE_TAG

  post_build:
    commands:
      - echo Pushing Docker image to ECR...
      - docker push $ECR_REPO_URI:$IMAGE_TAG
      - echo Build completed successfully.

artifacts:
  files: []
```

</details>

---

## **Step-by-Step guide** on how to store your `.env` secrets in **AWS Secrets Manager using the Console UI**

<details>
  <summary>Click to view Step-by-Step: Store Rails `.env` Secrets in AWS Secrets Manager (Console)</summary>

### 🪪 Step-by-Step: Store Rails `.env` Secrets in AWS Secrets Manager (Console)

### 🔹 **Step 1: Choose Secret Type**

1. Go to **AWS Secrets Manager > Store a new secret**
2. Under **Secret type**, select:
   - ✅ **Other type of secret**
   - (This is for API keys, app secrets, or in your case, environment variables)

---

### 🔹 **Step 2: Enter Key/Value Pairs**

Now, enter each key and its value from your `.env` file:

| Key                | Value                                                              |
|--------------------|--------------------------------------------------------------------|
| `RAILS_ENV`        | `production`                                                      |
| `DB_USER`          | `myuser`                                                          |
| `DB_PASSWORD`      | `mypassword`                                                      |
| `DB_HOST`          | `chat-app.c342ea4cs6ny.ap-south-1.rds.amazonaws.com`              |
| `DB_PORT`          | `5432`                                                            |
| `DB_NAME`          | `chat-app`                                                        |
| `REDIS_URL`        | `redis://redis:6379/0`                                            |
| `RAILS_MASTER_KEY` | `c3ca922688d4bf22ac7fe38430dd8849`                                |
| `SECRET_KEY_BASE`  | `600f21de02355f788c759ff862a2cb22ba84ccbf072487992f4...` *(etc.)* |

➡️ To do this:
- Click **+ Add row** for each new key.
- Paste in each key on the left and value on the right.

---

### 🔹 **Step 3: Encryption Key**

- Leave this as default: `aws/secretsmanager`

AWS will handle encryption with its default KMS key.

---

### 🔹 **Step 4: Click “Next”**

Once all keys are added:
- Click the **orange “Next”** button at the bottom-right.

---

### 🔹 **Step 5: Secret Name and Description**

1. Set the name to something like:
   ```
   chat-app-secrets
   ```
2. Optionally, add a helpful description, e.g.:
   ```
   Environment variables for Ruby on Rails chat app
   ```

---

### 🔹 **Step 6: Leave Rotation Off**

- Click **Next** on the rotation screen (optional).
- You don't need rotation for this kind of secret.

---

### 🔹 **Step 7: Review and Store**

1. Review your key-value pairs and secret name.
2. Click **Store**.
  
</details>

---



