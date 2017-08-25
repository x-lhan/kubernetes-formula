{% from "kubernetes/map.jinja" import config with context %}

/tmp/hyperkube:
  file.directory:
    - user: root
    - group: root

/usr/bin/nsenter:
  cmd.run:
    - unless: test -f /usr/bin/nsenter
    - name: docker run --rm -v /tmp/hyperkube:/target jpetazzo/nsenter
    - require:
      - file: /tmp/hyperkube
  file.managed:
    - unless: test -f /usr/bin/nsenter
    - source: /tmp/hyperkube/nsenter
    - mode: 755
    - makedirs: true
    - user: root
    - group: root
    - require:
      - cmd: /usr/bin/nsenter

/usr/local/bin/hyperkube:
  cmd.run:
    - unless: test -f /usr/local/bin/hyperkube
    - name: docker run --rm -v /tmp/hyperkube:/tmp/hyperkube --entrypoint cp {{ config.hyperkube_image }}:{{ config.version }} -vr /hyperkube /tmp/hyperkube
    - require:
      - file: /tmp/hyperkube
    {%- if grains.get('noservices') %}
    - onlyif: /bin/false
    {%- endif %}
  file.managed:
    - unless: test -f /usr/local/bin/hyperkube
    - source: /tmp/hyperkube/hyperkube
    - mode: 755
    - makedirs: true
    - user: root
    - group: root
    - require:
      - cmd: /usr/local/bin/hyperkube