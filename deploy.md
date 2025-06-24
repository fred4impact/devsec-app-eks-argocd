# M-Tier Application Deployment Guide

This guide provides the step-by-step commands and procedures to deploy the M-Tier application, from provisioning the infrastructure to deploying the application services on Kubernetes.

---

## Prerequisites

Before you begin, ensure you have the following tools installed and configured:

-   **AWS CLI:** Configured with the necessary permissions to create EKS, VPC, and IAM resources.
-   **Terraform:** Installed and available in your PATH.
-   **kubectl:** Installed and configured to interact with a Kubernetes cluster.
-   **Jenkins:** A running Jenkins instance with the `NodeJS`, `SonarQube Scanner`, `OWASP Dependency-Check`, and `Docker` plugins installed. You will also need to configure credentials within Jenkins.

---

## Stage 1: Infrastructure Provisioning with Terraform

This stage creates the foundational AWS resources, including the VPC and EKS cluster.

1.  **Navigate to the Terraform directory:**
    ```bash
    cd eks-terraform
    ```

2.  **Initialize Terraform:**
    This command downloads the necessary provider plugins.
    ```bash
    terraform init
    ```

3.  **(Optional) Review the execution plan:**
    This command shows you what resources Terraform will create, modify, or destroy. It's a good practice to review this before applying changes.
    ```bash
    terraform plan -var-file="variables.tfvars"
    ```

4.  **Apply the Terraform configuration:**
    This command provisions the resources on AWS. You will be prompted to confirm the action.
    ```bash
    terraform apply -var-file="variables.tfvars" --auto-approve
    ```
    *Note: The `--auto-approve` flag bypasses the interactive confirmation.*

5.  **Configure `kubectl`:**
    After the EKS cluster is created, you need to configure `kubectl` to communicate with it. The specific command will be an output from your Terraform apply, but it will look similar to this:
    ```bash
    aws eks --region $(terraform output -raw region) update-kubeconfig --name $(terraform output -raw cluster_name)
    ```

---

## Stage 2: CI/CD Pipeline Execution

This project uses Jenkins to build, test, and deploy the frontend and backend services.

1.  **Set up Jenkins Credentials:**
    Before running the pipelines, you must configure the following credentials in Jenkins with the specified IDs:
    -   `ACCOUNT_ID`: Your AWS Account ID.
    -   `ECR_REPO1`: The name of the ECR repository for the **frontend**.
    -   `ECR_REPO2`: The name of the ECR repository for the **backend**.
    -   `GITHUB`: Your GitHub personal access token with repo permissions.
    -   `sonar-token`: A user token from your SonarQube server.

2.  **Create Jenkins Pipelines:**
    In Jenkins, create two new "Pipeline" jobs, one for the frontend and one for the backend.
    -   **For each pipeline:** Point the "Pipeline script from SCM" setting to your GitHub repository and specify the correct `Jenkinsfile` path (`pipeline-Jenkinsfile-Code/Jenkinsfile-Frontend` or `pipeline-Jenkinsfile-Code/Jenkinsfile-Backend`).

3.  **Trigger the Pipelines:**
    Run the "Build Now" command for both the frontend and backend pipelines in Jenkins. The pipelines will execute the stages defined in the Jenkinsfiles, including scanning, building Docker images, pushing them to ECR, and updating the deployment manifests in your GitHub repository.

---

## Stage 3: Initial Kubernetes Deployment

While the Jenkins pipelines handle the continuous deployment of the frontend and backend applications, the other Kubernetes components must be deployed manually the first time.

1.  **Create the Namespace:**
    The `ingress.yaml` specifies the `three-tier` namespace. Create it first.
    ```bash
    kubectl create namespace three-tier
    ```

2.  **Deploy the Database:**
    Apply all the manifests in the `Database` directory. This will set up the MongoDB deployment, service, and persistent volume.
    ```bash
    kubectl apply -f k8s-manifests/Database/ -n three-tier
    ```

3.  **Deploy the Backend and Frontend Services:**
    Although the Jenkins pipeline will manage the deployments, you need to create the services and initial deployments so the Ingress has something to target.
    ```bash
    # Deploy Backend
    kubectl apply -f k8s-manifests/Backend/ -n three-tier

    # Deploy Frontend
    kubectl apply -f k8s-manifests/Frontend/ -n three-tier
    ```
    *The Jenkins pipeline will subsequently update the `image` tag in the `deployment.yaml` files for the frontend and backend.*

4.  **Deploy the Ingress Controller and Ingress Resource:**
    First, you need to install the AWS Load Balancer Controller in your cluster. Follow the official AWS documentation for this step. Once the controller is running, you can deploy the Ingress resource.
    ```bash
    kubectl apply -f k8s-manifests/ingress.yaml -n three-tier
    ```

---

## Post-Deployment

After completing these stages, your application should be fully deployed. The Jenkins pipelines will automatically handle any new changes pushed to the `main` branch. You can find the public URL of your application by checking the address of the Application Load Balancer created by the Ingress.

```bash
kubectl get ingress mainlb -n three-tier -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```
This command will give you the DNS hostname of the ALB, which you can use to access your application at `http://<your-alb-hostname>`. 