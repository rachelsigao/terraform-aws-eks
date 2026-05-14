# Create the EKS cluster using a pre-built community module (no need to write everything from scratch)
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0" # this is module version

  # Cluster name will be something like "roboshop-dev"
  name               = "${var.project}-${var.environment}"
  kubernetes_version = "1.33"

  # Essential Built-in EKS Add-ons that run inside the cluster - Managed by AWS and automatically kept up-to-date with Kubernetes versions
  addons = {
    coredns                = {}                  # DNS resolution inside the cluster (pods find each other by name)
    eks-pod-identity-agent = {
      before_compute = true                      # Install before nodes start, so pods can assume IAM roles securely
    }
    kube-proxy             = {}                  # Handles network routing rules on each node
    vpc-cni                = {
      before_compute = true                      # Install before nodes start, so pods get proper VPC IP addresses
    }
    metrics-server= {}                           # Collects CPU/memory stats (needed for autoscaling)
  }

  # Optional - Keep the Kubernetes API private — not reachable from the internet
  endpoint_public_access = false

  # Optional - Give the person running Terraform full admin access to the cluster automatically
  enable_cluster_creator_admin_permissions = true

  # Networking
  # Place the cluster inside the VPC and private subnets created in 00-vpc
  vpc_id                   = local.vpc_id
  subnet_ids               = local.private_subnet_ids
  control_plane_subnet_ids = local.private_subnet_ids

  # Use the security groups we already created in 10-sg (don't create new ones)
  create_node_security_group = false
  create_security_group = false
  security_group_id = local.eks_control_plane_sg_id      # SG for the control plane (API server)
  node_security_group_id = local.eks_node_sg_id          # SG for the worker nodes

  # EKS Managed Worker Node Groups (Blue/Green strategy for zero-downtime upgrades)
  eks_managed_node_groups = {

    # BLUE = current active node group (runs existing workloads)
    blue = {
      ami_type       = "AL2023_x86_64_STANDARD" # Amazon Linux 2023 OS is default AMI type for Kubernetes 1.30, login user is ec2-user
      instance_types = ["m5.xlarge"]            # 4 vCPU, 16GB RAM per node

      # Autoscaling: always keep 2 nodes running, scale up to 10 if needed
      min_size     = 2
      max_size     = 10
      desired_size = 2
      } 
    iam_role_additional_policies = {
     AmazonEBS = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
     AmazonEFS = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
     AmazonEKSLoad = "arn:aws:iam::aws:policy/AmazonEKSLoadBalancingPolicy"
    }

    # GREEN = upgraded node group (workloads are migrated here during upgrades)
    green = {
      ami_type       = "AL2023_x86_64_STANDARD" # Amazon Linux 2023 OS is default AMI type for Kubernetes 1.30, login user is ec2-user
      instance_types = ["m5.xlarge"]            # 4 vCPU, 16GB RAM per node

      # Autoscaling: always keep 2 nodes running, scale up to 10 if needed
      min_size     = 2
      max_size     = 10
      desired_size = 2

      # Extra permissions granted to nodes in this group
      iam_role_additional_policies = {
        AmazonEBS     = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"   # Allows attaching EBS volumes (persistent storage)
        AmazonEFS     = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"   # Allows mounting EFS shared storage
        AmazonEKSLoad = "arn:aws:iam::aws:policy/AmazonEKSLoadBalancingPolicy"            # Allows creating AWS load balancers
      }

      # Uncomment during upgrades to prevent new pods from scheduling on green nodes until you are ready to migrate workloads manually
      # taints = {
      #   upgrade = {
      #     key    = "upgrade"
      #     value  = "true"
      #     effect = "NO_SCHEDULE"
      #   }
      # } 
    }
  }

  # Apply common project tags + a Name tag to all resources created by this module
  tags = merge(
    local.common_tags,
    {
        Name = "${var.project}-${var.environment}"
    }
  )
}