{% from "kubernetes/map.jinja" import config with context %}

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

{% if pillar.kubernetes.master is defined and config.get("minion_id_as_hostname", false) -%}
{% for server, addrs in config.master_nodes.items() %}
ensure-master-node-{{server}}-fqdn-exist:
  host.present:
    - ip: {{ addrs }}
    - names:
      - {{ server }}
{% endfor %}

{% for server, addrs in config.pool_nodes.items() %}
ensure-pool-node-{{server}}-fqdn-exist:
  host.present:
    - ip: {{ addrs }}
    - names:
      - {{ server }}
{% endfor %}
{% endif %}



