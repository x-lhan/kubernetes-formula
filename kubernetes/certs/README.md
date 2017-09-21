# Certificate Management in Kubernetes

## Overview

Kubernetes uses certificates to facilitate secure communication between kubernetes system components (apiserver, the kubelet, and any system pods)

This part of the kubernetes formula helps you generate new certificates if you need them, it puts the certificates where they need to be to function properly and this documentation gives you some tips if you run into a problem.

If you want to learn more, please take a look at the kubernetes documentation. Below are a few articles that may give you more information

- [Managing TLS in a cluster](https://kubernetes.io/docs/tasks/tls/managing-tls-in-a-cluster/)
- [Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)

## Relevant States

- **present** - puts the certificates stored in the pillar in the right places
- **removed** - removes the certificates from the file system

More information can be gathered by reading the states, they are fairly straightforward.

## Relevant Runners

- **k8s-helper.generate_certs** - generates certificates necessary for secure system communication and stores them on the salt master's file system so they can be included in the pillar.

##Installing Certificates into a New Cluster

You'll need to generate new certificates and place them into your kubernetes pillar file. Using the k8s-helper runner, you can generate the certificates on the salt master and include those certificates in the pillar.

```
salt-run k8s-helper.generate_certs cluster_tag="default" api_service_address="10.254.0.1" api_server_fqdn="kubernetes.api"
```

k8s-helper.generate\_certs has a few arguments that can be passed to it, but they all have defaults (shown in the parentheses) that cover the normal case. Below are

* cluster\_tag ("default") - identifies which cluster the certificates are being created for
* api\_service\_address ("10.254.0.1") - the service address the api-server will use
* api\_server\_fqdn ("kubernetes.api") - the api-server fqdn (used as a SAN)
* force_regen (False) - Will force generation of the certificates, even if a previous set exists

The new certificates and keys will be in the following folder if you used "default" as the cluster_tag.

```
/var/salt/k8s-helper/pki/default/...
```

Again, assuming a cluster_tag of "default", you can include the files in the pillar by doing the following:

```
{% set cluster_tag = "default" %}
{% set pki_path = "/var/salt/k8s-helper/pki/" + cluster_tag + "/" %}

kubernetes:
  k8s_env: {{ cluster_tag }}
  certs:
    "ca.crt": |
      {{ salt.cmd.run("cat " + pki_path + "ca.crt") | indent(8) }}
    "kubecfg.crt": |
      {{ salt.cmd.run("cat " + pki_path + "kubecfg.crt") | indent(8) }}
    "kubecfg.key": |
      {{ salt.cmd.run("cat " + pki_path + "kubecfg.key") | indent(8) }}
    "server.cert": |
      {{ salt.cmd.run("cat " + pki_path + "server.crt") | indent(8) }}
    "server.key": |
      {{ salt.cmd.run("cat " + pki_path + "server.key") | indent(8) }}
  ...
...
```


## How to Replace Existing Certificates With New Ones

The following process assumes you're running a multi-master cluster, but should work on a single master cluster in the same fashion just by skipping the steps meant for the additional masters.

One thing to note is that until the cluster is setup with the new certificate, you may not be able to control the cluster properly using kubectl

The following example uses 3 kubernetes masters and 3 kubernetes nodes

```
k8s-master-1
k8s-master-2
k8s-master-3

k8s-node-1
k8s-node-2
k8s-node-3
```

First, you'll want to generate the certificates on the salt master. Follow the steps in the previous section titled [Installing Certificates into a New Cluster](#installing-certificates-into-a-new-cluster)

**CAUTION:** the kubernetes.kubelet.removed state ran below will remove all the containers running on the master. Because it's a kubernetes master, it'll likely only be running kubernetes specific system containers, so this shouldn't be a big issue.

```
salt k8s-master* saltutil.refresh_pillar
salt k8s-master* state.apply kubernetes.kubelet.removed
salt k8s-master* state.apply kubernetes.running
```

At this point, all the kubernetes masters should have the new certificates and should be running properly. Now, you'll need to get the kubernetes nodes setup with the new certificates.

```
salt k8s-node* saltutil.refresh_pillar
salt k8s-node* state.apply kubernetes.running
```

Now your nodes should be setup with the new certificates as well.

The CANAL system pods will likely not be functioning properly. Additionally, their secrets will need to be reset

```
salt k8s-master-1 cmd.run 'hyperkube kubectl delete secrets -n kube-system --all'
salt k8s-master-1 cmd.run 'hyperkube kubectl get pods -n kube-system -o wide'
```

The kubernetes kube-system secrets have been deleted at this point and you should have a listing of the system pods. You'll likely have a few CANAL system pods failing, but if you delete those pods, they'll get re-created automatically and should function properly.

**NOTE:** The CANAL pods may appear to be functioning properly on the nodes, but they probably are not. some of the system pods that run on the nodes may not be coming up, but deleting and re-creating the node's CANAL pod should get the system pods running on the node to function properly again.

```
salt k8s-master-1 cmd.run 'hyperkube kubectl delete pods <CANAL-POD-MASTER-1> <CANAL-POD-MASTER-2> <CANAL-POD-MASTER-3> <CANAL-POD-NODE-1> <CANAL-POD-NODE-2> <CANAL-POD-NODE-3> -n kube-system'
```

The kube-dns and kubernetes-dashboard pods may also not be functioning properly, or may take a moment to come back up properly. Deleting those should cause them to be re-created immediately. kube-dns could take a few minutes to come back up properly.

You should now be using the new certificates and in pretty good shape at this point.

## Troubleshooting and debugging

### Inspecting Certificates

It's helpful to know the different places the certificate will be. If there's a certificate issue, you can sanity check by making sure all the certificates in the various places are the same.

#### On the filesystem:

```
/srv/kubernetes/ca.crt
/usr/local/share/ca-certificates/kubernetes-ca.crt
/etc/ssl/certs/kubernetes.pem -> symlinked to kubernetes-ca.crt
/etc/ssl/certs/ca-certificates.crt -> global certificate list for the system
/var/lib/kubelet/ca.crt
```

#### Kubernetes secrets

You can get all the system secrets the following way

```
kubectl get secrets -n kube-system
```

You can also get the contents of the secrets, including the ca certificate, in base 64 encoding the following way

```
kubectl get secret <SECRET_ID> -n kube-system -o json
```

you can decode the secret on the ubuntu command line the following way

```
echo "<BASE64_ENCODED_SECRET>" | base64 --decode
```

#### etcd

You can also look at the secrets stored in etcd. These are not encoded in base64, so it can be a little easier to manage, but the commands have to be run directly on the etcd container.

There are two etcd containers, an etcd events container and an etcd server container. You'll want to run this on the etcd server container. You'll know which one is the etcd server when you run ```docker ps``` because the name should start with the ```k8s_etcd-container_etcd-server```

```
docker exec -e ETCDCTL_API=3 <container_id> etcdctl get "/registry/secrets/" --prefix=true
```

That command will return all the secrets stored in etcd.

#### Pod Mounts

The secrets also get copied into a directory that gets mounted by containers that need access to them. You can find the directory by running the ``` docker inspect <container_id>``` on a container that uses the secret. you'll see a mount with a destination that resembles something like ```/var/run/secrets/kubernetes.io/serviceaccount```. The source directory should contain the certificate, as well as token data copied into it.

### System Secrets Not Updating to New Certificate

If you run into problems where the kube-system secrets are not being updated with the new certificate, you may not have run the kubernetes.kubelet.removed state on that particular kubernetes master.

The reason we run that state is that it removes all the docker containers running on the system. You might be tempted to use a command like ```kubectl delete pods --all -n kube-system```. However, this command may only stop and start the existing containers without removing them and recreating them.

The secrets setup on the system pods will have the old certificate instead of the new one, causing authentication problems during communication between the system pods. Using the following command, you can delete the existing containers directly. The pods should automatically be re-created with the new secrets and new certificate.

```
docker rm -f $(docker ps -a -q)
```

This will remove all the containers running on the system. You can alternately remove the individual system containers. I wouldn't be surprised if only a subset of the system containers need to be removed, however, that route hasn't been fully explored yet.

### Still Stuck?

There's a good chance we (Lu or Arthur) may have run into the issue you're facing if it happens to be with certificates. Please reach out to us and hopefully we'll be able to help you out.