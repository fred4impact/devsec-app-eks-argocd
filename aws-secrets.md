# AWS Secrets Manager Integration Guide

This guide provides step-by-step instructions for integrating AWS Secrets Manager with Terraform to securely manage secrets in your M-Tier application deployment.

---

## Prerequisites

Before you begin, ensure you have the following:

- **AWS CLI** configured with appropriate permissions
- **Terraform** (version >= 1.0)
- **kubectl** (for Kubernetes operations)
- **AWS IAM permissions** for Secrets Manager operations

---

## Stage 1: AWS Secrets Manager Setup

### 1.1 Create Secrets in AWS Secrets Manager

1. **Database Credentials Secret:**
   ```bash
   aws secretsmanager create-secret \
     --name "three-tier/database" \
     --description "Database credentials for three-tier application" \
     --secret-string '{
       "username": "admin",
       "password": "secure-password-123",
       "connection_string": "mongodb://admin:secure-password-123@localhost:27017/three-tier",
       "database_name": "three-tier"
     }'
   ```

2. **AWS Credentials Secret:**
   ```bash
   aws secretsmanager create-secret \
     --name "three-tier/aws-credentials" \
     --description "AWS credentials for application deployment" \
     --secret-string '{
       "access_key_id": "YOUR_ACCESS_KEY",
       "secret_access_key": "YOUR_SECRET_KEY",
       "region": "us-east-1"
     }'
   ```

3. **Jenkins Credentials Secret:**
   ```bash
   aws secretsmanager create-secret \
     --name "three-tier/jenkins" \
     --description "Jenkins credentials and tokens" \
     --secret-string '{
       "github_token": "YOUR_GITHUB_TOKEN",
       "sonar_token": "YOUR_SONAR_TOKEN",
       "admin_password": "jenkins-admin-password"
     }'
   ```

4. **ECR Repository Names Secret:**
   ```bash
   aws secretsmanager create-secret \
     --name "three-tier/ecr-repos" \
     --description "ECR repository names" \
     --secret-string '{
       "frontend_repo": "three-tier-frontend",
       "backend_repo": "three-tier-backend"
     }'
   ```

5. **MongoDB Connection Secret:**
   ```bash
   aws secretsmanager create-secret \
     --name "three-tier/mongodb" \
     --description "MongoDB connection details" \
     --secret-string '{
       "host": "localhost",
       "port": "27017",
       "database": "three-tier",
       "username": "admin",
       "password": "secure-password-123"
     }'
   ```

---

## Stage 2: Update Terraform Configuration

### 2.1 Add AWS Secrets Manager Data Sources

Create a new file `aws-secrets.tf` in your `eks-terraform` directory:

```hcl
# Read secrets from AWS Secrets Manager
data "aws_secretsmanager_secret" "database" {
  name = "three-tier/database"
}

data "aws_secretsmanager_secret_version" "database" {
  secret_id = data.aws_secretsmanager_secret.database.id
}

data "aws_secretsmanager_secret" "aws_credentials" {
  name = "three-tier/aws-credentials"
}

data "aws_secretsmanager_secret_version" "aws_credentials" {
  secret_id = data.aws_secretsmanager_secret.aws_credentials.id
}

data "aws_secretsmanager_secret" "jenkins" {
  name = "three-tier/jenkins"
}

data "aws_secretsmanager_secret_version" "jenkins" {
  secret_id = data.aws_secretsmanager_secret.jenkins.id
}

data "aws_secretsmanager_secret" "ecr_repos" {
  name = "three-tier/ecr-repos"
}

data "aws_secretsmanager_secret_version" "ecr_repos" {
  secret_id = data.aws_secretsmanager_secret.ecr_repos.id
}

data "aws_secretsmanager_secret" "mongodb" {
  name = "three-tier/mongodb"
}

data "aws_secretsmanager_secret_version" "mongodb" {
  secret_id = data.aws_secretsmanager_secret.mongodb.id
}

# Parse JSON secrets
locals {
  database_secret = jsondecode(data.aws_secretsmanager_secret_version.database.secret_string)
  aws_credentials_secret = jsondecode(data.aws_secretsmanager_secret_version.aws_credentials.secret_string)
  jenkins_secret = jsondecode(data.aws_secretsmanager_secret_version.jenkins.secret_string)
  ecr_repos_secret = jsondecode(data.aws_secretsmanager_secret_version.ecr_repos.secret_string)
  mongodb_secret = jsondecode(data.aws_secretsmanager_secret_version.mongodb.secret_string)
}
```

### 2.2 Update Management Instance IAM Role

Add the following policy to your management instance IAM role in `main.tf`:

```hcl
# IAM policy for Secrets Manager access
resource "aws_iam_role_policy" "management_secrets" {
  name = "${var.project_name}-management-secrets-policy"
  role = aws_iam_role.management.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecrets"
        ]
        Resource = [
          "arn:aws:secretsmanager:${var.region}:*:secret:three-tier/*"
        ]
      }
    ]
  })
}
```

### 2.3 Create Kubernetes Secrets

Add the following to your Terraform configuration to create Kubernetes secrets:

```hcl
# Create Kubernetes secrets using AWS Secrets Manager data
resource "kubernetes_secret" "database" {
  metadata {
    name      = "database-secrets"
    namespace = "three-tier"
  }

  data = {
    username = local.database_secret["username"]
    password = local.database_secret["password"]
    connection_string = local.database_secret["connection_string"]
  }
}

resource "kubernetes_secret" "mongodb" {
  metadata {
    name      = "mongodb-secrets"
    namespace = "three-tier"
  }

  data = {
    host     = local.mongodb_secret["host"]
    port     = local.mongodb_secret["port"]
    database = local.mongodb_secret["database"]
    username = local.mongodb_secret["username"]
    password = local.mongodb_secret["password"]
  }
}

resource "kubernetes_secret" "aws" {
  metadata {
    name      = "aws-secrets"
    namespace = "three-tier"
  }

  data = {
    access_key_id     = local.aws_credentials_secret["access_key_id"]
    secret_access_key = local.aws_credentials_secret["secret_access_key"]
    region           = local.aws_credentials_secret["region"]
  }
}
```

---

## Stage 3: Update Kubernetes Manifests

### 3.1 Update Database Deployment

Modify `k8s-manifests/Database/deployment.yaml` to use the secrets:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mongodb
  namespace: three-tier
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mongodb
  template:
    metadata:
      labels:
        app: mongodb
    spec:
      containers:
      - name: mongodb
        image: mongo:latest
        ports:
        - containerPort: 27017
        env:
        - name: MONGO_INITDB_ROOT_USERNAME
          valueFrom:
            secretKeyRef:
              name: mongodb-secrets
              key: username
        - name: MONGO_INITDB_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mongodb-secrets
              key: password
        - name: MONGO_INITDB_DATABASE
          valueFrom:
            secretKeyRef:
              name: mongodb-secrets
              key: database
        volumeMounts:
        - name: mongodb-data
          mountPath: /data/db
      volumes:
      - name: mongodb-data
        persistentVolumeClaim:
          claimName: mongodb-pvc
```

### 3.2 Update Backend Deployment

Modify `k8s-manifests/Backend/deployment.yaml` to use the secrets:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  namespace: three-tier
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      containers:
      - name: api
        image: ${ECR_REPO2}:${BUILD_NUMBER}
        ports:
        - containerPort: 3500
        env:
        - name: MONGO_CONN_STR
          valueFrom:
            secretKeyRef:
              name: database-secrets
              key: connection_string
        - name: MONGO_USERNAME
          valueFrom:
            secretKeyRef:
              name: database-secrets
              key: username
        - name: MONGO_PASSWORD
          valueFrom:
            secretKeyRef:
              name: database-secrets
              key: password
        - name: USE_DB_AUTH
          value: "true"
```

---

## Stage 4: Update Jenkins Pipeline

### 4.1 Modify Jenkinsfiles to Use AWS Secrets Manager

Update both `Jenkinsfile-Backend` and `Jenkinsfile-Frontend`:

```groovy
pipeline {
    agent any 
    tools {
        nodejs 'nodejs'
    }
    environment {
        SCANNER_HOME = tool 'sonar-scanner'
        AWS_DEFAULT_REGION = 'us-east-1'
    }
    stages {
        stage('Get Secrets from AWS Secrets Manager') {
            steps {
                script {
                    // Get AWS credentials from Secrets Manager
                    def awsCredentials = sh(
                        script: 'aws secretsmanager get-secret-value --secret-id "three-tier/aws-credentials" --query SecretString --output text',
                        returnStdout: true
                    ).trim()
                    
                    def awsData = readJSON text: awsCredentials
                    env.AWS_ACCOUNT_ID = awsData.access_key_id
                    env.AWS_SECRET_ACCESS_KEY = awsData.secret_access_key
                    
                    // Get ECR repository names
                    def ecrRepos = sh(
                        script: 'aws secretsmanager get-secret-value --secret-id "three-tier/ecr-repos" --query SecretString --output text',
                        returnStdout: true
                    ).trim()
                    
                    def ecrData = readJSON text: ecrRepos
                    env.AWS_ECR_REPO_NAME = ecrData.backend_repo // or frontend_repo depending on pipeline
                    
                    // Get Jenkins credentials
                    def jenkinsCreds = sh(
                        script: 'aws secretsmanager get-secret-value --secret-id "three-tier/jenkins" --query SecretString --output text',
                        returnStdout: true
                    ).trim()
                    
                    def jenkinsData = readJSON text: jenkinsCreds
                    env.GITHUB_TOKEN = jenkinsData.github_token
                    env.SONAR_TOKEN = jenkinsData.sonar_token
                }
            }
        }
        
        // ... rest of your existing stages ...
    }
}
```

---

## Stage 5: Update Management Instance Script

### 5.1 Modify `tools-install.sh` to Use AWS Secrets Manager

Add the following to your `tools-install.sh` script:

```bash
# Install AWS CLI v2 (if not already installed)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Configure kubectl for EKS cluster
aws eks update-kubeconfig --region ${region} --name ${cluster_name}

# Get secrets from AWS Secrets Manager for configuration
echo "Configuring applications with secrets from AWS Secrets Manager..."

# Get database secrets
DB_SECRET=$(aws secretsmanager get-secret-value --secret-id "three-tier/database" --query SecretString --output text)
DB_USERNAME=$(echo $DB_SECRET | jq -r '.username')
DB_PASSWORD=$(echo $DB_SECRET | jq -r '.password')

# Get Jenkins secrets
JENKINS_SECRET=$(aws secretsmanager get-secret-value --secret-id "three-tier/jenkins" --query SecretString --output text)
JENKINS_ADMIN_PASSWORD=$(echo $JENKINS_SECRET | jq -r '.admin_password')

# Configure Jenkins with admin password
echo "Configuring Jenkins admin password..."
curl -X POST http://localhost:8080/setupWizard/configureAdmin \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin&password1=${JENKINS_ADMIN_PASSWORD}&password2=${JENKINS_ADMIN_PASSWORD}&fullname=Admin&email=admin@example.com"

# Create a status page with secret information
cat > /var/www/html/index.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>DevOps Tools Status</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .tool { margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
        .status { font-weight: bold; }
        .running { color: green; }
        .stopped { color: red; }
        .secret-info { background-color: #f9f9f9; padding: 10px; margin: 10px 0; border-radius: 3px; }
    </style>
</head>
<body>
    <h1>DevOps Tools Status</h1>
    <div class="tool">
        <h2>Jenkins</h2>
        <p>URL: <a href="http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080" target="_blank">http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080</a></p>
        <p class="status running">Status: Running</p>
        <div class="secret-info">
            <strong>Admin Password:</strong> Configured via AWS Secrets Manager
        </div>
    </div>
    <div class="tool">
        <h2>SonarQube</h2>
        <p>URL: <a href="http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):9000" target="_blank">http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):9000</a></p>
        <p>Default credentials: admin/admin</p>
        <p class="status running">Status: Running</p>
    </div>
    <div class="tool">
        <h2>Nexus</h2>
        <p>URL: <a href="http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8081" target="_blank">http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8081</a></p>
        <p>Default credentials: admin/admin123</p>
        <p class="status running">Status: Running</p>
    </div>
    <div class="tool">
        <h2>EKS Cluster</h2>
        <p>Cluster Name: ${cluster_name}</p>
        <p>Region: ${region}</p>
        <p class="status running">Status: Connected</p>
        <div class="secret-info">
            <strong>Database:</strong> Configured via AWS Secrets Manager<br>
            <strong>AWS Credentials:</strong> Managed via AWS Secrets Manager
        </div>
    </div>
</body>
</html>
EOF
```

---

## Stage 6: Secret Rotation Setup

### 6.1 Enable Automatic Rotation

1. **Enable rotation for database password:**
   ```bash
   aws secretsmanager rotate-secret \
     --secret-id "three-tier/database" \
     --rotation-rules '{"AutomaticallyAfterDays": 30}'
   ```

2. **Enable rotation for AWS credentials:**
   ```bash
   aws secretsmanager rotate-secret \
     --secret-id "three-tier/aws-credentials" \
     --rotation-rules '{"AutomaticallyAfterDays": 90}'
   ```

### 6.2 Create Custom Rotation Lambda

Create a custom rotation function for application-specific secrets:

```python
# rotation_lambda.py
import json
import boto3
import os

def lambda_handler(event, context):
    """Custom rotation function for application secrets"""
    
    arn = event['SecretId']
    token = event['ClientRequestToken']
    step = event['Step']
    
    # Create a Secrets Manager client
    service_client = boto3.client('secretsmanager')
    
    # Make sure the version is staged correctly
    metadata = service_client.describe_secret(SecretId=arn)
    if "RotationEnabled" in metadata and not metadata['RotationEnabled']:
        raise ValueError("Secret %s is not enabled for rotation" % arn)
    
    if step == "createSecret":
        # Create a new secret version
        # This is where you would generate new credentials
        new_secret = generate_new_secret()
        service_client.put_secret_value(
            SecretId=arn,
            ClientRequestToken=token,
            SecretString=json.dumps(new_secret)
        )
    
    elif step == "setSecret":
        # Set the secret in the application
        # This is where you would update the application with new credentials
        update_application_secret(arn, token)
    
    elif step == "testSecret":
        # Test the new secret
        test_secret(arn, token)
    
    elif step == "finishSecret":
        # Finish the rotation by marking the secret as active
        service_client.update_secret_version_stage(
            SecretId=arn,
            VersionStage="AWSCURRENT",
            MoveToVersionId=token,
            RemoveFromVersionId=get_secret_version_stage(arn, "AWSPREVIOUS")
        )
    
    return {"statusCode": 200, "body": json.dumps("Rotation completed successfully")}

def generate_new_secret():
    """Generate new secret values"""
    import secrets
    return {
        "username": "admin",
        "password": secrets.token_urlsafe(32),
        "connection_string": f"mongodb://admin:{secrets.token_urlsafe(32)}@localhost:27017/three-tier"
    }

def update_application_secret(arn, token):
    """Update application with new secret"""
    # Implementation depends on your application
    pass

def test_secret(arn, token):
    """Test the new secret"""
    # Implementation depends on your application
    pass

def get_secret_version_stage(arn, stage):
    """Get the version ID for a specific stage"""
    client = boto3.client('secretsmanager')
    response = client.describe_secret(SecretId=arn)
    for version in response['VersionIdsToStages']:
        if stage in response['VersionIdsToStages'][version]:
            return version
    return None
```

---

## Stage 7: Monitoring and Auditing

### 7.1 Set up CloudWatch Alarms

```bash
# Create CloudWatch alarm for secret access
aws cloudwatch put-metric-alarm \
  --alarm-name "SecretsManagerAccess" \
  --alarm-description "Monitor access to application secrets" \
  --metric-name "SecretAccessCount" \
  --namespace "AWS/SecretsManager" \
  --statistic "Sum" \
  --period 300 \
  --threshold 100 \
  --comparison-operator "GreaterThanThreshold" \
  --evaluation-periods 2
```

### 7.2 Enable CloudTrail Logging

```bash
# Enable CloudTrail for Secrets Manager events
aws cloudtrail create-trail \
  --name "SecretsManagerTrail" \
  --s3-bucket-name "your-audit-bucket" \
  --event-selectors '[{"ReadWriteType": "All", "IncludeManagementEvents": true, "DataResources": [{"Type": "AWS::SecretsManager::Secret", "Values": ["arn:aws:secretsmanager:*:*:secret:three-tier/*"]}]}]'
```

---

## Stage 8: Deployment Commands

### 8.1 Deploy with AWS Secrets Manager

```bash
cd eks-terraform

# Initialize Terraform
terraform init

# Plan deployment
terraform plan -var="key_pair_name=your-key-pair"

# Apply deployment
terraform apply -var="key_pair_name=your-key-pair" --auto-approve
```

### 8.2 Verify Secrets in Kubernetes

```bash
# Check secrets in Kubernetes
kubectl get secrets -n three-tier

# Verify secret contents
kubectl describe secret database-secrets -n three-tier
kubectl describe secret mongodb-secrets -n three-tier
kubectl describe secret aws-secrets -n three-tier
```

### 8.3 Test Secret Access

```bash
# Test secret retrieval from AWS Secrets Manager
aws secretsmanager get-secret-value --secret-id "three-tier/database"

# Test secret retrieval from Kubernetes
kubectl get secret database-secrets -n three-tier -o jsonpath='{.data.username}' | base64 -d
```

---

## Stage 9: Security Best Practices

### 9.1 IAM Policies

Create least-privilege IAM policies:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": [
        "arn:aws:secretsmanager:us-east-1:123456789012:secret:three-tier/*"
      ],
      "Condition": {
        "StringEquals": {
          "aws:RequestTag/Environment": "production"
        }
      }
    }
  ]
}
```

### 9.2 Resource Tags

Tag your secrets for better organization:

```bash
aws secretsmanager tag-resource \
  --secret-id "three-tier/database" \
  --tags '[{"Key": "Environment", "Value": "production"}, {"Key": "Application", "Value": "three-tier"}]'
```

### 9.3 Encryption

Ensure your secrets are encrypted with customer-managed keys:

```bash
# Create a KMS key for secrets encryption
aws kms create-key \
  --description "Key for three-tier application secrets" \
  --tags TagKey=Application,TagValue=three-tier

# Update secrets to use the KMS key
aws secretsmanager update-secret \
  --secret-id "three-tier/database" \
  --kms-key-id "arn:aws:kms:us-east-1:123456789012:key/your-kms-key-id"
```

---

## Stage 10: Cleanup

### 10.1 Remove Secrets

```bash
# Delete secrets from AWS Secrets Manager
aws secretsmanager delete-secret --secret-id "three-tier/database" --force-delete-without-recovery
aws secretsmanager delete-secret --secret-id "three-tier/aws-credentials" --force-delete-without-recovery
aws secretsmanager delete-secret --secret-id "three-tier/jenkins" --force-delete-without-recovery
aws secretsmanager delete-secret --secret-id "three-tier/ecr-repos" --force-delete-without-recovery
aws secretsmanager delete-secret --secret-id "three-tier/mongodb" --force-delete-without-recovery
```

### 10.2 Destroy Terraform Infrastructure

```bash
cd eks-terraform
terraform destroy -var="key_pair_name=your-key-pair" --auto-approve
```

---

## Benefits of AWS Secrets Manager

1. **Fully Managed**: No infrastructure to maintain
2. **Automatic Rotation**: Built-in rotation capabilities
3. **Integration**: Native integration with AWS services
4. **Encryption**: Automatic encryption at rest and in transit
5. **Auditing**: CloudTrail integration for access logging
6. **Cost Effective**: Pay only for what you use
7. **Compliance**: Meets various compliance standards

This comprehensive guide provides a complete setup for using AWS Secrets Manager with your Terraform deployment, offering a fully managed and secure solution for secret management in your AWS environment. 