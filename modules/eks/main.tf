data "aws_caller_identity" "current" {}

# Addon versions
data "aws_eks_addon_version" "vpc_cni" {
  addon_name         = "vpc-cni"
  kubernetes_version = var.cluster_version
  most_recent        = true
}

data "aws_eks_addon_version" "coredns" {
  addon_name         = "coredns"
  kubernetes_version = var.cluster_version
  most_recent        = true
}

data "aws_eks_addon_version" "kubeproxy" {
  addon_name         = "kube-proxy"
  kubernetes_version = var.cluster_version
  most_recent        = true
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name                    = var.eks_cluster_name
  cluster_version                 = var.cluster_version
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  # NO crear el AccessEntry del “cluster creator” para evitar ResourceInUse en recreaciones
  enable_cluster_creator_admin_permissions = var.enable_cluster_creator_admin_permissions

  # Node group “default” (si lo quieres para capacidad básica del clúster)
  eks_managed_node_groups = {
    default = {
      desired_size   = 2
      min_size       = 1
      max_size       = 3
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
    }
  }

  # Access Entries gestionados 100% por Terraform
  access_entries = {
    eks-operator = {
      principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/eks-operator"
      policy_associations = {
        admin = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }

    # Rol de los nodos híbridos
    hybrid-nodes = {
      principal_arn = var.hybrid_nodes_role_arn
      policy_associations = {
        # Para avanzar rápido lo dejamos con admin al clúster.
        # Más adelante podemos restringirlo si quieres.
        node = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  }

  # Addons con versiones compatibles detectadas
  cluster_addons = {
    vpc-cni = {
      addon_version     = data.aws_eks_addon_version.vpc_cni.version
      resolve_conflicts = "OVERWRITE"
    }
    coredns = {
      addon_version     = data.aws_eks_addon_version.coredns.version
      resolve_conflicts = "OVERWRITE"
    }
    kube-proxy = {
      addon_version     = data.aws_eks_addon_version.kubeproxy.version
      resolve_conflicts = "OVERWRITE"
    }
  }

  tags = var.tags
}
