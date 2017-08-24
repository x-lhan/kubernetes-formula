{% if salt["service.status"]("kubelet") %}
ensure-kubelet-service-stopped:
  service.dead:
    - name: kubelet
{% endif %}