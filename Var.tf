# Variables File

# Create Variables location 
variable "location" {
  type        = string
  default     = "centralus"
  description = "Azure region for deployment of resources."
}

# Create Enviroment
variable "production" {
  type        = string
  default     = "prod"
  description = "Azure region for deployment of resources."
}

# Create Enviroment
variable "connectivity" {
  type        = string
  default     = "cnct"
  description = "Azure region for deployment of resources."
}

# Azure Subscription ID
variable "SubIDs" {
  type        = string
  default     = ""
  description = "Azure Subscription ID."
}

variable "firewall_sku_tier" {
  type        = string
  description = "Firewall SkU."
  default     = "Standard"
}
