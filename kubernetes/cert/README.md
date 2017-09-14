# Certificate Management in Kubernetes

## Overview

Kubernetes uses certificates to facilitate secure communication between kubernetes system components (apiserver, the kubelet, and any system pods)

This part of the kubernetes formula helps you generate new certificates if you need them, it puts the certificates where they need to be to function properly and this documentation gives you some tips if you run into a problem.

If you want to learn more, please take a look at the kubernetes documentation. Below are a few articles that may give you more information

- [Managing TLS in a cluster](https://kubernetes.io/docs/tasks/tls/managing-tls-in-a-cluster/)
- [Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)

## Relevant States

### configured

Checks to see if certificates are configured in the pillar. If they are not, a new root CA certificate will be generated for Kubernetes, along with a public and private key pair for secure Kubernetes system communications.

Additionally, if new certificates are generated, a kubecfg key pair will be created as a super-user key pair that can be used to authenticate and authorize cluster actions through tools like the kubectl CLI client. 

### removed

Makes sure the following files are not present

```
/srv/kubernetes/ca.crt
/srv/kubernetes/server.cert
/srv/kubernetes/server.key
/srv/kubernetes/kubecfg.crt
/srv/kubernetes/kubecfg.key
/usr/local/share/ca-certificates/kubernetes-ca.crt
```

### view

views the certificates stored on the minion and prints them out so that they can be dropped into the pillar by a simple cut and paste

## How to Regenerate Certificates

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

Pick a master you'll use to regenerate the certificates

```
salt k8s-master-1 state.apply kubernetes.kubelet.removed
```

**CAUTION:** This step will remove all the containers running on the master. Because it's a kubernetes master, it'll likely only be running kubernetes specific system containers, so this shouldn't be a big issue.

```
salt k8s-master-1 state.apply kubernetes.cert.removed
```

This will remove the certificate files on this kubernetes master. Once this is done, **make sure to remove the existing certificates pillar data from the pillar file before generating new certificates**

```
salt k8s-master-1 saltutil.refresh_pillar
salt k8s-master-1 state.apply kubernetes.cert.configured
```

This will generate the new certificates.

```
salt k8s-master-1 state.apply kubernetes.cert.view
```

Use the output from the kubernetes.cert.view state to place the certificates into the pillar file for your kubernetes cluster.

```
salt k8s-master-1 saltutil.refresh_pillar
salt k8s-master-1 state.apply kubernetes.running
```

At this point, the first kubernetes master has the new certificates and is running properly. Now, you'll need to get the other kubernetes masters setup with the new certificates.

```
salt k8s-master-2 state.apply kubernetes.kubelet.removed
salt k8s-master-2 state.apply kubernetes.cert.removed
salt k8s-master-2 saltutil.refresh_pillar
salt k8s-master-2 state.apply kubernetes.running

salt k8s-master-3 state.apply kubernetes.kubelet.removed
salt k8s-master-3 state.apply kubernetes.cert.removed
salt k8s-master-3 saltutil.refresh_pillar
salt k8s-master-3 state.apply kubernetes.running
```

The above steps should get all your other kubernetes masters setup with the new certificates

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