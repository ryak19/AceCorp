# Variables File

# Create Variables location 
variable "location" {
  type        = string
  default     = "centralus"
  description = "Azure region for deployment of resources."
}

# Create Enviroment
variable "prod" {
  type        = string
  default     = "prod"
  description = "Azure region for deployment of resources."
}

# Create Enviroment
variable "cnct" {
  type        = string
  default     = "prod"
  description = "Azure region for deployment of resources."
}

# Azure Subscription ID
variable "SubIDs" {
  type        = string
  default     = ""
  description = "Azure Subscription ID."
}
