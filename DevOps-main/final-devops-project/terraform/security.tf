# Public entry point: only HTTP/HTTPS from var.ingress_cidrs (the ingress controller / load balancer).
resource "aws_security_group" "ingress" {
  name        = "${local.name}-ingress"
  description = "Public HTTP/HTTPS to the Kubernetes ingress"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${local.name}-ingress-sg" }
}

# trivy:ignore:AVD-AWS-0107 -- intentionally public web entry point (HTTP->HTTPS redirect + TLS on 443)
resource "aws_vpc_security_group_ingress_rule" "ingress_http" {
  for_each          = toset(var.ingress_cidrs)
  security_group_id = aws_security_group.ingress.id
  description       = "HTTP (redirected to HTTPS by the ingress controller)"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = each.value
}

# trivy:ignore:AVD-AWS-0107 -- intentionally public web entry point
resource "aws_vpc_security_group_ingress_rule" "ingress_https" {
  for_each          = toset(var.ingress_cidrs)
  security_group_id = aws_security_group.ingress.id
  description       = "HTTPS"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = each.value
}

# trivy:ignore:AVD-AWS-0104 -- nodes must pull images (GHCR/ECR) and OS updates through the NAT gateway
resource "aws_vpc_security_group_egress_rule" "ingress_all" {
  security_group_id = aws_security_group.ingress.id
  description       = "Outbound to the nodes"
  ip_protocol       = "-1"
  cidr_ipv4         = var.vpc_cidr
}

# Worker nodes: traffic only from the ingress SG and from each other; Kubernetes API only from admin CIDRs.
resource "aws_security_group" "nodes" {
  name        = "${local.name}-nodes"
  description = "Kubernetes worker nodes"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${local.name}-nodes-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "nodes_from_ingress" {
  security_group_id            = aws_security_group.nodes.id
  description                  = "NodePorts / ingress traffic from the public ingress SG"
  ip_protocol                  = "tcp"
  from_port                    = 30000
  to_port                      = 32767
  referenced_security_group_id = aws_security_group.ingress.id
}

resource "aws_vpc_security_group_ingress_rule" "nodes_self" {
  security_group_id            = aws_security_group.nodes.id
  description                  = "Node-to-node (pod network, kubelet)"
  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.nodes.id
}

resource "aws_vpc_security_group_ingress_rule" "nodes_kube_api" {
  for_each          = toset(var.admin_cidrs)
  security_group_id = aws_security_group.nodes.id
  description       = "Kubernetes API (k3s) from admin networks"
  ip_protocol       = "tcp"
  from_port         = 6443
  to_port           = 6443
  cidr_ipv4         = each.value
}

# trivy:ignore:AVD-AWS-0104 -- nodes pull container images and packages from the internet via NAT
resource "aws_vpc_security_group_egress_rule" "nodes_all" {
  security_group_id = aws_security_group.nodes.id
  description       = "Outbound (image pulls, OS updates) via NAT"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
