{% from "kubernetes/map.jinja" import config with context %}

bridge-utils:
  pkg.installed

docker:
# Starting Docker is racy on aws for some reason.  To be honest, since Monit
# is managing Docker restart we should probably just delete this whole thing
# but the kubernetes components use salt 'require' to set up a dag, and that
# complicated and scary to unwind.
# On AWS, we use a trick now... We don't start the docker service through Salt.
# Kubelet or our health checker will start it.  But we use service.enabled,
# so we still have a `service: docker` node for our DAG.
{% if grains.cloud is defined and grains.cloud == 'aws' %}
  service.enabled
{% else %}
  service.running:
    - enable: True
{% endif %}

