# modules/hybrid-node/outputs.tf

output "security_group_id" {
  description = "Hybrid node SG ID"
  value       = aws_security_group.hybrid_node.id
}

output "instance_id" {
  description = "ID de la instancia híbrida"
  value       = aws_instance.this.id
}

output "private_ip" {
  description = "IP privada del nodo híbrido"
  value       = aws_instance.this.private_ip
}
