include:
  - .kubelet.removed
  - .cni.removed
  - .certs.removed

# remove all manifests and addons  
/etc/kubernetes:
  file.absent

/srv/kubernetes:
  file.absent