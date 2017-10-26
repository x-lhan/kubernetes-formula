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

  You can use the etcd_restore module to restore a failed etcd cluster. There are a few requirements before you can start the restore process.

  You'll need to locate the etcd backup ebs volume or ebs volume AWS snapshot. Once you locate the snapshot.db and snapshot-events.db files corresponding to your etcd cluster, place them into the following salt fs accessible folder:

  ```
  salt://kubernetes/etcd/restore/
  ```

  Make sure your mine and pillar data are accurate and up to date:

  ```
  salt etcd_member* saltutil.sync_all
  salt etcd_member* saltutil.refresh_pillar
  salt etcd_member* mine.update
  salt etcd_member* saltutil.refresh_pillar
  ```

  Use the etcd\_restore.end\_to\_end\_restore module function, targetting all the etcd members you wish to restore and start the kubelet after that's done. There are several arguments that can be passed to end\_to\_end\_etcd\_restore, but by default, this will use mine and pillar data to perform the restore. If you wish to run the module, overriding some of the arguments, please take a look at the etcd\_restore module for more information.

  ```
  salt etcd_member* etcd_restore.end_to_end_etcd_restore
  salt etcd_member* etcd_restore.start_kubelet
  ```

  You should have a functioning etcd cluster after this. You can verify the cluster health by running the following command on any of the etcd members:

  ```
  salt etcd_member_1 cmd.run 'etcdctl cluster-health'
  ```
  
## Reference

1. [etcd official cluster recovery guide](https://github.com/coreos/etcd/blob/master/Documentation/op-guide/recovery.md)
2. [kubernetes restoring an etcd cluster section](https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/)