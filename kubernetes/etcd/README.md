# Kubernetes etcd cluster

## Intro

Kubernetes cluster rely on etcd to store its state. So please first ensure etcd cluster in health state before debugging any kuberente cluster problem. In the current setup, there are two etcd related resources are deployed through kubernetes:
  1. etcd cluster is deployed through static pod manifest. The manifest file is generated through `kubernetes.etcd.configured` state(which is in order being called by `kubernetes.running` state on master node) and when kubelet is running etcd pod will be created and the cluster will start running.
  2. etcd cluster snapshot cronjob is deployed through kube-addon manager after the kubernetes cluster become available. This cronjob will take etcd cluster snapshot on a single master node with the configured EBS volume.
  

## Backup

  Backup can be done automatically, if the following steps are taken once:
  
  1. Make sure related pillar data are set:
  
    ```
      # make sure pillar storage_backend is not exist or not as "etcd2"
      enable_etcd_snapshot: true
      runtime_config: batch/v2alpha1=true
      
    
      # (Optional) which storage_class this snapshot pvc related. Default to gp2
      # if did not override please enable_default_storage_class
      # etcd_snapshot_storage_classname: gp2
      # OR
      # enable_default_storage_class: true
    
      # Required to define pillar data "etcd_snapshot_zone" (Pick any master node in the AZ)
      # or "etcd_snapshot_hostname" to narrow down which master host to run.
      # etcd_snapshot_zone: us-west-1a
      # OR
      # etcd_snapshot_hostname: ip-172-31-2-119 
    
      # (Optional) snapshot volume size. Default to 1Gi
      etcd_snapshot_disk_size: 1Gi
      # (Optional) snapshot taken cronjob defination. Default to daily run at 06:02AM UTC
      etcd_snapshot_schedule: "02 6 * * *"
  
    ```
 2. Apply `kubernetes.running` to all master node. After few minutes addons-manager should pick up the changes and create cronjob accordingly.(`kubectl -n kube-system get cronjob` can be used to confirm cronjob exist)
 3. The snapshot should be taken after the configured cronjob time(`etcd_snapshot_schedule`, Default to daily run at 06:02AM UTC. If intend to get snapshot immediately please temporarily modify `etcd_snapshot_schedule` to `*/10 * * * *` to make snapshot every 10 minute)
 4. Locate the related volume with tags("Value": "kube-etcd-snapshot-pvc","Key": "kubernetes.io/created-for/pvc/name"). Make sure this volume is being taking EBS snapshot regularly.(e.g. Through Xetus [AWS-Autosnap](https://github.com/xetus-oss/aws-autosnap#usage) service)

## Restore

  Restore is done when disaster happened to the cluster(such as 2 out of 3 node has lost). Here is some manually steps to restore a single etcd cluster member:
  
  1. Make sure kubernetes/etcd are not running on the target host. (Unnecessary for new system. But old configuration state can be removed by `kubernetes.kubelet.removed` state)
  2. Locate the latest EBS snapshot of volume(tags with "Value": "kube-etcd-snapshot-pvc","Key": "kubernetes.io/created-for/pvc/name")
  3. Create an volume from the above snapshot within the same availability zone of the target host. (`aws ec2 create-volume --region us-east-1 --availability-zone us-east-1a --snapshot-id snap-066877671789bd71b --volume-type io1 --iops 1000`)
  4. Attach the above volume to target host. (`aws ec2 attach-volume --volume-id vol-0e1c163e3b3 --instance-id i-02603827c9c --device /dev/xvdbd`)
  5. Mount the volume to `/mnt/etcd` (`mkdir /mnt/etcd; mount /dev/xvdbd /mnt/etcd`) 
  6. (Optional) Make sure `/mnt/etcd/snapshot.db` and `/mnt/etcd/snapshot-events.db` exists; etcd snapshot status can be checked with command ` ETCDCTL_API=3 etcdctl --write-out=table snapshot status /mnt/etcd/snapshot.db`
  7. Apply `kubernetes.etcd.restored` state to target host.
  8. Clean up after mess.(`umount /dev/xvdbd` and `aws ec2 detach-volume --volume-id vol-0e1c163e3b3; aws ec2 delete-volume --volume-id vol-0e1c163e3b3`) 
  
  After apply the above steps to all master node. Apply `kubernetes.running` state to all master node, then kubernetes cluster should be restored.
  
## Reference

1. [etcd official cluster recovery guide](https://github.com/coreos/etcd/blob/master/Documentation/op-guide/recovery.md)
2. [kubernetes restoring an etcd cluster section](https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/)