############################################
# VPC principal (EKS)
############################################
module "vpc_main" {
  source   = "./modules/vpc-main"
  eks_name = var.eks_cluster_name
  cidr     = var.vpc_cidr
  azs      = slice(data.aws_availability_zones.available.names, 0, 2)
  tags     = var.tags
}

############################################
# VPC híbrida (nodo remoto)
############################################
module "vpc_hybrid" {
  source = "./modules/vpc-hybrid"
  name   = "${var.eks_cluster_name}-hybrid-vpc"
  cidr   = var.hybrid_vpc_cidr
  azs    = slice(data.aws_availability_zones.available.names, 0, 2)
  tags   = merge(var.tags, { "eks-hybrid" = "true" })
}

############################################
# Peering + rutas entre VPCs
############################################
module "peering" {
  source = "./modules/peering-and-routes"

  eks_vpc_id            = module.vpc_main.vpc_id
  eks_cidr              = module.vpc_main.vpc_cidr
  eks_public_route_ids  = module.vpc_main.public_route_table_ids
  eks_private_route_ids = module.vpc_main.private_route_table_ids

  hybrid_vpc_id            = module.vpc_hybrid.vpc_id
  hybrid_cidr              = module.vpc_hybrid.vpc_cidr
  hybrid_public_route_ids  = module.vpc_hybrid.public_route_table_ids
  hybrid_private_route_ids = module.vpc_hybrid.private_route_table_ids

  tags = var.tags
  depends_on = [
    module.vpc_main,
    module.vpc_hybrid
  ]
}

############################################
# IAM para nodos híbridos + activación SSM
############################################
module "iam_hybrid" {
  source = "./modules/iam-hybrid"

  # Requeridos por el módulo
  aws_region       = var.aws_region
  eks_cluster_name = var.eks_cluster_name

  # Usa tu variable existente del root (no cambiamos nombres en tu proyecto)
  ssm_registration_limit = var.hybrid_registration_limit

  tags = var.tags
}

############################################
# EKS (módulo v20)
############################################
module "eks" {
  source             = "./modules/eks"
  eks_cluster_name   = var.eks_cluster_name
  cluster_version    = var.cluster_version
  vpc_id             = module.vpc_main.vpc_id
  private_subnet_ids = module.vpc_main.private_subnet_ids

  enable_cluster_creator_admin_permissions = false
  hybrid_nodes_role_arn                    = module.iam_hybrid.activation_role_arn

  tags       = var.tags
  depends_on = [module.vpc_main]
}

############################################
# Endpoints Interface SSM en VPC híbrida
############################################
module "ssm_endpoints" {
  source = "./modules/ssm-endpoints"

  vpc_id          = module.vpc_hybrid.vpc_id
  private_subnets = module.vpc_hybrid.private_subnet_ids
  vpc_cidr        = module.vpc_hybrid.vpc_cidr
  aws_region      = var.aws_region
  tags            = var.tags

  depends_on = [module.vpc_hybrid]
}

############################################
# Nodo híbrido (EC2 en VPC híbrida)
############################################
module "hybrid_node" {
  source = "./modules/hybrid-node"

  ami_id        = data.aws_ami.al2023.id
  instance_type = var.hybrid_instance_type
  key_name      = var.hybrid_ssh_key_name

  private_subnet_id = module.vpc_hybrid.private_subnet_ids[0]
  hybrid_vpc_id     = module.vpc_hybrid.vpc_id
  hybrid_vpc_cidr   = module.vpc_hybrid.vpc_cidr
  eks_vpc_cidr      = module.vpc_main.vpc_cidr

  # OJO: no pasamos bastion_sg_id en este primer apply
  #bastion_sg_id = module.bastion.security_group_id

  iam_instance_profile = module.iam_hybrid.instance_profile_name
  ssm_activation_code  = module.iam_hybrid.ssm_activation_code
  ssm_activation_id    = module.iam_hybrid.ssm_activation_id

  kubernetes_version = var.kubernetes_version
  aws_region         = var.aws_region
  eks_cluster_name   = module.eks.cluster_name

  tags = var.tags

  depends_on = [
    module.ssm_endpoints,
    module.peering
  ]
}




############################################
# Habilitar remoteNetworkConfig en el clúster
############################################
module "remote_network" {
  source       = "./modules/remote-network"
  cluster_name = module.eks.cluster_name
  aws_region   = var.aws_region
  aws_profile  = var.aws_profile
  hybrid_cidr  = module.vpc_hybrid.vpc_cidr

  depends_on = [module.eks]
}

############################################
# Bastion público en VPC híbrida
############################################
module "bastion" {
  source           = "./modules/bastion"
  vpc_id           = module.vpc_hybrid.vpc_id
  eks_cluster_name = var.eks_cluster_name
  admin_cidrs      = local.admin_cidrs
  tags             = var.tags

  create_instance  = true
  ami_id           = data.aws_ami.al2023.id
  instance_type    = "t3.small"
  public_subnet_id = module.vpc_hybrid.public_subnet_ids[0]
  key_name         = var.hybrid_ssh_key_name
  associate_eip    = false
}



# main.tf (raíz) — fuera de cualquier bloque module/resource
locals {
  # Si ssh_ingress_cidr viene vacío, no se abre el 22/tcp en el bastion
  admin_cidrs = trimspace(var.ssh_ingress_cidr) != "" ? [var.ssh_ingress_cidr] : []
}


# root/main.tf
resource "aws_security_group_rule" "ssh_from_bastion_to_hybrid" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  security_group_id        = module.hybrid_node.security_group_id # exporta este output del módulo híbrido
  source_security_group_id = module.bastion.security_group_id
  description              = "SSH from Bastion SG"
}


