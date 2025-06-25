## Automating AWS Load Balancer Controller Setup with Terraform

To automate the AWS Load Balancer Controller prerequisites, add the following resources to your Terraform configuration (e.g., in `iam.tf` or a new file):

```hcl
# 1. Create the IAM policy for the AWS Load Balancer Controller
resource "aws_iam_policy" "aws_load_balancer_controller" {
  name        = "AWSLoadBalancerControllerIAMPolicy"
  description = "IAM policy for AWS Load Balancer Controller"
  policy      = file("iam_policy.json") # Download this file as in the manual step
}

# 2. Create the OIDC provider for your EKS cluster
resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.aws_eks_cluster.eks.identity[0].oidc[0].thumbprint]
  url             = data.aws_eks_cluster.eks.identity[0].oidc[0].issuer
}

# 3. Create the IAM role for the controller's service account
resource "aws_iam_role" "aws_load_balancer_controller" {
  name = "AmazonEKSLoadBalancerControllerRole"
  assume_role_policy = data.aws_iam_policy_document.aws_load_balancer_controller_assume_role_policy.json
}

# 4. Attach the policy to the role
resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  role       = aws_iam_role.aws_load_balancer_controller.name
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
}

# 5. (Optional) Use a Kubernetes provider to create the service account and annotate it with the IAM role
```

**Note:**
- You must download the official AWS Load Balancer Controller IAM policy JSON and reference it in your Terraform code (see [AWS docs](https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html)).
- You may need to use the `kubernetes_service_account` resource (with the Terraform Kubernetes provider) to create the service account and annotate it with the IAM role ARN.
- This will fully automate the prerequisites for the AWS Load Balancer Controller, so you won't need to run the manual commands in `commands.md`. 

## Manual Cleanup: Deleting AWS Load Balancer Controller Resources

If you created the AWS Load Balancer Controller prerequisites manually, use the following steps to delete them when you are done:

### 1. Delete the Kubernetes Service Account
```bash
kubectl delete serviceaccount aws-load-balancer-controller -n kube-system
```

### 2. Detach and Delete the IAM Policy and Role
- **Find the role and policy names/ARNs if you don't remember them:**
  ```bash
  aws iam list-roles | grep LoadBalancerController
  aws iam list-policies | grep LoadBalancerController
  ```

- **Detach the policy from the role:**
  ```bash
  aws iam detach-role-policy \
    --role-name AmazonEKSLoadBalancerControllerRole \
    --policy-arn arn:aws:iam::529088298985:policy/AWSLoadBalancerControllerIAMPolicy
  ```

- **Delete the IAM policy:**
  ```bash
  aws iam delete-policy --policy-arn arn:aws:iam::<ACCOUNT_ID>:policy/AWSLoadBalancerControllerIAMPolicy
  ```

- **Delete the IAM role:**
  ```bash
  aws iam delete-role --role-name AmazonEKSLoadBalancerControllerRole
  ```

### 3. Delete the OIDC Provider
- **List OIDC providers:**
  ```bash
  aws iam list-open-id-connect-providers
  ```
- **Delete the OIDC provider:**
  ```bash
  aws iam delete-open-id-connect-provider --open-id-connect-provider-arn arn:aws:iam::<ACCOUNT_ID>:oidc-provider/<OIDC_PROVIDER_URL>
  ```

### 4. (Optional) Delete the IAM policy JSON file if you downloaded it locally
```bash
rm iam_policy.json
```

**Note:**
- Replace `<ACCOUNT_ID>` and `<OIDC_PROVIDER_URL>` with your actual AWS account ID and OIDC provider URL as needed.
- Always double-check resource names/ARNs before deleting to avoid accidental removal of unrelated resources. 