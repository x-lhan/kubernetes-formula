{% from "kubernetes/map.jinja" import config with context %}
include:
  - .installed


{% if config.get('is_systemd') %}
{% set environment_file = '/etc/sysconfig/kubelet' %}
{% else %}
{% set environment_file = '/etc/default/kubelet' %}
{% endif %}

{{ environment_file}}:
  file.managed:
    - source: salt://kubernetes/kubelet/default
    - template: jinja
    - user: root
    - group: root
    - mode: 644

# The default here is that this file is blank. If this is the case, the kubelet
# won't be able to parse it as JSON and it will not be able to publish events
# to the apiserver. You'll see a single error line in the kubelet start up file
# about this.
/var/lib/kubelet/kubeconfig:
  file.managed:
    - source: salt://kubernetes/kubelet/kubeconfig
    - template: jinja
    - user: root
    - group: root
    - mode: 400
    - makedirs: true

/var/lib/kubelet/ca.crt:
  file.managed:
    {% if config.certs is defined and config.certs["ca.crt"] is defined %}
    - contents: |
        {{ config.certs["ca.crt"]| indent(8) }}
    {% else %}
    - onlyif: test -f /srv/kubernetes/ca.crt
    - source: /srv/kubernetes/ca.crt
    {% endif %}
    - user: root
    - group: root
    - mode: 400
    - makedirs: true

{% if config.get('is_systemd') %}

{{ config.get('systemd_system_path') }}/kubelet.service:
  file.managed:
    - source: salt://kubernetes/kubelet/kubelet.service
    - user: root
    - group: root

# The service.running block below doesn't work reliably
# Instead we run our script which e.g. does a systemd daemon-reload
# But we keep the service block below, so it can be used by dependencies
# TODO: Fix this
fix-service-kubelet:
  cmd.wait:
    - name: /opt/kubernetes/helpers/services bounce kubelet
    - watch:
      - file: /usr/local/bin/kubelet
      - file: {{ config.get('systemd_system_path') }}/kubelet.service
      - file: {{ environment_file }}
      - file: /var/lib/kubelet/kubeconfig
      - file: /var/lib/kubelet/ca.crt

{% else %}

/etc/init.d/kubelet:
  file.managed:
    - source: salt://kubernetes/kubelet/initd
    - user: root
    - group: root
    - mode: 755

{% endif %}


