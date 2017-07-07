{% from "kubernetes/map.jinja" import config with context %}


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

/tmp/hyperkube:
  file.directory:
    - user: root
    - group: root

/usr/bin/nsenter:
  cmd.run:
    - unless: test -f /usr/bin/nsenter
    - name: docker run --rm -v /tmp/hyperkube:/target jpetazzo/nsenter
    - require:
      - file: /tmp/hyperkube
  file.managed:
    - unless: test -f /usr/bin/nsenter
    - source: /tmp/hyperkube/nsenter
    - mode: 755
    - makedirs: true
    - user: root
    - group: root
    - require:
      - cmd: /usr/bin/nsenter

/usr/local/bin/hyperkube:
  cmd.run:
    - unless: test -f /usr/local/bin/hyperkube
    - name: docker run --rm -v /tmp/hyperkube:/tmp/hyperkube --entrypoint cp {{ config.hyperkube_image }}:{{ config.version }} -vr /hyperkube /tmp/hyperkube
    - require:
      - file: /tmp/hyperkube
    {%- if grains.get('noservices') %}
    - onlyif: /bin/false
    {%- endif %}
  file.managed:
    - unless: test -f /usr/local/bin/hyperkube
    - source: /tmp/hyperkube/hyperkube
    - mode: 755
    - makedirs: true
    - user: root
    - group: root
    - require:
      - cmd: /usr/local/bin/hyperkube

# The default here is that this file is blank. If this is the case, the kubelet
# won't be able to parse it as JSON and it will not be able to publish events
# to the apiserver. You'll see a single error line in the kubelet start up file
# about this.
/var/lib/kubelet/kubeconfig:
  file.managed:
    - source: salt://kubernetes/kubelet/kubeconfig
    - user: root
    - group: root
    - mode: 400
    - makedirs: true

/var/lib/kubelet/ca.crt:
  file.managed:
    - onlyif: test -f /srv/kubernetes/ca.crt
    - source: /srv/kubernetes/ca.crt
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
      - file: {{ environment_file }}
      - file: /var/lib/kubelet/kubeconfig
      - file: /var/lib/kubelet/ca.crt
{% if config.get('is_systemd') %}
    - provider:
      - service: systemd
{%- endif %}
