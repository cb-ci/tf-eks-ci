locals {
  kubeconfig_file      = "kubeconfig-${var.cluster_name}.yaml"
  kubeconfig_file_path = abspath("${path.root}/${local.kubeconfig_file}")
}
# create EKS cluster
module "base" {
  source = "./base/"
  cluster_version         = var.cluster_version
  cluster_name            = var.cluster_name
  name_prefix             = var.name_prefix
  main_network_block      = var.main_network_block
  cluster_azs             = var.cluster_azs
  subnet_prefix_extension = var.subnet_prefix_extension
  tags                    = var.tags
  zone_offset             = var.zone_offset
  #eks_managed_node_groups = var.eks_managed_node_groups
  autoscaling_average_cpu = var.autoscaling_average_cpu
}

# provision EKS cluster
module "config" {
  source = "./config/"

  cluster_name                             = var.cluster_name
  cluster_endpoint                         = module.base.cluster_endpoint
  cluster_certificate_authority_data       = module.base.cluster_certificate_authority_data
  spot_termination_handler_chart_name      = var.spot_termination_handler_chart_name
  spot_termination_handler_chart_repo      = var.spot_termination_handler_chart_repo
  spot_termination_handler_chart_version   = var.spot_termination_handler_chart_version
  spot_termination_handler_chart_namespace = var.spot_termination_handler_chart_namespace
  dns_base_domain                          = var.dns_base_domain
  ingress_gateway_name                     = var.ingress_gateway_name
  ingress_gateway_iam_role                 = var.ingress_gateway_iam_role
  ingress_gateway_chart_name               = var.ingress_gateway_chart_name
  ingress_gateway_chart_repo               = var.ingress_gateway_chart_repo
  ingress_gateway_chart_version            = var.ingress_gateway_chart_version
  external_dns_iam_role                    = var.external_dns_iam_role
  external_dns_chart_name                  = var.external_dns_chart_name
  external_dns_chart_repo                  = var.external_dns_chart_repo
  external_dns_chart_version               = var.external_dns_chart_version
  external_dns_values                      = var.external_dns_values
  namespaces                               = var.namespaces
  name_prefix                              = var.name_prefix
  admin_users                              = var.admin_users
  developer_users                          = var.developer_users
  tags                                     = var.tags
}

#---------------------------------------------------------------
# Generating kubeconfig file
#---------------------------------------------------------------

#https://www.bitslovers.com/terraform-null-resource/
resource "null_resource" "update_kubeconfig" {
  depends_on = [module.base]

  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --name ${var.cluster_name} --kubeconfig ${local.kubeconfig_file} --region ${var.region}"
  }
}
