terraform {
  backend "azurerm" {
    storage_account_name  = "cs437c2e37709bcx405exabb"
    container_name        = "k8s"
    key                   = "terraform.tfstate"
  }
}


resource "azurerm_resource_group" "k8s" {
    name     = "${var.resource_group_name}"
    location = "${var.location}"
}

resource "azurerm_virtual_network" "vnet1" {
  name                = "${var.resource_group_name}-vnet1"
  location            = "${var.location}"
  address_space       = ["10.0.0.0/16"]
  resource_group_name = "${azurerm_resource_group.k8s.name}"

}

resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = "${azurerm_resource_group.k8s.name}"
  virtual_network_name = "${azurerm_virtual_network.vnet1.name}"
  address_prefix       = "10.0.1.0/24"
}


resource "azurerm_log_analytics_workspace" "test" {
    name                = "${var.log_analytics_workspace_name}"
    location            = "${var.log_analytics_workspace_location}"
    resource_group_name = "${azurerm_resource_group.k8s.name}"
    sku                 = "${var.log_analytics_workspace_sku}"
}

resource "azurerm_log_analytics_solution" "test" {
    solution_name         = "ContainerInsights"
    location              = "${azurerm_log_analytics_workspace.test.location}"
    resource_group_name   = "${azurerm_resource_group.k8s.name}"
    workspace_resource_id = "${azurerm_log_analytics_workspace.test.id}"
    workspace_name        = "${azurerm_log_analytics_workspace.test.name}"

    plan {
        publisher = "Microsoft"
        product   = "OMSGallery/ContainerInsights"
    }
}

resource "azurerm_kubernetes_cluster" "k8s" {
    name                = "${var.cluster_name}"
    location            = "${azurerm_resource_group.k8s.location}"
    resource_group_name = "${azurerm_resource_group.k8s.name}"
    dns_prefix          = "${var.dns_prefix}"

    agent_pool_profile {
        name            = "agentpool"
        count           = "${var.agent_count}"
        vm_size         = "Standard_DS1_v2"
        os_type         = "Linux"
        os_disk_size_gb = 30

        vnet_subnet_id = "${azurerm_subnet.internal.id}"
    }

    service_principal {
        client_id     = "${var.client_id}"
        client_secret = "${var.client_secret}"
    }

    network_profile {
        network_plugin     = "azure"
        service_cidr       = "10.240.0.0/16"
        docker_bridge_cidr = "172.17.0.1/16"
        dns_service_ip     = "10.240.0.10"
    } 


    addon_profile {
        oms_agent {
        enabled                    = true
        log_analytics_workspace_id = "${azurerm_log_analytics_workspace.test.id}"
        }
    }

    tags {
        Environment = "Development"
    }
}
