## Kubernetes Formula

A salt formula to deploy a ready to use kubernetes cluster(Tested in Ubuntu 14.04). This formula mainly referenced from official [saltbase code](https://github.com/kubernetes/kubernetes/tree/master/cluster/saltbase).
The following component is deployed:

Master node:

  * etcd: deployed as static pod manifest
  * kubelet: using `hyperkube` bin and initd to ensure service running
  * kube-api-server: deployed as static pod manifest
  * kube-control-manager: deployed as static pod manifest
  * kube-scheduler: deployed as static pod manifest

Pool node:

  * kubelet: using `hyperkube` bin and initd to ensure service running
  * kube-proxy: deployed as static pod manifest

## Pre-request

1. Docker installation is not in the scope of this formula. It is required docker installed and running. Please make sure `iptables=false` and `ip-masq=false` docker opts are set.
2. A mine function `network.internal_ip`, distributed to all minions, that returns the internal IP address to use for apiserver communication. Example pillar data:

```
  mine_functions:
    network.internal_ip:
      - mine_function: grains.get
      - 'ip_interfaces:eth1:0'
```

## How to use?

1. Create pillar data file based on `pillar.example` file and modify as needed. More configurable pillar data can be referenced from `default.yml`.
2. (Optional) To use flannel as network plugin, please modify/add pillar data as needed(`bind_iface: eth1`, `network_provider: cni`, `allocate_node_cidrs: true`). 
3. (Optional, only required for multi-master nodes setup) Generate TLS certificates and share among master nodes:

    a. Scope master nodes by setting pillar data `kubernetes:master` to `True`.
  
    b. Apply `kuberentes.generate-cert` state to one master node.
  
    c. Copy all newly generated certs under `/srv/kubernets/`(ca.crt, server.key, server.cert, kubecfg.key, kubecfg.crt) into pillar `kubernetes:certs` with filename as key and file content as value.
  
4. Apply `kubernetes` state among cluster master and pool nodes.

### Note for setting up HA etcd/apiserver
* HA etcd require at least 3 node to be fault-tolerant, with the current setup meaning at least 3 master nodes
* HA apiserver require to put all apiserver endpoint(`https://MASTER_NODE_IP:6443`) behind one or multiple load balancer. Then add the load balancer ip and port to pillar data `kubernetes:api_server:ip` and `kubernetes:api_server:port` before step#3.

## Notes

* For easier debugging purpose: a `kuberenetes.kubelet.reset` state can be apply to all nodes to make sure kubelet is stop and all generated container is removed. e.g. To hard restart the cluster: `kubernetes` state can be apply to include this `kubelet.reset` state like this:

```
  salt minion* state.sls kubernetes pillar='{"kubernetes":{"reset_kubelet": true}}'
```
## TODO

1. add logrotate to generate logs
2. organize defaults.yml
