terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

# --- Resource group + network ---

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

resource "azurerm_virtual_network" "this" {
  name                = var.vnet_name
  location            = data.azurerm_resource_group.this.location
  resource_group_name = data.azurerm_resource_group.this.name
  address_space       = [var.vnet_cidr]
  tags                = var.tags
}

resource "azurerm_subnet" "aks" {
  name                 = var.aks_subnet_name
  resource_group_name  = data.azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.aks_subnet_cidr]
}

# --- AKS cluster using the module repo ---

module "aks" {
  # IaC module repo:
  source = "https://github.com/danishkhan24/saas-iac-modules.git//infra-modules/aks?ref=develop"

  name                = var.cluster_name
  location            = var.location
  resource_group_name = data.azurerm_resource_group.this.name
  dns_prefix          = var.dns_prefix

  kubernetes_version = var.kubernetes_version
  node_count         = var.node_count
  vm_size            = var.vm_size

  vnet_subnet_id          = azurerm_subnet.aks.id
  private_cluster_enabled = false # Keeping AKS public for test

  tags = var.tags
}

locals {
  kubeconfig = yamldecode(module.aks.kube_config_raw)
}

provider "kubernetes" {
  host = local.kubeconfig.clusters[0].cluster.server

  cluster_ca_certificate = base64decode(
    local.kubeconfig.clusters[0].cluster["certificate-authority-data"]
  )

  client_certificate = base64decode(
    local.kubeconfig.users[0].user["client-certificate-data"]
  )

  client_key = base64decode(
    local.kubeconfig.users[0].user["client-key-data"]
  )
}

provider "helm" {
  kubernetes {
    host = local.kubeconfig.clusters[0].cluster.server

    cluster_ca_certificate = base64decode(
      local.kubeconfig.clusters[0].cluster["certificate-authority-data"]
    )

    client_certificate = base64decode(
      local.kubeconfig.users[0].user["client-certificate-data"]
    )

    client_key = base64decode(
      local.kubeconfig.users[0].user["client-key-data"]
    )
  }
}

resource "kubernetes_namespace_v1" "webapp" {
  metadata {
    name = "webapp-dev"
  }
}

resource "kubernetes_deployment_v1" "hello_web" {
  metadata {
    name      = "hello-web"
    namespace = kubernetes_namespace_v1.webapp.metadata[0].name
    labels = {
      app = "hello-web"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "hello-web"
      }
    }

    template {
      metadata {
        labels = {
          app = "hello-web"
        }
      }

      spec {
        container {
          name  = "hello-web"
          image = "nginx:stable-alpine"

          port {
            container_port = 80
          }

          env {
            name  = "APP_MESSAGE"
            value = "Hello from AKS dev via Terraform!"
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "hello_web" {
  metadata {
    name      = "hello-web"
    namespace = kubernetes_namespace_v1.webapp.metadata[0].name
  }

  spec {
    selector = {
      app = "hello-web"
    }

    port {
      port        = 80
      target_port = 80
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_namespace_v1" "ingress_nginx" {
  metadata {
    name = "ingress-nginx"
  }
}

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  namespace  = kubernetes_namespace_v1.cert_manager.metadata[0].name
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "v1.15.3"

  depends_on = [
    kubernetes_namespace_v1.cert_manager
  ]

  set {
    name  = "installCRDs"
    value = "true"
  }
}

resource "helm_release" "ingress_nginx" {
  name       = "ingress-nginx"
  namespace  = kubernetes_namespace_v1.ingress_nginx.metadata[0].name
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.11.0" # or a recent version

  # ensure namespace exists first
  depends_on = [
    kubernetes_namespace_v1.ingress_nginx
  ]

  set {
    name  = "controller.ingressClassResource.default"
    value = "true"
  }

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }
}

resource "kubernetes_namespace_v1" "cert_manager" {
  metadata {
    name = "cert-manager"
  }
}

resource "kubernetes_ingress_v1" "hello_web" {
  metadata {
    name      = "hello-web"
    namespace = kubernetes_namespace_v1.webapp.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class"       = "nginx"
    }
  }

  spec {
    default_backend {
        service {
        name = kubernetes_service_v1.hello_web.metadata[0].name
        port {
            number = 80
        }
        }
    }
    
    rule {
    #   host = var.webapp_hostname

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service_v1.hello_web.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}