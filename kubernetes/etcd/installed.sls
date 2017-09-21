{% from "kubernetes/map.jinja" import config with context %}

touch /var/log/etcd.log:
  cmd.run:
    - creates: /var/log/etcd.log

touch /var/log/etcd-events.log:
  cmd.run:
    - creates: /var/log/etcd-events.log



{% set etcd_name = "etcd-v" + config.etcd_version + "-linux-amd64" -%}
{% set etcd_archive_name = etcd_name + ".tar.gz" -%}
{% set etcd_package_url = "v" + config.etcd_version + "/" + etcd_archive_name -%}

etcd-directory:
  file.directory:
    - name: /tmp/etcd
    - makedirs: True
    
etcd-download:
  cmd.run:
    - name: curl -L -s {{ config.etcd_install_base_url }}/{{ etcd_package_url }} -o {{ etcd_archive_name }}
    - cwd: /tmp/etcd
    - unless: test -f  /usr/local/bin/etcdctl

etcd-extract:
  cmd.run:
    - name: tar xzf {{ etcd_archive_name }} --strip-components 1
    - cwd:  /tmp/etcd
    - unless: test -f /usr/local/bin/etcdctl
etcdctl-installed:
  file.managed:
    - name: /usr/local/bin/etcdctl
    - source: /tmp/etcd/etcdctl
    - user: root
    - group: root
    - mode: 711
    - unless: test -f /usr/local/bin/etcdctl

    
/var/etcd:
  file.directory:
    - user: root
    - group: root
    - dir_mode: 700
    - recurse:
      - user
      - group
      - mode