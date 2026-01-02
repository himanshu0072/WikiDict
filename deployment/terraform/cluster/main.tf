# ============================================================================
# MAIN.TF - Single EKS Cluster with Multiple Namespaces
# ============================================================================
#
# This file creates:
#   1. VPC (Virtual Private Cloud) - Your private network
#   2. Subnets (Public & Private) - Subdivisions of VPC
#   3. Internet Gateway - Entry point from internet
#   4. NAT Gateway - Allows private resources to reach internet
#   5. Route Tables - Traffic rules
#   6. EKS Cluster - Managed Kubernetes
#   7. EKS Node Group - Worker machines
#   8. ECR Repository - Container image storage
#   9. Kubernetes Namespaces - Environment isolation
#
# ============================================================================

# ----------------------------------------------------------------------------
# SECTION 1: TERRAFORM CONFIGURATION
# ----------------------------------------------------------------------------
# This section declares:
#   - Required Terraform version
#   - Required providers (AWS, Kubernetes)
#   - Where to download them from
# ----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }

  # ┌─────────────────────────────────────────────────────────────────────────┐
  # │ REMOTE STATE BACKEND (Uncomment after running infra-setup)              │
  # ├─────────────────────────────────────────────────────────────────────────┤
  # │ Stores terraform.tfstate in S3 instead of locally                       │
  # │ Enables team collaboration and state locking                            │
  # └─────────────────────────────────────────────────────────────────────────┘
  # backend "s3" {
  #   bucket         = "sm-wikidict-terraform-state"
  #   key            = "cluster/terraform.tfstate"
  #   region         = "eu-north-1"
  #   encrypt        = true
  #   dynamodb_table = "sm-wikidict-terraform-locks"
  # }
}

# ----------------------------------------------------------------------------
# SECTION 2: PROVIDER CONFIGURATION
# ----------------------------------------------------------------------------
# Configures HOW to connect to AWS and Kubernetes
# ----------------------------------------------------------------------------

provider "aws" {
  region = var.aws_region

  # Default tags applied to ALL resources created by this config
  default_tags {
    tags = {
      Project   = var.service_name
      ManagedBy = "terraform"
    }
  }
}

# Kubernetes provider - configured AFTER EKS cluster is created
# Uses the cluster endpoint and certificate from EKS
provider "kubernetes" {
  host                   = aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority[0].data)

  # This gets a token to authenticate with EKS
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.main.name]
  }
}

# ----------------------------------------------------------------------------
# SECTION 3: LOCAL VALUES
# ----------------------------------------------------------------------------
# Computed values used throughout the configuration
# ----------------------------------------------------------------------------

locals {
  cluster_name = "${var.service_name}-cluster"

  common_tags = merge(var.tags, {
    Project   = var.service_name
    ManagedBy = "terraform"
  })
}

# ============================================================================
# SECTION 4: VPC (Virtual Private Cloud)
# ============================================================================
#
#   ┌─────────────────────────────────────────────────────────────────────┐
#   │                           VPC                                       │
#   │                      (Your Private Network)                         │
#   │                                                                     │
#   │   Everything you create in AWS lives inside this VPC                │
#   │   It's isolated from other AWS customers                            │
#   └─────────────────────────────────────────────────────────────────────┘
#
# ============================================================================

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true  # Instances get DNS names like ip-10-0-1-5.ec2.internal
  enable_dns_support   = true  # Enable DNS resolution within VPC

  tags = merge(local.common_tags, {
    Name = "${var.service_name}-vpc"
  })
}

# ============================================================================
# SECTION 5: INTERNET GATEWAY
# ============================================================================
#
#   Internet
#      │
#      ▼
#   ┌─────────────────┐
#   │ Internet Gateway │ ← This resource
#   └────────┬────────┘
#            │
#            ▼
#   ┌─────────────────┐
#   │      VPC        │
#   └─────────────────┘
#
#   Without this, nothing in your VPC can reach the internet
#
# ============================================================================

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.service_name}-igw"
  })
}

# ============================================================================
# SECTION 6: SUBNETS
# ============================================================================
#
#   ┌─────────────────────────── VPC ───────────────────────────┐
#   │                                                            │
#   │   AZ: eu-north-1a           AZ: eu-north-1b               │
#   │   ┌──────────────┐          ┌──────────────┐              │
#   │   │ PUBLIC       │          │ PUBLIC       │              │
#   │   │ 10.0.1.0/24  │          │ 10.0.2.0/24  │              │
#   │   │ [LB, NAT]    │          │ [LB, NAT]    │              │
#   │   └──────────────┘          └──────────────┘              │
#   │                                                            │
#   │   ┌──────────────┐          ┌──────────────┐              │
#   │   │ PRIVATE      │          │ PRIVATE      │              │
#   │   │ 10.0.10.0/24 │          │ 10.0.11.0/24 │              │
#   │   │ [EKS Nodes]  │          │ [EKS Nodes]  │              │
#   │   └──────────────┘          └──────────────┘              │
#   │                                                            │
#   └────────────────────────────────────────────────────────────┘
#
# ============================================================================

# PUBLIC SUBNETS - For Load Balancers, NAT Gateways
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true  # Resources here get public IPs automatically

  tags = merge(local.common_tags, {
    Name = "${var.service_name}-public-${var.availability_zones[count.index]}"

    # Special tags for Kubernetes to discover subnets for Load Balancers
    "kubernetes.io/role/elb"                        = "1"
    "kubernetes.io/cluster/${local.cluster_name}"   = "shared"
  })
}

# PRIVATE SUBNETS - For EKS Nodes (more secure)
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]
  # No public IP - these are private!

  tags = merge(local.common_tags, {
    Name = "${var.service_name}-private-${var.availability_zones[count.index]}"

    # Special tags for Kubernetes to discover subnets for internal Load Balancers
    "kubernetes.io/role/internal-elb"               = "1"
    "kubernetes.io/cluster/${local.cluster_name}"   = "shared"
  })
}

# ============================================================================
# SECTION 7: NAT GATEWAY
# ============================================================================
#
#   Private Subnet needs to download packages, pull Docker images, etc.
#   But it has no public IP. NAT Gateway solves this:
#
#   ┌──────────────┐     ┌─────────────┐     ┌──────────┐
#   │ Private      │ ──▶ │ NAT Gateway │ ──▶ │ Internet │
#   │ Subnet       │     │ (in Public) │     │          │
#   │ [EKS Node]   │     └─────────────┘     └──────────┘
#   └──────────────┘
#         │
#         │  ✓ Can download FROM internet (outbound)
#         │  ✗ Cannot be reached FROM internet (inbound blocked)
#
# ============================================================================

# Elastic IP for NAT Gateway (a static public IP)
resource "aws_eip" "nat" {
  count  = length(var.public_subnet_cidrs)
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${var.service_name}-nat-eip-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.main]
}

# NAT Gateway - Lives in public subnet, allows private subnet to reach internet
resource "aws_nat_gateway" "main" {
  count         = length(var.public_subnet_cidrs)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(local.common_tags, {
    Name = "${var.service_name}-nat-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.main]
}

# ============================================================================
# SECTION 8: ROUTE TABLES
# ============================================================================
#
#   Route Tables = Traffic rules that say "to reach X, go through Y"
#
#   PUBLIC ROUTE TABLE:
#     Destination     │ Target
#     ────────────────┼─────────────────
#     10.0.0.0/16     │ local (within VPC)
#     0.0.0.0/0       │ Internet Gateway  ← All other traffic goes to internet
#
#   PRIVATE ROUTE TABLE:
#     Destination     │ Target
#     ────────────────┼─────────────────
#     10.0.0.0/16     │ local (within VPC)
#     0.0.0.0/0       │ NAT Gateway       ← All other traffic goes through NAT
#
# ============================================================================

# PUBLIC ROUTE TABLE
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"           # All traffic not in VPC
    gateway_id = aws_internet_gateway.main.id  # Goes to Internet Gateway
  }

  tags = merge(local.common_tags, {
    Name = "${var.service_name}-public-rt"
  })
}

# PRIVATE ROUTE TABLES (one per AZ for high availability)
resource "aws_route_table" "private" {
  count  = length(var.private_subnet_cidrs)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"                      # All traffic not in VPC
    nat_gateway_id = aws_nat_gateway.main[count.index].id  # Goes through NAT
  }

  tags = merge(local.common_tags, {
    Name = "${var.service_name}-private-rt-${count.index + 1}"
  })
}

# ASSOCIATE ROUTE TABLES WITH SUBNETS
resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = length(var.private_subnet_cidrs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# ============================================================================
# SECTION 9: EKS CLUSTER IAM ROLE
# ============================================================================
#
#   IAM Role = "Who can do what"
#
#   EKS Cluster needs permissions to:
#     - Manage EC2 instances
#     - Create/manage network interfaces
#     - Write logs to CloudWatch
#
#   We create a Role and attach AWS-managed policies to it
#
# ============================================================================

resource "aws_iam_role" "eks_cluster" {
  name = "${local.cluster_name}-role"

  # Trust policy: WHO can assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"  # Only EKS service can use this role
      }
    }]
  })

  tags = local.common_tags
}

# Attach AWS-managed policy for EKS
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

# ============================================================================
# SECTION 10: EKS CLUSTER
# ============================================================================
#
#   ┌─────────────────────────────────────────────────────────────────────┐
#   │                         EKS CLUSTER                                  │
#   │                                                                      │
#   │   ┌─────────────────────────────────────────────────────────────┐   │
#   │   │                    Control Plane                             │   │
#   │   │               (Managed by AWS - $0.10/hr)                    │   │
#   │   │                                                              │   │
#   │   │   • API Server (kubectl talks to this)                      │   │
#   │   │   • etcd (stores cluster state)                             │   │
#   │   │   • Scheduler (decides where pods run)                      │   │
#   │   │   • Controller Manager (maintains desired state)            │   │
#   │   └─────────────────────────────────────────────────────────────┘   │
#   │                              │                                       │
#   │                              ▼                                       │
#   │   ┌─────────────────────────────────────────────────────────────┐   │
#   │   │                    Node Group                                │   │
#   │   │               (EC2 instances you pay for)                    │   │
#   │   │                                                              │   │
#   │   │   ┌─────────┐  ┌─────────┐  ┌─────────┐                    │   │
#   │   │   │ Node 1  │  │ Node 2  │  │ Node 3  │                    │   │
#   │   │   │ [pods]  │  │ [pods]  │  │ [pods]  │                    │   │
#   │   │   └─────────┘  └─────────┘  └─────────┘                    │   │
#   │   └─────────────────────────────────────────────────────────────┘   │
#   └─────────────────────────────────────────────────────────────────────┘
#
# ============================================================================

resource "aws_eks_cluster" "main" {
  name     = local.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    subnet_ids              = aws_subnet.private[*].id  # Deploy in private subnets
    endpoint_private_access = true   # Can access API from within VPC
    endpoint_public_access  = true   # Can access API from internet (for kubectl)
  }

  # Enable logging for debugging
  enabled_cluster_log_types = ["api", "audit", "authenticator"]

  tags = merge(local.common_tags, {
    Name = local.cluster_name
  })

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]
}

# ============================================================================
# SECTION 11: EKS NODE GROUP IAM ROLE
# ============================================================================
#
#   Worker nodes need permissions to:
#     - Join the cluster
#     - Pull images from ECR
#     - Manage network interfaces
#
# ============================================================================

resource "aws_iam_role" "eks_nodes" {
  name = "${local.cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"  # EC2 instances can use this role
      }
    }]
  })

  tags = local.common_tags
}

# Attach required policies for worker nodes
resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "eks_container_registry" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_nodes.name
}

# ============================================================================
# SECTION 12: EKS NODE GROUP
# ============================================================================
#
#   The actual EC2 machines that run your containers
#
# ============================================================================

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${local.cluster_name}-nodes"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = aws_subnet.private[*].id
  instance_types  = var.node_instance_types

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  update_config {
    max_unavailable = 1  # During updates, only 1 node unavailable at a time
  }

  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-nodes"
  })

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_container_registry,
  ]
}

# ============================================================================
# SECTION 13: ECR REPOSITORY
# ============================================================================
#
#   ECR = Elastic Container Registry (like Docker Hub, but private on AWS)
#
#   Your CI/CD pipeline:
#     1. Build Docker image
#     2. Push to ECR
#     3. EKS pulls image from ECR
#
# ============================================================================

resource "aws_ecr_repository" "main" {
  name                 = var.service_name
  image_tag_mutability = "MUTABLE"  # Can overwrite tags (e.g., "latest")

  image_scanning_configuration {
    scan_on_push = true  # Scan images for vulnerabilities
  }

  tags = merge(local.common_tags, {
    Name = var.service_name
  })
}

# Lifecycle policy - automatically delete old images
resource "aws_ecr_lifecycle_policy" "main" {
  repository = aws_ecr_repository.main.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 5 images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 5
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Delete untagged images older than 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ============================================================================
# SECTION 14: KUBERNETES NAMESPACES
# ============================================================================
#
#   This is where Kubernetes provider kicks in!
#   We create a namespace for each environment (autoqa, prod)
#
#   ┌─────────────────────────────────────────────────────────────────────┐
#   │                         EKS CLUSTER                                  │
#   │                                                                      │
#   │   ┌─────────────────┐              ┌─────────────────┐             │
#   │   │    autoqa       │              │      prod       │             │
#   │   │   namespace     │              │    namespace    │             │
#   │   │                 │              │                 │             │
#   │   │ • deployments   │              │ • deployments   │             │
#   │   │ • services      │              │ • services      │             │
#   │   │ • configmaps    │              │ • configmaps    │             │
#   │   │ • secrets       │              │ • secrets       │             │
#   │   └─────────────────┘              └─────────────────┘             │
#   │                                                                      │
#   └─────────────────────────────────────────────────────────────────────┘
#
# ============================================================================

resource "kubernetes_namespace" "environments" {
  for_each = toset(var.environments)

  metadata {
    name = each.key

    labels = {
      name        = each.key
      environment = each.key
      managed-by  = "terraform"
    }
  }

  depends_on = [aws_eks_node_group.main]
}
