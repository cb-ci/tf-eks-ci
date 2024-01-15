#! /bin/bash

CLUSTER=acaternberg-tf-02
export AWS_REGION=us-east-1

aws iam create-policy --policy-name $CLUSTER-AmazonEKSClusterAutoscalerPolicy --policy-document file://AmazonEKSClusterAutoscalerPolicy.json

aws iam list-policies --max-items 1