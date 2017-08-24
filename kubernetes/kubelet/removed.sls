{% from "kubernetes/map.jinja" import config with context %}

include:
  - .stopped
  


{% if config.get('is_systemd') %}
{% set environment_file = '/etc/sysconfig/kubelet' %}
{% else %}
{% set environment_file = '/etc/default/kubelet' %}
{% endif %}

remove-all-containers:
  cmd.run:
    - name: docker rm -f $(docker ps -a -q)
    - shall: bash

{{ environment_file}}:
  file.absent




/usr/bin/nsenter:
  file.absent
  

/usr/local/bin/hyperkube:
  file.absent
  

# The default here is that this file is blank. If this is the case, the kubelet
# won't be able to parse it as JSON and it will not be able to publish events
# to the apiserver. You'll see a single error line in the kubelet start up file
# about this.
/var/lib/kubelet/kubeconfig:
  file.absent
  

/var/lib/kubelet/ca.crt:
  file.absent
  

{% if config.get('is_systemd') %}

{{ config.get('systemd_system_path') }}/kubelet.service:
  file.absent

{% else %}

/etc/init.d/kubelet:
  file.absent

{% endif %}