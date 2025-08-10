output "cluster_id" {
  value = aws_eks_cluster.prtk.id
}

output "node_group_id" {
  value = aws_eks_node_group.prtk.id
}

output "vpc_id" {
  value = aws_vpc.prtk_vpc.id
}

output "subnet_ids" {
  value =  aws_subnet.prtk_subnet[*].id
}
