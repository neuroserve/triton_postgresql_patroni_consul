resource "random_password" "admin_password" {
    length = 32
    special = false
}

data "triton_image" "os" {
    name = "postgresql12-patroni"
    version = "20210815"
}

resource "triton_machine" "postgresql" {
    count = var.config.vm.replicas
    name = "postgresql-${count.index}"
    package = "k1-highcpu-8G"

    image = data.triton_image.os.id

    cns {
        services = ["postgresql"]
    }

    networks = var.config.machine_networks

    tags = {
        role = "postgresql"
    }
    
    affinity = ["role!=~postgresql"]

    connection {
        host = self.primaryip
    }

    provisioner "file" {
        content = templatefile("${path.module}/templates/patroni.yml.tpl", {
            hostname = "postgresql-${count.index}"
            consul_addr = var.config.consul_addr
            consul_scope = var.config.consul_scope
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
