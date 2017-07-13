{% from "kubernetes/map.jinja" import config with context %}


{%- if pillar.kubernetes is defined %}
include:
  - .base
  - .generate-cert

{%- if pillar.kubernetes.master is defined %}
  
  - .etcd
{% if config.get('network_provider', '').lower() == 'kubenet' %}
  - .cni
{% elif config.get('network_provider', '').lower() == 'cni' %}
  - .cni
{% endif %}
  - .kube-apiserver
  - .kube-controller-manager
  - .kube-scheduler 
  - .docker
  - .kubelet
{%- endif %}

{%- if pillar.kubernetes.pool is defined %}
  - .docker
{% if config.get('network_policy_provider', '').lower() == 'calico' %}
  - .cni
{% elif config.get('network_provider', '').lower() == 'kubenet' %}
  - .cni
{% elif config.get('network_provider', '').lower() == 'cni' %}
  - .cni
{% endif %}
  - .kubelet
  - .kube-proxy
{%- endif %}
{% if config.get('network_provider', '').lower() == 'cni' and config.get('cni_provider', '').lower() == 'flannel'%}
  - .flannel
{% endif %}
{%- endif %}