#! /bin/bash


#https://docs.aws.amazon.com/de_de/eks/latest/userguide/efs-csi.html
#https://github.com/kubernetes-sigs/aws-efs-csi-driver/tree/master/examples/kubernetes/dynamic_provisioning
#THIS: https://github.com/kubernetes-sigs/aws-efs-csi-driver/blob/master/docs/efs-create-filesystem.md

continueOrExit (){

echo "Press 'y' to continue or 'n' to exit."

  # Wait for the user to press a key
  read -s -n 1 key

  # Check which key was pressed
  case $key in
      y|Y)
          echo "You pressed 'y'. Continuing..."
          ;;
      n|N)
          echo "You pressed 'n'. Exiting..."
          exit 1
          ;;
      *)
          echo "Invalid input. Please press 'y' or 'n'."
          ;;
  esac

}

#CLUSTER=acaternberg-ci-02
CLUSTER=acaternberg-tf-02
PREFIX=tmp
export AWS_REGION=us-east-1
#export cluster_name=$CLUSTER


#see https://us-east-1.console.aws.amazon.com/billing/home?region=us-east-1#/account
aws_account_id=324005994172
TAGS="Key=cb:user,Value=acaternberg Key=cb:owner,Value=professional-services Key=cb:environment,Value=$PREFIX-$CLUSTER Key=ps-genetes/cluster,Value=$CLUSTER  Key=ps-genetes/created,Value=manual"


# Get the OIDC ID from the EKS Cluster
oidc_id=$(aws eks describe-cluster --name $CLUSTER --query "cluster.identity.oidc.issuer" --region $AWS_REGION --output text |sed "s#^.*/id/##g")
echo "OIDC $oidc_id" |tee  $0.log
#aws eks describe-cluster --name "$CLUSTER" --query "cluster.identity.oidc.issuer" --output text
continueOrExit

vpc_id=$(aws eks describe-cluster \
    --name $CLUSTER \
    --query "cluster.resourcesVpcConfig.vpcId" \
    --output text)
echo "Got VPC_ID: $vpc_id for cluster $CLUSTER" |tee -a $0.log
continueOrExit

cidr_range=$(aws ec2 describe-vpcs \
    --vpc-ids $vpc_id \
    --query "Vpcs[].CidrBlock" \
    --output text)
echo "CIDR_RANGE $cidr_range for $vpc_id" |tee -a $0.log
continueOrExit

#security_group_id=$(aws ec2 describe-security-groups \
#  --group-name ${CLUSTER}-EfsSecurityGroup \
#  --query "SecurityGroups[].GroupId" \
#  --filter Name=vpc-id,Values=$vpcid)
#echo "Got Security_groud_id: $security_group_id for groupname: ${PREFIX}-EfsSecurityGroup" |tee -a $0.log
#aws ec2 delete-security-group --group-id $security_group_id  --group-name ${PREFIX}-EfsSecurityGroup
security_group_id=$(aws ec2 create-security-group \
    --group-name ${PREFIX}-${CLUSTER}-EfsSecurityGroup \
    --description "${PREFIX}-${CLUSTER} EFS security group" \
    --vpc-id $vpc_id \
    --output text)
echo "Security_groud_id: $security_group_id" |tee -a $0.log
aws ec2 create-tags --resources $security_group_id --tags $TAGS
continueOrExit


aws ec2 authorize-security-group-ingress \
    --group-id $security_group_id \
    --protocol tcp \
    --port 2049 \
    --cidr $cidr_range |tee -a $0.log
continueOrExit

file_system_id=$(aws efs create-file-system \
    --region $AWS_REGION \
    --performance-mode generalPurpose \
    --tags $TAGS
    --query 'FileSystemId' \
    --output text)

echo "created EFS filesystem with ID: $file_system_id" |tee -a $0.log
continueOrExit


kubectl get nodes  |tee -a $0.log


aws ec2 describe-subnets \
     --filters "Name=vpc-id,Values=$vpc_id" \
     --query 'Subnets[*].{SubnetId: SubnetId,AvailabilityZone: AvailabilityZone,CidrBlock: CidrBlock}' \
     --output table  |tee -a $0.log

#Here we need the Clusters VPC private subnet ids
aws efs create-mount-target \
    --file-system-id $file_system_id \
    --subnet-id subnet-00c1898bc5542ccdc \
    --security-groups $security_group_id
#
#aws efs create-mount-target \
#    --file-system-id $file_system_id \
#    --subnet-id subnet-03cf9db8a93e203c6 \
#    --security-groups $security_group_id



# see for example https://github.com/kubernetes-sigs/aws-efs-csi-driver/blob/master/examples/kubernetes/encryption_in_transit/specs/pv.yaml