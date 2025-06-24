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
    - Username: `admin`
    - Password: `admin123`

3.  **Change the default password when prompted**

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
# Get cluster information from Terraform outputs
aws eks --region $(terraform output -raw region) update-kubeconfig --name $(terraform output -raw cluster_name)
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