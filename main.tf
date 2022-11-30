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
# provider "tls" {}

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

#data "template_file" "user_data" {
#  template = file("user_data.yml")
#}

resource "yandex_compute_instance" "vm-1" {
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

  provisioner "remote-exec" {
    inline = [
      
    ]
    
  }

  #  provisioner "local-exec" {
  #    command = "ansible-playbook -u cloud-user -i '${self.network_interface.0.nat_ip_address},' --private-key id_rsa nginx.yml"
  #  }
}

resource "yandex_compute_instance" "php-fpm" {

  count    = 2
  name     = "php-${count.index}"
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
    # nat       = true
  }

  metadata = {
    ssh-keys = "cloud-user:${tls_private_key.ssh.public_key_openssh}"
  }

  # connection {
  #   type        = "ssh"
  #   user        = "cloud-user"
  #   private_key = tls_private_key.ssh.private_key_pem
  #   host        = self.network_interface.0.nat_ip_address
  # }

  # provisioner "remote-exec" {
  #   inline = ["echo 'php is up'"]
  # }

  #  provisioner "local-exec" {
  #      command = "ansible-playbook -u cloud-user -i '${self.network_interface.0.nat_ip_address},' --private-key ~/.ssh/id_rsa php.yml"
  #  }
}

#resource "yandex_compute_instance" "db" {
#
#  name = "db"
#  hostname = "db"
#
#  resources {
#    cores  = 2
#    memory = 4
#  }
#
#  boot_disk {
#    initialize_params {
#      image_id = var.image_id
#    }
#  }
#
#  network_interface {
#    subnet_id = yandex_vpc_subnet.subnet01.id
#    nat = true
#  }
#
#  metadata = {
#    ssh-keys = "cloud-user:${file("~/.ssh/id_rsa.pub")}"
#  }
#}

resource "yandex_vpc_network" "net01" {
  name = "net01"
}

resource "yandex_vpc_subnet" "subnet01" {
  name           = "subnet1"
  zone           = var.zone
  network_id     = yandex_vpc_network.net01.id
  v4_cidr_blocks = ["192.168.100.0/24"]
}

output "internal_ip_address_vm-1" {
  value = yandex_compute_instance.vm-1.*.network_interface.0.ip_address
}

output "external_ip_address_vm-1" {
  value = yandex_compute_instance.vm-1.*.network_interface.0.nat_ip_address
}

#output "internal_ip_address_php" {
# value = yandex_compute_instance.php-fpm.*.network_interface.0.ip_address
#}

#output "external_ip_address_php" {
#  value = yandex_compute_instance.php-fpm.*.network_interface.0.nat_ip_address
#}

#output "external_ip_address_db" {
#  value = yandex_compute_instance.db.*.network_interface.0.nat_ip_address
#}

#output "internal_ip_address_db" {
# value = yandex_compute_instance.db.*.network_interface.0.ip_address
#}

#output "public_ssh" {
#  value = tls_private_key.ssh.public_key_pem
#}
#
#output "private_ssh" {
#  value = tls_private_key.ssh.private_key_pem
#  sensitive = true
#}
#
#output "public_ssh_fingerprint" {
#  value = tls_private_key.ssh.public_key_fingerprint_md5
##  sensitive = true
#}
