{% from "kubernetes/map.jinja" import config with context %}

# group used for managing kubernetes certificates
kube-cert:
  group.present:
    - system: True

{% if config.certs is defined %}
# Copy certificates into /srv/kubernetes to be used by system components
{% for name in config.certs_files %} 
/srv/kubernetes/{{ name }}:
  file.managed:
    - mode: 660
    - user: root
    - group: kube-cert
    - makedirs: true
    - contents: |
        {{ config.certs[name] | indent(8) }}   
{% endfor %}
{% else %}
# The certs are not in the pillar! This state should fail
certs-not-in-pillar:
  test.configurable_test_state:
    - comment: "You must include certificates in the pillar"
    - result: False
    - changes: False
{% endif %}

# Installs the certificate into the machine global certificate list
sys-install-kubernetes-ca:
  file.managed:
    - source: /srv/kubernetes/ca.crt
    - name: /usr/local/share/ca-certificates/kubernetes-ca.crt
    - user: root
    - group: root
    - mode: "0644"
  cmd.run:
    - name: update-ca-certificates
    - unless:
      - "cat /etc/ssl/certs/ca-certificates.crt | tr -d \" \\t\\n\\r\" | grep -q -- \"`cat /usr/local/share/ca-certificates/kubernetes-ca.crt`\""
    - require:
      - file: sys-install-kubernetes-ca
