variable "aws_region" {
  type = string
}

variable "eks_cluster_name" {
  type = string
}

variable "ssm_registration_limit" {
  description = "Cantidad máxima de instancias que podrán registrarse con esta activación SSM."
  type        = number
  default     = 5
}

variable "tags" {
  type    = map(string)
  default = {}
}
