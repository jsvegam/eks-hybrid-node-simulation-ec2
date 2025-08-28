############################################################
# Security Group del nodo híbrido (reglas explícitas)
############################################################
resource "aws_security_group" "hybrid_node" {
  name        = "${var.eks_cluster_name}-hybrid-node-sg"
  description = "Security group for Hybrid node in private subnet"
  vpc_id      = var.hybrid_vpc_id

  tags = merge(var.tags, { Name = "${var.eks_cluster_name}-hybrid-node-sg" })
}

# SSH desde el CIDR de la VPC híbrida (estable en un solo apply)
resource "aws_security_group_rule" "ssh_from_hybrid_vpc" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  security_group_id = aws_security_group.hybrid_node.id
  cidr_blocks       = [var.hybrid_vpc_cidr]
  description       = "SSH from Hybrid VPC CIDR"
}

# Tráfico desde la VPC del clúster EKS hacia el nodo híbrido
resource "aws_security_group_rule" "eks_to_hybrid" {
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  security_group_id = aws_security_group.hybrid_node.id
  cidr_blocks       = [var.eks_vpc_cidr]
  description       = "EKS to Hybrid communication"
}

# Egreso full
resource "aws_security_group_rule" "egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.hybrid_node.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "All outbound traffic"
}

############################################################
# User data render (AL2023 + SSM + nodeadm + join)
############################################################
locals {
  user_data = templatefile("${path.module}/files/userdata.sh.tftpl", {
    aws_region          = var.aws_region
    kubernetes_version  = var.kubernetes_version
    ssm_activation_code = var.ssm_activation_code
    ssm_activation_id   = var.ssm_activation_id
    eks_cluster_name    = var.eks_cluster_name
  })
}

############################################################
# Instancia EC2 del nodo híbrido
############################################################
resource "aws_instance" "this" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.private_subnet_id
  vpc_security_group_ids      = [aws_security_group.hybrid_node.id]
  associate_public_ip_address = false
  key_name                    = var.key_name

  iam_instance_profile = try(var.iam_instance_profile, null)

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
  }

  user_data_base64 = base64encode(local.user_data)

  tags = merge(var.tags, {
    Name                             = "${var.eks_cluster_name}-hybrid-node",
    "eks.amazonaws.com/compute-type" = "hybrid",
    "eks-hybrid"                     = "true"
  })
}
