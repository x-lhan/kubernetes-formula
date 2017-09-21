#!/bin/bash
{% from "kubernetes/map.jinja" import config with context %}

{% set etcd_protocol = 'http' -%}
{% if config.get('etcd_over_ssl', '').lower() == 'true' -%}
  {% set etcd_protocol = 'https' -%}
{% endif -%}
{% set host_ip = grains.get("ip_interfaces").get(config.bind_iface)[0] %}

{% set etcd_cluster = '' -%}
{% set vars = {'etcd_cluster': ''} -%}
{% for host in config.master_ips -%}
  {% if etcd_cluster != '' -%}
    {% set etcd_cluster = etcd_cluster ~ ',' -%}
  {% endif -%}
  {% set etcd_cluster = etcd_cluster ~ 'etcd-' ~ host|replace('.','-') ~ '=' ~ etcd_protocol ~'://' ~ host ~ ':' ~ server_port -%}
  {% do vars.update({'etcd_cluster': etcd_cluster}) -%}
{% endfor -%}
{% set etcd_cluster = vars.etcd_cluster -%}

{% set cluster_name = "etcd-server" + suffix %}

ETCDCTL_API=3 etcdctl snapshot restore /mnt/etcd/snapshot{{suffix}}.db \
  --name etcd-{{ host_ip|replace('.','-') }} \
  --initial-advertise-peer-urls {{ etcd_protocol }}://{{ host_ip }}:{{ server_port }} \
  --data-dir /mnt/master-pd/var/etcd/data{{ suffix }} \
  --initial-cluster-token {{cluster_name}} \
  --initial-cluster {{ etcd_cluster }}