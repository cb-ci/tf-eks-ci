# create some variables
variable "dns_base_domain" {
  type        = string
  description = "DNS Zone name to be used from EKS Ingress."
}
variable "ingress_gateway_name" {
  type        = string
  description = "Load-balancer service name."
}
variable "ingress_gateway_iam_role" {
  type        = string
  description = "IAM Role Name associated with load-balancer service."
}
variable "ingress_gateway_chart_name" {
  type        = string
  description = "Ingress Gateway Helm chart name."
}
variable "ingress_gateway_chart_repo" {
  type        = string
  description = "Ingress Gateway Helm repository name."
}
variable "ingress_gateway_chart_version" {
  type        = string
  description = "Ingress Gateway Helm chart version."
}
variable "tags" {
  type        = map
  description = "aws tags to set"
}

# get (externally configured) DNS Zone
# ATTENTION: if you don't have a Route53 Zone already, replace this data by a new resource
data "aws_route53_zone" "base_domain" {
  name = var.dns_base_domain
}

# create AWS-issued SSL certificate
resource "aws_acm_certificate" "eks_domain_cert" {
  domain_name               = var.dns_base_domain
  subject_alternative_names = ["*.${var.dns_base_domain}"]
  validation_method         = "DNS"

  tags = merge(
    {
      "Name" = "${var.dns_base_domain}"
    },
    var.tags,
  )
}
resource "aws_route53_record" "eks_domain_cert_validation_dns" {
  for_each = {
    for dvo in aws_acm_certificate.eks_domain_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.base_domain.zone_id
}
resource "aws_acm_certificate_validation" "eks_domain_cert_validation" {
  certificate_arn         = aws_acm_certificate.eks_domain_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.eks_domain_cert_validation_dns : record.fqdn]
}

# deploy Ingress Controller
resource "kubernetes_service_account" "load_balancer_controller" {
  metadata {
    name      = var.ingress_gateway_name
    namespace = "kube-system"

    labels = {
      "app.kubernetes.io/component" = "controller"
      "app.kubernetes.io/name"      = var.ingress_gateway_name
    }

    annotations = {
      "eks.amazonaws.com/role-arn" = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.ingress_gateway_iam_role}"
    }
  }
}
resource "kubernetes_secret" "load_balancer_controller" {
  type                           = "kubernetes.io/service-account-token"
  wait_for_service_account_token = true

  metadata {
    namespace     = kubernetes_service_account.load_balancer_controller.metadata.0.namespace
    generate_name = "${kubernetes_service_account.load_balancer_controller.metadata.0.name}-token"
    annotations   = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.load_balancer_controller.metadata.0.name
    }
  }
}
resource "helm_release" "ingress_gateway" {
  name       = var.ingress_gateway_chart_name
  chart      = var.ingress_gateway_chart_name
  repository = var.ingress_gateway_chart_repo
  version    = var.ingress_gateway_chart_version
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "serviceAccount.name"
    value = kubernetes_service_account.load_balancer_controller.metadata.0.name
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }
}
