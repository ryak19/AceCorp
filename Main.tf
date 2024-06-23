# Define the local variables
locals {
  address_space_vnet_Connectivity   = "10.14.0.0/23"
  address_space_snet_GatewaySubnet  = "10.14.0.0/24"
  address_space_snet_BastionSubnet  = "10.14.1.0/26"
  address_space_snet_FirewallSubnet = "10.14.1.64/26"
  address_space_vnet_Production     = "10.15.0.0/24"
  # vpn_local_gateway_PIP_address           = "208.123.205.98"      
  # vpn_local_gateway_LAN_address           = "10.1.1.0/24"         
  # vpn_connector_sharekey                  = "T5Tfq1sK3yW0rk2"     
}


# Create a resource group CONNECTIVITY
resource "azurerm_resource_group" "connectivity" {
  name     = "rg-ace-${var.connectivity}-${var.location}-01"
  location = var.location
  tags = {
    environment = "AceCorp"
  }
}


# Create a resource group PRODUCTION
resource "azurerm_resource_group" "production" {
  name     = "rg-ace-${var.production}-${var.location}-01"
  location = var.location
  tags = {
    environment = "AceCorp"
  }
}

# Create a Hub vnet
resource "azurerm_virtual_network" "connectivity-vnet" {
  name                = "vnet-ace-${var.connectivity}-${var.location}-01"
  location            = azurerm_resource_group.connectivity.location
  resource_group_name = azurerm_resource_group.connectivity.name
  address_space       = [local.address_space_vnet_Connectivity]
  tags = {
    environment = "AceCorp"
  }
}

# Create Vnet peering from Connectivity to Production
resource "azurerm_virtual_network_peering" "cnct-prod-peer" {
    name                      = "vnet-ace-${var.connectivity}-${var.location}-01-to-vnet-ace-${var.production}-${var.location}-01"
    resource_group_name       = azurerm_resource_group.connectivity.name
    virtual_network_name      = azurerm_virtual_network.connectivity-vnet.name
    remote_virtual_network_id = azurerm_virtual_network.production-vnet.id
    allow_virtual_network_access = true
    allow_forwarded_traffic   = true
    allow_gateway_transit     = false
    use_remote_gateways       = true
#    depends_on = [azurerm_virtual_network.spoke2-vnet, azurerm_virtual_network.hub-vnet, azurerm_virtual_network_gateway.hub-vnet-gateway]
}

# Create a Prod vnet
resource "azurerm_virtual_network" "production-vnet" {
  name                = "vnet-ace-${var.production}-${var.location}-01"
  location            = azurerm_resource_group.production.location
  resource_group_name = azurerm_resource_group.production.name
  address_space       = [local.address_space_vnet_Production]
  tags = {
    environment = "AceCorp"
  }
}

#Create  Vnet peering from Production to Connectivity
resource "azurerm_virtual_network_peering" "prod-cnct-peer" {
    name                      = "vnet-ace-${var.production}-${var.location}-01-to-vnet-ace-${var.connectivity}-${var.location}-01"
    resource_group_name       = azurerm_resource_group.production.name
    virtual_network_name      = azurerm_virtual_network.production-vnet.name
    remote_virtual_network_id = azurerm_virtual_network.production-vnet.id

    allow_virtual_network_access = true
    allow_forwarded_traffic = true
    allow_gateway_transit   = true
    use_remote_gateways     = false
#    depends_on = [azurerm_virtual_network.spoke2-vnet, azurerm_virtual_network.hub-vnet, azurerm_virtual_network_gateway.hub-vnet-gateway]
}

# Create SUBNET - GatewaySubnet
resource "azurerm_subnet" "GatewaySubnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.connectivity.name
  virtual_network_name = azurerm_virtual_network.connectivity-vnet.name
  address_prefixes     = [local.address_space_snet_GatewaySubnet]
}

resource "azurerm_public_ip" "pip_appgw" {
  name                = "pip-appgw-${var.connectivity}-${var.location}-01"
  resource_group_name = azurerm_resource_group.connectivity.name
  location            = azurerm_resource_group.connectivity.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

# since these variables are re-used - a locals block makes this more maintainable
locals {
  backend_address_pool_name      = "${azurerm_virtual_network.example.name}-beap"
  frontend_port_name             = "${azurerm_virtual_network.example.name}-feport"
  frontend_ip_configuration_name = "${azurerm_virtual_network.example.name}-feip"
  http_setting_name              = "${azurerm_virtual_network.example.name}-be-htst"
  listener_name                  = "${azurerm_virtual_network.example.name}-httplstn"
  request_routing_rule_name      = "${azurerm_virtual_network.example.name}-rqrt"
  redirect_configuration_name    = "${azurerm_virtual_network.example.name}-rdrcfg"
}

resource "azurerm_application_gateway" "appgateway" {
  name                = "appgw-${var.connectivity}-${var.location}-01"
  resource_group_name = azurerm_resource_group.connectivity.name
  location            = azurerm_resource_group.connectivity.location

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "my-gateway-ip-configuration"
    subnet_id = azurerm_subnet.GatewaySubnet.id
  }

  frontend_port {
    name = local.frontend_port_name
    port = 80
  }

  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.pip_appgw.id
  }

  backend_address_pool {
    name = local.backend_address_pool_name
  }

  backend_http_settings {
    name                  = local.http_setting_name
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }

  http_listener {
    name                           = local.listener_name
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = local.request_routing_rule_name
    priority                   = 9
    rule_type                  = "Basic"
    http_listener_name         = local.listener_name
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.http_setting_name
  }
}

# Create SUBNET - FirewallSubnet
resource "azurerm_subnet" "FirewallSubnet" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.connectivity.name
  virtual_network_name = azurerm_virtual_network.connectivity-vnet.name
  address_prefixes     = [local.address_space_snet_FirewallSubnet]
}

#Create Firewall Public IP
resource "azurerm_public_ip" "pip_azfw"{
name                   = "pip-fw-${var.connectivity}-${var.location}-01"
location               = azurerm_resource_group.connectivity.location
resource_group_name    = azurerm_resource_group.connectivity.name
allocation_method      = "Static"
sku                    = "Standard"
}

resource "azurerm_firewall_policy" "azfw_policy" {
  name                     = "azfw-policy-${var.location}-01"
  resource_group_name      = azurerm_resource_group.connectivity.name
  location                 = azurerm_resource_group.connectivity.location
  sku                      = var.firewall_sku_tier
  threat_intelligence_mode = "Alert"
}

resource "azurerm_firewall_policy_rule_collection_group" "net_policy_rule_collection_group" {
  name               = "DefaultNetworkRuleCollectionGroup"
  firewall_policy_id = azurerm_firewall_policy.azfw_policy.id
  priority           = 200
  network_rule_collection {
    name     = "DefaultNetworkRuleCollection"
    action   = "Allow"
    priority = 200
    rule {
      name                  = "time-windows"
      protocols             = ["UDP"]
      source_ip_groups      = [azurerm_ip_group.workload_ip_group.id, azurerm_ip_group.infra_ip_group.id]
      destination_ports     = ["123"]
      destination_addresses = ["132.86.101.172"]
    }
  }
}

resource "azurerm_firewall_policy_rule_collection_group" "app_policy_rule_collection_group" {
  name               = "DefaulApplicationtRuleCollectionGroup"
  firewall_policy_id = azurerm_firewall_policy.azfw_policy.id
  priority           = 300
  application_rule_collection {
    name     = "DefaultApplicationRuleCollection"
    action   = "Allow"
    priority = 500
    rule {
      name = "AllowWindowsUpdate"

      description = "Allow Windows Update"
      protocols {
        type = "Http"
        port = 80
      }
      protocols {
        type = "Https"
        port = 443
      }
      source_ip_groups      = [azurerm_ip_group.workload_ip_group.id, azurerm_ip_group.infra_ip_group.id]
      destination_fqdn_tags = ["WindowsUpdate"]
    }
    rule {
      name        = "Global Rule"
      description = "Allow access to Microsoft.com"
      protocols {
        type = "Https"
        port = 443
      }
      destination_fqdns = ["*.microsoft.com"]
      terminate_tls     = false
      source_ip_groups  = [azurerm_ip_group.workload_ip_group.id, azurerm_ip_group.infra_ip_group.id]
    }
  }
}

resource "azurerm_firewall" "Firewall" {
  name                = "fw-ace-${var.connectivity}-${var.location}-01"
  location            = azurerm_resource_group.connectivity.location
  resource_group_name = azurerm_resource_group.connectivity.name
  sku_name            = "AZFW_VNet"
  sku_tier            = var.firewall_sku_tier
  ip_configuration {
    name                 = "azfw-ipconfig"
    subnet_id            = azurerm_subnet.FirewallSubnet.id
    public_ip_address_id = azurerm_public_ip.pip_azfw.id
  }
  firewall_policy_id = azurerm_firewall_policy.azfw_policy.id
}

# Create SUBNET - BastionSubnet
resource "azurerm_subnet" "BastionSubnet" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.connectivity.name
  virtual_network_name = azurerm_virtual_network.connectivity-vnet.name
  address_prefixes     = [local.address_space_snet_BastionSubnet]
}

#resource "azurerm_network_security_group" "connectivity" {
#  name                = "nsg-${var.cnct}-${var.location}-01"
#  location            = azurerm_resource_group.connectivity.location
#  resource_group_name = azurerm_resource_group.connectivity.name
#}

#resource "azurerm_subnet_network_security_group_association" "nsg_vm_subnet_association" {
#  network_security_group_id = azurerm_network_security_group.vm_subnet_nsg.id
#  subnet_id                 = azurerm_subnet.vm_subnet.id
#}

#resource "azurerm_network_security_group" "production" {
#  name                = "nsg-${var.prod}-${var.location}-01"
#  location            = azurerm_resource_group.connectivity.location
#  resource_group_name = azurerm_resource_group.production.name
#}


