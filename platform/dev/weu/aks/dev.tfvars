location            = "eastus2"
resource_group_name = "danish-trial-rg"
subscription_id     = "fd0ca716-0b48-4d3a-bfe1-12ba81a84f9c"
vnet_name           = "vnet-platform-dev-weu"
vnet_cidr           = "10.50.0.0/16"

aks_subnet_name  = "snet-aks"
aks_subnet_cidr  = "10.50.10.0/24"

cluster_name = "aks-platform-dev-weu"
dns_prefix   = "aks-platform-dev-weu"

kubernetes_version = null        # let Azure choose default for now
node_count         = 1
vm_size            = "Standard_B2s"

tags = {
  env   = "dev"
  owner = "platform-team"
}