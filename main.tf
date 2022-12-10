terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = ">= 0.13"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">=3.0.0"
    }
  }
}


provider "yandex" {
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = var.zone
  token     = var.yc_token
}
provider "tls" {}

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = "4096"
}

resource "local_file" "private_ssh" {
  filename        = "id_rsa"
  content         = tls_private_key.ssh.private_key_pem
  file_permission = "0600"
}

resource "local_file" "public_ssh" {
  filename        = "id_rsa.pub"
  content         = tls_private_key.ssh.public_key_openssh
  file_permission = "0600"
}

resource "local_file" "hosts" {
  filename = "ansible/hosts"
  content = templatefile("hosts.tpl",
    {
      backend_workers = yandex_compute_instance.backend.*.network_interface.0.ip_address
      nginx_workers   = yandex_compute_instance.nginx.*.network_interface.0.ip_address
      db_workers      = yandex_compute_instance.db.*.network_interface.0.ip_address
  })
  depends_on = [
    yandex_compute_instance.nginx,
    yandex_compute_instance.backend,
    yandex_compute_instance.db,
  ]
}

resource "yandex_compute_instance" "ansible" {

  name     = "ansible"
  hostname = "ansible"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = var.image_id
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet01.id
    nat       = true
  }

  metadata = {
    #    ssh-keys = "cloud-user:${file("~/.ssh/id_rsa.pub")}"
    ssh-keys = "cloud-user:${tls_private_key.ssh.public_key_openssh}"
  }

  connection {
    type        = "ssh"
    user        = "cloud-user"
    private_key = tls_private_key.ssh.private_key_pem
    host        = self.network_interface.0.nat_ip_address
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'host is up'",
      "sudo dnf install -y epel-release",
      "sudo dnf install -y ansible"
    ]
  }

  provisioner "file" {
    source      = "ansible"
    destination = "/home/cloud-user"

  }

  provisioner "file" {
    source      = "id_rsa"
    destination = "/home/cloud-user/.ssh/id_rsa"

  }

  provisioner "file" {
    source      = "id_rsa.pub"
    destination = "/home/cloud-user/.ssh/id_rsa.pub"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 600 /home/cloud-user/.ssh/id_rsa"
    ]

  }

  provisioner "file" {
    source      = "./ansible/ansible.cfg"
    destination = "/home/cloud-user/ansible.cfg"

  }

  provisioner "remote-exec" {
    # command = "ansible-playbook -u cloud-user -i '${self.network_interface.0.nat_ip_address},' --private-key id_rsa nginx.yml"
    inline = [
      "ansible-playbook -u cloud-user -i /home/cloud-user/ansible/hosts /home/cloud-user/ansible/playbooks/main.yml"
    ]
  }

  depends_on = [
    yandex_compute_instance.nginx,
    yandex_compute_instance.backend,
    yandex_compute_instance.db,
  ]
}

resource "yandex_compute_instance" "nginx" {

  count    = 2
  name     = "nginx${count.index}"
  hostname = "nginx${count.index}"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = var.image_id
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet01.id
    # nat       = true
  }

  metadata = {
    ssh-keys = "cloud-user:${tls_private_key.ssh.public_key_openssh}"
  }

}

resource "yandex_compute_instance" "backend" {

  count    = 2
  name     = "backend${count.index}"
  hostname = "backend${count.index}"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = var.image_id
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet01.id
    # nat       = true
  }

  metadata = {
    ssh-keys = "cloud-user:${tls_private_key.ssh.public_key_openssh}"
  }

}

resource "yandex_compute_instance" "db" {

  name     = "db"
  hostname = "db"

  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    initialize_params {
      image_id = var.image_id
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet01.id

  }

  metadata = {
    ssh-keys = "cloud-user:${tls_private_key.ssh.public_key_openssh}"
  }
}

resource "yandex_vpc_network" "net01" {
  name = "net01"
}

resource "yandex_vpc_subnet" "subnet01" {
  name           = "subnet1"
  zone           = var.zone
  network_id     = yandex_vpc_network.net01.id
  v4_cidr_blocks = ["192.168.100.0/24"]
  route_table_id = yandex_vpc_route_table.rt.id
}

resource "yandex_vpc_gateway" "nat_gateway" {
  name = "gateway01"
  shared_egress_gateway {}
}

resource "yandex_vpc_route_table" "rt" {
  name       = "route-table"
  network_id = yandex_vpc_network.net01.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat_gateway.id
  }
}

resource "yandex_lb_target_group" "nginx" {
  name = "nginx-workers-tadget"

  target {
    subnet_id = yandex_vpc_subnet.subnet01.id
    address   = yandex_compute_instance.nginx.0.network_interface.0.ip_address
  }

  target {
    subnet_id = yandex_vpc_subnet.subnet01.id
    address   = yandex_compute_instance.nginx.1.network_interface.0.ip_address
  }

  depends_on = [
    yandex_compute_instance.nginx
  ]
}

resource "yandex_lb_network_load_balancer" "lb01" {
  name = "nlb01"
  listener {
    name = "listener01"
    port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }
  attached_target_group {
    target_group_id = yandex_lb_target_group.nginx.id
    healthcheck {
      name = "healthchecker01"
      http_options {
        port = 80
      }
      interval = 2
    }
  }
}

output "external_ip_address_ansible" {
  value = yandex_compute_instance.ansible.*.network_interface.0.nat_ip_address
}

output "internal_ip_address_nginx" {
  value = yandex_compute_instance.nginx.*.network_interface.0.ip_address
}

output "external_ip_address_lb" {
  value = yandex_lb_network_load_balancer.lb01.listener.*
}

output "internal_ip_address_backend" {
  value = yandex_compute_instance.backend.*.network_interface.0.ip_address
}


output "internal_ip_address_db" {
  value = yandex_compute_instance.db.*.network_interface.0.ip_address
}
