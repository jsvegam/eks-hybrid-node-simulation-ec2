# modules/iam-hybrid/main.tf

locals {
  activation_role_name = "${var.eks_cluster_name}-eks-hybrid-activation-role"
}

data "aws_iam_policy_document" "ssm_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ssm.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "hybrid_activation" {
  name               = local.activation_role_name
  assume_role_policy = data.aws_iam_policy_document.ssm_trust.json
  tags               = var.tags
}

# Adjunta SSM Managed Instance Core (requerido por activaciones SSM)
resource "aws_iam_role_policy_attachment" "activation_ssm_core" {
  role       = aws_iam_role.hybrid_activation.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Adjunta ECR ReadOnly (pull de imágenes)
resource "aws_iam_role_policy_attachment" "activation_ecr_readonly" {
  role       = aws_iam_role.hybrid_activation.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Permisos mínimos adicionales: ecr:GetAuthorizationToken y eks:DescribeCluster
data "aws_iam_policy_document" "activation_extras" {
  statement {
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
      "eks:DescribeCluster"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "activation_ecr_eks" {
  name   = "${local.activation_role_name}-extras"
  role   = aws_iam_role.hybrid_activation.id
  policy = data.aws_iam_policy_document.activation_extras.json
}

resource "aws_ssm_activation" "this" {
  name               = "${var.eks_cluster_name}-hybrid-activation"
  description        = "Activation for EKS hybrid node"
  iam_role           = aws_iam_role.hybrid_activation.name
  registration_limit = var.ssm_registration_limit
  tags               = var.tags
}


# === (OPCIONAL, lo quieres mantener) EC2 role + instance profile para el nodo híbrido ===
data "aws_iam_policy_document" "ec2_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# Rol de instancia EC2 para el hybrid node
resource "aws_iam_role" "hybrid_instance" {
  name               = "${var.eks_cluster_name}-hybrid-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
  tags               = var.tags
}

# Políticas útiles para el nodo (SSM + ECR pull)
resource "aws_iam_role_policy_attachment" "hybrid_instance_ssm_core" {
  role       = aws_iam_role.hybrid_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "hybrid_instance_ecr_ro" {
  role       = aws_iam_role.hybrid_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Instance Profile para asociar a la instancia EC2
resource "aws_iam_instance_profile" "hybrid_instance" {
  name = "${var.eks_cluster_name}-hybrid-ec2-profile"
  role = aws_iam_role.hybrid_instance.name
  tags = var.tags
}
