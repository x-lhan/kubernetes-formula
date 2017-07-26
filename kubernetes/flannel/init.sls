{% if pillar.kubernetes.master is defined %}

ensure-docker-service-running:
  service.running:
    - name: docker

ensure-kubelet-service-running:
  service.running:
    - name: kubelet

/etc/kubernetes/kube-flannel.yml:
  file.managed:
    - source: salt://kubernetes/flannel/kube-flannel.yml
    - template: jinja
    - user: root
    - group: root
    - mode: 644
    - makedirs: true
    - dir_mode: 755
    - require:
      - service: ensure-docker-service-running
      - service: ensure-kubelet-service-running

deploy-flannel-daemonset:
  cmd.run:
    - require:
      - file: /etc/kubernetes/kube-flannel.yml
    - name:  hyperkube kubectl apply -f /etc/kubernetes/kube-flannel.yml
    - watch:
      - file: /etc/kubernetes/kube-flannel.yml
{% endif %}


