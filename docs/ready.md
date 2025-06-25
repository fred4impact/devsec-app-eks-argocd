---

## Complete Terraform Example: AWS Load Balancer Controller Prerequisites

Paste the following into your Terraform configuration (e.g., `alb-controller.tf`). Adjust variable names and references as needed for your environment.

```hcl
# Download the official AWS Load Balancer Controller IAM policy JSON and place it in your repo as iam_policy.json
# https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.5.4/docs/install/iam_policy.json

# 1. IAM Policy for the Controller
resource "aws_iam_policy" "aws_load_balancer_controller" {
  name        = "AWSLoadBalancerControllerIAMPolicy"
  description = "IAM policy for AWS Load Balancer Controller"
  policy      = file("${path.module}/iam_policy.json")
}

# 2. OIDC Provider for EKS (data source for EKS cluster)
data "aws_eks_cluster" "eks" {
  name = var.eks_cluster_name
}

data "aws_eks_cluster_auth" "eks" {
  name = var.eks_cluster_name
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.aws_eks_cluster.eks.identity[0].oidc[0].thumbprint]
  url             = data.aws_eks_cluster.eks.identity[0].oidc[0].issuer
}

# 3. IAM Role for the Service Account
# Trust policy for the service account
resource "aws_iam_role" "aws_load_balancer_controller" {
  name = "AmazonEKSLoadBalancerControllerRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(data.aws_eks_cluster.eks.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }]
  })
}

# 4. Attach the policy to the role
resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  role       = aws_iam_role.aws_load_balancer_controller.name
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
}

# 5. (Optional) Create the Kubernetes service account and annotate with IAM role
provider "kubernetes" {
  host                   = data.aws_eks_cluster.eks.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.eks.token
}

resource "kubernetes_service_account" "aws_load_balancer_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.aws_load_balancer_controller.arn
    }
  }
}
```

**Instructions:**
- Download the IAM policy JSON and place it as `iam_policy.json` in your Terraform module directory.
- Set `var.eks_cluster_name` to your EKS cluster name.
- This example assumes you have the AWS and Kubernetes providers configured.
- After applying, you can install the AWS Load Balancer Controller with Helm, referencing the created service account.

--- 




Here's how you should approach automating the deployment of the AWS Load Balancer Controller resources with Terraform, especially if you want to avoid manual steps and ensure everything is provisioned in the right order:
1. Terraform Resource Dependencies
Terraform automatically handles resource dependencies using references. For example, your IAM role depends on the OIDC provider, which depends on the EKS cluster data source. As long as you reference outputs from one resource in another, Terraform will create them in the correct order.
2. Deployment Order
Here's the recommended order for deploying these resources:
EKS Cluster: Your EKS cluster and its node groups must be created first.
OIDC Provider: The OIDC provider for the EKS cluster is created next, as it requires information from the cluster.
IAM Policy and Role: The IAM policy and role for the AWS Load Balancer Controller are created, referencing the OIDC provider.
Kubernetes Service Account: The service account is created in the EKS cluster, annotated with the IAM role ARN.
Helm Chart (Controller): Finally, you install the AWS Load Balancer Controller in the cluster, referencing the service account.
3. Automating with Terraform
Step 1: In your Terraform code, ensure your EKS cluster and node groups are defined and created first (in a separate module or earlier in your main file).
Step 2: Add the resources from your ready.md (OIDC, IAM policy, IAM role, service account) in a new module or after the cluster resources.
Step 3: Use the depends_on argument if you need to enforce order, but usually referencing outputs is enough.
Step 4: (Optional) Use the Terraform Helm provider to automate the installation of the AWS Load Balancer Controller Helm chart after the service account is created.
4. No Manual Steps Needed
If you use the Kubernetes and Helm providers in Terraform, you can automate everything, including the Helm chart installation. The only manual step is downloading the IAM policy JSON, unless you automate that with a local-exec provisioner or a data source.
5. Example Layout
Here's a high-level structure for your Terraform code:
main.tf
  - module "eks" { ... }                # EKS cluster and node groups
  - module "alb_controller" { ... }     # OIDC, IAM, Service Account, Helm chart
Or, if all in one file, just ensure the resources are in the right order and reference each other.
6. Summary Table
Step	Resource/Action	Terraform?	Depends On
1	EKS Cluster & Node Groups	Yes	-
2	OIDC Provider	Yes	EKS Cluster
3	IAM Policy & Role	Yes	OIDC Provider
4	Kubernetes Service Account	Yes	IAM Role, EKS Cluster
5	AWS Load Balancer Controller (Helm)	Yes	Service Account
