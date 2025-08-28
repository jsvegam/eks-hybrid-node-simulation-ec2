resource "aws_security_group" "ssm_endpoints" {
  name        = "hybrid-ssm-endpoints-sg"
  description = "Allow 443 from Hybrid VPC to SSM endpoints"
  vpc_id      = var.vpc_id

  ingress {
    description = "443 from Hybrid VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]  # <- CIDR de la VPC híbrida
  }

  egress {
    description = "All egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "hybrid-ssm-endpoints-sg" })
}

locals {
  # TIENEN que estar los 3
  ssm_services = [
    "com.amazonaws.${var.aws_region}.ssm",
    "com.amazonaws.${var.aws_region}.ssmmessages",
    "com.amazonaws.${var.aws_region}.ec2messages",
  ]
}

resource "aws_vpc_endpoint" "ssm_if" {
  for_each            = toset(local.ssm_services)
  vpc_id              = var.vpc_id
  service_name        = each.value
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = var.private_subnets     # <- TODAS tus subredes privadas
  security_group_ids  = [aws_security_group.ssm_endpoints.id]
  tags                = merge(var.tags, { Name = "endpoint-${replace(each.value, ".", "-")}" })
}