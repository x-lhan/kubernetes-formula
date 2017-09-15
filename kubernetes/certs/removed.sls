{% from "kubernetes/map.jinja" import config with context %}
remove-generated-ca-crt:
  file.absent: 
    - onlyif: test -f /usr/local/share/ca-certificates/kubernetes-ca.crt
    - name: /usr/local/share/ca-certificates/kubernates-ca.crt
  cmd.run:
    - name: update-ca-certificates
    - require:
      - file: remove-generated-ca-crt

{% for file in config.certs_files %}
remove-generated-{{ file }}:
  file.absent: 
    - name: /srv/kubernetes/{{ file }}
{% endfor %}

remove-kubernetes-certificate:
  file.absent:
    - name: /usr/local/share/ca-certificates/kubernetes-ca.crt

remove-kubernetes-cert-from-sys-list:
  cmd.run:
    - name: update-ca-certificates
    - require:
      - file: remove-kubernetes-certificate