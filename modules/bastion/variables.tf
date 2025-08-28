variable "vpc_id" {
  description = "VPC donde vive el bastion"
  type        = string
}

variable "eks_cluster_name" {
  description = "Nombre del clúster EKS (solo para tags/nombres)"
  type        = string
}

variable "admin_cidrs" {
  description = "CIDRs autorizados a entrar por SSH (22/tcp) al bastion"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags comunes"
  type        = map(string)
  default     = {}
}

variable "bastion_sg_id" {
  description = "Si lo proporcionas, reutiliza este Security Group. Si vacío, lo crea el módulo."
  type        = string
  default     = null
}

# EC2 opcional
variable "create_instance" {
  description = "Si true, lanza una instancia EC2 como bastion"
  type        = bool
  default     = true
}

variable "ami_id" {
  description = "AMI a usar para el bastion (ej. data.aws_ami.al2023.id)"
  type        = string
  default     = null
}

variable "instance_type" {
  description = "Tipo de instancia para el bastion"
  type        = string
  default     = "t3.small"
}

variable "public_subnet_id" {
  description = "Subnet pública donde lanzar el bastion"
  type        = string
  default     = null
}

variable "key_name" {
  description = "Nombre de la llave SSH a asociar a la instancia"
  type        = string
  default     = null
}

variable "associate_eip" {
  description = "Asociar una Elastic IP para IP pública estática"
  type        = bool
  default     = true
}
