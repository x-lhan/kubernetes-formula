include:
  - .installed

etcd-data-directory:
  file.directory:
    - name: /mnt/master-pd/var/etcd
    - makedirs: True

etcd-cluster-member-restored:
  file.managed:
    - name: /tmp/etcd-cluster-restore.sh
    - source: salt://kubernetes/etcd/etcd-restore.sh
    - user: root
    - group: root
    - mode: 711
    - template: jinja
    - context:
        suffix: ""
        server_port: 2380
  cmd.run:
    - name: /tmp/etcd-cluster-restore.sh
    - onlyif: test -f /mnt/etcd/snapshot.db
    - unless: test -d /mnt/master-pd/var/etcd/data


etcd-events-cluster-member-restored:
  file.managed:
    - name: /tmp/etcd-events-cluster-restore.sh
    - source: salt://kubernetes/etcd//etcd-restore.sh
    - user: root
    - group: root
    - mode: 711
    - template: jinja
    - context:
        suffix: "-events"
        server_port: 2381
  cmd.run:
    - name: /tmp/etcd-events-cluster-restore.sh
    - onlyif: test -f /mnt/etcd/snapshot-events.db
    - unless: test -d /mnt/master-pd/var/etcd/data-events
    