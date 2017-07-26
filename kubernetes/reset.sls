{% if pillar.kubernetes.master is defined %}

reset-kube_system-pods:
  cmd.run:
    - name:  hyperkube kubectl -n kube-system delete po --all

{% endif %}