resource "google_container_node_pool" "pools" {
  for_each = var.node_pools
  
  provider = google-beta
  
  name           = "${var.cluster_name}-${each.key}"
  location       = var.region
  cluster        = var.cluster_id
  node_locations = each.value.zones != null ? each.value.zones : var.zones
  
  autoscaling {
    min_node_count = each.value.min_count
    max_node_count = each.value.max_count
  }

  management {
    auto_repair  = each.value.auto_repair
    auto_upgrade = each.value.auto_upgrade
  }

  upgrade_settings {
    max_surge       = each.value.max_surge
    max_unavailable = each.value.max_unavailable
  }

  node_config {
    machine_type = each.value.machine_type
    disk_size_gb = each.value.disk_size_gb
    disk_type    = each.value.disk_type
    spot         = each.value.spot
    
    service_account = var.node_service_account
    oauth_scopes = [
        "https://www.googleapis.com/auth/cloud-platform",
        "https://www.googleapis.com/auth/compute",
        "https://www.googleapis.com/auth/devstorage.read_only",
        "https://www.googleapis.com/auth/logging.write",
        "https://www.googleapis.com/auth/monitoring",
      ]

    workload_metadata_config {
      mode = "GCE_METADATA"
    }

    labels = merge(
      {
        "node-pool" = each.key
      },
      each.value.labels
    )

    # Dynamic taints
    dynamic "taint" {
      for_each = each.value.taints
      content {
        key    = taint.value.key
        value  = taint.value.value
        effect = taint.value.effect
      }
    }

    # Dynamic guest accelerators (GPUs)
    dynamic "guest_accelerator" {
      for_each = each.value.guest_accelerators
      content {
        type  = guest_accelerator.value.type
        count = guest_accelerator.value.count
        gpu_driver_installation_config {
          gpu_driver_version = "LATEST"
        }
      }
    }

    shielded_instance_config {
      enable_secure_boot          = each.value.secure_boot
      enable_integrity_monitoring = each.value.integrity_monitoring
    }

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }

  lifecycle {
    ignore_changes = [
      initial_node_count,
    ]
  }
}