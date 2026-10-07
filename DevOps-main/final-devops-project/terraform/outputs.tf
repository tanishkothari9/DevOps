output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs (one per AZ)"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs (one per AZ)"
  value       = aws_subnet.private[*].id
}

output "availability_zones" {
  description = "AZs used by the subnets"
  value       = local.azs
}

output "nat_gateway_id" {
  description = "NAT gateway ID (null when disabled)"
  value       = one(aws_nat_gateway.main[*].id)
}

output "security_group_ids" {
  description = "Ingress and node security groups"
  value = {
    ingress = aws_security_group.ingress.id
    nodes   = aws_security_group.nodes.id
  }
}

output "artifacts_bucket" {
  description = "S3 bucket for CI artefacts"
  value       = aws_s3_bucket.artifacts.bucket
}

output "ecr_repository_urls" {
  description = "ECR repositories (empty when enable_ecr = false)"
  value       = { for k, r in aws_ecr_repository.app : k => r.repository_url }
}

output "k3s_node" {
  description = "Single-node k3s host (null when enable_k3s_node = false)"
  value = var.enable_k3s_node ? {
    instance_id = aws_instance.k3s[0].id
    public_ip   = aws_instance.k3s[0].public_ip
    private_ip  = aws_instance.k3s[0].private_ip
  } : null
}

output "eks_cluster" {
  description = "EKS cluster name/endpoint and the kubeconfig command (null when enable_eks = false)"
  value = var.enable_eks ? {
    name               = aws_eks_cluster.main[0].name
    endpoint           = aws_eks_cluster.main[0].endpoint
    kubeconfig_command = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.main[0].name}"
  } : null
}
