#To add EFS we first need to add a security group:
resource "aws_security_group" "efs" {
  name        = "${var.cluster_name} efs"
  description = "Allow traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "nfs"
    from_port   = 2049
    to_port     = 2049
    protocol    = "TCP"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }
}


# EFS storage class for persistent volumes
resource "kubernetes_storage_class_v1" "efs" {
  metadata {
    name = "efs"
  }

  storage_provisioner = "efs.csi.aws.com"
  parameters          = {
    provisioningMode = "efs-ap" # Dynamic provisioning
    fileSystemId     = module.efs.id
    directoryPerms   = "700"
  }

  mount_options = [
    "iam"
  ]

  depends_on = [
    module.cluster
  ]
}

resource "aws_iam_policy" "node_efs_policy" {
  name        = "eks_node_efs-${var.cluster_name}"
  path        = "/"
  description = "Policy for EKS nodes to use EFS"

  policy = jsonencode({
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "elasticfilesystem:DescribeAccessPoints",
          "elasticfilesystem:DescribeFileSystems",
          "elasticfilesystem:DescribeMountTargets",
          "ec2:DescribeAvailabilityZones"
        ],
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "elasticfilesystem:CreateAccessPoint"
        ],
        "Resource" : "*",
        "Condition" : {
          "StringLike" : {
            "aws:RequestTag/efs.csi.aws.com/cluster" : "true"
          }
        }
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "elasticfilesystem:TagResource"
        ],
        "Resource" : "*",
        "Condition" : {
          "StringLike" : {
            "aws:ResourceTag/efs.csi.aws.com/cluster" : "true"
          }
        }
      },
      {
        "Effect" : "Allow",
        "Action" : "elasticfilesystem:DeleteAccessPoint",
        "Resource" : "*",
        "Condition" : {
          "StringEquals" : {
            "aws:ResourceTag/efs.csi.aws.com/cluster" : "true"
          }
        }
      }
    ],
    "Version" : "2012-10-17"
  }
  )
}

#resource "aws_efs_file_system" "kube" {
#  creation_token = "eks-efs"
#}

##see https://stackoverflow.com/questions/48817967/aws-terraform-filter-specific-subnets-by-matching-substring-in-tag-name/48818168#48818168
#resource "aws_efs_mount_target" "mount" {
#  depends_on      = [module.vpc]
#  ##subnet_id       = each.value
#  file_system_id  = aws_efs_file_system.kube.id
#  subnet_id       = each.key
#  for_each        = toset(data.aws_subnets.private_subnet.ids)
#  security_groups = [aws_security_group.efs.id]
#}


module "efs" {
  source  = "terraform-aws-modules/efs/aws"
  version = "~> 1.0"

  creation_token = var.cluster_name
  name           = var.cluster_name

  # Mount targets / security group
  mount_targets = {
  for k, v in zipmap(var.cluster_azs, module.vpc.private_subnets) : k => { subnet_id = v }
  }
  security_group_description = "${var.cluster_name} EFS security group"
  security_group_vpc_id      = module.vpc.vpc_id
  security_group_rules       = {
    vpc = {
      # relying on the defaults provdied for EFS/NFS (2049/TCP + ingress)
      description = "${var.cluster_name} NFS ingress from VPC private subnets"
      cidr_blocks = module.vpc.private_subnets_cidr_blocks
    }
  }

  //tags = local.tags
}