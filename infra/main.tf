provider "aws" {
    region = "ap-south-1"
}

#creating VPC
resource "aws_vpc" "vpc_eks" {
    cidr_block = "10.0.0.0/16"
    tags = {
        Name = "vpc_eks"
    }
}
#subnets
resource "aws_subnet" "subnet_eks" {
    count = 2
    vpc_id = aws_vpc.vpc_eks.id
    cidr_block = cidrsubnet(aws_vpc.vpc_eks.cidr_block, 8, count.index)
    availability_zone = element (["ap-south-1a","ap-south-1b"], count.index)
    map_public_ip_on_launch = true
    tags = {
        Name = "subnet_eks_${count.index}"
    }

}
#internet gateway
resource "aws_internet_gateway" "igw_eks" {
    vpc_id = aws_vpc.vpc_eks.id
    tags = {
        Name = "igw_eks"
    }
}
#route table
resource "aws_route_table" "rt_eks" {
    vpc_id = aws_vpc.vpc_eks.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw_eks.id
    }
    tags = {
        Name = "rt_eks"
    }
}
#route table association
resource "aws_route_table_association" "rtba_eks" {
    count = 2
    subnet_id = aws_subnet.subnet_eks[count.index].id
    route_table_id = aws_route_table.rt_eks.id
    
}
#security group-cluster
resource "aws_security_group" "eks_cluster_sg" {
    vpc_id = aws_vpc.vpc_eks.id
    egress {
        from_port = 0
        to_port = 0
        protocol = -1
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Name = "eks_cluster_sg"
    }
}
#security group-node
resource "aws_security_group" "eks_node_sg" {
    vpc_id = aws_vpc.vpc_eks.id
    ingress {
        from_port = 0
        to_port = 0
        protocol = -1
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = -1
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Name = "eks_node_sg"
    }
}
#iam roles and policies-cluster
resource "aws_iam_role" "eks_iam_cluster_role" {
    name = "eks_iam_cluster_role"
    assume_role_policy = <<EOF
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": {
            "Service": "eks.amazonaws.com"
          },
          "Action": "sts:AssumeRole"
        }
      ]
    }
    EOF
}
resource "aws_iam_role_policy_attachment" "eks_cluster_role_policy" {
    role = aws_iam_role.eks_iam_cluster_role.name
    policy_arn = "are:aws:iam::aws/policy/AmazonEKSClusterPolicy"
}
#iam roles and policies-node
resource "aws_iam_role" "eks_iam_node_role" {
    name = "eks_iam_node_role"
    assume_role_policy = <<EOF
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": {
            "Service": "ec2.amazonaws.com"
          },
          "Action": "sts:AssumeRole"
        }
      ]
    }
    EOF
}
resource "aws_iam_role_policy_attachment" "eks_node_role_policy" {
    role = aws_iam_role.eks_iam_node_role.name
    policy_arn = "arn:aws:iam::aws/policy/AmazonEKSWorkerNodePolicy"
}
resource  "aws_iam_role_policy_attachment" "eks_node_group_cni_policy" {
    role = aws_iam_role.eks_node_role.name
    policy_arn = "arn:aws:iam::aws/policy/AmazonEKS_CNI_Policy"
}
resource  "aws_iam_role_policy_attachment" "eks_node_group_registry_policy" {
    role = aws_iam_role.eks_node_role.name
    policy_arn = "arn:aws:iam::aws/policy/AmazonEC2ContainerRegistryReadOnly"
}
#eks cluster
resource "aws_eks_cluster" "eks_cluster" {
    name = "eks_cluster"
    role_arn = aws_iam_role.eks_iam_cluster_role.arn
    vpc_config {
        subnet_ids = aws_subnet.subnet_eks[*].id
        security_group_ids = [aws_security_group.eks_cluster_sg.id]
    }
}
#eks node group
resource "aws_eks_node_group" "eks_cluster" {
    cluster_name = aws_eks_cluster.eks_cluster.name
    node_group_name = "eks_node_group"
    node_role_arn = aws_iam_role.eks_iam_node_role.arn
    subnet_ids = aws_subnet.subnet_eks[*].id
    scaling_config {
        desired_size = 3
        max_size = 5
        min_size = 3
    }

    instance_types = ["m7i-flex.large"]
    remote_access {
        ec2_ssh_key = var.ec2_ssh_key_name
        source_security_group_ids = [aws_security_group.eks_node_sg.id]
    }
}

