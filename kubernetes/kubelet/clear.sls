{% if salt["service.status"]("kubelet") %}
ensure-kubelet-service-stopped:
  service.dead:
    - name: kubelet

remove-all-containers:
  cmd.run:
    - name: docker rm -f $(docker ps -a -q)
    - shall: bash
{% endif %}