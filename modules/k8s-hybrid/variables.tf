# modules/k8s-hybrid/variables.tf

# Nuevas (preferidas)
variable "activation_role_arn" {
  description = "ARN del rol SSM de activación que se mapeará en aws-auth"
  type        = string
}

variable "cluster_name" {
  description = "Nombre del clúster EKS"
  type        = string
  default     = null
}

variable "region" {
  description = "Región AWS del clúster"
  type        = string
  default     = null
}

variable "profile" {
  description = "Perfil AWS CLI para los local-exec (opcional)"
  type        = string
  default     = ""
}

# Compat / nombres antiguos utilizados dentro del módulo
variable "eks_cluster_name" {
  description = "Compat: nombre del clúster (si el código interno aún lo usa)"
  type        = string
  default     = null
}

variable "aws_region" {
  description = "Compat: región (si el código interno aún lo usa)"
  type        = string
  default     = null
}

variable "manage_aws_auth" {
  description = "Si true, este módulo parchea aws-auth. Pon en false si lo hace el módulo EKS."
  type        = bool
  default     = true
}


locals {
  # Unificamos para usar SIEMPRE locals.* en el main del módulo
  eff_cluster_name = coalesce(var.cluster_name, var.eks_cluster_name)
  eff_region       = coalesce(var.region, var.aws_region)
  eff_profile      = var.profile
}
