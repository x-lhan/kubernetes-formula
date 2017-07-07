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

1. Docker installation is not in the scope of this formula. It is required docker installed and running.
2. A mine function `network.internal_ip`, distributed to all minions, that returns the internal IP address to use for apiserver communication. Example pillar data:

```
  mine_functions:
    network.internal_ip:
      - mine_function: grains.get
      - 'ip_interfaces:eth1:0'
```

## How to use?

1. Create pillar data file based on `pillar.example` file and modify as needed. More configurable pillar data can be referenced from `default.yml`.
2. Apply `kubernetes` state among cluster master and pool hosts.

## TODO

1. make kubenet/other network plugin working: currently kubenet cannot be used based on an opening [bug](https://github.com/kubernetes/kubernetes/issues/47618) in hyperkube
2. Include `kube-addon` and other needed sub-component from saltbase
