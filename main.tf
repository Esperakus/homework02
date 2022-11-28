terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = ">= 0.13"
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

resource "yandex_compute_instance" "nginx" {
  count = 2
  name     = "nginx-${count.index}"
  hostname = "nginx-${count.index}"

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
    ssh-keys = "cloud-user:${file("~/.ssh/id_rsa.pub")}"
#    ssh-keys = "inner-user:"
#    users:
#      - name: inner
#      - groups: sudo
#      - shell: /bin/bash
#      - ssh_authorized_keys
  }

  connection {
    type        = "ssh"
    user        = "cloud-user"
    private_key = "${file("~/.ssh/id_rsa")}"
    host        = self.network_interface.0.nat_ip_address
  }

  provisioner "remote-exec" {
    inline = ["echo 'Nginx is up'"]
  }
}

resource "yandex_compute_instance" "php-fpm" {

  count = 3
  name = "php-${count.index}"
  hostname = "php-${count.index}"

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
  }

  metadata = {
    ssh-keys = "cloud-user:${file("~/.ssh/id_rsa.pub")}"
  }
}

resource "yandex_compute_instance" "db" {

  name = "db"
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
    ssh-keys = "cloud-user:${file("~/.ssh/id_rsa.pub")}"
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
}

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = "4096"
}

output "internal_ip_address_nginx" {
 value = yandex_compute_instance.nginx.*.network_interface.0.ip_address
}

output "internal_ip_address_php" {
 value = yandex_compute_instance.php-fpm.*.network_interface.0.ip_address
}

output "internal_ip_address_db" {
 value = yandex_compute_instance.db.*.network_interface.0.ip_address
}

output "external_ip_address_nginx" {
 value = yandex_compute_instance.nginx.*.network_interface.0.nat_ip_address
}