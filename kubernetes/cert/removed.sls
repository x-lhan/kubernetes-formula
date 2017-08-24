{% set certs_filenames = ['ca.crt', 'server.key', 'server.cert', 'kubecfg.key', 'kubecfg.crt'] %}
remove-generated-ca-crt:
  file.absent: 
    - onlyif: test -f /usr/local/share/ca-certificates/kubernetes-ca.crt
    - name: /usr/local/share/ca-certificates/kubernates-ca.crt
  cmd.run:
    - name: update-ca-certificates
    - require:
      - file: remove-generated-ca-crt

{% for file in certs_filenames %}
remove-generated-{{ file }}:
  file.absent: 
    - name: /srv/kubernetes/{{ file }}
{% endfor %}
