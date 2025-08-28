output "vpc_peering_connection_id" {
  value       = aws_vpc_peering_connection.eks_hybrid.id
  description = "ID del peering EKS↔Hybrid"
}
