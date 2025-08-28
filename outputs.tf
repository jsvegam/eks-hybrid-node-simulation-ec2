output "bastion_security_group_id" {
  value       = module.bastion.security_group_id
  description = "Security Group del bastion (creado o reutilizado)."
}