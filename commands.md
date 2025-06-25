# Updated Deployment Commands for M-Tier Application

This document contains the updated deployment commands that reflect the new Terraform configuration with the management instance hosting DevOps tools.

---

## Prerequisites

Before you begin, ensure you have the following tools installed and configured:

-   **AWS CLI:** Configured with the necessary permissions to create EKS, VPC, IAM, and EC2 resources.
-   **Terraform:** Installed and available in your PATH.
-   **kubectl:** Installed and configured to interact with a Kubernetes cluster.
-   **SSH Key Pair:** An AWS key pair for accessing the management instance.

---

## Stage 1: Create AWS Key Pair (if needed)

If you don't have an AWS key pair, create one:

```bash
# Create a new key pair
aws ec2 create-key-pair --key-name my-key-pair --query 'KeyMaterial' --output text > my-key-pair.pem

# Set proper permissions
chmod 400 my-key-pair.pem
```

---

## Stage 2: Infrastructure Provisioning with Terraform

This stage creates the foundational AWS resources, including the VPC, EKS cluster, and management instance.

1.  **Navigate to the Terraform directory:**
    ```bash
    cd eks-terraform
    ```

2.  **Initialize Terraform:**
    This command downloads the necessary provider plugins and modules.
    ```bash
    terraform init
    ```

3.  **(Optional) Review the execution plan:**
    This command shows you what resources Terraform will create, modify, or destroy.
    ```bash
    terraform plan -var="key_pair_name=my-key-pair"
    ```

4.  **Apply the Terraform configuration:**
    This command provisions the resources on AWS. Replace `my-key-pair` with your actual key pair name.
    ```bash
    terraform apply -var="key_pair_name=my-key-pair" --auto-approve
    ```

5.  **Note the outputs:**
    After successful deployment, Terraform will output the URLs for your DevOps tools:
    ```bash
    terraform output
    ```

---

## Stage 3: Access DevOps Tools

After the infrastructure is provisioned, you can access the DevOps tools using the URLs provided in the Terraform outputs.

### Jenkins Setup
1.  **Access Jenkins:**
    ```bash
    # Get the Jenkins URL
    terraform output jenkins_url
    ```
    Open the URL in your browser: `http://<management-instance-ip>:8080`

2.  **Get the initial admin password:**
    ```bash
    # SSH into the management instance
    ssh -i my-key-pair.pem ec2-user@$(terraform output -raw management_instance_public_ip)
    
    # Get Jenkins initial admin password
    cat /var/lib/jenkins/secrets/initialAdminPassword
    ```

3.  **Complete Jenkins setup:**
    - Install suggested plugins
    - Create admin user
    - Configure Jenkins URL

### SonarQube Setup
1.  **Access SonarQube:**
    ```bash
    # Get the SonarQube URL
    terraform output sonarqube_url
    ```
    Open the URL in your browser: `http://<management-instance-ip>:9000`

2.  **Login with default credentials:**
    - Username: `admin`
    - Password: `admin`

3.  **Change the default password when prompted**

### Nexus Setup
1.  **Access Nexus:**
    ```bash
    # Get the Nexus URL
    terraform output nexus_url
    ```
    Open the URL in your browser: `http://<management-instance-ip>:8081`

2.  **Login with default credentials:**
docker exec nexus bash cat /nexus-data/admin.password


3.  **If the password was changed or you need to retrieve it from the pod:**
    ```bash
    # Get the Nexus admin password from the running pod (if using Kubernetes)
    kubectl get secret --namespace nexus nexus-admin-password -o jsonpath="{.data.password}" | base64 -d && echo
    ```

4.  **Change the default password when prompted**

---

### ArgoCD Setup
1.  **Create the ArgoCD Namespace:**
    ```bash
    kubectl create namespace argocd
    ```

2.  **Install ArgoCD:**
    ```bash
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    ```

3.  **Get the ArgoCD Server URL:**
    ```bash
    kubectl get svc argocd-server -n argocd
    # For LoadBalancer, get the EXTERNAL-IP. For NodePort, use the node IP and port.
```bash
    kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
    ```

4.  **Get the ArgoCD Admin Password:**
    ```bash
    kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d && echo
    ```

5.  **Access the ArgoCD UI:**
    Open the ArgoCD URL in your browser and login with:
    - Username: `admin`
    - Password: (from the command above)

---

### Status Page
Access the DevOps tools status page:
```bash
# Get the status page URL
terraform output status_page_url
```
Open the URL in your browser: `http://<management-instance-ip>`

---

## Stage 4: Configure kubectl for EKS

The management instance is already configured to connect to the EKS cluster. To configure kubectl on your local machine:

```bash
aws configure 
# Get cluster information from Terraform outputs
aws eks update-kubeconfig --region us-east-1 --name dev-bilarn-cluster
##Added new context arn:aws:eks:us-east-1:529088298985:cluster/dev-bilarn-cluster to /home/ubuntu/.kube/config
```

---

## Stage 5: CI/CD Pipeline Execution

This project uses Jenkins to build, test, and deploy the frontend and backend services.

1.  **Set up Jenkins Credentials:**
    In Jenkins, configure the following credentials with the specified IDs:
    -   `ACCOUNT_ID`: Your AWS Account ID.
    -   `ECR_REPO1`: The name of the ECR repository for the **frontend**.
    -   `ECR_REPO2`: The name of the ECR repository for the **backend**.
    -   `GITHUB`: Your GitHub personal access token with repo permissions.
    -   `sonar-token`: A user token from your SonarQube server.




2.  **Create Jenkins Pipelines:**
    In Jenkins, create two new "Pipeline" jobs, one for the frontend and one for the backend.
    -   **For each pipeline:** Point the "Pipeline script from SCM" setting to your GitHub repository and specify the correct `Jenkinsfile` path (`pipeline-Jenkinsfile-Code/Jenkinsfile-Frontend` or `pipeline-Jenkinsfile-Code/Jenkinsfile-Backend`).

3.  **Trigger the Pipelines:**
    Run the "Build Now" command for both the frontend and backend pipelines in Jenkins.

---

## Stage 6: Initial Kubernetes Deployment

While the Jenkins pipelines handle the continuous deployment of the frontend and backend applications, the other Kubernetes components must be deployed manually the first time.

1.  **Create the Namespace:**
    ```bash
    kubectl create namespace three-tier
    ```

2.  **Deploy the Database:**
    ```bash
    kubectl apply -f k8s-manifests/Database/ -n three-tier
    ```

3.  **Deploy the Backend and Frontend Services:**
    ```bash
    # Deploy Backend
    kubectl apply -f k8s-manifests/Backend/ -n three-tier

    # Deploy Frontend
    kubectl apply -f k8s-manifests/Frontend/ -n three-tier
    ```

4.  **Deploy the Ingress Resource:**
    First, install the AWS Load Balancer Controller in your cluster, then:
    ```bash
    kubectl apply -f k8s-manifests/ingress.yaml -n three-tier
    ```

---

## Post-Deployment

After completing these stages, your application should be fully deployed. The Jenkins pipelines will automatically handle any new changes pushed to the `main` branch.

### Access Your Application
```bash
kubectl get ingress mainlb -n three-tier -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

### Useful Commands for Management Instance
```bash
# SSH into management instance
ssh -i my-key-pair.pem ec2-user@$(terraform output -raw management_instance_public_ip)

# Check EKS cluster status
kubectl get nodes

# Check running pods
kubectl get pods -n three-tier

# Check services
kubectl get services -n three-tier

# Check ingress
kubectl get ingress -n three-tier
```

---

## Cleanup

To destroy all resources when you're done:
```bash
cd eks-terraform
terraform destroy -var="key_pair_name=my-key-pair" --auto-approve
```

**Note:** This will permanently delete all resources including the EKS cluster, management instance, and all data. 

# Pluging to install 
AWS Credentials
Pipeline: AWS Steps

Docker
Docker Commons
Docker Pipeline
Docker API
docker-build-step
Eclipse Temurin installer
NodeJS
OWASP Dependency-Check
SonarQube Scanner


# checks to make 
# Download the policy for the LoadBalancer prerequisite.
curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.5.4/docs/install/iam_policy.json

# Create the IAM policy 
aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy --policy-document file://iam_policy.json

# Create OIDC Provider
eksctl utils associate-iam-oidc-provider --region=us-east-1 --cluster=dev-bilarn-cluster --approve

# Create a Service Account
Create a Service Account by using below command and replace your account ID with your one

eksctl create iamserviceaccount --cluster=dev-bilarn-cluster --namespace=kube-system --name=aws-load-balancer-controller --role-name AmazonEKSLoadBalancerControllerRole --attach-policy-arn=arn:aws:iam::590184055656:policy/AWSLoadBalancerControllerIAMPolicy --approve --region=us-east-1

# Run the below command to deploy the AWS Load Balancer Controller

sudo snap install helm --classic

helm repo add eks https://aws.github.io/eks-charts
helm repo update eks
helm install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system --set clusterName=dev-bilarn-cluster --set serviceAccount.create=false --set serviceAccount.name=aws-load-balancer-controller

---

## AWS Load Balancer Controller: Manual Setup Commands & Explanations

### 1. Download the IAM Policy for the Load Balancer Controller
```bash
curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.5.4/docs/install/iam_policy.json
```
**What it does:** Downloads the official AWS IAM policy JSON file required by the AWS Load Balancer Controller.

**Why it's important:** The controller needs specific AWS permissions to manage AWS resources (like ELBs, Target Groups, etc.) on behalf of your Kubernetes cluster. This policy defines those permissions.

---

### 2. Create the IAM Policy in AWS
```bash
aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy --policy-document file://iam_policy.json
```
**What it does:** Creates a new IAM policy in your AWS account using the permissions defined in the downloaded `iam_policy.json`.

**Why it's important:** This policy will later be attached to an IAM role that the controller will assume, granting it the necessary permissions to operate.

---

### 3. Create the OIDC Provider for EKS
```bash
eksctl utils associate-iam-oidc-provider --region=us-east-1 --cluster=dev-bilarn-cluster --approve
```
**What it does:** Associates an OpenID Connect (OIDC) identity provider with your EKS cluster.

**Why it's important:** OIDC allows Kubernetes service accounts to assume AWS IAM roles securely. This is required for the service account used by the Load Balancer Controller to get AWS permissions via IAM roles.

---

### 4. Create the Service Account and Attach the IAM Role
```bash
eksctl create iamserviceaccount --cluster=dev-bilarn-cluster --namespace=kube-system --name=aws-load-balancer-controller --role-name AmazonEKSLoadBalancerControllerRole --attach-policy-arn=arn:aws:iam::529088298985:policy/AWSLoadBalancerControllerIAMPolicy --approve --region=us-east-1
```
**What it does:** Creates a Kubernetes service account named `aws-load-balancer-controller` in the `kube-system` namespace, and creates/attaches an IAM role (with the policy from step 2) to this service account.

**Why it's important:** This links the Kubernetes service account to AWS IAM permissions, allowing the controller running in the cluster to interact with AWS resources securely and with least privilege.

---

### 5. Install Helm (if not already installed)
```bash
sudo snap install helm --classic
```
**What it does:** Installs Helm, a package manager for Kubernetes.

**Why it's important:** Helm is used to install and manage Kubernetes applications, including the AWS Load Balancer Controller.

---

### 6. Add the EKS Helm Chart Repository
```bash
helm repo add eks https://aws.github.io/eks-charts
```
**What it does:** Adds the AWS EKS charts repository to Helm.

**Why it's important:** This repository contains the Helm chart for the AWS Load Balancer Controller.

---

### 7. Update the Helm Repository
```bash
helm repo update eks
```
**What it does:** Updates the local Helm chart repository cache.

**Why it's important:** Ensures you have the latest version of the charts available for installation.

---

### 8. Install the AWS Load Balancer Controller
```bash
helm install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system --set clusterName=dev-bilarn-cluster  --set serviceAccount.create=false --set serviceAccount.name=aws-load-balancer-controller
```
**What it does:** Installs the AWS Load Balancer Controller into the `kube-system` namespace, using the existing service account created earlier.

**Why it's important:** This deploys the controller, which will manage AWS load balancers for your Kubernetes services. The flags ensure it uses the pre-created service account (with the correct IAM permissions).

---

### 9. Verify the Controller Deployment
```bash
kubectl get deployment -n kube-system aws-load-balancer-controller
```
**What it does:** Checks the status of the AWS Load Balancer Controller deployment in the `kube-system` namespace.

**Why it's important:** Verifies that the controller is running and ready to manage AWS load balancers for your cluster.

---

