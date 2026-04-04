# Core Project Settings
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "Primary region for the cluster"
  type        = string
}

variable "cluster_name" {
  description = "Base name for the cluster (region suffix added automatically)"
  type        = string
}

variable "environment" {
  description = "Environment label (prod, staging, dev)"
  type        = string
  default     = "prod"
}

# VPC Configuration (Existing)
variable "vpc_name" {
  description = "Name of existing VPC"
  type        = string
}

variable "subnet_name" {
  description = "Name of existing subnet"
  type        = string
}

variable "pods_range_name" {
  description = "Secondary range name for pods"
  type        = string
}

variable "services_range_name" {
  description = "Secondary range name for services"
  type        = string
}

# GKE Version and Release
variable "kubernetes_version" {
  description = "Kubernetes version (minor version, latest patch auto-selected)"
  type        = string
  default     = "1.29"
}

variable "release_channel" {
  description = "GKE release channel"
  type        = string
  default     = "REGULAR"
  validation {
    condition     = contains(["UNSPECIFIED", "RAPID", "REGULAR", "STABLE", "EXTENDED"], var.release_channel)
    error_message = "Release channel must be one of: UNSPECIFIED, RAPID, REGULAR, STABLE, EXTENDED."
  }
}

# Network Security
variable "enable_private_endpoint" {
  description = "Enable private master endpoint"
  type        = bool
  default     = true
}

variable "enable_private_nodes" {
  description = "Enable private nodes (no public IPs)"
  type        = bool
  default     = true
}

variable "master_ipv4_cidr_block" {
  description = "CIDR block for private master endpoint"
  type        = string
}

variable "master_authorized_networks" {
  description = "List of authorized CIDR blocks for master access"
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []
}

variable "dns_access_scope" {
  description = "DNS access scope for private clusters"
  type        = string
  default     = "VPC_SCOPE"  # or "PUBLIC_SCOPE"
}

# Maintenance Windows
variable "maintenance_config" {
  description = "Maintenance window configuration"
  type = object({
    start_time = string
    end_time   = string
    recurrence = string
    exclusions = optional(list(object({
      name            = string
      start_time      = string
      end_time        = string
      exclusion_scope = optional(string, "NO_UPGRADES")
    })), [])
  })
}

# Node Pools Configuration
variable "node_pools" {
  description = "Map of node pool configurations"
  type = map(object({
    machine_type       = string
    min_count          = number
    max_count          = number
    disk_size_gb       = optional(number, 100)
    disk_type          = optional(string, "pd-ssd")
    spot               = optional(bool, false)
    taints             = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])
    labels             = optional(map(string), {})
    guest_accelerators = optional(list(object({
      type  = string
      count = number
    })), [])
    zones              = optional(list(string), null)  # null uses cluster zones
    auto_repair        = optional(bool, true)
    auto_upgrade       = optional(bool, true)
    max_surge          = optional(number, 1)
    max_unavailable    = optional(number, 0)
    secure_boot        = optional(bool, true)
    integrity_monitoring = optional(bool, true)
  }))
  default = {}
  # validation {
  #   condition     = length(keys(var.node_pools)) > 0
  #   error_message = "At least one node pool must be defined."
  # }
}

variable "zones" {
  description = "Zones for cluster and node pools"
  type        = list(string)
}

# Cluster Autoscaling
variable "cluster_autoscaling_limits" {
  description = "Resource limits for cluster autoscaling"
  type = map(object({
    minimum = number
    maximum = number
  }))
  default = {}
}

# Workload Identity Configuration
variable "workload_identity_service_accounts" {
  description = "Map of Workload Identity service accounts to create"
  type = map(object({
    display_name = string
    description  = string
    namespace    = string
    ksa_name     = string
    roles        = list(string)
  }))
  default = {}
}

# ArgoCD Configuration
variable "argocd_config" {
  description = "ArgoCD Workload Identity configuration"
  type = object({
    namespace       = string
    service_account = string
    roles           = optional(list(string), ["roles/container.developer"])
  })
  default = null
}

# Observability
variable "enable_managed_prometheus" {
  description = "Enable Google Managed Prometheus"
  type        = bool
  default     = true
}

variable "logging_components" {
  description = "Logging components to enable"
  type        = list(string)
  default     = ["SYSTEM_COMPONENTS", "WORKLOADS", "APISERVER", "CONTROLLER_MANAGER", "SCHEDULER"]
}

variable "monitoring_components" {
  description = "Monitoring components to enable"
  type        = list(string)
  default     = ["SYSTEM_COMPONENTS", "APISERVER", "SCHEDULER", "CONTROLLER_MANAGER", "STORAGE", "HPA", "POD", "DAEMONSET", "DEPLOYMENT", "STATEFULSET"]
}

# Binary Authorization
variable "binary_authorization_mode" {
  description = "Binary Authorization evaluation mode"
  type        = string
  default     = "PROJECT_SINGLETON_POLICY_ENFORCE"
}

# Cost Management
variable "enable_cost_allocation" {
  description = "Enable cost allocation tracking"
  type        = bool
  default     = true
}

variable "resource_usage_dataset_id" {
  description = "BigQuery dataset for resource usage"
  type        = string
  default     = null
}

# Labels
variable "common_labels" {
  description = "Common labels applied to all resources"
  type        = map(string)
  default     = {}
}

# Notification Configuration
variable "notification_topics" {
  description = "Pub/Sub topics for cluster notifications"
  type = map(object({
    labels = optional(map(string), {})
  }))
  default = {}
}

variable "create_nat" {
  type    = bool
  default = false
}

variable "location" {
  type    = string
  default = null
}