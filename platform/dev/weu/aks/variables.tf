variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for AKS and network"
  type        = string
}

variable "subscription_id" {
  description = "Azure subcription ID"
  type        = string
}

variable "vnet_name" {
  description = "VNet name"
  type        = string
}

variable "vnet_cidr" {
  description = "VNet CIDR"
  type        = string
}

variable "aks_subnet_name" {
  description = "Subnet name for AKS nodes"
  type        = string
}

variable "aks_subnet_cidr" {
  description = "Subnet CIDR for AKS nodes"
  type        = string
}

variable "cluster_name" {
  description = "AKS cluster name"
  type        = string
}

variable "dns_prefix" {
  description = "DNS prefix for AKS API server"
  type        = string
}

variable "kubernetes_version" {
  description = "AKS version (optional)"
  type        = string
  default     = null
}

variable "node_count" {
  description = "Node count for default node pool"
  type        = number
  default     = 2
}

variable "vm_size" {
  description = "VM size for default node pool"
  type        = string
  default     = "Standard_D4s_v5"
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

variable "allowed_cidrs" {
  description = "CIDR ranges allowed to access the test webapp LoadBalancer"
  type        = list(string)
  default     = ["0.0.0.0/0"] # open to the world for now; tighten later
}

variable "webapp_hostname" {
  description = "Hostname for the webapp ingress (for dev, use something like webapp.local)"
  type        = string
  default     = "webapp.local"
}