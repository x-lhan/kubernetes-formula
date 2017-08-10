{% from "kubernetes/map.jinja" import config with context %}

pkg-core:
  pkg.installed:
    - names:
      - curl
      - ebtables
{% if grains['os_family'] == 'RedHat' %}
      - python
      - git
      - socat
{% else %}
      - apt-transport-https
      - python-apt
      - nfs-common
      - socat
{% endif %}
# Ubuntu installs netcat-openbsd by default, but on GCE/Debian netcat-traditional is installed.
# They behave slightly differently.
# For sanity, we try to make sure we have the same netcat on all OSes (#15166)
{% if grains['os'] == 'Ubuntu' %}
      - netcat-traditional
{% endif %}
# Make sure git is installed for mounting git volumes
{% if grains['os'] == 'Ubuntu' %}
      - git
{% endif %}

# Fix ARP cache issues on AWS by setting net.ipv4.neigh.default.gc_thresh1=0
# See issue #23395
{% if grains.get('cloud') == 'aws' %}
# Work around Salt #18089: https://github.com/saltstack/salt/issues/18089
# (we also have to give it a different id from the same fix elsewhere)
99-salt-conf-with-a-different-id:
  file.touch:
    - unless: test -f /etc/sysctl.d/99-salt.conf
    - name: /etc/sysctl.d/99-salt.conf

net.ipv4.neigh.default.gc_thresh1:
  sysctl.present:
    - value: 0
{% endif %}

ensure-api_server-fqdn-exist:
  host.present:
    - ip: {{ config.api_server.ip }}
    - names:
      - {{ config.api_server.fqdn }}

{% if pillar.kubernetes.master is defined -%}
{% for server, addrs in config.pool_nodes.items() %}
ensure-pool-node-{{server}}-fqdn-exist:
  host.present:
    - ip: {{ addrs }}
    - names:
      - {{ server }}
{% endfor %}
{% endif %}



