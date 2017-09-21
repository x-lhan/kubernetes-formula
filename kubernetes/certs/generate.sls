{% from "kubernetes/map.jinja" import config with context %}

{% set master_extra_sans=config.get('master_extra_sans') + ",DNS:" + config.api_server.fqdn %}

openssl:
  pkg.installed: []

curl:
  pkg.installed: []

generate-certs:
  cmd.script:
    - source: salt://kubernetes/certs/generate-certs.sh
    - args: {{master_extra_sans}}
    - cwd: /
    - user: root
    - group: root
    - shell: /bin/bash
    - require:
      - pkg: openssl 
      - pkg: curl

view-all-certs-as-configurable-certs-pillar:
  cmd.run:
    - name: >
        {% for cert in config.certs_files %}echo '"{{cert}}": |' && sed -e 's/^/    /' {{cert}};{% endfor %}
    - cwd: /tmp/kubernetes/

/tmp/kubernetes:
  file.absent