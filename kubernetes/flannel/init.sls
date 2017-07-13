{% from "kubernetes/map.jinja" import config with context %}

{% if pillar.kubernetes.master is defined %}
{% set ips = salt['mine.get']('kubernetes:master', 'network.internal_ip', 'pillar').values() -%}
config-network-to-etcd:
  cmd.run:
    - name: >
        curl http://{{ ips[0] }}:2379/v2/keys/kubernetes.io/network/config 
        -XPUT 
        -d value='{ "Network": "{{ config.cluster_cidr }}", "Backend": {"Type": "vxlan"}}'

/etc/kubernetes/kube-flannel.yml:
  file.managed:
    - source: salt://kubernetes/flannel/kube-flannel.yml
    - template: jinja
    - user: root
    - group: root
    - mode: 644
    - makedirs: true
    - dir_mode: 755
    - require:
      - cmd: config-network-to-etcd
      - service: docker
      - service: kubelet

deploy-flannel-daemonset:
  cmd.run:
    - require:
      - file: /etc/kubernetes/kube-flannel.yml
    - name:  hyperkube kubectl apply -f /etc/kubernetes/kube-flannel.yml
{% endif %}


