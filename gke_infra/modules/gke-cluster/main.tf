locals {
  # Construct network self_links directly — no data source lookup needed
  network    = "projects/${var.project_id}/global/networks/${var.vpc_name}"
  subnetwork = "projects/${var.project_id}/regions/${var.region}/subnetworks/${var.subnet_name}"

  gpu_resources = [
    for resource, limits in var.cluster_autoscaling_limits : {
      resource_type = resource
      minimum       = limits.minimum
      maximum       = limits.maximum
    }
    if contains(["nvidia-tesla-a100", "nvidia-tesla-v100", "nvidia-tesla-t4", "nvidia-l4", "nvidia-a10g"], resource)
  ]

  standard_resources = [
    for resource, limits in var.cluster_autoscaling_limits : {
      resource_type = resource
      minimum       = limits.minimum
      maximum       = limits.maximum
    }
    if !contains(["nvidia-tesla-a100", "nvidia-tesla-v100", "nvidia-tesla-t4", "nvidia-l4", "nvidia-a10g"], resource)
  ]

  node_sa_roles = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/artifactregistry.reader",
    "roles/stackdriver.resourceMetadata.writer"
  ]
}

resource "google_service_account" "gke_nodes" {
  account_id   = "${var.cluster_name}-nodes"
  display_name = "GKE Node Service Account for ${var.cluster_name}"
  description  = "Minimal privilege SA for GKE nodes"
}

resource "google_project_iam_member" "node_sa_bindings" {
  for_each = toset(local.node_sa_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_compute_router" "router" {
  count   = var.create_nat ? 1 : 0
  name    = "${var.cluster_name}-router"
  region  = var.region
  network = local.network
}

resource "google_compute_router_nat" "nat" {
  count                              = var.create_nat ? 1 : 0
  name                               = "${var.cluster_name}-nat"
  router                             = google_compute_router.router[0].name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

resource "google_pubsub_topic" "notifications" {
  for_each = var.notification_topics

  name   = "${var.cluster_name}-${each.key}"
  labels = merge(var.cluster_labels, lookup(each.value, "labels", {}))
}

resource "google_container_cluster" "primary" {
  provider = google-beta

  name     = var.cluster_name
  location = coalesce(var.location, var.zone) 
  project  = var.project_id

  deletion_protection = false
  initial_node_count       = 1 
  
  network         = local.network
  subnetwork      = local.subnetwork
  networking_mode = "VPC_NATIVE"

  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  release_channel {
    channel = var.release_channel
  }

  min_master_version       = var.kubernetes_version
  remove_default_node_pool = true
  

  
  node_config {

    machine_type = "e2-medium"   # required to fully override defaults
    disk_type    = "pd-standard"
    disk_size_gb = 20
  }

  dynamic "private_cluster_config" {
    for_each = var.enable_private_nodes ? [1] : []
    content {
      enable_private_nodes    = true
      enable_private_endpoint = var.enable_private_endpoint
      master_ipv4_cidr_block  = var.master_ipv4_cidr_block
      

      master_global_access_config {
        enabled = true
      }

      private_endpoint_subnetwork = null
    }
  }

  timeouts {
    create = "60m"
    update = "60m"
    delete = "30m"
  }

  dynamic "master_authorized_networks_config" {
    for_each = length(var.master_authorized_networks) > 0 ? [1] : []
    content {
      dynamic "cidr_blocks" {
        for_each = var.master_authorized_networks
        content {
          cidr_block   = cidr_blocks.value.cidr_block
          display_name = cidr_blocks.value.display_name
        }
      }
    }
  }

  dynamic "dns_config" {
  for_each = var.dns_access_scope != "" ? [1] : []
  content {
    cluster_dns        = "CLOUD_DNS"
    cluster_dns_scope  = var.dns_access_scope
    cluster_dns_domain = "cluster.local"
  }
}

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  datapath_provider = "ADVANCED_DATAPATH"

  dynamic "binary_authorization" {
    for_each = var.binary_authorization_mode != "" ? [1] : []
    content {
      evaluation_mode = var.binary_authorization_mode
    }
  }

  enable_shielded_nodes = true

  dynamic "resource_usage_export_config" {
    for_each = var.resource_usage_dataset_id != null ? [1] : []
    content {
      enable_network_egress_metering       = true
      enable_resource_consumption_metering = true

      bigquery_destination {
        dataset_id = var.resource_usage_dataset_id
      }
    }
  }

  maintenance_policy {
    recurring_window {
      start_time = var.maintenance_config.start_time
      end_time   = var.maintenance_config.end_time
      recurrence = var.maintenance_config.recurrence
    }

    dynamic "maintenance_exclusion" {
      for_each = var.maintenance_config.exclusions
      content {
        exclusion_name = maintenance_exclusion.value.name
        start_time     = maintenance_exclusion.value.start_time
        end_time       = maintenance_exclusion.value.end_time
      }
    }
  }

  logging_config {
    enable_components = var.logging_components
  }

  monitoring_config {
    enable_components = var.monitoring_components

    dynamic "managed_prometheus" {
      for_each = var.enable_managed_prometheus ? [1] : []
      content {
        enabled = true
      }
    }

    dynamic "advanced_datapath_observability_config" {
      for_each = var.enable_managed_prometheus ? [1] : []
      content {
        enable_metrics = true
        enable_relay   = true
      }
    }
  }

  cluster_autoscaling {
    enabled = true

    dynamic "resource_limits" {
      for_each = local.standard_resources
      content {
        resource_type = resource_limits.value.resource_type
        minimum       = resource_limits.value.minimum
        maximum       = resource_limits.value.maximum
      }
    }

    dynamic "resource_limits" {
      for_each = local.gpu_resources
      content {
        resource_type = resource_limits.value.resource_type
        minimum       = resource_limits.value.minimum
        maximum       = resource_limits.value.maximum
      }
    }

    auto_provisioning_defaults {
    service_account = google_service_account.gke_nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    disk_type       = "pd-standard"
    

    management {
      auto_repair  = true
      auto_upgrade = true
    }

      upgrade_settings {
        max_surge       = 1
        max_unavailable = 0
      }

      shielded_instance_config {
        enable_secure_boot          = true
        enable_integrity_monitoring = true
      }
    }
  }

  vertical_pod_autoscaling {
    enabled = true
  }

  dynamic "cost_management_config" {
    for_each = var.enable_cost_allocation ? [1] : []
    content {
      enabled = true
    }
  }

  dynamic "notification_config" {
    for_each = length(var.notification_topics) > 0 ? [1] : []
    content {
      pubsub {
        enabled = true
        topic   = google_pubsub_topic.notifications["upgrades"].id
      }
    }
  }

  resource_labels = var.cluster_labels

  depends_on = [
    google_project_iam_member.node_sa_bindings,
    google_compute_router_nat.nat,
  ]

  lifecycle {
    ignore_changes = [initial_node_count]
  }
}

# resource "google_container_node_pool" "bootstrap" {
#   name     = "bootstrap-pool"
#   cluster  = google_container_cluster.primary.name
#   location = var.region

#   node_count = 1

#   node_config {
#     machine_type = "e2-small"
#     disk_type    = "pd-standard"
#     disk_size_gb = 20

#     service_account = google_service_account.gke_nodes.email
#     oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
#   }
# }