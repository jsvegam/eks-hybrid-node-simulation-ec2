# modules/bastion/outputs.tf

output "security_group_id" {
  description = "ID del Security Group (creado o externo)"
  value       = local.sg_id
}

output "instance_id" {
  description = "ID de la instancia del bastion (si fue creada)"
  value       = try(aws_instance.bastion[0].id, null)
}

output "public_ip" {
  description = "IP pública del bastion (EIP si se asoció, sino la pública directa)."
  value       = try(aws_eip.bastion[0].public_ip, try(aws_instance.bastion[0].public_ip, null))
}

output "public_dns" {
  description = "DNS público del bastion (si fue creado)"
  value       = try(aws_instance.bastion[0].public_dns, null)
}
