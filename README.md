## Kubernetes Formula

A salt formula to deploy a ready to use kubernetes cluster(Tested in Ubuntu 14.04). This formula mainly referenced from official [saltbase code](https://github.com/kubernetes/kubernetes/tree/master/cluster/saltbase).
The following component is deployed:

Master node:

  * etcd: deployed as static pod manifest
  * kubelet: using `hyperkube` bin and initd to ensure service running
  * kube-api-server: deployed as static pod manifest
  * kube-control-manager: deployed as static pod manifest
  * kube-scheduler: deployed as static pod manifest 
  * kube-addons: deployed as static pod manifest

Pool node:

  * kubelet: using `hyperkube` bin and initd to ensure service running
  * kube-proxy: deployed as static pod manifest

In cluster:

  * kube-dns: deployed as deployment manifest
  * kubernetes-dashboard: deployed as deployment manifest

## Pre-request

1. Docker installation is not in the scope of this formula. It is required docker installed and running. Please make sure `iptables=false` and `ip-masq=false` docker opts are set.
2. make sure node do not have old conflict network configuration; if there is please follow the steps under _"Note for removing cni network plugin"_ section.
   * ensure flannel.1 interface is not existing
   * ensure no existing cni configuration under `/etc/cni/net.d`
3. A mine function `network.internal_ip`, distributed to all minions, that returns the internal IP address to use for apiserver communication. Example pillar data:

```
  mine_functions:
    network.internal_ip:
      - mine_function: grains.get
      - 'ip_interfaces:eth1:0'
```


## How to use?

* Pillar and grains data preparation:
  1. (Only for multi-clusters) scope nodes into different clusters by identifying node's grains data `k8s_env` with the same cluster environment name(e.g. stage/qa etc.); For the nodes do not have `k8s_env` grain set will be added into the `defaults` clusters.
  2. Create pillar data file based on `pillar.example`/`pillar-multi-cluster.example` file and modify as needed.(Master/pool nodes grouping can be confirmed with command like: `salt ANY_NODE mine.get kubernetes:[K8S_ENV]:[master|pool] network.internal_ip pillar`); 
  3. (Only for aws) make sure grains data `cloud` is `aws` for all aws nodes;
  4. Generate new or reuse existing TLS certificates and share among nodes:
  
      * (Only for generate new)Apply `kuberentes.cert.configured` state to one master node.
      * Copy all newly generated(using `kuberentes.cert.view` for convenience) or existing certs contents into pillar `kubernetes:[K8S_ENV]:certs`.
  
* Apply `kubernetes.running` state among cluster master and pool nodes.

### Note for setting up HA etcd/apiserver
* HA etcd require at least 3 nodes to be fault-tolerant, with the current setup meaning at least 3 master nodes
* HA apiserver require to put all apiserver endpoint(`https://MASTER_NODE_IP:6443`) behind one or multiple load balancer. Then add the load balancer ip and port to pillar data `kubernetes:[K8S_ENV]:api_server:ip` and `kubernetes:[K8S_ENV]:api_server:port` before step#3.

### Note for add/remove node into existing cluster

#### Master node

* Add steps:

    1. make sure pillar data `kubernetes:[K8S_ENV]:master` is true for the host need to add.
    2. make sure grain data `initial_etcd_cluster_state` is "existing" for the host need to add; (Required for aws) make sure grains data `cloud` is `aws`
    3. run `salt 'ALL_NODE_*' saltutil.refresh_pillar` to update pillar data
    4. run `salt 'TARGET_MASTER_NODE' state.sls kubernetes.running` to apply kubernetes state
    5. confirm the ip address of the host need to add with command like `salt TARGET_MASTER_NODE grains.get ip_interfaces:eth0`
    6. add the new etcd node into existing etcd cluster by running the following commands within an etcd container. For example the ip of the new master node is 192.168.51.7, then:
    
      * (for add kubernete main etcd cluster) `etcdctl member add etcd-192-168-51-7 http://192.168.51.7:2380`
      * (for add kubernete event etcd cluster) `etcdctl --endpoints=http://127.0.0.1:4002 member add etcd-192-168-51-7 http://192.168.51.7:2381`
      
    7. make sure load-balancer(e.g. haproxy) is updated if configured 

* Remove steps:

    1. evict all scheduled pods by using command `hyperkube kubectl taint node TARGET_NODE evict=true:NoExecute`
    2. remove the target etcd node from existing etcd cluster by running the following commands within an etcd container. For example the ip of the new master node is 192.168.51.7, then:
    
      * locate member_id by matching ip with result of command `etcdctl member list`; then remove from kubernete main etcd cluster by command `etcdctl member remove TARGET_MEMBER_ID`
      * locate member_id by matching ip with result of command `etcdctl --endpoints=http://127.0.0.1:4002 member list`; then remove from kubernete event etcd cluster by using `etcdctl --endpoints=http://127.0.0.1:4002 member remove TARGET_MEMBER_ID` 
      
    3. remove node from kubernete cluster by using `hyperkube kubectl delete node TARGET_NODE` on a master node
    4. using salt-cloud/salt-key to delete the node from saltstack cluster
    5. run `salt 'ALL_NODE_*' saltutil.refresh_pillar` to update pillar data
    6. make sure load-balancer(e.g. haproxy) is updated if configured 


#### Pool node

* Add steps:

    1. make sure pillar data `kubernetes:[K8S_ENV]:pool` is true for the host need to add; (Required for aws) make sure grains data `cloud` is `aws`
    2. run `salt 'TARGET_POOL_NODE' state.sls kubernetes.running` to apply kubernetes state

* Remove steps:

    1. evict all scheduled pods by using command `hyperkube kubectl taint node TARGET_NODE evict=true:NoExecute`
    2. remove node from kubernete cluster by using `hyperkube kubectl delete node TARGET_NODE" on a master node`
    3. using salt-cloud/salt-key to delete the node from saltstack cluster 

### Note for upgrade/downgrade node

  1. evict all scheduled pods by using command `hyperkube kubectl taint node TARGET_NODE evict=true:NoExecute`
  2. modify version pillar data needed(currently major version update is handled by formula default file; but each component version is configurable through respect pillar data)
  3. remove existing pkg by using command `salt TARGET_NODE state.sls kubernetes.kubelet.removed`
  4. run `salt 'TARGET_NODE' state.sls kubernetes.running` to apply kubernetes state again
  5. mark node as working status with command `hyperkube kubectl taint node TARGET_NODE evict:NoExecute-` 

### Note for cluster auto-scaler

  * cluster auto-scaler feature rely on cloud provider, for AWS please reference [here](https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/cloudprovider/aws/README.md)
  * To enable auto-scaler make sure pillar data `kubernetes:[K8S_ENV]:cluster_autoscaler:enabled` is true(Default is false) and set `kubernetes:[K8S_ENV]:cluster_autoscaler:params` as needed. 

### Note for removing cni network plugin
  1. evict all scheduled pods by using command `hyperkube kubectl taint node TARGET_NODE evict=true:NoExecute`
  2. remove kubelet service to prevent re-apply old cni configuration by applying `kubernetes.kubelet.removed` state
  3. remove existing cni configuration by applying `kubernetes.cni.removed` state
  4. restart the node to clean up old network configuration rule on the host

### Note for cluster registry

  * cluster registry rely on cloud provider(AWS), it provide a docker registry within the cluster.
  * To start registry, please make sure the following pillar data existing, then apply `kubernetes.running` state to all master nodes:
   
      ```
        kubernetes:
          [K8S_ENV]:
            enable_cluster_registry: true
            cluster_registry_disk_size: 1Gi
      
            # (optional) specify storage_classname or enable default storage class name
            # cluster_registry_storage_classname: gp2
            # enable_default_storage_class: true
            # default_storage_class_zones: "us-west-1a,us-west-1c[,ADD_SUPPORT_ZONES]"
            
            # (optional) override default registry server(10.254.50.50)
            # registry_server: 10.254.50.50
      ```    
  * To stop registry, please use salt to remove `/etc/kubernetes/addons/registry/registry-rc.yaml` file in all master node. (If intend to remove the *persistent volume* as well, remove `/etc/kubernetes/addons/registry/` directory instead)
  * To push image from outside of cluster(e.g. linux workstation, there is a [bug](https://github.com/moby/moby/issues/29608) prevent osx client), the following command can be used to forward the local `5000` port to registry pod `5000` port:
   
      ```
        kubectl port-forward --namespace kube-system REPLACE_WITH_REGISTRY_POD_NAME 5000:5000 &
        docker tag IMAGE_ID localhost:5000/IMAGE_NAME
        docker push localhost:5000/IMAGE_NAME
      ```
  * After configured docker daemon to accept `10.254.50.50:5000` as insecure registry. Image within registry can be consumed like `image: 10.254.50.50:5000/IMAGE_NAME` by kubelet. 
   

## Support states

### kubernetes.installed

Ensure required pkg is installed on the host

### kubernetes.configured

Ensure all required kubernetes components are configured, required `kubernetes.installed` state

### kubernetes.running

Ensure the cluster is running by start kubelet service, required `kubernetes.configured` state

### kubernetes.removed

Ensure kubelet/cni network plugin/certificate are removed.

### kubernetes.kubelet.running

Ensure kubelet service is running

### kubernetes.kubelet.stopped

Ensure kubelet service is stoppted

### kubernetes.kubelet.removed

Ensure all containers is removed and kubelet service is removed, required `kubernetes.kubelet.stopped` state

### kubernetes.cni.removed

Ensure cni network plugin is removed, please make sure cni configuration will not re-apply by existing cni daemonset(e.g. apply `kubernetes.kubelet.removed` state) 

### kubernetes.cert.configured

Ensure kubernetes cluster certificate is generated and configured into host

### kubernetes.cert.view

View the configured certificates as configurable pillar data `kubernetes:[K8S_ENV]:certs`

### kubernetes.cert.removed

Remove all kubernetes cluster certificate
