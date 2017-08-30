include:
  - .kubelet.removed
  - .cni.removed
  - .cert.removed

# remove all manifests and addons  
/etc/kubernetes:
  file.absent

/srv/kubernetes:
  file.absent