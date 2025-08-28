# modules/hybrid-node/variables.tf

variable "eks_cluster_name" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "hybrid_vpc_id" {
  type = string
}

variable "hybrid_vpc_cidr" {
  type = string
}

variable "eks_vpc_cidr" {
  type = string
}

variable "ami_id" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "private_subnet_id" {
  type = string
}

variable "key_name" {
  type = string
}

variable "iam_instance_profile" {
  type    = string
  default = null
}

variable "kubernetes_version" {
  type = string
}

variable "ssm_activation_id" {
  type = string
}

variable "ssm_activation_code" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
