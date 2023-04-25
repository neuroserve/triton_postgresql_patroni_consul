{
    "datacenter": "${datacenter_name}",
    "data_dir": "/opt/local/consul",
    "log_level": "INFO",
    "node_name": "${node_name}",
    "server": false,
    "leave_on_terminate": true,
    "bind_addr": "{{ GetInterfaceIP \"net0\" }}"
}
