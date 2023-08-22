# create some variables
#variable "eks_managed_node_groups" {
#  type        = map(any)
#  description = "Map of EKS managed node group definitions to create"
#}
variable "autoscaling_average_cpu" {
  type        = number
  description = "Average CPU threshold to autoscale EKS EC2 instances."
}


locals {
  s3_backup_name            = "${var.cluster_name}-backups"
  s3_artifacts_name         = "${var.cluster_name}-artifacts"
  s3_bucket_list            = [local.s3_backup_name, local.s3_artifacts_name]
  cidr_blocks_k8s_whitelist = ["0.0.0.0/0"]
}


# create EKS cluster
module "cluster" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.13.1"

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }
  cluster_name                         = var.cluster_name
  cluster_version                      = var.cluster_version
  cluster_endpoint_private_access      = true
  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = local.cidr_blocks_k8s_whitelist
  cluster_tags                         = var.tags
  subnet_ids                           = module.vpc.private_subnets
  vpc_id                               = module.vpc.vpc_id
  #eks_managed_node_groups         = var.eks_managed_node_groups
  eks_managed_node_groups              = {
    # Default node group - as provided by AWS EKS
    ci-mg_k8sApps = {
      node_group_name = "acaternberg-ci-managed-k8s-apps"
      #https://aws.amazon.com/ec2/instance-types/
      instance_types  = ["t3.large"]
      min_size        = 1
      max_size        = 6
      desired_size    = 1
    },
    ci-controllers = {
      node_group_name = "acaternberg-ci-controllers"
      min_size        = 1
      max_size        = 3
      desired_size    = 1
      instance_types  = ["t3.large"]
    },
    ci-agents = {
      node_group_name = "acaternberg-ci-agents"
      min_size        = 1
      max_size        = 3
      desired_size    = 1
      instance_types  = ["t3.large"]
    }
  }
  eks_managed_node_group_defaults = {
    instance_types         = ["t3.large"]
    vpc_security_group_ids = [module.vpc.default_vpc_default_security_group_id]
  }
  node_security_group_additional_rules = {
    # allow connections from ALB security group
    ingress_allow_access_from_alb_sg = {
      type                     = "ingress"
      protocol                 = "-1"
      from_port                = 0
      to_port                  = 0
      source_security_group_id = aws_security_group.alb.id
    }
    # allow connections from EKS to the internet
    egress_all = {
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
    # allow connections from EKS to EKS (internal calls)
    ingress_self_all = {
      protocol  = "-1"
      from_port = 0
      to_port   = 0
      type      = "ingress"
      self      = true
    }
  }
}
output "cluster_endpoint" {
  value = module.cluster.cluster_endpoint
}
output "cluster_certificate_authority_data" {
  value = module.cluster.cluster_certificate_authority_data
}

output "cluster_name" {
  value = module.cluster.cluster_name
}

# create IAM role for AWS Load Balancer Controller, and attach to EKS OIDC
module "eks_ingress_iam" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.17.1"

  role_name                              = "load-balancer-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = module.cluster.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

# create IAM role for External DNS, and attach to EKS OIDC
module "eks_external_dns_iam" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.17.1"

  role_name                     = "external-dns"
  attach_external_dns_policy    = true
  external_dns_hosted_zone_arns = ["arn:aws:route53:::hostedzone/*"]

  oidc_providers = {
    ex = {
      provider_arn               = module.cluster.oidc_provider_arn
      namespace_service_accounts = ["kube-system:external-dns"]
    }
  }
}


#---------------------------------------------------------------
# Custom IAM roles for Node Group Cloudbees Apps
#---------------------------------------------------------------

data "aws_iam_policy_document" "managed_ng_assume_role_policy" {
  statement {
    sid = "EKSWorkerAssumeRole"

    actions = [
      "sts:AssumeRole",
      "sts:AssumeRoleWithWebIdentity",
    ]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "managed_ng" {
  name                  = "managed-node-role-${var.cluster_name}"
  description           = "EKS Managed Node group IAM Role"
  assume_role_policy    = data.aws_iam_policy_document.managed_ng_assume_role_policy.json
  path                  = "/"
  force_detach_policies = true
  managed_policy_arns   = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]
  inline_policy {
    name   = "CloudBees_CI"
    policy = jsonencode(
      {
        "Version" : "2012-10-17",
        "Statement" : [
          {
            "Sid" : "CBCIBackupPolicy1",
            "Effect" : "Allow",
            "Action" : [
              "s3:PutObject",
              "s3:GetObject",
              "s3:DeleteObject"
            ],
            "Resource" : "arn:aws:s3:::${local.s3_backup_name}/cbci/*"
          },
          {
            "Sid" : "CBCIBackupPolicy2",
            "Effect" : "Allow",
            "Action" : "s3:ListBucket",
            "Resource" : "arn:aws:s3:::${local.s3_backup_name}"
          },
        ]
      }
    )
  }
  // we use aws provider default tags
  //tags = var.tags
}

resource "aws_iam_instance_profile" "managed_ng" {
  name = "managed-node-instance-profile-ci-${var.cluster_name}"
  role = aws_iam_role.managed_ng.name
  path = "/"

  lifecycle {
    create_before_destroy = false
  }

  //tags = var.tags
}


# set spot fleet Autoscaling policy
resource "aws_autoscaling_policy" "eks_autoscaling_policy" {
  count = length(module.cluster.eks_managed_node_groups)

  name                   = "${module.cluster.eks_managed_node_groups_autoscaling_group_names[count.index]}-autoscaling-policy"
  autoscaling_group_name = module.cluster.eks_managed_node_groups_autoscaling_group_names[count.index]
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.autoscaling_average_cpu
  }
}
