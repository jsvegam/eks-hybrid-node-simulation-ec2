variable "pod_cidr_hybrid" {
  type        = string
  description = "PodCIDR usado por Cilium (cluster-pool). No debe solapar la VPC/Service CIDR."
  default     = "100.64.0.0/16"
}

variable "cilium_version" {
  type        = string
  description = "Versión del chart de Cilium."
  default     = "1.18.1"
}

variable "activation_role_name" {
  type        = string
  description = "Nombre del rol IAM de activación SSM para nodos híbridos."
  default     = "eks-hybrid-activation-role"
}


variable "admin_cidrs" {
  type        = list(string)
  description = "CIDRs con acceso SSH (22) al bastion."
  default     = []
}
