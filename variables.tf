variable "instance_size" {
  description = "The size of the machines"
  type        = string
  default     = "Standard_F2"
}

variable "location" {
  description = "Azure Region"
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Resource Group Name"
  type        = string
  default     = "int4"
}