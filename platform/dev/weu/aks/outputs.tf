output "resource_group_name" {
  value = data.azurerm_resource_group.this.name
}

output "cluster_name" {
  value = module.aks.name
}

output "kube_config_raw" {
  value     = module.aks.kube_config_raw
  sensitive = true
}
