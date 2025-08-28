output "activation_role_arn" {
  description = "ARN del rol SSM de activación (el que se mapea en aws-auth)"
  value       = aws_iam_role.hybrid_activation.arn
}

output "ssm_activation_code" {
  description = "SSM Activation Code"
  value       = aws_ssm_activation.this.activation_code
  sensitive   = true
}

output "ssm_activation_id" {
  description = "SSM Activation ID"
  value       = aws_ssm_activation.this.id
  sensitive   = true
}

# EC2 role/profile (opcional)
output "instance_profile_name" {
  description = "Nombre del Instance Profile para el nodo híbrido (EC2)"
  value       = aws_iam_instance_profile.hybrid_instance.name
}

output "instance_role_arn" {
  description = "ARN del rol EC2 del nodo híbrido (no mapear en aws-auth)"
  value       = aws_iam_role.hybrid_instance.arn
}



output "activation_id"   { value = aws_ssm_activation.this.id }
output "activation_code" { value = aws_ssm_activation.this.activation_code }
