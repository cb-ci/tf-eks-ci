# create some variables
variable "asg_instance_types" {
  type        = list(string)
  description = "List of EC2 instance machine types to be used in EKS."
}
variable "autoscaling_minimum_size_by_az" {
  type        = number
  description = "Minimum number of EC2 instances to autoscale our EKS cluster on each AZ."
}
variable "autoscaling_maximum_size_by_az" {
  type        = number
  description = "Maximum number of EC2 instances to autoscale our EKS cluster on each AZ."
}
variable "autoscaling_average_cpu" {
  type        = number
  description = "Average CPU threshold to autoscale EKS EC2 instances."
}

locals {
  # create single EKS node group
  eks_node_groups = {
    my_managed_group = {
      min_size       = var.autoscaling_minimum_size_by_az * length(data.aws_availability_zones.available_azs.zone_ids)
      max_size       = var.autoscaling_maximum_size_by_az * length(data.aws_availability_zones.available_azs.zone_ids)
      desired_size   = var.autoscaling_minimum_size_by_az * length(data.aws_availability_zones.available_azs.zone_ids)
      instance_types = var.asg_instance_types
      capacity_type  = "SPOT"
      network_interfaces = [{
        delete_on_termination = true
      }]
    }
  }
}

# create EKS cluster
module "cluster" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 18.20.2"

  cluster_name                    = var.cluster_name
  cluster_version                 = "1.22"
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true
  subnet_ids                      = module.vpc.private_subnets
  vpc_id                          = module.vpc.vpc_id
  eks_managed_node_groups         = local.eks_node_groups

  node_security_group_additional_rules = {
    # https://github.com/kubernetes-sigs/aws-load-balancer-controller/issues/2039#issuecomment-1099032289
    ingress_allow_access_from_control_plane = {
      type                          = "ingress"
      protocol                      = "tcp"
      from_port                     = 9443
      to_port                       = 9443
      source_cluster_security_group = true
    }
  }
}

# create IAM role for AWS Load Balancer Controller, and attach to EKS OIDC
module "eks-ingress-iam" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 4.22.0"

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
module "eks-external-dns-iam" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 4.22.0"

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

# set spot fleet Autoscaling policy
resource "aws_autoscaling_policy" "eks_autoscaling_policy" {
  count = length(local.eks_node_groups)

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
