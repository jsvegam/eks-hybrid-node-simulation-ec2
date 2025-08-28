# modules/ssm-endpoints/outputs.tf

# Claves de servicio bien formadas (evita plantillas dentro de índices)
locals {
  svc_ssm         = format("com.amazonaws.%s.ssm",         var.aws_region)
  svc_ssmmessages = format("com.amazonaws.%s.ssmmessages", var.aws_region)
  svc_ec2messages = format("com.amazonaws.%s.ec2messages", var.aws_region)
  # Estos dos pueden NO existir si tu main.tf no crea endpoints de ECR
  svc_ecr_api     = format("com.amazonaws.%s.ecr.api",     var.aws_region)
  svc_ecr_dkr     = format("com.amazonaws.%s.ecr.dkr",     var.aws_region)

  # Mapa cómodo: service_name => endpoint_id
  endpoint_id_map = { for k, v in aws_vpc_endpoint.ssm_if : k => v.id }
}

output "security_group_id" {
  description = "ID del SG usado por los Interface Endpoints (SSM/ECR)"
  value       = aws_security_group.ssm_endpoints.id
}

# Mapa completo: service_name => endpoint_id (tal como están en for_each)
output "endpoint_ids" {
  description = "Mapa service_name => VPC Endpoint ID"
  value       = local.endpoint_id_map
}

# Mapa corto, con valores opcionales para ECR (null si no existen)
output "endpoint_ids_short" {
  description = "IDs por clave corta (ssm, ssmmessages, ec2messages, ecr_api, ecr_dkr)"
  value = {
    ssm         = local.endpoint_id_map[local.svc_ssm]
    ssmmessages = local.endpoint_id_map[local.svc_ssmmessages]
    ec2messages = local.endpoint_id_map[local.svc_ec2messages]
    ecr_api     = lookup(local.endpoint_id_map, local.svc_ecr_api, null)
    ecr_dkr     = lookup(local.endpoint_id_map, local.svc_ecr_dkr, null)
  }
}

# (Opcional) ENIs por servicio para troubleshooting
output "endpoint_eni_ids" {
  description = "Mapa service_name => lista de ENIs asociadas al endpoint"
  value       = { for svc, ep in aws_vpc_endpoint.ssm_if : svc => ep.network_interface_ids }
}
