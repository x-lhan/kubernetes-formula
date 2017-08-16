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
{% if config.cluster_autoscaler.enabled %}
  - .cluster-autoscaler
{% endif %}
{% if config.enable_rescheduler %}
  - .rescheduler
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