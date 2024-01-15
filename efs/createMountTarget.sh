#! /bin/bash

aws efs create-mount-target --region=us-east-1 \
    --file-system-id $1 \
    --subnet-id $2  \
    --security-groups $3 
