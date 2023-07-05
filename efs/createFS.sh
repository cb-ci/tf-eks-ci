#! /bin/bash

#see https://docs.aws.amazon.com/efs/latest/ug/creating-using-create-fs.html#creating-using-fs-part1-cli
CLUSTER=acaternberg-tf-01
export AWS_REGION=us-east-1

curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-efs-csi-driver/master/docs/iam-policy-example.json
aws iam create-policy \
    --policy-name AcaternbergAmazonEKS_EFS_CSI_Driver_Policy \
    --policy-document file://iam-policy-example.json

aws iam create-role \
  --role-name ACaternbergAmazonEKS_EFS_CSI_DriverRole \
  --assume-role-policy-document file://"aws-ebs-csi-driver-trust-policy.json"

aws iam attach-role-policy \
  --policy-arn arn:aws:iam::324005994172:policy/AcaternbergAmazonEKS_EFS_CSI_Driver_Policy \
  --role-name ACaternbergAmazonEKS_EFS_CSI_DriverRole

vpc_id=$(aws eks describe-cluster \
    --name $CLUSTER \
    --query "cluster.resourcesVpcConfig.vpcId" \
    --output text)

cidr_range=$(aws ec2 describe-vpcs \
    --vpc-ids $vpc_id \
    --query "Vpcs[].CidrBlock" \
    --output text)



security_group_id=$(aws ec2 create-security-group \
    --group-name AcaternbergEfsSecurityGroup \
    --description "My EFS security group" \
    --vpc-id $vpc_id \
    --output text)

aws ec2 authorize-security-group-ingress \
    --group-id $security_group_id \
    --protocol tcp \
    --port 2049 \
    --cidr $cidr_range

#file_system_id=$(aws efs create-file-system \
#    --performance-mode generalPurpose \
#    --throughput-mode bursting \
#    --query 'FileSystemId' \
#    --tags Key=Name,Value="AcaternbergTestFileSystem" Key=developer,Value=acaternberg \
#    --output text)

aws ec2 describe-subnets \
     --filters "Name=vpc-id,Values=$vpc_id" \
     --query 'Subnets[*].{SubnetId: SubnetId,AvailabilityZone: AvailabilityZone,CidrBlock: CidrBlock}' \
     --output table

#Here we need the Clusters VPC private subnet ids
#aws efs create-mount-target \
#    --file-system-id $file_system_id \
#    --subnet-id subnet-027ec08eda4ba3a47 \
#    --security-groups $security_group_id

#aws efs create-mount-target \
#    --file-system-id $file_system_id \
#    --subnet-id subnet-05aa264ad83287dc5 \
#    --security-groups $security_group_id

#aws efs create-mount-target \
#    --file-system-id $file_system_id \
#    --subnet-id subnet-039f27466224d46d7 \
#    --security-groups $security_group_id

