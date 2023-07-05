

## Install EFS CSI driver
* https://aws.amazon.com/blogs/storage/persistent-storage-for-kubernetes/
* https://docs.aws.amazon.com/eks/latest/userguide/efs-csi.html
* https://docs.aws.amazon.com/eks/latest/userguide/csi-iam-role.html
* https://docs.aws.amazon.com/efs/latest/ug/creating-using-create-fs.html#creating-using-fs-part1-cli
* https://archive.eksworkshop.com/beginner/190_efs/efs-csi-driver/


example: https://github.com/aws-ia/terraform-aws-eks-blueprints-addons/issues/150
## OIDC

+ Jira; https://cloudbees.atlassian.net/issues/?jql=text+%7E+%22%5C%22Not+authorized+to+perform+sts%3AAssumeRoleWithWebIdentity%5C%22%22&atlOrigin=eyJpIjoiNTdmNDlhYTRjMDg2NGZjMWEyZjk5NTllMmE4ZWNkY2UiLCJwIjoiaiJ9

+ My OIDC: https://oidc.eks.us-east-1.amazonaws.com/id/4CC190FC655B2E1B143A6631C0406574

```
helm repo add aws-efs-csi-driver https://kubernetes-sigs.github.io/aws-efs-csi-driver
helm repo update aws-efs-csi-driver

helm upgrade -i aws-efs-csi-driver aws-efs-csi-driver/aws-efs-csi-driver \
    --namespace kube-system \
    --set image.repository=	602401143452.dkr.ecr.us-east-1.amazonaws.com/eks/aws-efs-csi-driver \
    --set controller.serviceAccount.create=false \
    --set controller.serviceAccount.name=efs-csi-controller-sa

```

```
apiVersion: v1
kind: PersistentVolume
metadata:
  name: efs-pv
spec:
  capacity:
    storage: 5Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: efs-sc
  csi:
    driver: efs.csi.aws.com
    volumeHandle: fs-4af69aab
    volumeAttributes:
      encryptInTransit: "true"
```

