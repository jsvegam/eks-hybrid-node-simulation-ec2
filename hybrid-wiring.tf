# (si no lo tenías) para Cilium
variable "hybrid_pod_cidr" {
  type    = string
  default = "100.64.0.0/16"
}

module "k8s_hybrid" {
  source = "./modules/k8s-hybrid"

  activation_role_arn = module.iam_hybrid.activation_role_arn
  cluster_name        = var.eks_cluster_name
  region              = var.aws_region
  profile             = var.aws_profile
  manage_aws_auth     = false # <- si el módulo EKS ya hace el mapeo


  # Si este módulo hace cosas que dependen del rol/activación ya creados:
  depends_on = [
    module.eks,
    module.iam_hybrid
  ]
}
