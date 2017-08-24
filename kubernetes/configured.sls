{% from "kubernetes/map.jinja" import config with context %}


{%- if pillar.kubernetes is defined %}
include:
  - .docker
  - .installed
  - .base

{% if config.get('network_provider', '').lower() == 'kubenet' %}
  - .cni
{% elif config.get('network_provider', '').lower() == 'cni' %}
  - .cni
{% endif %}

{%- if pillar.kubernetes.master is defined %}
  - .cert.configured
  - .etcd
  - .kube-apiserver
  - .kube-controller-manager
  - .kube-scheduler
  - .kube-addons
{% if config.cluster_autoscaler.enabled %}
  - .cluster-autoscaler
{% endif %}
{% if config.enable_rescheduler %}
  - .rescheduler
{% endif %}
{%- endif %}

  - .kubelet.configured
  - .kube-proxy
{%- endif %}