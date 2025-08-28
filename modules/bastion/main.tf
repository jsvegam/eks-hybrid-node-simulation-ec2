# modules/bastion/main.tf

locals {
  create_sg = var.bastion_sg_id == null || var.bastion_sg_id == ""
  name      = "${var.eks_cluster_name}-bastion"
  sg_id     = local.create_sg ? aws_security_group.bastion[0].id : var.bastion_sg_id
}

# Crea el SG solo si no pasaste uno externo
resource "aws_security_group" "bastion" {
  count       = local.create_sg ? 1 : 0
  name        = "${local.name}-sg"
  description = "Bastion security group"
  vpc_id      = var.vpc_id

  # SSH permitido desde los CIDRs administradores
  dynamic "ingress" {
    for_each = length(var.admin_cidrs) > 0 ? var.admin_cidrs : []
    content {
      description = "SSH from admin CIDR"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  # Salida abierta
  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${local.name}-sg" })
}

# (Opcional) EC2 del bastion
resource "aws_instance" "bastion" {
  count                       = var.create_instance ? 1 : 0
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [local.sg_id]
  associate_public_ip_address = true
  key_name                    = var.key_name

  tags = merge(var.tags, { Name = local.name })
}

# (Opcional) Elastic IP
resource "aws_eip" "bastion" {
  count    = var.create_instance && var.associate_eip ? 1 : 0
  instance = aws_instance.bastion[0].id
  domain   = "vpc"

  tags = merge(var.tags, { Name = "${local.name}-eip" })
}
