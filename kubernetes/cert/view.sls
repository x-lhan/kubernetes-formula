{% from "kubernetes/map.jinja" import config with context %}

view-all-certs-as-configurable-certs-pillar:
  cmd.run:
    - name: >
        {% for cert in config.certs_files %}echo '"{{cert}}": |' && sed -e 's/^/    /' {{cert}};{% endfor %}
    - cwd: /srv/kubernetes/