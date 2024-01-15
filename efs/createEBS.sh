#! /bin/bash

#sse https://docs.aws.amazon.com/de_de/eks/latest/userguide/efs-csi.html
#https://github.com/kubernetes-sigs/aws-efs-csi-driver/tree/master/examples/kubernetes/dynamic_provisioning


#CLUSTER=acaternberg-ci
CLUSTER=acaternberg-tf-02

export AWS_REGION=us-east-1
#export AWS_PROFILE=profile infra-admin-acaternberg-sso
#see https://us-east-1.console.aws.amazon.com/billing/home?region=us-east-1#/account
aws_account_id=324005994172
PREFIX=$CLUSTER
TAGS="Key=cb:user,Value=acaternberg \
 Key=cb:owner,Value=professional-services \
 Key=cb:environment,Value=ps-dev \
 Key=ps-genetes/cluster  Value=$CLUSTER \
 Key=ps-genetes/created  Value=manual"


# Get the OIDC ID from the EKS Cluster
oidc_id=$(aws eks describe-cluster --name $CLUSTER --query "cluster.identity.oidc.issuer" --region $AWS_REGION --output text |sed "s#^.*/id/##g")
echo "OIDC $oidc_id"
#aws eks describe-cluster --name "$CLUSTER" --query "cluster.identity.oidc.issuer" --output text


eksctl create iamserviceaccount \
    --name ebs-csi-controller-sa \
    --namespace kube-system \
    --cluster $CLUSTER \
    --role-name ${PREFIX}-AmazonEKS_EBS_CSI_DriverRole \
    --role-only \
    --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
    --approve




## Install EFS CSI driver
# see https://docs.aws.amazon.com/eks/latest/userguide/efs-csi.html
# Create an IAM policy and role
# Create an IAM policy and assign it to an IAM role.
# The policy will allow the Amazon EFS driver to interact with your file system.

#curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-efs-csi-driver/master/docs/iam-policy-example.json

#echo "aws iam delete-policy  --policy-name ${PREFIX}-AmazonEKS_EFS_CSI_Driver_Policy"
#aws iam delete-policy  --policy-name ${PREFIX}-AmazonEKS_EFS_CSI_Driver_Policy
echo "aws iam create-policy \
          --policy-name ${PREFIX}-AmazonEKS_EFS_CSI_Driver_Policy \
          --policy-document file://iam-policy-example.json \
          --tags $TAGS"
aws iam create-policy \
    --policy-name ${PREFIX}-AmazonEKS_EFS_CSI_Driver_Policy \
    --policy-document file://iam-policy-example.json



# Now replace

# Create IAM EFS Role
#aws iam delete-role --role-name ${PREFIX}-AmazonEKS_EFS_CSI_DriverRole
aws iam create-role \
  --role-name ${PREFIX}-AmazonEKS_EFS_CSI_DriverRole \
  --assume-role-policy-document file://"aws-efs-csi-driver-trust-policy.json"

aws iam attach-role-policy \
  --policy-arn arn:aws:iam::${aws_account_id}:policy/${PREFIX}-AmazonEKS_EFS_CSI_Driver_Policy \
  --role-name ${PREFIX}-AmazonEKS_EFS_CSI_DriverRole

vpc_id=$(aws eks describe-cluster \
    --name $CLUSTER \
    --query "cluster.resourcesVpcConfig.vpcId" \
    --output text)

cidr_range=$(aws ec2 describe-vpcs \
    --vpc-ids $vpc_id \
    --query "Vpcs[].CidrBlock" \
    --output text)


#aws ec2 delete-security-group     --group-name ${PREFIX}-EfsSecurityGroup
security_group_id=$(aws ec2 create-security-group \
    --group-name ${PREFIX}-EfsSecurityGroup \
    --description "${PREFIX} EFS security group" \
    --vpc-id $vpc_id \
    --output text)
#aws ec2 describe-security-groups --region us-east-1 --query "SecurityGroups[].GroupId" --filter Name=vpc-id,Values=$vpcid

aws ec2 authorize-security-group-ingress \
    --group-id $security_group_id \
    --protocol tcp \
    --port 2049 \
    --cidr $cidr_range



aws ec2 describe-subnets \
     --filters "Name=vpc-id,Values=$vpc_id" \
     --query 'Subnets[*].{SubnetId: SubnetId,AvailabilityZone: AvailabilityZone,CidrBlock: CidrBlock}' \
     --output table

#Here we need the Clusters VPC private subnet ids
aws efs create-mount-target \
    --file-system-id $file_system_id \
    --subnet-id subnet-027ec08eda4ba3a47 \
    --security-groups $security_group_id

#aws efs create-mount-target \
#    --file-system-id $file_system_id \
#    --subnet-id subnet-05aa264ad83287dc5 \
#    --security-groups $security_group_id

#aws efs create-mount-target \
#    --file-system-id $file_system_id \
#    --subnet-id subnet-039f27466224d46d7 \
#    --security-groups $security_group_id

# see for example https://github.com/kubernetes-sigs/aws-efs-csi-driver/blob/master/examples/kubernetes/encryption_in_transit/specs/pv.yaml