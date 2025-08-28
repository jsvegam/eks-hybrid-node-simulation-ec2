variable "eks_vpc_id" {
  type        = string
  description = "VPC ID del cluster EKS"
}

variable "eks_cidr" {
  type        = string
  description = "CIDR de la VPC del cluster EKS"
}

variable "eks_private_route_ids" {
  type        = list(string)
  description = "IDs de route tables privadas en la VPC EKS"
}

variable "eks_public_route_ids" {
  type        = list(string)
  description = "IDs de route tables públicas en la VPC EKS"
}

variable "hybrid_vpc_id" {
  type        = string
  description = "VPC ID de la VPC híbrida"
}

variable "hybrid_cidr" {
  type        = string
  description = "CIDR de la VPC híbrida"
}

variable "hybrid_private_route_ids" {
  type        = list(string)
  description = "IDs de route tables privadas en la VPC híbrida"
}

variable "hybrid_public_route_ids" {
  type        = list(string)
  description = "IDs de route tables públicas en la VPC híbrida"
}

variable "tags" {
  type        = map(string)
  description = "Etiquetas comunes"
  default     = {}
}
