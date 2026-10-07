output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_id" {
  description = "ID of the public subnet."
  value       = aws_subnet.public.id
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway."
  value       = aws_internet_gateway.main.id
}

output "route_table_id" {
  description = "ID of the public route table."
  value       = aws_route_table.public.id
}

output "security_group_id" {
  description = "ID of the web security group."
  value       = aws_security_group.web.id
}

output "instance_id" {
  description = "ID of the EC2 instance."
  value       = aws_instance.web.id
}

output "instance_private_ip" {
  description = "Private IP of the EC2 instance."
  value       = aws_instance.web.private_ip
}

output "instance_public_ip" {
  description = "Public IP of the EC2 instance."
  value       = aws_instance.web.public_ip
}

output "web_url" {
  description = "URL of the web server."
  value       = "http://${aws_instance.web.public_ip}"
}

output "s3_bucket_name" {
  description = "Name of the artifacts bucket."
  value       = aws_s3_bucket.artifacts.bucket
}

output "s3_bucket_arn" {
  description = "ARN of the artifacts bucket."
  value       = aws_s3_bucket.artifacts.arn
}

output "deployment_info_object" {
  description = "S3 URI of the deployment info object."
  value       = "s3://${aws_s3_bucket.artifacts.bucket}/${aws_s3_object.deployment_info.key}"
}
