project_id   = "fresh-84"
region       = "us-central1"
location     = "us-central1-a"
cluster_name = "ai-ent"
environment  = "dev"

vpc_name            = "dev-fresh-84-vpc"
subnet_name         = "dev-fresh-84-subnet-web-us-central1"

enable_private_nodes = false 

kubernetes_version = "1.32"
release_channel    = "REGULAR"

# enable_private_endpoint = false  # Public endpoint for dev
# enable_private_nodes    = false
master_ipv4_cidr_block  = "172.16.0.0/28"


master_authorized_networks = [
  {
    cidr_block   = "0.0.0.0/0"  # Open for dev (restrict in real scenarios)
    display_name = "open-access"
  }
]

zones = ["us-central1-a"]

maintenance_config = {
  start_time = "2026-01-01T03:00:00Z"
  end_time   = "2026-01-01T07:00:00Z"
  recurrence = "FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR,SA,SU"
  exclusions = []
}

node_pools = {
  system = {
    machine_type = "e2-medium"
    min_count    = 1
    max_count    = 3
    disk_size_gb = 15
    disk_type    = "pd-standard"
    labels = {
      "node-type" = "system"
    }
    taints = []
  }
  general = {
    machine_type = "e2-standard-4"
    min_count    = 0
    max_count    = 5
    labels = {}
    taints = []
  }
}

cluster_autoscaling_limits = {
  cpu = {
    minimum = 2
    maximum = 20
  }
  memory = {
    minimum = 8
    maximum = 80
  }
}

argocd_config = {
  namespace       = "argocd"
  service_account = "argocd-application-controller"
  roles           = ["roles/container.developer"]
}

workload_identity_service_accounts = {}

enable_cost_allocation = false

pods_range_name     = "gke-pods"
services_range_name = "gke-services"

resource_usage_dataset_id = null