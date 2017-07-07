{% from "kubernetes/map.jinja" import config with context %}

{% if config.get('is_systemd') %}
  {% set environment_file = '/etc/sysconfig/docker' %}
{% else %}
  {% set environment_file = '/etc/default/docker' %}
{% endif %}

bridge-utils:
  pkg.installed
  
{{ environment_file }}:
  file.managed:
    - source: salt://kubernetes/docker/docker-defaults
    - template: jinja
    - user: root
    - group: root
    - mode: 644
    - makedirs: true

cbr0:
  network.managed:
    - enabled: True
    - type: bridge
    - proto: dhcp
    - ports: none
    - bridge: cbr0
    - delay: 0
    - bypassfirewall: True
    - require_in:
      - service: docker

docker:
# Starting Docker is racy on aws for some reason.  To be honest, since Monit
# is managing Docker restart we should probably just delete this whole thing
# but the kubernetes components use salt 'require' to set up a dag, and that
# complicated and scary to unwind.
# On AWS, we use a trick now... We don't start the docker service through Salt.
# Kubelet or our health checker will start it.  But we use service.enabled,
# so we still have a `service: docker` node for our DAG.
{% if grains.cloud is defined and grains.cloud == 'aws' %}
  service.enabled:
{% else %}
  service.running:
    - enable: True
{% endif %}
# If we put a watch on this, salt will try to start the service.
# We put the watch on the fixer instead
{% if not pillar.get('is_systemd') %}
    - watch:
      - file: {{ environment_file }}
{% endif %}
    - require:
      - file: {{ environment_file }}
