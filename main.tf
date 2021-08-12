data "triton_image" "os" {
    name = "base-64-lts"
    version = "20.4.0"
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

    provisioner "remote-exec" {
        inline = [
            "pkgin -y update",
            "pkgin -y in postgresql12",
            "pkgin -y in consul",

            # Patroni dependencies
            "pkgin -y in gcc9",
            "pkgin -y in py38-psycopg2",
            
            "python3.8 -m ensurepip --upgrade",
            "python3.8 -m pip install --upgrade pip",

            "pip3 install patroni[consul]",
        ]
    }
}
