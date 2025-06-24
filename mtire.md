# M-Tier Application Architecture and Workflow Analysis

This document outlines the architecture and complete operational flow of the M-Tier application, from infrastructure provisioning to application deployment and access.

## 1. Project Structure

The project is organized into four main directories:

-   `eks-terraform`: Contains Infrastructure as Code (IaC) scripts to provision the necessary AWS resources.
-   `Project-code`: Holds the source code for the application's frontend and backend services.
-   `pipeline-Jenkinsfile-Code`: Defines the CI/CD pipelines for building and deploying the application.
-   `k8s-manifests`: Contains Kubernetes manifest files for deploying and managing the application on EKS.

---

## 2. Infrastructure Provisioning (`eks-terraform`)

The foundation of the project is laid using Terraform scripts that automate the creation of the cloud environment on AWS.

-   **VPC (`vpc.tf`):** A custom Virtual Private Cloud is created to provide a logically isolated network for the application resources.
-   **EKS Cluster (`ec2.tf`, `iam-*.tf`):** An Amazon EKS (Elastic Kubernetes Service) cluster is provisioned. This cluster serves as the container orchestration platform where the application will run. Associated IAM roles and policies are created to grant necessary permissions to the EKS control plane and worker nodes.
-   **Tooling (`tools-install.sh`):** This script likely runs on a management or Jenkins instance to install essential command-line tools like `kubectl`, `eksctl`, and `aws-cli` for interacting with the cluster and AWS.

---

## 3. Application Code (`Project-code`)

The application itself is a classic two-tier architecture.

### Backend (`Project-code/backend`)

-   **Technology:** A Node.js and Express.js application.
-   **Database:** It connects to a MongoDB database, as indicated by `db.js`, which uses the `mongoose` library. The connection string and credentials are provided via environment variables (`MONGO_CONN_STR`, `MONGO_USERNAME`, `MONGO_PASSWORD`).
-   **API:** It exposes a RESTful API for managing tasks (defined in `routes/tasks.js` and `models/task.js`).
-   **Containerization:** A `Dockerfile` is present to package the backend service into a Docker image.

### Frontend (`Project-code/frontend`)

-   **Technology:** A React.js single-page application (SPA), bootstrapped with `create-react-app`.
-   **Functionality:** It provides the user interface for the application. It interacts with the backend service to create, view, and manage tasks, as seen in `src/services/taskServices.js`.
-   **Containerization:** A `Dockerfile` is also present here to package the frontend application, likely serving the static build files with a web server like Nginx.

---

## 4. CI/CD DevSecOps Pipeline (`pipeline-Jenkinsfile-Code`)

The project uses Jenkins for Continuous Integration, Continuous Delivery, and security scanning. Separate pipelines are defined for the frontend and backend (`Jenkinsfile-Frontend`, `Jenkinsfile-Backend`).

The pipeline stages are as follows:

1.  **Checkout:** The pipeline checks out the latest code from the `main` branch of the GitHub repository.
2.  **Static Analysis (SAST):** Code is scanned for quality and security vulnerabilities using **SonarQube**. The pipeline waits for the SonarQube Quality Gate to pass before proceeding.
3.  **Dependency Scanning (SCA):** **OWASP Dependency-Check** is used to scan the project's dependencies for known CVEs.
4.  **Filesystem Vulnerability Scan:** **Trivy** scans the project's file system for vulnerabilities (`trivy fs`).
5.  **Build Docker Image:** A Docker image is built for the service (frontend or backend) using its respective `Dockerfile`.
6.  **Push to ECR:** The newly built Docker image is tagged and pushed to an Amazon ECR (Elastic Container Registry) repository.
7.  **Image Vulnerability Scan:** **Trivy** is used again, this time to scan the final Docker image in ECR for OS and application-level vulnerabilities (`trivy image`).
8.  **Update Manifest & Deploy:**
    -   The pipeline checks out the repository again.
    -   It modifies the Kubernetes `deployment.yaml` for the corresponding service, updating the image tag to the new version (e.g., `${AWS_ECR_REPO_NAME}:${BUILD_NUMBER}`).
    -   It commits and pushes this change directly back to the GitHub repository.
    -   This git push triggers an automatic deployment reconciliation in the EKS cluster (assuming a GitOps tool like ArgoCD or Flux is configured, or it relies on a manual `kubectl apply` or a subsequent pipeline step not shown).

---

## 5. Kubernetes Deployment (`k8s-manifests`)

The Kubernetes manifests define the desired state of the application running in the EKS cluster.

-   **Database (`k8s-manifests/Database`):**
    -   `deployment.yaml`: Deploys a MongoDB instance.
    -   `service.yaml`: Creates a `ClusterIP` service so the backend can communicate with the database.
    -   `secrets.yaml`: Manages the MongoDB credentials securely.
    -   `pv.yaml` & `pvc.yaml`: Provision persistent storage to ensure database data survives pod restarts.

-   **Backend (`k8s-manifests/Backend`):**
    -   `deployment.yaml`: Manages the deployment of the backend application pods using the image from ECR.
    -   `service.yaml`: Exposes the backend pods internally within the cluster via a `ClusterIP` service named `api`.

-   **Frontend (`k8s-manifests/Frontend`):**
    -   `deployment.yaml`: Manages the deployment of the frontend application pods.
    -   `service.yaml`: Exposes the frontend pods internally within the cluster via a `ClusterIP` service named `frontend`.

---

## 6. Traffic Flow (`ingress.yaml`)

External access to the application is managed by an AWS Application Load Balancer (ALB), configured via a Kubernetes Ingress resource.

1.  A user navigates to `http://bilarn.com`.
2.  The request hits the internet-facing ALB.
3.  The ALB uses the rules defined in `ingress.yaml` to route the request:
    -   If the path starts with `/api`, the request is forwarded to the backend service (`api`) on port 3500.
    -   For all other paths (e.g., `/`), the request is forwarded to the frontend service (`frontend`) on port 3000.
4.  The services then route the traffic to the appropriate pods, allowing the user to see the web application and interact with it.

This setup creates a robust, scalable, and secure M-tier application architecture on AWS, fully automated through IaC and a DevSecOps CI/CD pipeline. 


Deploy MongoDB within Kubernetes: Your project already includes manifests for this in the k8s-manifests/Database/ directory. These files will create a MongoDB deployment, a service to access it, and persistent storage within your EKS cluster. In this scenario, the MONGO_CONN_STR environment variable for your backend pods would be set to point to the internal Kubernetes service name for the database (e.g., mongodb://mongodb-service.three-tier.svc.cluster.local:27017/mydatabase).
