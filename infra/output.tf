output "Cluster_ID" {
    description = "The ID of the created cluster"
    value       = aws_eks_cluster.eks_cluster.id
}
output "node_group_name" {
    description = "The name of the created node group"
    value       = aws_eks_node_group.eks_node_group.id
}
output "vpc_id" {
    description = "The ID of the created VPC"
    value       = aws_vpc.vpc_eks.id
}