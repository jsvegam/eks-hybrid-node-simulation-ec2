variable "eks_cluster_name" { type = string }
variable "cluster_version" { type = string }
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "hybrid_nodes_role_arn" { type = string }

variable "tags" {
  type    = map(string)
  default = {}
}

variable "enable_cluster_creator_admin_permissions" {
  type        = bool
  default     = false
  description = "Si true, el módulo crea un AccessEntry para el cluster creator. Déjalo en false para evitar duplicados."
}
