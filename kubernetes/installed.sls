{% from "kubernetes/map.jinja" import config with context %}

pkg-core:
  pkg.installed:
    - names:
      - curl
      - ebtables
      - logrotate
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