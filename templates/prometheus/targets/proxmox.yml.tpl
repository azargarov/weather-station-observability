- targets:
    - ${PROXMOX_NODE_EXPORTER_TARGET}
  labels:
    env: ${ENV_NAME}
    host: ${PROXMOX_HOST_LABEL}