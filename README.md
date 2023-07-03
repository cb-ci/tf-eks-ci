* https://medium.com/@nicosingh/build-an-eks-cluster-with-terraform-d35db8005963
* https://cloudbees.slack.com/archives/D055L01ACT1/p1683818237758859 
* OIDC with EKS/AWS 
  * https://medium.com/@forest.ruan/use-openid-connect-to-authenticate-aws-account-in-github-actions-455ff7710597 
  * https://marcincuber.medium.com/amazon-eks-with-oidc-provider-iam-roles-for-kubernetes-services-accounts-59015d15cb0c

# AWS login/SSO

```    aws sso login --profile infra-admin-acaternberg-sso
 
```

# Create/Setup  EKS cluster
```
    terraform init 
    terraform plan -out=development.tfplan   -var-file==<(cat *.tfvars)
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

```

# Issues 

## 1 secret no longer being generated for service account,
Default secret no longer being generated for service account, with Kubernetes 1.24.0 #1724
* https://github.com/hashicorp/terraform-provider-kubernetes/issues/1724 

## 2 EntityAlreadyExists
╷
│ Error: creating IAM Role (managed-node-role): EntityAlreadyExists: Role with name managed-node-role already exists.
│ 	status code: 409, request id: 6239b687-55c5-4466-be30-4c859f3a111a
│
│   with module.base.aws_iam_role.managed_ng,
│   on base/eks.tf line 141, in resource "aws_iam_role" "managed_ng":
│  141: resource "aws_iam_role" "managed_ng" {
│
╵

--> delete role manually, was orphan 
```
    aws iam delete-instance-profile --instance-profile-name managed-node-instance-profile-ci
```
## 3 OIDC

╷
│ Error: creating IAM OIDC Provider: LimitExceeded: Cannot exceed quota for OpenIdConnectProvidersPerAccount: 100
│ 	status code: 409, request id: 7b194b7a-8e2c-4873-a944-cfb20a549962
│
│   with module.base.module.cluster.aws_iam_openid_connect_provider.oidc_provider[0],
│   on .terraform/modules/base.cluster/main.tf line 230, in resource "aws_iam_openid_connect_provider" "oidc_provider":
│  230: resource "aws_iam_openid_connect_provider" "oidc_provider" {

https://repost.aws/knowledge-center/eks-troubleshoot-oidc-and-irsa

aws eks describe-cluster --name acaternberg-tf --query "cluster.identity.oidc.issuer" --output text --region us-east-1 
https://oidc.eks.us-east-1.amazonaws.com/id/786E622BE77FCFA93C7D8325E763C3B5

List the IAM OIDC providers in your account. Replace 786E622BE77FCFA93C7D8325E763C3B5 (include < >) with the value returned from the previous command:

aws iam list-open-id-connect-providers | grep 786E622BE77FCFA93C7D8325E763C3B5

see https://cloudbees.slack.com/archives/GBX5K1DPF/p1687949985600689 




# Get the LB previously created and set DNS

## Get the (first) load balancer (at this point they're likely both the same)
LB="$(kubectl get ingress -o json | jq -r '.items[0].status.loadBalancer.ingress[0].hostname')"

sed -i "" -e 's/@@NEW_FQDN@@/'$NEW_FQDN'/' zone-records.json
sed -i "" -e 's/@@LOAD_BALANCER_FQDN@@/'$LB'/' zone-records.json

## Create CNAME
aws route53 change-resource-record-sets \
--hosted-zone-id $HOSTED_ZONE_ID \
--change-batch file://zone-records.json

## Make sure you can dig it
dig +noall +answer $NEW_FQDN