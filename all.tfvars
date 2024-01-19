##################### backend.tfvars:
bucket               = "acaternberg-tf-state"
key                  = "infra.json"
#region               = "us-east-1"
workspace_key_prefix = "environment"

##################### base-eks-development.tfvars:
autoscaling_average_cpu = 30

##################### base-network-development.tfvars:
cluster_name            = "acaternberg-tf-02"
name_prefix             = "acaternberg-tf-02"
cluster_version         = "1.27"
main_network_block      = "10.0.0.0/16"
region                  = "us-east-1"
#cluster_azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
cluster_azs             = ["us-east-1a", "us-east-1b"]
subnet_prefix_extension = 4
zone_offset             = 8

##################### config-eks-development.tfvars:
spot_termination_handler_chart_name      = "aws-node-termination-handler"
spot_termination_handler_chart_repo      = "https://aws.github.io/eks-charts"
spot_termination_handler_chart_version   = "0.21.0"
spot_termination_handler_chart_namespace = "kube-system"

##################### config-external-dns-development.tfvars:
external_dns_iam_role      = "external-dns"
external_dns_chart_name    = "external-dns"
external_dns_chart_repo    = "https://kubernetes-sigs.github.io/external-dns/"
external_dns_chart_version = "1.9.0"

external_dns_values = {
  "image.repository"   = "k8s.gcr.io/external-dns/external-dns",
  "image.tag"          = "v0.11.0",
  "logLevel"           = "info",
  "logFormat"          = "json",
  "triggerLoopOnEvent" = "true",
  "interval"           = "5m",
  "policy"             = "sync",
  "sources"            = "{ingress}"
}

##################### config-iam-development.tfvars:
admin_users     = ["acaternberg"]
developer_users = ["acaternberg"]

##################### config-ingress-development.tfvars:
dns_base_domain               = "acaternberg.pscbdemos.com"
ingress_gateway_name          = "aws-load-balancer-controller"
ingress_gateway_iam_role      = "load-balancer-controller"
ingress_gateway_chart_name    = "aws-load-balancer-controller"
ingress_gateway_chart_repo    = "https://aws.github.io/eks-charts"
ingress_gateway_chart_version = "1.4.1"

##################### config-namespaces-development.tfvars:
namespaces = ["sample-apps"]


##################### default tags
tags = {  # Optional. Tags for the resources created. Default set to empty. Shared among all.
  "cb-owner" : "professional-services"
  "cb-user" : "acaternberg"
  "cb-environment" : "acaternberg-tf-02"
}

