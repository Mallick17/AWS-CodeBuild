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

## Step-by-Step: Create IAM Role for CodeBuild (with Required Policies)
### 1. **Go to IAM > Roles > Create Role**
- **Trusted Entity**: AWS service
- **Use case**: Choose **CodeBuild**
- Click **Next**

---

### 2. **Attach Policies**

<details>
  <summary>Click to view all the 10 Policies Attached to the Role</summary>


- **I. `AmazonEC2ContainerRegistryPowerUser`**
  - Provides full access to Amazon EC2 Container Registry repositories, but does not allow repository deletion or policy changes.
  - AWS managed

<details>
  <summary>Click to view given Permissions through JSON Format</summary>

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ecr:GetAuthorizationToken",
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:GetRepositoryPolicy",
                "ecr:DescribeRepositories",
                "ecr:ListImages",
                "ecr:DescribeImages",
                "ecr:BatchGetImage",
                "ecr:GetLifecyclePolicy",
                "ecr:GetLifecyclePolicyPreview",
                "ecr:ListTagsForResource",
                "ecr:DescribeImageScanFindings",
                "ecr:InitiateLayerUpload",
                "ecr:UploadLayerPart",
                "ecr:CompleteLayerUpload",
                "ecr:PutImage"
            ],
            "Resource": "*"
        }
    ]
}
```
  
</details>
  
- **II. `AmazonECS_FullAccess`**
  - Provides administrative access to Amazon ECS resources and enables ECS features through access to other AWS service resources, including VPCs, Auto Scaling groups, and CloudFormation stacks.
  - AWS managed
  
<details>
  <summary>Click to view given Permissions through JSON Format</summary>

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "ECSIntegrationsManagementPolicy",
            "Effect": "Allow",
            "Action": [
                "application-autoscaling:DeleteScalingPolicy",
                "application-autoscaling:DeregisterScalableTarget",
                "application-autoscaling:DescribeScalableTargets",
                "application-autoscaling:DescribeScalingActivities",
                "application-autoscaling:DescribeScalingPolicies",
                "application-autoscaling:PutScalingPolicy",
                "application-autoscaling:RegisterScalableTarget",
                "appmesh:DescribeVirtualGateway",
                "appmesh:DescribeVirtualNode",
                "appmesh:ListMeshes",
                "appmesh:ListVirtualGateways",
                "appmesh:ListVirtualNodes",
                "autoscaling:CreateAutoScalingGroup",
                "autoscaling:CreateLaunchConfiguration",
                "autoscaling:DeleteAutoScalingGroup",
                "autoscaling:DeleteLaunchConfiguration",
                "autoscaling:Describe*",
                "autoscaling:UpdateAutoScalingGroup",
                "cloudformation:CreateStack",
                "cloudformation:DeleteStack",
                "cloudformation:DescribeStack*",
                "cloudformation:UpdateStack",
                "cloudwatch:DeleteAlarms",
                "cloudwatch:DescribeAlarms",
                "cloudwatch:GetMetricStatistics",
                "cloudwatch:PutMetricAlarm",
                "codedeploy:BatchGetApplicationRevisions",
                "codedeploy:BatchGetApplications",
                "codedeploy:BatchGetDeploymentGroups",
                "codedeploy:BatchGetDeployments",
                "codedeploy:ContinueDeployment",
                "codedeploy:CreateApplication",
                "codedeploy:CreateDeployment",
                "codedeploy:CreateDeploymentGroup",
                "codedeploy:GetApplication",
                "codedeploy:GetApplicationRevision",
                "codedeploy:GetDeployment",
                "codedeploy:GetDeploymentConfig",
                "codedeploy:GetDeploymentGroup",
                "codedeploy:GetDeploymentTarget",
                "codedeploy:ListApplicationRevisions",
                "codedeploy:ListApplications",
                "codedeploy:ListDeploymentConfigs",
                "codedeploy:ListDeploymentGroups",
                "codedeploy:ListDeployments",
                "codedeploy:ListDeploymentTargets",
                "codedeploy:RegisterApplicationRevision",
                "codedeploy:StopDeployment",
                "ec2:AssociateRouteTable",
                "ec2:AttachInternetGateway",
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:CancelSpotFleetRequests",
                "ec2:CreateInternetGateway",
                "ec2:CreateLaunchTemplate",
                "ec2:CreateRoute",
                "ec2:CreateRouteTable",
                "ec2:CreateSecurityGroup",
                "ec2:CreateSubnet",
                "ec2:CreateVpc",
                "ec2:DeleteLaunchTemplate",
                "ec2:DeleteSubnet",
                "ec2:DeleteVpc",
                "ec2:Describe*",
                "ec2:DetachInternetGateway",
                "ec2:DisassociateRouteTable",
                "ec2:ModifySubnetAttribute",
                "ec2:ModifyVpcAttribute",
                "ec2:RequestSpotFleet",
                "ec2:RunInstances",
                "ecs:*",
                "elasticfilesystem:DescribeAccessPoints",
                "elasticfilesystem:DescribeFileSystems",
                "elasticloadbalancing:CreateListener",
                "elasticloadbalancing:CreateLoadBalancer",
                "elasticloadbalancing:CreateRule",
                "elasticloadbalancing:CreateTargetGroup",
                "elasticloadbalancing:DeleteListener",
                "elasticloadbalancing:DeleteLoadBalancer",
                "elasticloadbalancing:DeleteRule",
                "elasticloadbalancing:DeleteTargetGroup",
                "elasticloadbalancing:DescribeListeners",
                "elasticloadbalancing:DescribeLoadBalancers",
                "elasticloadbalancing:DescribeRules",
                "elasticloadbalancing:DescribeTargetGroups",
                "events:DeleteRule",
                "events:DescribeRule",
                "events:ListRuleNamesByTarget",
                "events:ListTargetsByRule",
                "events:PutRule",
                "events:PutTargets",
                "events:RemoveTargets",
                "fsx:DescribeFileSystems",
                "iam:ListAttachedRolePolicies",
                "iam:ListInstanceProfiles",
                "iam:ListRoles",
                "lambda:ListFunctions",
                "logs:CreateLogGroup",
                "logs:DescribeLogGroups",
                "logs:FilterLogEvents",
                "route53:CreateHostedZone",
                "route53:DeleteHostedZone",
                "route53:GetHealthCheck",
                "route53:GetHostedZone",
                "route53:ListHostedZonesByName",
                "servicediscovery:CreatePrivateDnsNamespace",
                "servicediscovery:CreateService",
                "servicediscovery:DeleteService",
                "servicediscovery:GetNamespace",
                "servicediscovery:GetOperation",
                "servicediscovery:GetService",
                "servicediscovery:ListNamespaces",
                "servicediscovery:ListServices",
                "servicediscovery:UpdateService",
                "sns:ListTopics"
            ],
            "Resource": [
                "*"
            ]
        },
        {
            "Sid": "SSMPolicy",
            "Effect": "Allow",
            "Action": [
                "ssm:GetParameter",
                "ssm:GetParameters",
                "ssm:GetParametersByPath"
            ],
            "Resource": "arn:aws:ssm:*:*:parameter/aws/service/ecs*"
        },
        {
            "Sid": "ManagedCloudformationResourcesCleanupPolicy",
            "Effect": "Allow",
            "Action": [
                "ec2:DeleteInternetGateway",
                "ec2:DeleteRoute",
                "ec2:DeleteRouteTable",
                "ec2:DeleteSecurityGroup"
            ],
            "Resource": [
                "*"
            ],
            "Condition": {
                "StringLike": {
                    "ec2:ResourceTag/aws:cloudformation:stack-name": "EC2ContainerService-*"
                }
            }
        },
        {
            "Sid": "TasksPassRolePolicy",
            "Action": "iam:PassRole",
            "Effect": "Allow",
            "Resource": [
                "*"
            ],
            "Condition": {
                "StringLike": {
                    "iam:PassedToService": "ecs-tasks.amazonaws.com"
                }
            }
        },
        {
            "Sid": "InfrastructurePassRolePolicy",
            "Action": "iam:PassRole",
            "Effect": "Allow",
            "Resource": [
                "arn:aws:iam::*:role/ecsInfrastructureRole"
            ],
            "Condition": {
                "StringEquals": {
                    "iam:PassedToService": "ecs.amazonaws.com"
                }
            }
        },
        {
            "Sid": "InstancePassRolePolicy",
            "Action": "iam:PassRole",
            "Effect": "Allow",
            "Resource": [
                "arn:aws:iam::*:role/ecsInstanceRole*"
            ],
            "Condition": {
                "StringLike": {
                    "iam:PassedToService": [
                        "ec2.amazonaws.com",
                        "ec2.amazonaws.com.cn"
                    ]
                }
            }
        },
        {
            "Sid": "AutoScalingPassRolePolicy",
            "Action": "iam:PassRole",
            "Effect": "Allow",
            "Resource": [
                "arn:aws:iam::*:role/ecsAutoscaleRole*"
            ],
            "Condition": {
                "StringLike": {
                    "iam:PassedToService": [
                        "application-autoscaling.amazonaws.com",
                        "application-autoscaling.amazonaws.com.cn"
                    ]
                }
            }
        },
        {
            "Sid": "ServiceLinkedRoleCreationPolicy",
            "Effect": "Allow",
            "Action": "iam:CreateServiceLinkedRole",
            "Resource": "*",
            "Condition": {
                "StringLike": {
                    "iam:AWSServiceName": [
                        "ecs.amazonaws.com",
                        "autoscaling.amazonaws.com",
                        "ecs.application-autoscaling.amazonaws.com",
                        "spot.amazonaws.com",
                        "spotfleet.amazonaws.com"
                    ]
                }
            }
        },
        {
            "Sid": "ELBTaggingPolicy",
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:AddTags"
            ],
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "elasticloadbalancing:CreateAction": [
                        "CreateTargetGroup",
                        "CreateRule",
                        "CreateListener",
                        "CreateLoadBalancer"
                    ]
                }
            }
        }
    ]
}
```

</details>

- **III. `AmazonRDSReadOnlyAccess`**
  - Provides read only access to Amazon RDS via the AWS Management Console.
  - AWS managed

<details>
  <summary>Click to view given Permissions through JSON Format</summary>

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "rds:Describe*",
                "rds:ListTagsForResource",
                "ec2:DescribeAccountAttributes",
                "ec2:DescribeAvailabilityZones",
                "ec2:DescribeInternetGateways",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeSubnets",
                "ec2:DescribeVpcAttribute",
                "ec2:DescribeVpcs"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "cloudwatch:GetMetricStatistics",
                "cloudwatch:ListMetrics",
                "cloudwatch:GetMetricData",
                "logs:DescribeLogStreams",
                "logs:GetLogEvents",
                "devops-guru:GetResourceCollection"
            ],
            "Resource": "*"
        },
        {
            "Action": [
                "devops-guru:SearchInsights",
                "devops-guru:ListAnomaliesForInsight"
            ],
            "Effect": "Allow",
            "Resource": "*",
            "Condition": {
                "ForAllValues:StringEquals": {
                    "devops-guru:ServiceNames": [
                        "RDS"
                    ]
                },
                "Null": {
                    "devops-guru:ServiceNames": "false"
                }
            }
        }
    ]
}
```

</details>

- **IV. `AmazonVPCFullAccess`**
  - Provides full access to Amazon VPC via the AWS Management Console.
  - AWS managed

<details>
  <summary>Click to view given Permissions through JSON Format</summary>

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AmazonVPCFullAccess",
            "Effect": "Allow",
            "Action": [
                "ec2:AcceptVpcPeeringConnection",
                "ec2:AcceptVpcEndpointConnections",
                "ec2:AllocateAddress",
                "ec2:AssignIpv6Addresses",
                "ec2:AssignPrivateIpAddresses",
                "ec2:AssociateAddress",
                "ec2:AssociateDhcpOptions",
                "ec2:AssociateRouteTable",
                "ec2:AssociateSecurityGroupVpc",
                "ec2:AssociateSubnetCidrBlock",
                "ec2:AssociateVpcCidrBlock",
                "ec2:AttachClassicLinkVpc",
                "ec2:AttachInternetGateway",
                "ec2:AttachNetworkInterface",
                "ec2:AttachVpnGateway",
                "ec2:AuthorizeSecurityGroupEgress",
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:CreateCarrierGateway",
                "ec2:CreateCustomerGateway",
                "ec2:CreateDefaultSubnet",
                "ec2:CreateDefaultVpc",
                "ec2:CreateDhcpOptions",
                "ec2:CreateEgressOnlyInternetGateway",
                "ec2:CreateFlowLogs",
                "ec2:CreateInternetGateway",
                "ec2:CreateLocalGatewayRouteTableVpcAssociation",
                "ec2:CreateNatGateway",
                "ec2:CreateNetworkAcl",
                "ec2:CreateNetworkAclEntry",
                "ec2:CreateNetworkInterface",
                "ec2:CreateNetworkInterfacePermission",
                "ec2:CreateRoute",
                "ec2:CreateRouteTable",
                "ec2:CreateSecurityGroup",
                "ec2:CreateSubnet",
                "ec2:CreateTags",
                "ec2:CreateVpc",
                "ec2:CreateVpcEndpoint",
                "ec2:CreateVpcEndpointConnectionNotification",
                "ec2:CreateVpcEndpointServiceConfiguration",
                "ec2:CreateVpcPeeringConnection",
                "ec2:CreateVpnConnection",
                "ec2:CreateVpnConnectionRoute",
                "ec2:CreateVpnGateway",
                "ec2:DeleteCarrierGateway",
                "ec2:DeleteCustomerGateway",
                "ec2:DeleteDhcpOptions",
                "ec2:DeleteEgressOnlyInternetGateway",
                "ec2:DeleteFlowLogs",
                "ec2:DeleteInternetGateway",
                "ec2:DeleteLocalGatewayRouteTableVpcAssociation",
                "ec2:DeleteNatGateway",
                "ec2:DeleteNetworkAcl",
                "ec2:DeleteNetworkAclEntry",
                "ec2:DeleteNetworkInterface",
                "ec2:DeleteNetworkInterfacePermission",
                "ec2:DeleteRoute",
                "ec2:DeleteRouteTable",
                "ec2:DeleteSecurityGroup",
                "ec2:DeleteSubnet",
                "ec2:DeleteTags",
                "ec2:DeleteVpc",
                "ec2:DeleteVpcEndpoints",
                "ec2:DeleteVpcEndpointConnectionNotifications",
                "ec2:DeleteVpcEndpointServiceConfigurations",
                "ec2:DeleteVpcPeeringConnection",
                "ec2:DeleteVpnConnection",
                "ec2:DeleteVpnConnectionRoute",
                "ec2:DeleteVpnGateway",
                "ec2:DescribeAccountAttributes",
                "ec2:DescribeAddresses",
                "ec2:DescribeAvailabilityZones",
                "ec2:DescribeCarrierGateways",
                "ec2:DescribeClassicLinkInstances",
                "ec2:DescribeCustomerGateways",
                "ec2:DescribeDhcpOptions",
                "ec2:DescribeEgressOnlyInternetGateways",
                "ec2:DescribeFlowLogs",
                "ec2:DescribeInstances",
                "ec2:DescribeInternetGateways",
                "ec2:DescribeIpv6Pools",
                "ec2:DescribeLocalGatewayRouteTables",
                "ec2:DescribeLocalGatewayRouteTableVpcAssociations",
                "ec2:DescribeKeyPairs",
                "ec2:DescribeMovingAddresses",
                "ec2:DescribeNatGateways",
                "ec2:DescribeNetworkAcls",
                "ec2:DescribeNetworkInterfaceAttribute",
                "ec2:DescribeNetworkInterfacePermissions",
                "ec2:DescribeNetworkInterfaces",
                "ec2:DescribePrefixLists",
                "ec2:DescribeRouteTables",
                "ec2:DescribeSecurityGroupReferences",
                "ec2:DescribeSecurityGroupRules",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeSecurityGroupVpcAssociations",
                "ec2:DescribeStaleSecurityGroups",
                "ec2:DescribeSubnets",
                "ec2:DescribeTags",
                "ec2:DescribeVpcAttribute",
                "ec2:DescribeVpcClassicLink",
                "ec2:DescribeVpcClassicLinkDnsSupport",
                "ec2:DescribeVpcEndpointConnectionNotifications",
                "ec2:DescribeVpcEndpointConnections",
                "ec2:DescribeVpcEndpoints",
                "ec2:DescribeVpcEndpointServiceConfigurations",
                "ec2:DescribeVpcEndpointServicePermissions",
                "ec2:DescribeVpcEndpointServices",
                "ec2:DescribeVpcPeeringConnections",
                "ec2:DescribeVpcs",
                "ec2:DescribeVpnConnections",
                "ec2:DescribeVpnGateways",
                "ec2:DetachClassicLinkVpc",
                "ec2:DetachInternetGateway",
                "ec2:DetachNetworkInterface",
                "ec2:DetachVpnGateway",
                "ec2:DisableVgwRoutePropagation",
                "ec2:DisableVpcClassicLink",
                "ec2:DisableVpcClassicLinkDnsSupport",
                "ec2:DisassociateAddress",
                "ec2:DisassociateRouteTable",
                "ec2:DisassociateSecurityGroupVpc",
                "ec2:DisassociateSubnetCidrBlock",
                "ec2:DisassociateVpcCidrBlock",
                "ec2:EnableVgwRoutePropagation",
                "ec2:EnableVpcClassicLink",
                "ec2:EnableVpcClassicLinkDnsSupport",
                "ec2:GetSecurityGroupsForVpc",
                "ec2:ModifyNetworkInterfaceAttribute",
                "ec2:ModifySecurityGroupRules",
                "ec2:ModifySubnetAttribute",
                "ec2:ModifyVpcAttribute",
                "ec2:ModifyVpcEndpoint",
                "ec2:ModifyVpcEndpointConnectionNotification",
                "ec2:ModifyVpcEndpointServiceConfiguration",
                "ec2:ModifyVpcEndpointServicePermissions",
                "ec2:ModifyVpcPeeringConnectionOptions",
                "ec2:ModifyVpcTenancy",
                "ec2:MoveAddressToVpc",
                "ec2:RejectVpcEndpointConnections",
                "ec2:RejectVpcPeeringConnection",
                "ec2:ReleaseAddress",
                "ec2:ReplaceNetworkAclAssociation",
                "ec2:ReplaceNetworkAclEntry",
                "ec2:ReplaceRoute",
                "ec2:ReplaceRouteTableAssociation",
                "ec2:ResetNetworkInterfaceAttribute",
                "ec2:RestoreAddressToClassic",
                "ec2:RevokeSecurityGroupEgress",
                "ec2:RevokeSecurityGroupIngress",
                "ec2:UnassignIpv6Addresses",
                "ec2:UnassignPrivateIpAddresses",
                "ec2:UpdateSecurityGroupRuleDescriptionsEgress",
                "ec2:UpdateSecurityGroupRuleDescriptionsIngress"
            ],
            "Resource": "*"
        }
    ]
}
```

</details>

- **V. `AWSCodeBuildAdminAccess`**
  - Provides full access to AWS CodeBuild via the AWS Management Console. Also attach AmazonS3ReadOnlyAccess to provide access to download build artifacts, and attach IAMFullAccess to create and manage the service role for CodeBuild.
  - AWS managed

<details>
  <summary>Click to view given Permissions through JSON Format</summary>

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AWSServicesAccess",
            "Action": [
                "codebuild:*",
                "codecommit:GetBranch",
                "codecommit:GetCommit",
                "codecommit:GetRepository",
                "codecommit:ListBranches",
                "codecommit:ListRepositories",
                "cloudwatch:GetMetricStatistics",
                "ec2:DescribeVpcs",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeSubnets",
                "ecr:DescribeRepositories",
                "ecr:ListImages",
                "elasticfilesystem:DescribeFileSystems",
                "events:DeleteRule",
                "events:DescribeRule",
                "events:DisableRule",
                "events:EnableRule",
                "events:ListTargetsByRule",
                "events:ListRuleNamesByTarget",
                "events:PutRule",
                "events:PutTargets",
                "events:RemoveTargets",
                "logs:GetLogEvents",
                "s3:GetBucketLocation",
                "s3:ListAllMyBuckets"
            ],
            "Effect": "Allow",
            "Resource": "*"
        },
        {
            "Sid": "CWLDeleteLogGroupAccess",
            "Action": [
                "logs:DeleteLogGroup"
            ],
            "Effect": "Allow",
            "Resource": "arn:aws:logs:*:*:log-group:/aws/codebuild/*:log-stream:*"
        },
        {
            "Sid": "SSMParameterWriteAccess",
            "Effect": "Allow",
            "Action": [
                "ssm:PutParameter"
            ],
            "Resource": "arn:aws:ssm:*:*:parameter/CodeBuild/*"
        },
        {
            "Sid": "SSMStartSessionAccess",
            "Effect": "Allow",
            "Action": [
                "ssm:StartSession"
            ],
            "Resource": "arn:aws:ecs:*:*:task/*/*"
        },
        {
            "Sid": "CodeStarConnectionsReadWriteAccess",
            "Effect": "Allow",
            "Action": [
                "codestar-connections:CreateConnection",
                "codestar-connections:DeleteConnection",
                "codestar-connections:UpdateConnectionInstallation",
                "codestar-connections:TagResource",
                "codestar-connections:UntagResource",
                "codestar-connections:ListConnections",
                "codestar-connections:ListInstallationTargets",
                "codestar-connections:ListTagsForResource",
                "codestar-connections:GetConnection",
                "codestar-connections:GetIndividualAccessToken",
                "codestar-connections:GetInstallationUrl",
                "codestar-connections:PassConnection",
                "codestar-connections:StartOAuthHandshake",
                "codestar-connections:UseConnection"
            ],
            "Resource": [
                "arn:aws:codestar-connections:*:*:connection/*",
                "arn:aws:codeconnections:*:*:connection/*"
            ]
        },
        {
            "Sid": "CodeStarNotificationsReadWriteAccess",
            "Effect": "Allow",
            "Action": [
                "codestar-notifications:CreateNotificationRule",
                "codestar-notifications:DescribeNotificationRule",
                "codestar-notifications:UpdateNotificationRule",
                "codestar-notifications:DeleteNotificationRule",
                "codestar-notifications:Subscribe",
                "codestar-notifications:Unsubscribe"
            ],
            "Resource": "*",
            "Condition": {
                "ArnLike": {
                    "codestar-notifications:NotificationsForResource": "arn:aws:codebuild:*:*:project/*"
                }
            }
        },
        {
            "Sid": "CodeStarNotificationsListAccess",
            "Effect": "Allow",
            "Action": [
                "codestar-notifications:ListNotificationRules",
                "codestar-notifications:ListEventTypes",
                "codestar-notifications:ListTargets",
                "codestar-notifications:ListTagsforResource"
            ],
            "Resource": "*"
        },
        {
            "Sid": "CodeStarNotificationsSNSTopicCreateAccess",
            "Effect": "Allow",
            "Action": [
                "sns:CreateTopic",
                "sns:SetTopicAttributes"
            ],
            "Resource": "arn:aws:sns:*:*:codestar-notifications*"
        },
        {
            "Sid": "SNSTopicListAccess",
            "Effect": "Allow",
            "Action": [
                "sns:ListTopics",
                "sns:GetTopicAttributes"
            ],
            "Resource": "*"
        },
        {
            "Sid": "CodeStarNotificationsChatbotAccess",
            "Effect": "Allow",
            "Action": [
                "chatbot:DescribeSlackChannelConfigurations",
                "chatbot:ListMicrosoftTeamsChannelConfigurations"
            ],
            "Resource": "*"
        }
    ]
}
```

</details>

- **VI. `CloudWatchLogsFullAccess`**
  - Provides full access to AWS CodeBuild via the AWS Management Console. Also attach AmazonS3ReadOnlyAccess to provide access to download build artifacts, and attach IAMFullAccess to create and manage the service role for CodeBuild.
  - AWS managed

<details>
  <summary>Click to view given Permissions through JSON Format</summary>

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "CloudWatchLogsFullAccess",
            "Effect": "Allow",
            "Action": [
                "logs:*",
                "cloudwatch:GenerateQuery"
            ],
            "Resource": "*"
        }
    ]
}
```

</details>

- **VII. `CodeBuildBasePolicy-codebuild-ror-app-role-ap-south-1`**
  - Customer managed
  
<details>
  <summary>Click to view given Permissions through JSON Format</summary>

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Resource": [
                "arn:aws:logs:ap-south-1:339713104321:log-group:/aws/codebuild/ror-chat-app-build",
                "arn:aws:logs:ap-south-1:339713104321:log-group:/aws/codebuild/ror-chat-app-build:*"
            ],
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ]
        },
        {
            "Effect": "Allow",
            "Resource": [
                "arn:aws:s3:::codepipeline-ap-south-1-*"
            ],
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:GetObjectVersion",
                "s3:GetBucketAcl",
                "s3:GetBucketLocation"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "codebuild:CreateReportGroup",
                "codebuild:CreateReport",
                "codebuild:UpdateReport",
                "codebuild:BatchPutTestCases",
                "codebuild:BatchPutCodeCoverages"
            ],
            "Resource": [
                "arn:aws:codebuild:ap-south-1:339713104321:report-group/ror-chat-app-build-*"
            ]
        }
    ]
}
```

</details>

- **VIII. `CodeBuildCodeConnectionsSourceCredentialsPolicy-ror-chat-app-build-ap-south-1-339713104321`**
  - Policy used in trust relationship with CodeBuild
  - Customer managed

<details>
  <summary>Click to view given Permissions through JSON Format</summary>

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "codestar-connections:GetConnectionToken",
                "codestar-connections:GetConnection",
                "codeconnections:GetConnectionToken",
                "codeconnections:GetConnection",
                "codeconnections:UseConnection"
            ],
            "Resource": [
                "arn:aws:codestar-connections:ap-south-1:339713104321:connection/e78bca79-a1be-4f00-9f47-58e0d3058c09",
                "arn:aws:codeconnections:ap-south-1:339713104321:connection/e78bca79-a1be-4f00-9f47-58e0d3058c09"
            ]
        }
    ]
}
```

</details>

- **IX. `CodeBuildSecretsManagerPolicy-chat-app-ap-south-1`**
  - Policy used in trust relationship with CodeBuild
  - Customer managed

<details>
  <summary>Click to view given Permissions through JSON Format</summary>

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "secretsmanager:GetSecretValue"
            ],
            "Resource": [
                "arn:aws:secretsmanager:ap-south-1:339713104321:secret:/CodeBuild/*"
            ]
        }
    ]
}
```

</details>

- **X. `SecretsManagerReadWrite`**
  - Provides read/write access to AWS Secrets Manager via the AWS Management Console. Note: this exludes IAM actions, so combine with IAMFullAccess if rotation configuration is required.
  - AWS managed

<details>
  <summary>Click to view given Permissions through JSON Format</summary>

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "BasePermissions",
            "Effect": "Allow",
            "Action": [
                "secretsmanager:*",
                "cloudformation:CreateChangeSet",
                "cloudformation:DescribeChangeSet",
                "cloudformation:DescribeStackResource",
                "cloudformation:DescribeStacks",
                "cloudformation:ExecuteChangeSet",
                "docdb-elastic:GetCluster",
                "docdb-elastic:ListClusters",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeSubnets",
                "ec2:DescribeVpcs",
                "kms:DescribeKey",
                "kms:ListAliases",
                "kms:ListKeys",
                "lambda:ListFunctions",
                "rds:DescribeDBClusters",
                "rds:DescribeDBInstances",
                "redshift:DescribeClusters",
                "redshift-serverless:ListWorkgroups",
                "redshift-serverless:GetNamespace",
                "tag:GetResources"
            ],
            "Resource": "*"
        },
        {
            "Sid": "LambdaPermissions",
            "Effect": "Allow",
            "Action": [
                "lambda:AddPermission",
                "lambda:CreateFunction",
                "lambda:GetFunction",
                "lambda:InvokeFunction",
                "lambda:UpdateFunctionConfiguration"
            ],
            "Resource": "arn:aws:lambda:*:*:function:SecretsManager*"
        },
        {
            "Sid": "SARPermissions",
            "Effect": "Allow",
            "Action": [
                "serverlessrepo:CreateCloudFormationChangeSet",
                "serverlessrepo:GetApplication"
            ],
            "Resource": "arn:aws:serverlessrepo:*:*:applications/SecretsManager*"
        },
        {
            "Sid": "S3Permissions",
            "Effect": "Allow",
            "Action": [
                "s3:GetObject"
            ],
            "Resource": [
                "arn:aws:s3:::awsserverlessrepo-changesets*",
                "arn:aws:s3:::secrets-manager-rotation-apps-*/*"
            ]
        }
    ]
}
```

</details>

</details>

### 3. **Give Role a Name**

Example:
```
codebuild-ror-app-role
```

### 4. **Finish and Create Role**
---
