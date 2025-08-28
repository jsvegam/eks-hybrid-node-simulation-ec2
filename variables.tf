variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "aws_profile" {
  type    = string
  default = "eks-operator"
}

variable "eks_cluster_name" {
  type    = string
  default = "my-eks-cluster"
}

variable "cluster_version" {
  type    = string
  default = "1.28"
}

variable "kubernetes_version" {
  type    = string
  default = "1.28"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "hybrid_vpc_cidr" {
  type    = string
  default = "192.168.0.0/16"
}

variable "hybrid_instance_type" {
  type    = string
  default = "t3.small"
}

variable "hybrid_ssh_key_name" {
  type    = string
  default = "eks-hybrid-debug"
}

variable "hybrid_registration_limit" {
  type    = number
  default = 5
}

variable "ssh_ingress_cidr" {
  description = "Tu IP pública /32 para acceder por SSH al bastion (dejar vacío para cerrar SSH)"
  type        = string
  default     = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}


