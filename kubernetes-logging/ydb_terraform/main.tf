variable "cloud_id" {
  description = "Cloud id where to create the sources"
  type        = string
}

variable "folder_id" {
  description = "Folder id where to create the sources"
  type        = string
}



terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  zone = "ru-central1-d" # Зона доступности по умолчанию
  #service_account_key_file = "key.json"
  cloud_id                 = var.cloud_id
  folder_id                = var.folder_id
}



# Yandex Object Storage bucket

# Create a service account for Object Storage creation.
resource "yandex_iam_service_account" "s3-sa" {
  folder_id = var.folder_id
  name      = "s3-sa-default"
}

// Grant permissions
resource "yandex_resourcemanager_folder_iam_member" "s3-sa-editor" {
  folder_id = var.folder_id
  role      = "storage.editor"
  member    = "serviceAccount:${yandex_iam_service_account.s3-sa.id}"
}


# Grant the service account storage.admin role to create storages and grant bucket ACLs.
resource "yandex_resourcemanager_folder_iam_binding" "storage-editor" {
  folder_id = var.folder_id
  role      = "storage.admin"
  members = [
    "serviceAccount:${yandex_iam_service_account.s3-sa.id}"
  ]
}


# Service Account static access keys
resource "yandex_iam_service_account_static_access_key" "s3-sa-static-key" {
  description        = "Static access key for Object Storage"
  service_account_id = yandex_iam_service_account.s3-sa.id
}


# Use keys to create a bucket and grant permission
resource "yandex_storage_bucket" "logging-bucket" {
  access_key = yandex_iam_service_account_static_access_key.s3-sa-static-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.s3-sa-static-key.secret_key
  bucket     = "s3-bucket-otus-default"
  folder_id = var.folder_id

  grant {
    id          = yandex_iam_service_account.s3-sa.id
    type        = "CanonicalUser"
    permissions = ["FULL_CONTROL"]
  }

  depends_on = [yandex_iam_service_account_static_access_key.s3-sa-static-key]
}




### NETWORK ###

# SECTION VPC
resource "yandex_vpc_network" "vpc-01" {
  name = "vpc-01"
}

# SECTION Subnets
resource "yandex_vpc_subnet" "subnet-01" {
  name           = "subnet-01"
  zone           = "ru-central1-d"
  network_id     = yandex_vpc_network.vpc-01.id
  v4_cidr_blocks = ["10.101.0.0/24"]
  route_table_id = yandex_vpc_route_table.rt.id
}

resource "yandex_vpc_gateway" "nat_gateway" {
  folder_id = var.folder_id
  name      = "k8s-gateway"
  shared_egress_gateway {}
}

resource "yandex_vpc_route_table" "rt" {
  folder_id  = var.folder_id
  name       = "rt-tab-dev-01"
  network_id = yandex_vpc_network.vpc-01.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat_gateway.id
  }
}






module "kube" {
  cluster_version = "1.28"
  source          = "github.com/terraform-yc-modules/terraform-yc-kubernetes.git"
  network_id      = yandex_vpc_network.vpc-01.id

  master_locations = [
    {
      zone      = "ru-central1-d",
      subnet_id = yandex_vpc_subnet.subnet-01.id
    }
  ]

  master_maintenance_windows = [
    {
      day        = "sunday"
      start_time = "07:00"
      duration   = "4h"
    }
  ]

  node_groups = {

    "infra-node-group" = {
      node_memory = 24
      node_cores  = 4
      disk_size   = 30
      description = "Infra group for k8s"
      fixed_scale = {
        size = 1
      }
      node_labels = {
        role        = "infra-services"
        environment = "infra"
        infra       = "true"

      }
      node_taints = [
        "node-role=infra:NoSchedule"
      ]

    },

    "app-node-group" = {
      node_memory = 4
      node_cores  = 4
      disk_size   = 30
      description = "Worker group for k8s"
      fixed_scale = {
        size = 1
      }
      node_labels = {
        role        = "app-services"
        environment = "dev"
        infra       = "false" 
      }

      max_expansion   = 1
      max_unavailable = 1
    }
  }
}

###
output "kube_cluster_id" {
  description = "Kubernetes 01 cluster ID."
  value       = try(module.kube.cluster_id, null)
}

output "kube_cluster_name" {
  description = "Kubernetes 01 cluster name."
  value       = try(module.kube.cluster_name, null)
}

output "kube_external_cluster_cmd_str" {
  description = "Connection string to external Kubernetes 01 cluster."
  value       = try(module.kube.external_cluster_cmd, null)
}

output "kube_internal_cluster_cmd_str" {
  description = "Connection string to internal Kubernetes 01 cluster."
  value       = try(module.kube.internal_cluster_cmd, null)
}