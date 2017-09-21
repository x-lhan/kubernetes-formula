include:
  - .installed

/etc/kubernetes/manifests/etcd.manifest:
  file.managed:
    - source: salt://kubernetes/etcd/etcd.manifest
    - template: jinja
    - user: root
    - group: root
    - mode: 644
    - makedirs: true
    - dir_mode: 755
    - context:
        suffix: ""
        port: 2379
        server_port: 2380
        cpulimit: '"200m"'

/etc/kubernetes/manifests/etcd-events.manifest:
  file.managed:
    - source: salt://kubernetes/etcd/etcd.manifest
    - template: jinja
    - user: root
    - group: root
    - mode: 644
    - makedirs: true
    - dir_mode: 755
    - context:
        suffix: "-events"
        port: 4002
        server_port: 2381
        cpulimit: '"100m"'
