
# Define the local variables
locals {
  address_space_vnet_connectivity   = "10.14.0.0/23"
  address_space_snet_GatewaySubnet  = "10.14.0.0/24"
  address_space_snet_BastionSubnet  = "10.14.1.0/26"
  address_space_snet_FirewallSubnet = "10.14.1.64/26"
  # vpn_local_gateway_PIP_address           = "208.123.205.98"      
  # vpn_local_gateway_LAN_address           = "10.1.1.0/24"         
  # vpn_connector_sharekey                  = "T5Tfq1sK3yW0rk2"     
}


# Create a resource group CONNECTIVITY
resource "azurerm_resource_group" "connectivity" {
  name     = "rg-ace-${var.cnct}-${var.location}-01"
  location = var.location
  tags = {
    environment = "AceCorp"
  }
}


# Create a resource group PRODUCTION
resource "azurerm_resource_group" "production" {
  name     = "rg-ace-${var.prod}-${var.location}-01"
  location = var.location
  tags = {
    environment = "AceCorp"
  }
}

# Create a Hub vnet
resource "azurerm_virtual_network" "connectivity-vnet" {
  name                = "vnet-${var.cnct}-${var.location}-01"
  location            = azurerm_resource_group.connectivity.location
  resource_group_name = azurerm_resource_group.connectivity.name
  address_space       = [local.address_space_vnet_connectivity]
  tags = {
    environment = "AceCorp"
  }
}

# Create a Prod vnet
resource "azurerm_virtual_network" "production-vnet" {
  name                = "vnet-${var.cnct}-${var.location}-01"
  location            = azurerm_resource_group.production.location
  resource_group_name = azurerm_resource_group.production.name
  address_space       = [local.address_space_vnet_connectivity]
  tags = {
    environment = "AceCorp"
  }
}

# Create SUBNET - GatewaySubnet
resource "azurerm_subnet" "GatewaySubnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.connectivity.name
  virtual_network_name = azurerm_virtual_network.connectivity-vnet.name
  address_prefixes     = [local.address_space_snet_GatewaySubnet]
}

# Create SUBNET - FirewallSubnet
resource "azurerm_subnet" "FirewallSubnet" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.connectivity.name
  virtual_network_name = azurerm_virtual_network.connectivity-vnet.name
  address_prefixes     = [local.address_space_snet_FirewallSubnet]
}

# Create SUBNET - BastionSubnet
resource "azurerm_subnet" "BastionSubnet" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.connectivity.name
  virtual_network_name = azurerm_virtual_network.connectivity-vnet.name
  address_prefixes     = [local.address_space_snet_BastionSubnet]
}

resource "azurerm_network_security_group" "connectivity" {
  name                = "cnct-security-group"
  location            = azurerm_resource_group.connectivity.location
  resource_group_name = azurerm_resource_group.connectivity.name
}

resource "azurerm_network_security_group" "production" {
  name                = "prod-security-group"
  location            = azurerm_resource_group.connectivity.location
  resource_group_name = azurerm_resource_group.production.name
}
