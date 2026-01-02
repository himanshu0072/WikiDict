# Terraform - Single EKS Cluster with Namespaces

This directory contains Terraform configurations for deploying the SM-WikiDict application to AWS EKS using a **single cluster with namespace-based environment isolation**.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                            AWS (eu-north-1)                              │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                         VPC (10.0.0.0/16)                           │ │
│  │                                                                     │ │
│  │   ┌─────────────────┐              ┌─────────────────┐             │ │
│  │   │ Public Subnet   │              │ Public Subnet   │             │ │
│  │   │ 10.0.1.0/24     │              │ 10.0.2.0/24     │             │ │
│  │   │ [NAT Gateway]   │              │ [NAT Gateway]   │             │ │
│  │   │ [Load Balancer] │              │ [Load Balancer] │             │ │
│  │   └────────┬────────┘              └────────┬────────┘             │ │
│  │            │                                │                       │ │
│  │   ┌────────▼────────┐              ┌────────▼────────┐             │ │
│  │   │ Private Subnet  │              │ Private Subnet  │             │ │
│  │   │ 10.0.10.0/24    │              │ 10.0.11.0/24    │             │ │
│  │   │ [EKS Nodes]     │              │ [EKS Nodes]     │             │ │
│  │   └─────────────────┘              └─────────────────┘             │ │
│  │                                                                     │ │
│  │   ┌─────────────────────────────────────────────────────────────┐  │ │
│  │   │                    EKS CLUSTER                               │  │ │
│  │   │                                                              │  │ │
│  │   │   ┌──────────────────┐      ┌──────────────────┐           │  │ │
│  │   │   │ Namespace:       │      │ Namespace:       │           │  │ │
│  │   │   │ autoqa           │      │ prod             │           │  │ │
│  │   │   │                  │      │                  │           │  │ │
│  │   │   │ • deployments    │      │ • deployments    │           │  │ │
│  │   │   │ • services       │      │ • services       │           │  │ │
│  │   │   │ • configmaps     │      │ • configmaps     │           │  │ │
│  │   │   └──────────────────┘      └──────────────────┘           │  │ │
│  │   └─────────────────────────────────────────────────────────────┘  │ │
│  │                                                                     │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
│  ┌──────────────────┐                                                   │
│  │ ECR Repository   │  (Container images)                               │
│  │ sm-wikidict      │                                                   │
│  └──────────────────┘                                                   │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## Directory Structure

```
terraform/
├── infra-setup/          # Step 1: S3 + DynamoDB for remote state
│   └── main.tf
│
├── cluster/              # Step 2: All infrastructure
│   ├── main.tf           # VPC + EKS + ECR + Namespaces
│   ├── variables.tf      # Input variables (with documentation)
│   └── outputs.tf        # Output values
│
└── README.md             # This file
```

## What Gets Created

| Resource | Description | Cost Estimate |
|----------|-------------|---------------|
| VPC | Private network with 2 AZs | Free |
| Public Subnets (2) | For load balancers | Free |
| Private Subnets (2) | For EKS nodes | Free |
| Internet Gateway | Internet access | Free |
| NAT Gateways (2) | Private subnet internet access | ~$65/month |
| EKS Cluster | Managed Kubernetes control plane | ~$72/month |
| EKS Node Group | t3.small × 1-3 nodes | ~$15-45/month |
| ECR Repository | Container image storage | ~$1/month |
| **Total** | | **~$150-180/month** |

## Prerequisites

1. **AWS CLI** configured with credentials
   ```bash
   aws configure
   ```

2. **Terraform** >= 1.0.0 installed
   ```bash
   terraform --version
   ```

3. **kubectl** installed for EKS access
   ```bash
   kubectl version --client
   ```

## Quick Start

### Step 1: Set up Remote State Backend (One-time)

```bash
cd deployment/terraform/infra-setup
terraform init
terraform plan    # Review what will be created
terraform apply   # Create S3 bucket + DynamoDB table
```

This creates:
- S3 bucket: `sm-wikidict-terraform-state`
- DynamoDB table: `sm-wikidict-terraform-locks`

### Step 2: Enable Remote State (Optional but Recommended)

After Step 1, uncomment the backend block in `cluster/main.tf`:

```hcl
backend "s3" {
  bucket         = "sm-wikidict-terraform-state"
  key            = "cluster/terraform.tfstate"
  region         = "eu-north-1"
  encrypt        = true
  dynamodb_table = "sm-wikidict-terraform-locks"
}
```

### Step 3: Deploy the Cluster

```bash
cd deployment/terraform/cluster
terraform init
terraform plan    # Review: VPC, EKS, ECR, Namespaces
terraform apply   # Takes ~15-20 minutes
```

### Step 4: Configure kubectl

After deployment, terraform shows the command:

```bash
# Run this to configure kubectl
aws eks update-kubeconfig --region eu-north-1 --name sm-wikidict-cluster

# Verify connection
kubectl get nodes
kubectl get namespaces
```

## Deploying Your Application

### 1. Login to ECR

```bash
aws ecr get-login-password --region eu-north-1 | \
  docker login --username AWS --password-stdin \
  <account-id>.dkr.ecr.eu-north-1.amazonaws.com
```

### 2. Build and Push Image

```bash
# Build
docker build -t sm-wikidict .

# Tag
docker tag sm-wikidict:latest <ecr-url>:v1.0.0

# Push
docker push <ecr-url>:v1.0.0
```

### 3. Deploy to Kubernetes

```bash
# Deploy to autoqa namespace
kubectl apply -f k8s/deployment.yaml -n autoqa

# Deploy to prod namespace
kubectl apply -f k8s/deployment.yaml -n prod
```

## Terraform Commands Reference

| Command | Description |
|---------|-------------|
| `terraform init` | Download providers, initialize backend |
| `terraform plan` | Preview changes (dry run) |
| `terraform apply` | Create/update resources |
| `terraform destroy` | Delete all resources |
| `terraform output` | Show output values |
| `terraform state list` | List all managed resources |

## Customizing Variables

You can override defaults in `cluster/variables.tf`:

```bash
# Option 1: Command line
terraform apply -var="node_desired_size=2"

# Option 2: Create terraform.tfvars
cat > terraform.tfvars <<EOF
node_desired_size   = 2
node_instance_types = ["t3.medium"]
environments        = ["dev", "staging", "prod"]
EOF
```

## Destroying Resources

```bash
# Destroy cluster and all resources
cd deployment/terraform/cluster
terraform destroy

# Destroy backend (only if you want to completely clean up)
cd ../infra-setup
terraform destroy
```

**Warning**:
- Destroy cluster BEFORE destroying infra-setup
- Ensure no running workloads before destroying
- S3 bucket has `prevent_destroy = true` - remove this if you want to delete it

## Security Notes

- EKS nodes are in **private subnets** (no public IP)
- EKS API endpoint is publicly accessible (for kubectl)
- NAT Gateways allow outbound-only internet access
- S3 state bucket has encryption enabled
- All resources are tagged for tracking

## Troubleshooting

### "Error: Kubernetes cluster unreachable"
```bash
# Update kubeconfig
aws eks update-kubeconfig --region eu-north-1 --name sm-wikidict-cluster
```

### "Error: creating EKS Cluster: AccessDeniedException"
```bash
# Check your AWS credentials
aws sts get-caller-identity
```

### Nodes not joining cluster
```bash
# Check node group status
aws eks describe-nodegroup \
  --cluster-name sm-wikidict-cluster \
  --nodegroup-name sm-wikidict-cluster-nodes \
  --region eu-north-1
```

## Learning Resources

Each file contains detailed comments explaining:
- What each resource does
- Why it's configured that way
- Visual diagrams of the architecture

Start with `cluster/variables.tf` for documented input parameters.
