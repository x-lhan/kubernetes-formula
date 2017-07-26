{% from "kubernetes/map.jinja" import config with context %}


{%- if pillar.kubernetes is defined %}
include:
  - .base
{% if config.get("reset_kubelet", False) %}
  - .kubelet.reset
{% endif %}
{%- if pillar.kubernetes.master is defined %}
  - .generate-cert
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
  - .kube-proxy
  - .kube-addons
{% if config.get('enable_cluster_autoscaler', '').lower() == 'true' %}
    - .cluster-autoscaler
{% endif %}
{% if config.get('enable_rescheduler', '').lower() == 'true' %}
    - .rescheduler
{% endif %}
{% if config.get('network_provider', '').lower() == 'cni' and config.get('cni_provider', '').lower() == 'flannel' %}
  - .flannel
{% endif %}
{% if config.get("reset_kubelet", False) %}
  - .reset
{% endif %}
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

{%- endif %}