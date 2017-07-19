{% from "kubernetes/map.jinja" import config with context %}
kube-cert:
  group.present:
    - system: True
{% if config.certs is defined %}
{% for name, cert in config.certs.items() %} 
/srv/kubernetes/{{ name }}:
  file.managed:
    - mode: 660
    - user: root
    - group: kube-cert
    - makedirs: true
    - contents: |
        {{ cert| indent(8) }}   
{% endfor %}

{% else %}
{% if grains.cloud is defined %}
  {% if grains.cloud == 'gce' %}
    {% set cert_ip='_use_gce_external_ip_' %}
  {% endif %}
  {% if grains.cloud == 'aws' %}
    {% set cert_ip='_use_aws_external_ip_' %}
  {% endif %}
  {% if grains.cloud == 'azure-legacy' %}
    {% set cert_ip='_use_azure_dns_name_' %}
  {% endif %}
  {% if grains.cloud == 'photon-controller' %}
    {% set cert_ip=grains.ip_interfaces.eth0[0] %}
  {% endif %}
{% endif %}

{% set cert_ip = salt['mine.get']('kubernetes:master', 'network.internal_ip', 'pillar').values()[0] %}
{% set master_extra_sans=config.get('master_extra_sans', 'DNS:kubernetes,DNS:kubernetes.default,DNS:kubernetes.default.svc,DNS:kubernetes.default.svc.cluster.local') %}

# If there is a config defined, override any defaults.
{% if config['cert_ip'] is defined %}
  {% set cert_ip=config['cert_ip'] %}
{% endif %}

{% set certgen="make-cert.sh" %}
{% if cert_ip is defined %}
  {% set certgen="make-ca-cert.sh" %}
{% endif %}

openssl:
  pkg.installed: []



kubernetes-cert:
  cmd.script:
    - unless: test -f /srv/kubernetes/server.cert
    - source: salt://kubernetes/generate-cert/{{certgen}}
{% if cert_ip is defined %}
    - args: {{cert_ip}} {{master_extra_sans}}
    - require:
      - pkg: curl
{% endif %}
    - cwd: /
    - user: root
    - group: root
    - shell: /bin/bash
    - require:
      - pkg: openssl
{% endif %}
sys-install-kubernates-ca:
  file.managed:
    - unless: test -f /usr/local/share/ca-certificates/kubernetes-ca.crt
    - source: /srv/kubernetes/ca.crt
    - name: /usr/local/share/ca-certificates/kubernates-ca.crt
    - user: root
    - group: root
    - mode: "0644"
  cmd.run:
    - name: update-ca-certificates
    - unless:
      - "cat /etc/ssl/certs/ca-certificates.crt | tr -d \" \\t\\n\\r\" | grep -q -- \"`cat /usr/local/share/ca-certificates/kubernates-ca.crt`\""
    - require:
      - file: sys-install-kubernates-ca


