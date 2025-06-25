# Terraform Vault Integration Guide

This guide provides step-by-step instructions for integrating HashiCorp Vault with Terraform to securely manage secrets in your M-Tier application deployment.

---

## Prerequisites

Before you begin, ensure you have the following installed:

- **HashiCorp Vault** (latest version)
- **Terraform** (version >= 1.0)
- **AWS CLI** (configured with appropriate permissions)
- **kubectl** (for Kubernetes operations)
- **Docker** (for running Vault in development mode)

---

## Stage 1: Vault Server Setup

### Option A: Local Development Setup

1. **Start Vault in Development Mode:**
   ```bash
   # Start Vault server in development mode
   vault server -dev -dev-root-token-id="dev-token-12345"
   
   # In a new terminal, set the environment variables
   export VAULT_ADDR='http://127.0.0.1:8200'
   export VAULT_TOKEN='dev-token-12345'
   ```

2. **Verify Vault is Running:**
   ```bash
   vault status
   ```

### Option B: Production Vault Setup (AWS)

1. **Deploy Vault on AWS using Terraform:**
   ```bash
   # Create a new directory for Vault infrastructure
   mkdir vault-infrastructure
   cd vault-infrastructure
   ```

2. **Create `vault-main.tf`:**
   ```hcl
   terraform {
     required_providers {
       aws = {
         source  = "hashicorp/aws"
         version = ">= 5.0"
       }
     }
   }

   provider "aws" {
     region = "us-east-1"
   }

   # VPC for Vault
   module "vault_vpc" {
     source  = "terraform-aws-modules/vpc/aws"
     version = "5.5.3"

     name = "vault-vpc"
     cidr = "10.1.0.0/16"

     azs             = ["us-east-1a", "us-east-1b"]
     private_subnets = ["10.1.1.0/24", "10.1.2.0/24"]
     public_subnets  = ["10.1.101.0/24", "10.1.102.0/24"]

     enable_nat_gateway = true
     single_nat_gateway = true
   }

   # Vault EC2 instance
   resource "aws_instance" "vault" {
     ami                    = data.aws_ami.amazon_linux.id
     instance_type          = "t3.medium"
     key_name               = var.key_pair_name
     subnet_id              = module.vault_vpc.public_subnets[0]
     vpc_security_group_ids = [aws_security_group.vault.id]

     user_data = templatefile("${path.module}/vault-install.sh", {})

     tags = {
       Name = "vault-server"
     }
   }

   # Security group for Vault
   resource "aws_security_group" "vault" {
     name_prefix = "vault-"
     vpc_id      = module.vault_vpc.vpc_id

     ingress {
       description = "Vault API"
       from_port   = 8200
       to_port     = 8200
       protocol    = "tcp"
       cidr_blocks = ["0.0.0.0/0"]
     }

     ingress {
       description = "SSH"
       from_port   = 22
       to_port     = 22
       protocol    = "tcp"
       cidr_blocks = ["0.0.0.0/0"]
     }

     egress {
       from_port   = 0
       to_port     = 0
       protocol    = "-1"
       cidr_blocks = ["0.0.0.0/0"]
     }
   }

   data "aws_ami" "amazon_linux" {
     most_recent = true
     owners      = ["amazon"]

     filter {
       name   = "name"
       values = ["amzn2-ami-hvm-*-x86_64-gp2"]
     }
   }

   variable "key_pair_name" {
     description = "AWS key pair name"
     type        = string
   }

   output "vault_public_ip" {
     value = aws_instance.vault.public_ip
   }
   ```

3. **Create `vault-install.sh`:**
   ```bash
   #!/bin/bash
   yum update -y
   yum install -y unzip

   # Install Vault
   wget https://releases.hashicorp.com/vault/1.15.0/vault_1.15.0_linux_amd64.zip
   unzip vault_1.15.0_linux_amd64.zip
   mv vault /usr/local/bin/
   rm vault_1.15.0_linux_amd64.zip

   # Create Vault user
   useradd -r -s /bin/false vault

   # Create Vault directories
   mkdir -p /opt/vault/{config,data}
   chown -R vault:vault /opt/vault

   # Create Vault configuration
   cat > /opt/vault/config/vault.json << EOF
   {
     "storage": {
       "file": {
         "path": "/opt/vault/data"
       }
     },
     "listener": {
       "tcp": {
         "address": "0.0.0.0:8200",
         "tls_disable": 1
       }
     },
     "ui": true,
     "disable_mlock": true
   }
   EOF

   # Create systemd service
   cat > /etc/systemd/system/vault.service << EOF
   [Unit]
   Description=Vault
   After=network.target

   [Service]
   User=vault
   Group=vault
   ExecStart=/usr/local/bin/vault server -config=/opt/vault/config/vault.json
   Restart=on-failure
   LimitNOFILE=65536

   [Install]
   WantedBy=multi-user.target
   EOF

   systemctl daemon-reload
   systemctl enable vault
   systemctl start vault
   ```

4. **Deploy Vault Infrastructure:**
   ```bash
   terraform init
   terraform apply -var="key_pair_name=your-key-pair-name"
   ```

---

## Stage 2: Vault Initialization and Configuration

1. **Set Vault Environment Variables:**
   ```bash
   # For local development
   export VAULT_ADDR='http://127.0.0.1:8200'
   
   # For production (replace with your Vault server IP)
   export VAULT_ADDR='http://<vault-public-ip>:8200'
   ```

2. **Initialize Vault:**
   ```bash
   vault operator init
   ```
   **Important:** Save the 5 unseal keys and root token securely!

3. **Unseal Vault:**
   ```bash
   # You need to provide 3 of the 5 unseal keys
   vault operator unseal <unseal-key-1>
   vault operator unseal <unseal-key-2>
   vault operator unseal <unseal-key-3>
   ```

4. **Login to Vault:**
   ```bash
   vault login <root-token>
   ```

5. **Enable Secrets Engines:**
   ```bash
   # Enable AWS secrets engine
   vault secrets enable aws

   # Enable database secrets engine
   vault secrets enable database

   # Enable key-value secrets engine
   vault secrets enable -path=secret kv-v2
   ```

---

## Stage 3: Configure AWS Secrets Engine

1. **Configure AWS Credentials:**
   ```bash
   vault write aws/config/root \
     access_key=<your-aws-access-key> \
     secret_key=<your-aws-secret-key> \
     region=us-east-1
   ```

2. **Create AWS Role for EKS:**
   ```bash
   vault write aws/roles/eks-admin \
     credential_type=iam_user \
     policy_document=-<<EOF
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": [
           "eks:*",
           "ec2:*",
           "iam:*"
         ],
         "Resource": "*"
       }
     ]
   }
   EOF
   ```

---

## Stage 4: Store Application Secrets

1. **Store Database Credentials:**
   ```bash
   vault kv put secret/three-tier/database \
     username=admin \
     password=secure-password-123 \
     connection_string="mongodb://admin:secure-password-123@localhost:27017/three-tier"
   ```

2. **Store AWS Credentials:**
   ```bash
   vault kv put secret/three-tier/aws \
     access_key_id=<your-aws-access-key> \
     secret_access_key=<your-aws-secret-key> \
     region=us-east-1
   ```

3. **Store Jenkins Credentials:**
   ```bash
   vault kv put secret/three-tier/jenkins \
     github_token=<your-github-token> \
     sonar_token=<your-sonar-token> \
     admin_password=<jenkins-admin-password>
   ```

4. **Store ECR Repository Names:**
   ```bash
   vault kv put secret/three-tier/ecr \
     frontend_repo=three-tier-frontend \
     backend_repo=three-tier-backend
   ```

---

## Stage 5: Update Terraform Configuration

1. **Add Vault Provider to `versions.tf`:**
   ```hcl
   terraform {
     required_version = ">= 1.0"

     required_providers {
       aws = {
         source  = "hashicorp/aws"
         version = ">= 5.0"
       }
       vault = {
         source  = "hashicorp/vault"
         version = ">= 3.0"
       }
     }
   }
   ```

2. **Add Vault Provider to `main.tf`:**
   ```hcl
   provider "vault" {
     address = "http://<vault-server-ip>:8200"
     token   = var.vault_token
   }
   ```

3. **Add Vault Variables to `variables.tf`:**
   ```hcl
   variable "vault_token" {
     description = "Vault token for authentication"
     type        = string
     sensitive   = true
   }

   variable "vault_address" {
     description = "Vault server address"
     type        = string
     default     = "http://127.0.0.1:8200"
   }
   ```

4. **Create a new file `vault-secrets.tf`:**
   ```hcl
   # Read secrets from Vault
   data "vault_generic_secret" "database" {
     path = "secret/three-tier/database"
   }

   data "vault_generic_secret" "aws" {
     path = "secret/three-tier/aws"
   }

   data "vault_generic_secret" "jenkins" {
     path = "secret/three-tier/jenkins"
   }

   data "vault_generic_secret" "ecr" {
     path = "secret/three-tier/ecr"
   }

   # Use secrets in your resources
   resource "aws_iam_user" "jenkins" {
     name = "jenkins-user"
   }

   resource "aws_iam_access_key" "jenkins" {
     user = aws_iam_user.jenkins.name
   }

   # Store the generated access key back to Vault
   resource "vault_generic_secret" "jenkins_aws_credentials" {
     path = "secret/three-tier/jenkins-aws"

     data_json = jsonencode({
       access_key_id     = aws_iam_access_key.jenkins.id
       secret_access_key = aws_iam_access_key.jenkins.secret
     })
   }
   ```

---

## Stage 6: Update Kubernetes Secrets

1. **Create `vault-k8s-secrets.tf`:**
   ```hcl
   # Create Kubernetes secrets using Vault data
   resource "kubernetes_secret" "database" {
     metadata {
       name      = "database-secrets"
       namespace = "three-tier"
     }

     data = {
       username = data.vault_generic_secret.database.data["username"]
       password = data.vault_generic_secret.database.data["password"]
     }
   }

   resource "kubernetes_secret" "aws" {
     metadata {
       name      = "aws-secrets"
       namespace = "three-tier"
     }

     data = {
       access_key_id     = data.vault_generic_secret.aws.data["access_key_id"]
       secret_access_key = data.vault_generic_secret.aws.data["secret_access_key"]
       region           = data.vault_generic_secret.aws.data["region"]
     }
   }
   ```

---

## Stage 7: Update Jenkins Pipeline

1. **Modify Jenkinsfiles to use Vault:**
   ```groovy
   // In Jenkinsfile-Backend and Jenkinsfile-Frontend
   environment {
     VAULT_ADDR = 'http://<vault-server-ip>:8200'
     VAULT_TOKEN = credentials('vault-token')
   }

   stage('Get Secrets from Vault') {
     steps {
       script {
         // Install Vault CLI
         sh 'curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -'
         sh 'sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"'
         sh 'sudo apt-get update && sudo apt-get install vault'
         
         // Get secrets
         sh '''
           export AWS_ACCESS_KEY_ID=$(vault kv get -field=access_key_id secret/three-tier/aws)
           export AWS_SECRET_ACCESS_KEY=$(vault kv get -field=secret_access_key secret/three-tier/aws)
           export AWS_DEFAULT_REGION=$(vault kv get -field=region secret/three-tier/aws)
         '''
       }
     }
   }
   ```

---

## Stage 8: Deployment Commands

1. **Deploy with Vault Integration:**
   ```bash
   cd eks-terraform
   
   # Set Vault token as environment variable
   export TF_VAR_vault_token="your-vault-token"
   
   # Initialize Terraform
   terraform init
   
   # Plan deployment
   terraform plan -var="key_pair_name=your-key-pair" -var="vault_token=$TF_VAR_vault_token"
   
   # Apply deployment
   terraform apply -var="key_pair_name=your-key-pair" -var="vault_token=$TF_VAR_vault_token" --auto-approve
   ```

2. **Verify Secrets in Kubernetes:**
   ```bash
   kubectl get secrets -n three-tier
   kubectl describe secret database-secrets -n three-tier
   ```

---

## Stage 9: Security Best Practices

1. **Use Vault Policies:**
   ```bash
   # Create policy for Terraform
   vault policy write terraform-policy -<<EOF
   path "secret/three-tier/*" {
     capabilities = ["read"]
   }
   path "aws/creds/eks-admin" {
     capabilities = ["read"]
   }
   EOF
   ```

2. **Use AppRole Authentication:**
   ```bash
   # Enable AppRole auth method
   vault auth enable approle

   # Create AppRole for Terraform
   vault write auth/approle/role/terraform \
     secret_id_ttl=10m \
     token_num_uses=10 \
     token_ttl=20m \
     token_max_ttl=30m \
     policies=terraform-policy
   ```

3. **Rotate Secrets Regularly:**
   ```bash
   # Create script for secret rotation
   cat > rotate-secrets.sh << 'EOF'
   #!/bin/bash
   # Rotate database password
   new_password=$(openssl rand -base64 32)
   vault kv put secret/three-tier/database password=$new_password
   
   # Update Kubernetes secret
   kubectl patch secret database-secrets -n three-tier \
     -p="{\"data\":{\"password\":\"$(echo -n $new_password | base64)\"}}"
   EOF
   chmod +x rotate-secrets.sh
   ```

---

## Stage 10: Monitoring and Auditing

1. **Enable Vault Audit Logging:**
   ```bash
   vault audit enable file file_path=/var/log/vault/audit.log
   ```

2. **Monitor Vault Metrics:**
   ```bash
   # Enable telemetry
   vault write sys/config/telemetry {
     "telemetry": {
       "prometheus_retention_time": "24h",
       "disable_hostname": true
     }
   }
   ```

3. **Set up Vault Health Checks:**
   ```bash
   # Create health check script
   cat > vault-health-check.sh << 'EOF'
   #!/bin/bash
   if vault status | grep -q "Sealed.*false"; then
     echo "Vault is unsealed and running"
   else
     echo "Vault is sealed or not running"
     exit 1
   fi
   EOF
   chmod +x vault-health-check.sh
   ```

---

## Troubleshooting

### Common Issues:

1. **Vault Connection Issues:**
   ```bash
   # Check Vault status
   vault status
   
   # Check network connectivity
   curl -s $VAULT_ADDR/v1/sys/health
   ```

2. **Permission Denied:**
   ```bash
   # Check token permissions
   vault token lookup
   
   # Verify policy
   vault policy read terraform-policy
   ```

3. **Secrets Not Found:**
   ```bash
   # List secrets
   vault kv list secret/three-tier
   
   # Get specific secret
   vault kv get secret/three-tier/database
   ```

---

## Cleanup

1. **Destroy Terraform Resources:**
   ```bash
   terraform destroy -var="key_pair_name=your-key-pair" -var="vault_token=$TF_VAR_vault_token"
   ```

2. **Clean Up Vault:**
   ```bash
   # Delete secrets
   vault kv delete secret/three-tier/database
   vault kv delete secret/three-tier/aws
   vault kv delete secret/three-tier/jenkins
   vault kv delete secret/three-tier/ecr
   
   # Disable secrets engines
   vault secrets disable aws
   vault secrets disable database
   vault secrets disable secret
   ```

This comprehensive guide provides a complete setup for integrating HashiCorp Vault with your Terraform deployment, ensuring secure secret management throughout your M-Tier application infrastructure. 