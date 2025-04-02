#lab1.9

variable "resource_group_name" {
  description = "Name for the resource group"
  type        = string
  default     = "terraform-basics-yourName"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "West Europe"
}

variable "container_group_name" {
  description = "Name of the container group"
  type        = string
  default     = "terraform-basics-yourName"
}

variable "prefix" {
  description = "Prefix string to ensure FQDNs are globally unique"
  type        = string
}

