terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# Peering entre VPC de EKS y VPC híbrida
resource "aws_vpc_peering_connection" "eks_hybrid" {
  vpc_id      = var.eks_vpc_id
  peer_vpc_id = var.hybrid_vpc_id
  auto_accept = true

  tags = merge(var.tags, {
    Name = "eks-hybrid-peering"
  })
}

# Construimos mapas con claves estáticas (índices) para que for_each tenga keys conocidas en plan
locals {
  eks_private_route_map    = { for idx, rt in tolist(var.eks_private_route_ids) : idx => rt }
  eks_public_route_map     = { for idx, rt in tolist(var.eks_public_route_ids) : idx => rt }
  hybrid_private_route_map = { for idx, rt in tolist(var.hybrid_private_route_ids) : idx => rt }
  hybrid_public_route_map  = { for idx, rt in tolist(var.hybrid_public_route_ids) : idx => rt }
}

# Rutas EKS -> Hybrid (en tablas PRIVADAS de la VPC EKS)
resource "aws_route" "eks_to_hybrid_private" {
  for_each                  = local.eks_private_route_map
  route_table_id            = each.value
  destination_cidr_block    = var.hybrid_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.eks_hybrid.id

  depends_on = [aws_vpc_peering_connection.eks_hybrid]
}

# Rutas EKS -> Hybrid (en tablas PÚBLICAS de la VPC EKS)
resource "aws_route" "eks_to_hybrid_public" {
  for_each                  = local.eks_public_route_map
  route_table_id            = each.value
  destination_cidr_block    = var.hybrid_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.eks_hybrid.id

  depends_on = [aws_vpc_peering_connection.eks_hybrid]
}

# Rutas Hybrid -> EKS (en tablas PRIVADAS de la VPC híbrida)
resource "aws_route" "hybrid_to_eks_private" {
  for_each                  = local.hybrid_private_route_map
  route_table_id            = each.value
  destination_cidr_block    = var.eks_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.eks_hybrid.id

  depends_on = [aws_vpc_peering_connection.eks_hybrid]
}

# Rutas Hybrid -> EKS (en tablas PÚBLICAS de la VPC híbrida)
resource "aws_route" "hybrid_to_eks_public" {
  for_each                  = local.hybrid_public_route_map
  route_table_id            = each.value
  destination_cidr_block    = var.eks_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.eks_hybrid.id

  depends_on = [aws_vpc_peering_connection.eks_hybrid]
}
