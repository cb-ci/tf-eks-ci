#! /bin/bash

CLUSTER=acaternberg-tf-02
#CLUSTER=acaternberg-ci-02

export AWS_REGION=us-east-1


export cluster_name=$CLUSTER
export role_name=$CLUSTER-AmazonEKS_EFS_CSI_DriverRole
eksctl create iamserviceaccount \
    --name efs-csi-controller-sa \
    --namespace kube-system \
    --cluster $cluster_name \
    --role-name $role_name \
    --role-only \
    --override-existing-serviceaccounts \
    --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy \
    --approve \
    --verbose 5
TRUST_POLICY=$(aws iam get-role --role-name $role_name --query 'Role.AssumeRolePolicyDocument' | \
    sed -e 's/efs-csi-controller-sa/efs-csi-*/' -e 's/StringEquals/StringLike/')
echo "TRUST_POLICY: $TRUST_POLICY"
aws iam update-assume-role-policy --role-name $role_name --policy-document "$TRUST_POLICY"  --debug