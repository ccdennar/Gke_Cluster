locals {
  cluster_name = "${var.cluster_name}-${var.region}"
  
  # Merge common labels with environment-specific labels
  cluster_labels = merge(
    var.common_labels,
    {
      environment = var.environment
      managed_by  = "terraform"
      cluster     = local.cluster_name
    }
  )
  
  # # Default node pool if none provided (should be overridden)
  # default_node_pools = {
  #   system = {
  #     machine_type = "e2-standard-4"
  #     min_count    = 2
  #     max_count    = 10
  #     labels = {
  #       "node-type" = "system"
  #       "workload"  = "infrastructure"
  #     }
  #     taints = [{
  #       key    = "dedicated"
  #       value  = "system"
  #       effect = "NO_SCHEDULE"
  #     }]
  #   }
  # }
  
  # effective_node_pools = length(var.node_pools) > 0 ? var.node_pools : tomap(local.default_node_pools)
}

# GKE Cluster Module
module "gke_cluster" {
  source = "./modules/gke-cluster"

  project_id  = var.project_id
  region      = var.region
  cluster_name = local.cluster_name
  
  # Networking
  vpc_name            = var.vpc_name
  subnet_name         = var.subnet_name
  create_nat          = var.create_nat
  
  pods_range_name     = var.pods_range_name
  services_range_name   = var.services_range_name
  
  # Version and Release
  kubernetes_version = var.kubernetes_version
  release_channel    = var.release_channel
  
  # Security
  enable_private_endpoint = var.enable_private_endpoint
  enable_private_nodes    = var.enable_private_nodes
  master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  master_authorized_networks = var.master_authorized_networks
  dns_access_scope        = var.dns_access_scope
  
  # Maintenance
  maintenance_config = var.maintenance_config
  
  # Observability
  enable_managed_prometheus = var.enable_managed_prometheus
  logging_components        = var.logging_components
  monitoring_components     = var.monitoring_components
  
  # Binary Authorization
  binary_authorization_mode = var.binary_authorization_mode
  
  # Cost Management
  enable_cost_allocation      = var.enable_cost_allocation
  resource_usage_dataset_id   = var.resource_usage_dataset_id
  
  # Autoscaling
  cluster_autoscaling_limits = var.cluster_autoscaling_limits
  
  # Labels
  cluster_labels = local.cluster_labels
  
  # Notifications
  notification_topics = var.notification_topics
}

# Node Pools Module
module "node_pools" {
  source = "./modules/node-pools"

  cluster_name         = local.cluster_name
  cluster_id           = module.gke_cluster.cluster_id
  region               = var.region
  zones                = var.zones
  node_service_account = module.gke_cluster.node_service_account_email
  
  node_pools = var.node_pools
}

# Workload Identity Module
module "workload_identity" {
  source = "./modules/workload-identity"

  project_id = var.project_id
  
  # ArgoCD Configuration
  argocd_config = var.argocd_config
  
  # Additional Workload Identity SAs
  service_accounts = var.workload_identity_service_accounts
  
  # Cluster info for Workload Identity pool
  workload_identity_pool = module.gke_cluster.workload_identity_pool

  depends_on = [ module.gke_cluster ]
}

# # Kubernetes Provider Setup
# data "google_client_config" "default" {}

# provider "kubernetes" {
#   host                   = "https://${module.gke_cluster.cluster_endpoint}"
#   token                  = data.google_client_config.default.access_token
#   cluster_ca_certificate = base64decode(module.gke_cluster.cluster_ca_certificate)
# }

# # Dynamic Namespace Creation
# resource "kubernetes_namespace" "workloads" {
#   for_each = var.workload_identity_service_accounts
  
#   metadata {
#     name = each.value.namespace
#     labels = merge(
#       local.cluster_labels,
#       {
#         "workload-type" = each.key
#       }
#     )
#   }
  
#   depends_on = [module.gke_cluster]
# }

# # Dynamic Service Account Creation with Workload Identity
# resource "kubernetes_service_account" "workloads" {
#   for_each = var.workload_identity_service_accounts
  
#   metadata {
#     name      = each.value.ksa_name
#     namespace = kubernetes_namespace.workloads[each.key].metadata[0].name
#     annotations = {
#       "iam.gke.io/gcp-service-account" = module.workload_identity.service_account_emails[each.key]
#     }
#     labels = local.cluster_labels
#   }
  
#   depends_on = [kubernetes_namespace.workloads]
# }