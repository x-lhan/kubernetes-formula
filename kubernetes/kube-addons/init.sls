{% from "kubernetes/map.jinja" import config with context %}
{% if config.get("reset_addons", false) %}
addon-dir-delete:
  file.absent:
    - name: /etc/kubernetes/addons
{% endif %}

addon-dir-create:
  file.directory:
    - name: /etc/kubernetes/addons
    - user: root
    - group: root
    - mode: 0755
{% if config.get("reset_addons", false) %}
    - require:
        - file: addon-dir-delete
{% endif %}
        

{% if config.get('enable_cluster_monitoring', '').lower() == 'influxdb' %}
/etc/kubernetes/addons/cluster-monitoring/influxdb:
  file.recurse:
    - source: salt://kubernetes/kube-addons/cluster-monitoring/influxdb
    - include_pat: E@(^.+\.yaml$|^.+\.json$)
    - template: jinja
    - user: root
    - group: root
    - dir_mode: 755
    - file_mode: 644
{% endif %}

{% if config.get('enable_l7_loadbalancing', '').lower() == 'glbc' %}
/etc/kubernetes/addons/cluster-loadbalancing/glbc:
  file.recurse:
    - source: salt://kubernetes/kube-addons/cluster-loadbalancing/glbc
    - include_pat: E@(^.+\.yaml$|^.+\.json$)
    - template: jinja
    - user: root
    - group: root
    - dir_mode: 755
    - file_mode: 644
{% endif %}

{% if config.get('enable_cluster_monitoring', '').lower() == 'google' %}
/etc/kubernetes/addons/cluster-monitoring/google:
  file.recurse:
    - source: salt://kubernetes/kube-addons/cluster-monitoring/google
    - include_pat: E@(^.+\.yaml$|^.+\.json$)
    - template: jinja
    - user: root
    - group: root
    - dir_mode: 755
    - file_mode: 644
{% endif %}

{% if config.get('enable_cluster_monitoring', '').lower() == 'standalone' %}
/etc/kubernetes/addons/cluster-monitoring/standalone:
  file.recurse:
    - source: salt://kubernetes/kube-addons/cluster-monitoring/standalone
    - include_pat: E@(^.+\.yaml$|^.+\.json$)
    - template: jinja
    - user: root
    - group: root
    - dir_mode: 755
    - file_mode: 644
{% endif %}

{% if config.get('enable_cluster_monitoring', '').lower() == 'googleinfluxdb' %}
/etc/kubernetes/addons/cluster-monitoring/googleinfluxdb:
  file.recurse:
    - source: salt://kubernetes/kube-addons/cluster-monitoring
    - include_pat: E@(^.+\.yaml$|^.+\.json$)
    - exclude_pat: E@(^.+heapster-controller\.yaml$|^.+heapster-controller\.json$)
    - template: jinja
    - user: root
    - group: root
    - dir_mode: 755
    - file_mode: 644
{% endif %}

{% if config.enable_cluster_dns is defined and config.enable_cluster_dns %}
/etc/kubernetes/addons/dns/kubedns-svc.yaml:
  file.managed:
    - source: salt://kubernetes/kube-addons/dns/kubedns-svc.yaml.in
    - template: jinja
    - group: root
    - dir_mode: 755
    - makedirs: True

/etc/kubernetes/addons/dns/kubedns-controller.yaml:
  file.managed:
    - source: salt://kubernetes/kube-addons/dns/kubedns-controller.yaml.in
    - template: jinja
    - group: root
    - dir_mode: 755
    - makedirs: True

/etc/kubernetes/addons/dns/kubedns-sa.yaml:
  file.managed:
    - source: salt://kubernetes/kube-addons/dns/kubedns-sa.yaml
    - user: root
    - group: root
    - file_mode: 644
    - makedirs: True

/etc/kubernetes/addons/dns/kubedns-cm.yaml:
  file.managed:
    - source: salt://kubernetes/kube-addons/dns/kubedns-cm.yaml
    - template: jinja
    - user: root
    - group: root
    - file_mode: 644
    - makedirs: True
{% endif %}

{% if config.enable_dns_horizontal_autoscaler is defined and config.enable_dns_horizontal_autoscaler
   and config.enable_cluster_dns is defined and config.enable_cluster_dns %}
/etc/kubernetes/addons/dns-horizontal-autoscaler/dns-horizontal-autoscaler.yaml:
  file.managed:
    - source: salt://kubernetes/kube-addons/dns-horizontal-autoscaler/dns-horizontal-autoscaler.yaml
    - user: root
    - group: root
    - file_mode: 644
    - makedirs: True
{% endif %}

{% if config.enable_cluster_registry %}
/etc/kubernetes/addons/registry/registry-svc.yaml:
  file.managed:
    - source: salt://kubernetes/kube-addons/registry/registry-svc.yaml
    - template: jinja
    - user: root
    - group: root
    - file_mode: 644
    - makedirs: True

/etc/kubernetes/addons/registry/registry-rc.yaml:
  file.managed:
    - source: salt://kubernetes/kube-addons/registry/registry-rc.yaml
    - user: root
    - group: root
    - file_mode: 644
    - makedirs: True

/etc/kubernetes/addons/registry/registry-pvc.yaml:
  file.managed:
    - source: salt://kubernetes/kube-addons/registry/registry-pvc.yaml.in
    - template: jinja
    - user: root
    - group: root
    - file_mode: 644
    - makedirs: True
{% endif %}

{% if config.enable_etcd_snapshot and config.storage_backend == 'etcd3' %}
/etc/kubernetes/addons/etcd-snapshot/etcd-snapshot-pvc.yaml:
  file.managed:
    - source: salt://kubernetes/kube-addons/etcd-snapshot/etcd-snapshot-pvc.yaml
    - template: jinja
    - user: root
    - group: root
    - file_mode: 644
    - makedirs: True
/etc/kubernetes/addons/etcd-snapshot/etcd-snapshot-job.yaml:
  file.managed:
    - source: salt://kubernetes/kube-addons/etcd-snapshot/etcd-snapshot-job.yaml
    - template: jinja
    - user: root
    - group: root
    - file_mode: 644
    - makedirs: True

{% endif %}

{% if config.enable_cluster_ui is defined and config.enable_cluster_ui %}
/etc/kubernetes/addons/dashboard:
  file.recurse:
    - source: salt://kubernetes/kube-addons/dashboard 
    - template: jinja
    - include_pat: E@^.+\.yaml$
    - user: root
    - group: root
    - dir_mode: 755
    - file_mode: 644
{% endif %}

{% if config.get('network_provider', '').lower() == 'cni' %}

{% if config.get('cni_provider', '').lower() == 'flannel' %}

/etc/kubernetes/addons/flannel/kube-flannel.yaml:
  file.managed:
    - source: salt://kubernetes/kube-addons/flannel/kube-flannel.yaml 
    - template: jinja
    - user: root
    - group: root
    - dir_mode: 755
    - file_mode: 644
    - makedirs: True

{% elif config.get('cni_provider', '').lower() == 'canal' %}
/etc/kubernetes/addons/canal/kube-canal.yaml:
  file.managed:
    - source: salt://kubernetes/kube-addons/canal/kube-canal.yaml 
    - template: jinja
    - user: root
    - group: root
    - dir_mode: 755
    - file_mode: 644
    - makedirs: True

{% endif %}

{% endif %}


/etc/kubernetes/manifests/kube-addon-manager.yaml:
  file.managed:
    - template: jinja
    - source: salt://kubernetes/kube-addons/kube-addon-manager.yaml
    - user: root
    - group: root
    - mode: 755
{% if config.enable_default_storage_class and grains['cloud'] is defined and grains['cloud'] in ['aws', 'gce', 'openstack'] %}
/etc/kubernetes/addons/storage-class/default.yaml:
  file.managed:
    - source: salt://kubernetes/kube-addons/storage-class/{{ grains['cloud'] }}/default.yaml
    - template: jinja
    - user: root
    - group: root
    - mode: 644
    - makedirs: True
{% endif %}