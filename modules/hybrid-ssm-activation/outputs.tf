output "activation_id" {
  value     = aws_ssm_activation.this.activation_id
  sensitive = true
}
output "activation_code" {
  value     = aws_ssm_activation.this.activation_code
  sensitive = true
}
output "register_command" {
  value = join(" ", [
    "sudo amazon-ssm-agent -register",
    "-code", aws_ssm_activation.this.activation_code,
    "-id", aws_ssm_activation.this.activation_id,
    "-region", var.region,
    "&& sudo systemctl enable --now amazon-ssm-agent"
  ])
  sensitive = true
}
