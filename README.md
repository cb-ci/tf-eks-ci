# Referenced docs
* TF+EKS+ALB: https://medium.com/@nicosingh/build-an-eks-cluster-with-terraform-d35db8005963
* TF+EKS+EFS: https://andrewtarry.com/posts/aws-kubernetes-with-efs/
* OIDC with EKS/AWS 
  * https://medium.com/@forest.ruan/use-openid-connect-to-authenticate-aws-account-in-github-actions-455ff7710597 
  * https://marcincuber.medium.com/amazon-eks-with-oidc-provider-iam-roles-for-kubernetes-services-accounts-59015d15cb0c


# AWS login/SSO

```    
   aws sso login --profile infra-admin-acaternberg-sso #--region us-east-1
 
```
# Prep

```
cp renameme_all.tfvars all.tfvars
```

# Create/Setup  EKS cluster
```
    terraform init 
    terraform plan -out=development.tfplan   -var-file=all.tfvars
    ##some internals 
    #for i in *.tfvars;do printf  "\n##################### $i:\n"  &&  cat $i;done |tee  all.tfvars
    #terraform plan -out=development.tfplan   -var-file==<(cat *.tfvars)
```
OR
```
    terraform plan -out=development.tfplan \
    -var-file=base-network-development.tfvars \
    -var-file=backend.tfvars \
    -var-file=config-iam-development.tfvars \
    -var-file=config-namespaces-development.tfvars \
    -var-file=config-external-dns-development.tfvars \
    -var-file config-eks-development.tfvars \
    -var-file=config-ingress-development.tfvars \
    -var-file=base-eks-development.tfvars
```
Apply the plan 
```
    terraform apply development.tfplan
```

# Install sample app

```
cd helm/sample-app 
helm upgrade  -i  -f helm/config/values-development.yaml sample-app   ./helm
```

# Destroy

```
 terraform destroy  -var-file=all.tfvars
 
 
 terraform destroy  \
-var-file=base-network-development.tfvars \
-var-file=backend.tfvars \
-var-file=config-iam-development.tfvars \
-var-file=config-namespaces-development.tfvars \
-var-file=config-external-dns-development.tfvars \
-var-file config-eks-development.tfvars \
-var-file=config-ingress-development.tfvars \
-var-file=base-eks-development.tfvars

aws iam delete-instance-profile --instance-profile-name managed-node-instance-profile-ci

# NOTE: ALB ingress can not be deleted because of targetgroup, see issues below
kubectl patch ingress <name-of-the-ingress> -n<your-namespace> -p '{"metadata":{"finalizers":[]}}' --type=merge
```

# Issues 

## Default Secret no longer being generated for service account,
Default secret no longer being generated for service account, with Kubernetes 1.24.0 #1724
* https://github.com/hashicorp/terraform-provider-kubernetes/issues/1724 

## EntityAlreadyExists
```
╷
│ Error: creating IAM Role (managed-node-role): EntityAlreadyExists: Role with name managed-node-role already exists.
│ 	status code: 409, request id: 6239b687-55c5-4466-be30-4c859f3a111a
│
│   with module.base.aws_iam_role.managed_ng,
│   on base/eks.tf line 141, in resource "aws_iam_role" "managed_ng":
│  141: resource "aws_iam_role" "managed_ng" {
│
╵
```

--> delete role manually, was orphan 
```
    aws iam delete-instance-profile --instance-profile-name managed-node-instance-profile-ci
```

## │ Error: deleting EC2 Subnet (subnet-05aa264ad83287dc5): DependencyViolation: The subnet 'subnet-05aa264ad83287dc5' has dependencies and cannot be deleted.

## OIDC Provider LimitExceeded 
```
╷
│ Error: creating IAM OIDC Provider: LimitExceeded: Cannot exceed quota for OpenIdConnectProvidersPerAccount: 100
│ 	status code: 409, request id: 7b194b7a-8e2c-4873-a944-cfb20a549962
│
│   with module.base.module.cluster.aws_iam_openid_connect_provider.oidc_provider[0],
│   on .terraform/modules/base.cluster/main.tf line 230, in resource "aws_iam_openid_connect_provider" "oidc_provider":
│  230: resource "aws_iam_openid_connect_provider" "oidc_provider" {
```

see https://repost.aws/knowledge-center/eks-troubleshoot-oidc-and-irsa
> aws eks describe-cluster --name acaternberg-tf --query "cluster.identity.oidc.issuer" --output text --region us-east-1 
https://oidc.eks.us-east-1.amazonaws.com/id/12345678901234567890

List the IAM OIDC providers in your account. Replace 12345678901234567890 (include < >) with the value returned from the previous command:
> aws iam list-open-id-connect-providers | grep 12345678901234567890

see https://cloudbees.slack.com/archives/GBX5K1DPF/p1687949985600689 

WORKAROUND: DELETE ORPHAN OICD PROVIDER MANUALLY

## How to delete a Kubernetes namespace stuck at Terminating Status
see 
* https://dev.to/jmarhee/how-to-delete-a-kubernetes-namespace-stuck-at-terminating-status-53o5
* https://www.ibm.com/docs/en/cloud-private/3.2.0?topic=console-namespace-is-stuck-in-terminating-state
> kubectl api-resources --verbs=list --namespaced -o name | xargs -n 1 kubectl get --show-kind --ignore-not-found 

## How to list all aws resources by tag
see 
* https://stackoverflow.com/questions/52594359/aws-cli-search-resource-by-tags
> aws resourcegroupstaggingapi get-resources --tag-filters "Key=cb:user,Values=acaternberg" --region us-east-1  | grep ResourceARN
 
## Don`t use  default Network ACL
TODO
see https://cloudbees.slack.com/archives/D055L01ACT1/p1683818237758859

## ALB/ Ingress can not be deleted by TF

see
* https://github.com/kubernetes-sigs/aws-load-balancer-controller/issues/1629
* https://github.com/kubernetes-sigs/aws-load-balancer-controller/issues/1629#issuecomment-731011683
> kubectl patch ingress <name-of-the-ingress> -n<your-namespace> -p '{"metadata":{"finalizers":[]}}' --type=merge
> kubectl patch ingress sample-app-ingress-rules  -p '{"metadata":{"finalizers":[]}}' --type=merge
> kctl get TargetGroupBinding k8s-sampleap-sampleap-ae2448355d -n sample-apps -o yaml
> kubectl patch TargetGroupBinding k8s-sampleap-sampleap-ae2448355d   -p '{"metadata":{"finalizers":[]}}' --type=merge

There is an TF issue in the deleted targetGroupBinding (see below), therefore we must remove the metadata.finalizer 

TF ALB creation and deletion phases are: 

while creation.:

* created securityGroup - Will create SG for ALB
* authorized securityGroup ingress - Will add rules to the ALB SG
* created targetGroup - Will create targetGroup to be assigned to Loadbalancer.
* created loadBalancer - Will create a LoadBalancer.
* created listener - the port on which loadbalancer will be listening on.
* created listener rule - Rules to forward to the targets (target groups in our case)
* created targetGroupBinding - Will create a custom resource which maintains target groups and assignment/removal of ELB SG rule from worker node security group inbound rule.
* authorized securityGroup ingress - adding ELB SG as an inbound rule to the worker node’s SG
* registered targets - All the concerned targets are registered.
  
while Deleting:

* deleting loadBalancer
* deleted loadBalancer
* deleting targetGroupBinding
* deRegistering targets
  #####This step is missing in logs###### - revoking securityGroup ingress
* deleted targetGroupBinding
* deleting targetGroup
* deleted targetGroup
* deleting securityGroup
 