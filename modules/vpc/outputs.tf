output "vpc_id" {
  value       = aws_vpc.main.id
  description = "The ID of the VPC."
}

output "private_subnet_ids" {
  value       = aws_subnet.private[*].id
  description = "List of private subnet IDs for Kubernetes nodes."
  depends_on = [
    aws_route_table_association.private,
    aws_nat_gateway.nat,
  ]
}

output "public_subnet_ids" {
  value       = aws_subnet.public[*].id
  description = "List of public subnet IDs for load balancers."
  depends_on = [
    aws_route_table_association.public,
    aws_internet_gateway.igw,
  ]
}