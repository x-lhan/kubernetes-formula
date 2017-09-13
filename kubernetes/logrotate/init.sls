{% set logrotate_files = ['kube-scheduler', 'kube-proxy', 'kubelet', 'kube-apiserver', 'kube-apiserver-audit', 'kube-controller-manager', 'kube-addon-manager', 'docker', 'rescheduler'] %}
{% for file in logrotate_files %}
/etc/logrotate.d/{{ file }}:
  file:
    - managed
    - source: salt://kubernetes/logrotate/conf
    - template: jinja
    - user: root
    - group: root
    - mode: 644
    - context:
      file: {{ file }}
{% endfor %}

/etc/logrotate.d/docker-containers:
  file:
    - managed
    - source: salt://kubernetes/logrotate/docker-containers
    - template: jinja
    - user: root
    - group: root
    - mode: 644

/etc/cron.hourly/logrotate:
  file:
    - managed
    - source: salt://kubernetes/logrotate/cron
    - template: jinja
    - user: root
    - group: root
    - mode: 755
