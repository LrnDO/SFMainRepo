data "yandex_compute_image" "ubuntu_image" {
  family = "ubuntu-2404-lts"
}

resource "yandex_iam_service_account" "vm-sa" {
  name        = "vm-service-account"
  description = "Service account for VMs"
}

resource "yandex_resourcemanager_folder_iam_member" "vm-editor" {
  folder_id = var.folder_id
  role      = "editor"
  member    = "serviceAccount:${yandex_iam_service_account.vm-sa.id}"
}

# Виртуальная машина №1 - первый узел Kubernetes
resource "yandex_compute_instance" "k8s-node-1" {
  name               = "k8s-node-1"
  platform_id        = "standard-v3"
  zone               = var.zone
  service_account_id = yandex_iam_service_account.vm-sa.id

  resources {
    cores         = 2
    memory        = 4
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_image.id
      size     = 20
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.k8s-subnet.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.k8s-sg.id]
  }

  metadata = {
    ssh-keys = "${var.vm_username}:${var.ssh_public_key}"
  }
}

# Виртуальная машина №2 - мастер нода Kubernetes
resource "yandex_compute_instance" "k8s-cp" {
  name               = "k8s-cp"
  platform_id        = "standard-v3"
  zone               = var.zone
  service_account_id = yandex_iam_service_account.vm-sa.id

  resources {
    cores         = 2
    memory        = 4
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_image.id
      size     = 20
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.k8s-subnet.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.k8s-sg.id]
  }

  metadata = {
    ssh-keys = "${var.vm_username}:${var.ssh_public_key}"
  }
}

# Виртуальная машина №3 - для управления и мониторинга
resource "yandex_compute_instance" "srv" {
  name               = "srv"
  platform_id        = "standard-v3"
  zone               = var.zone
  service_account_id = yandex_iam_service_account.vm-sa.id

  resources {
    cores         = 2
    memory        = 4
    core_fraction = 50
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_image.id
      size     = 30 # Больше места для логов и метрик
      type     = "network-ssd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.k8s-subnet.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.k8s-sg.id]
  }

  metadata = {
    ssh-keys  = "${var.vm_username}:${var.ssh_public_key}"
    user-data = file("${path.module}/cloud-config.yaml")
  }
}
