{% from "kubernetes/map.jinja" import config with context %}
include:
  - .configured
kubelet:
  service.running:
    - enable: True
    - watch:
      - file: /usr/local/bin/hyperkube
{% if config.get('is_systemd') %}
      - file: {{ config.get('systemd_system_path') }}/kubelet.service
{% else %}
      - file: /etc/init.d/kubelet
{% endif %}
{% if grains['os_family'] == 'RedHat' %}
      - file: /usr/lib/systemd/system/kubelet.service
{% endif %}
      - sls: kubernetes.kubelet.configured
      - file: /var/lib/kubelet/kubeconfig
      - file: /var/lib/kubelet/ca.crt
{% if config.get('is_systemd') %}
    - provider:
      - service: systemd
{%- endif %}