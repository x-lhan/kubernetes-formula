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
2. Apply `kubernetes` state among cluster master and pool noeds.
3. (Optional) To use flannel as network plugin, please modify/add pillar data as needed(`bind_iface: eth1`, `network_provider: cni`) and apply `kubernetes` and `kubernetes.flannel` state to the master node.
4. (Optional) For easier debugging purpose: a `kuberenetes.kubelet.reset` state can be apply to all nodes to make sure kubelet is stop and all generated container is removed. e.g. To hard restart the cluster: `kubernetes` state can be apply to include this `kubelet.reset` state like this:

```
  salt minion* state.sls kubernetes pillar='{"kubernetes":{"reset_kubelet": true}}'
```
## TODO

1. add logrotate to generate logs
2. organize defaults.yml
