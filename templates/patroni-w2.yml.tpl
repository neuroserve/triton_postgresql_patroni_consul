scope: ${consul_scope}
namespace: ${consul_namespace}
name: ${hostname}

restapi:
  listen: ${listen_ip}:8008
  connect_address: ${listen_ip}:8008

consul:
  host: localhost:8500
  register_service: true

citus:
  group: 2
  database: citus

bootstrap:
  dcs:
    ttl: 30
    loop_wait: 10
    retry_timeout: 10
    maximum_lag_on_failover: 1048576
    postgresql:
      use_pg_rewind: true
      parameters:

  # some desired options for 'initdb'
  initdb:  # Note: It needs to be a list (some options need values, others are switches)
  - encoding: UTF8
  - data-checksums

  pg_hba:  # Add following lines to pg_hba.conf after running 'initdb'
  - host replication replicator 127.0.0.1/32 md5
  - host replication replicator 192.168.129.0/22 md5
  - host all all 0.0.0.0/0 md5

  # Additional script to be launched after initial cluster creation (will be passed the connection URL as parameter)
# post_init: /usr/local/bin/setup_cluster.sh

  # Some additional users users which needs to be created after initializing new cluster
  users:
    admin:
      password: ${admin_password}
      options:
        - createrole
        - createdb

postgresql:
  listen: "*:5432"
  connect_address: ${listen_ip}:5432
  data_dir: /var/pgsql/data
  pgpass: /tmp/pgpass0
  authentication:
    replication:
      username: replicator
      password: rep-pass
    superuser:
      username: postgres
      password: ${admin_password}
    rewind:  # Has no effect on postgres 10 and lower
      username: rewind_user
      password: rewind_password
  parameters:
    unix_socket_directories: '.'

tags:
    nofailover: false
    noloadbalance: false
    clonefrom: false
    nosync: false
