
variable "location" {
  type        = string
  description = "Region"
  dedefault = "East US"
}

variable "name_rg" {
  type = string
  description = "nombre de grupo de recursos"
}

variable "name_net" {
  type = string
  desdescription = "Nombre de network "
}

variable "name_subnet_1" {
  type = string
  desdescription = "Nombre de subnet"
}

variable "name_net_2" {
  type = string
  desdescription = "Nombre de subnet"
}

variable "name_public_lb" {
  type = string
  desdescription = "Nombre de ip publica del load balancer"
}

variable "name_public_vm" {
  type = string
  desdescription = "Nombre de ip de la maquina virtual"
}

variable "name_set" {
  type = string
  desdescription = "Nombre de avialability name"
}

variable "name_nic" {
  type = string
  desdescription = "Nombre de nic"
}

variable "name_file_ssh" {
  type = string
  desdescription = "Nombre de aricho de par de clave"
}

variable "name_name_vm" {
  type = string
  desdescription = "Nombre de maquina virtual"
}

variable "size" {
  type = string
  desdescription = "Caracteristicas de la maquina virtual"
}

variable "user_admin" {
  type = string
  desdescription = "Nombre de user root"
}

variable "name_load" {
  type = string
  desdescription = "Nombre del load balancer"
}

variable "name_address_pool_1" {
  type = string
  description = "value"
}

variable "name_addr_pool_addr" {
  type = string
  desdescription = "Nombre del poll address"
}

variable "name_probe" {
  type = string
  desdescription = "Nombre del probe"
}

variable "name_security_group" {
  type = string
  desdescription = "Nombre del security group"
}