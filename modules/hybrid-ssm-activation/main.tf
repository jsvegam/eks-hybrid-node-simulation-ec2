data "aws_iam_role" "activation" {
  name = var.activation_role_name
}

resource "aws_ssm_activation" "this" {
  name               = "${var.cluster_name}-hybrid"
  description        = "Activation for EKS Hybrid Nodes (${var.cluster_name})"
  iam_role           = data.aws_iam_role.activation.name # nombre, no ARN
  registration_limit = 50
  tags = {
    EKSCluster = var.cluster_name
    Compute    = "hybrid"
  }
}
