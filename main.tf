provider "triton" {
  insecure_skip_tls_verify = false
}

resource "random_password" "admin_password" {
    length = 32
    special = false
}

## Create the Consul certificates
#resource "tls_private_key" "consul" {
#    count = var.config.vm.replicas
#    algorithm = "RSA"
#    rsa_bits  = "4096"
#}

## Create the request to sign the cert with our CA
#resource "tls_cert_request" "consul-req" {
#    count = var.config.vm.replicas
#    # key_algorithm   = tls_private_key.consul[count.index].algorithm
#    private_key_pem = tls_private_key.consul[count.index].private_key_pem
#
#    dns_names = [
#        "consul",
#        "consul.local",
#    ]
#
#    subject {
#        common_name  = "consul.local"
#        organization = var.config.organization.name
#    }
#}

#resource "tls_locally_signed_cert" "consul" {
#    count = var.config.vm.replicas
#    cert_request_pem = tls_cert_request.consul-req[count.index].cert_request_pem
#
#    # ca_key_algorithm   = var.config.certificate_authority.algorithm
#    ca_private_key_pem = var.config.certificate_authority.private_key_pem
#    ca_cert_pem        = var.config.certificate_authority.certificate_pem
#
#    validity_period_hours = 8760
#
#    allowed_uses = [
#        "cert_signing",
#        "client_auth",
#        "digital_signature",
#        "key_encipherment",
#        "server_auth",
#    ]
#}

data "triton_image" "os" {
    name = "postgresql14-patroni-consul"
    version = var.config.image_version
}

resource "triton_machine" "postgresql-c" {
    count = var.config.vm.creplicas
    name = "postgresql-citus-control-${count.index}"
    package = "sample-2G"

    image = data.triton_image.os.id

    cns {
        services = ["postgresql"]
    }

    networks = var.config.machine_networks

    tags = {
        role = "postgresql"
        "tritoncli.ssh.proxy" = "bast2"
    }
    
    affinity = ["role!=~postgresql"]

    connection {
       type = "ssh"
       user = "root" 
       private_key = "${file("~/.ssh/sdc-docker-hbloed.id_rsa")}"
       agent = "true" 
       bastion_host = "10.65.69.143"
       bastion_user = "root" 
       bastion_private_key = "${file("~/.ssh/sdc-docker-hbloed.id_rsa")}"
       host = self.primaryip
    }

#    provisioner "remote-exec" {
#        inline = [
#            "mkdir -p /opt/local/etc/consul.d/certificates",
#            # "chown consul /opt/local/etc/consul.d/certificates",
#            # "chgrp consul /opt/local/etc/consul.d/certificates",
#        ]
#    }

#    provisioner "file" {
#        content = var.config.certificate_authority.certificate_pem
#        destination = "/opt/local/etc/consul.d/certificates/ca.pem"
#    }

#    provisioner "file" {
#        content = tls_locally_signed_cert.consul[count.index].cert_pem
#        destination = "/opt/local/etc/consul.d/certificates/cert.pem"
#    }

#    provisioner "file" {
#        content = tls_private_key.consul[count.index].private_key_pem
#        destination = "/opt/local/etc/consul.d/certificates/private_key.pem"
#    }

    provisioner "file" {
        content = templatefile("${path.module}/templates/consul.hcl.tpl", {
            datacenter_name = var.config.consul_datacenter_name,
            node_name = "postgresql-citus-control-${count.index}"
            consul_addr = var.config.consul_addr,
            encryption_key = var.config.consul_encryption_key,
        })
        destination = "/opt/local/etc/consul.d/consul.hcl"
    }

    provisioner "remote-exec" {
        inline = [
            "svcadm enable consul",
        ]
    }

    provisioner "file" {
        content = templatefile("${path.module}/templates/patroni-c.yml.tpl", {
            hostname = "postgresql-citus-control-${count.index}"
            consul_addr = var.config.consul_addr
            consul_scope = var.config.consul_scope
            consul_namespace = var.config.consul_namespace
            admin_password = random_password.admin_password.result
            listen_ip = self.primaryip
        })
        destination = "/var/pgsql/patroni.yml"
    }

    provisioner "remote-exec" {
        inline = [
            "chown postgres /var/pgsql/patroni.yml",
            "chgrp postgres /var/pgsql/patroni.yml",

            "svcadm enable patroni",
        ]
    }
}

resource "triton_machine" "postgresql-w1" {
    count = var.config.vm.wcluster1
    name = "postgresql-citus-wcluster1-${count.index}"
    package = "sample-8G"

    image = data.triton_image.os.id

    cns {
        services = ["postgresql"]
    }

    networks = var.config.machine_networks

    tags = {
        role = "postgresql"
        "tritoncli.ssh.proxy" = "bast2"
    }

    affinity = ["role!=~postgresql"]

    connection {
       type = "ssh"
       user = "root"
       private_key = "${file("~/.ssh/sdc-docker-hbloed.id_rsa")}"
       agent = "true"
       bastion_host = "10.65.69.143"
       bastion_user = "root"
       bastion_private_key = "${file("~/.ssh/sdc-docker-hbloed.id_rsa")}"
       host = self.primaryip
    }

    provisioner "file" {
        content = templatefile("${path.module}/templates/consul.hcl.tpl", {
            datacenter_name = var.config.consul_datacenter_name,
            node_name = "postgresql-citus-wcluster1-${count.index}"
            consul_addr = var.config.consul_addr,
            encryption_key = var.config.consul_encryption_key,
        })
        destination = "/opt/local/etc/consul.d/consul.hcl"
    }

    provisioner "remote-exec" {
        inline = [
            "svcadm enable consul",
        ]
    }

    provisioner "file" {
        content = templatefile("${path.module}/templates/patroni-w1.yml.tpl", {
            hostname = "postgresql-citus-wcluster1-${count.index}"
            consul_addr = var.config.consul_addr
            consul_scope = var.config.consul_scope
            consul_namespace = var.config.consul_namespace
            admin_password = random_password.admin_password.result
            listen_ip = self.primaryip
        })
        destination = "/var/pgsql/patroni.yml"
    }

    provisioner "remote-exec" {
        inline = [
            "chown postgres /var/pgsql/patroni.yml",
            "chgrp postgres /var/pgsql/patroni.yml",

            "svcadm enable patroni",
        ]
    }
}

resource "triton_machine" "postgresql-w2" {
    count = var.config.vm.wcluster2
    name = "postgresql-citus-wcluster2-${count.index}"
    package = "sample-8G"

    image = data.triton_image.os.id

    cns {
        services = ["postgresql"]
    }

    networks = var.config.machine_networks

    tags = {
        role = "postgresql"
        "tritoncli.ssh.proxy" = "bast2"
    }

    affinity = ["role!=~postgresql"]

    connection {
       type = "ssh"
       user = "root"
       private_key = "${file("~/.ssh/sdc-docker-hbloed.id_rsa")}"
       agent = "true"
       bastion_host = "10.65.69.143"
       bastion_user = "root"
       bastion_private_key = "${file("~/.ssh/sdc-docker-hbloed.id_rsa")}"
       host = self.primaryip
    }

    provisioner "file" {
        content = templatefile("${path.module}/templates/consul.hcl.tpl", {
            datacenter_name = var.config.consul_datacenter_name,
            node_name = "postgresql-citus-wcluster2-${count.index}"
            consul_addr = var.config.consul_addr,
            encryption_key = var.config.consul_encryption_key,
        })
        destination = "/opt/local/etc/consul.d/consul.hcl"
    }

    provisioner "remote-exec" {
        inline = [
            "svcadm enable consul",
        ]
    }

    provisioner "file" {
        content = templatefile("${path.module}/templates/patroni-w2.yml.tpl", {
            hostname = "postgresql-citus-wcluster2-${count.index}"
            consul_addr = var.config.consul_addr
            consul_scope = var.config.consul_scope
            consul_namespace = var.config.consul_namespace
            admin_password = random_password.admin_password.result
            listen_ip = self.primaryip
        })
        destination = "/var/pgsql/patroni.yml"
    }

    provisioner "remote-exec" {
        inline = [
            "chown postgres /var/pgsql/patroni.yml",
            "chgrp postgres /var/pgsql/patroni.yml",

            "svcadm enable patroni",
        ]
    }
}

resource "triton_machine" "postgresql-w3" {
    count = var.config.vm.wcluster3
    name = "postgresql-citus-wcluster3-${count.index}"
    package = "sample-8G"

    image = data.triton_image.os.id

    cns {
        services = ["postgresql"]
    }

    networks = var.config.machine_networks

    tags = {
        role = "postgresql"
        "tritoncli.ssh.proxy" = "bast2"
    }

    affinity = ["role!=~postgresql"]

    connection {
       type = "ssh"
       user = "root"
       private_key = "${file("~/.ssh/sdc-docker-hbloed.id_rsa")}"
       agent = "true"
       bastion_host = "10.65.69.143"
       bastion_user = "root"
       bastion_private_key = "${file("~/.ssh/sdc-docker-hbloed.id_rsa")}"
       host = self.primaryip
    }

    provisioner "file" {
        content = templatefile("${path.module}/templates/consul.hcl.tpl", {
            datacenter_name = var.config.consul_datacenter_name,
            node_name = "postgresql-citus-wcluster3-${count.index}"
            consul_addr = var.config.consul_addr,
            encryption_key = var.config.consul_encryption_key,
        })
        destination = "/opt/local/etc/consul.d/consul.hcl"
    }

    provisioner "remote-exec" {
        inline = [
            "svcadm enable consul",
        ]
    }

    provisioner "file" {
        content = templatefile("${path.module}/templates/patroni-w3.yml.tpl", {
            hostname = "postgresql-citus-wcluster3-${count.index}"
            consul_addr = var.config.consul_addr
            consul_scope = var.config.consul_scope
            consul_namespace = var.config.consul_namespace
            admin_password = random_password.admin_password.result
            listen_ip = self.primaryip
        })
        destination = "/var/pgsql/patroni.yml"
    }

    provisioner "remote-exec" {
        inline = [
            "chown postgres /var/pgsql/patroni.yml",
            "chgrp postgres /var/pgsql/patroni.yml",

            "svcadm enable patroni",
        ]
    }
}

resource "triton_machine" "postgresql-w4" {
    count = var.config.vm.wcluster4
    name = "postgresql-citus-wcluster4-${count.index}"
    package = "sample-8G"

    image = data.triton_image.os.id

    cns {
        services = ["postgresql"]
    }

    networks = var.config.machine_networks

    tags = {
        role = "postgresql"
        "tritoncli.ssh.proxy" = "bast2"
    }

    affinity = ["role!=~postgresql"]

    connection {
       type = "ssh"
       user = "root"
       private_key = "${file("~/.ssh/sdc-docker-hbloed.id_rsa")}"
       agent = "true"
       bastion_host = "10.65.69.143"
       bastion_user = "root"
       bastion_private_key = "${file("~/.ssh/sdc-docker-hbloed.id_rsa")}"
       host = self.primaryip
    }

    provisioner "file" {
        content = templatefile("${path.module}/templates/consul.hcl.tpl", {
            datacenter_name = var.config.consul_datacenter_name,
            node_name = "postgresql-citus-wcluster4-${count.index}"
            consul_addr = var.config.consul_addr,
            encryption_key = var.config.consul_encryption_key,
        })
        destination = "/opt/local/etc/consul.d/consul.hcl"
    }

    provisioner "remote-exec" {
        inline = [
            "svcadm enable consul",
        ]
    }

    provisioner "file" {
        content = templatefile("${path.module}/templates/patroni-w4.yml.tpl", {
            hostname = "postgresql-citus-wcluster4-${count.index}"
            consul_addr = var.config.consul_addr
            consul_scope = var.config.consul_scope
            consul_namespace = var.config.consul_namespace
            admin_password = random_password.admin_password.result
            listen_ip = self.primaryip
        })
        destination = "/var/pgsql/patroni.yml"
    }

    provisioner "remote-exec" {
        inline = [
            "chown postgres /var/pgsql/patroni.yml",
            "chgrp postgres /var/pgsql/patroni.yml",

            "svcadm enable patroni",
        ]
    }
}
