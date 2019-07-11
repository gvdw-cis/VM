// NOTE: in a Production Environment you're likely to have Network Security Rules
// which lock down traffic between Subnets. These are omited below to keep the
// examples easy to understand - and should be added before being used in Production.

#resource "azurerm_virtual_network" "main" {
#  name                = "${var.prefix}-network"
#  address_space       = ["10.0.0.0/16"]
#  location            = "${var.location}"
#  resource_group_name = "${var.resource_group_name}"
#  dns_servers         = ["10.0.1.4", "8.8.8.8"]
#}

resource "azurerm_virtual_network" "main" {
  name                = "vnet_cis"
  address_space       = ["10.150.0.0/16"]
  location            = "${var.location}"
  resource_group_name = "${var.resource_group_name}"
  dns_servers         = ["10.150.1.4", "8.8.8.8"]
}

resource "azurerm_subnet" "domain-controllers" {
  name                 = "subnet_test"
  resource_group_name  = "${var.resource_group_name}"
  virtual_network_name = "${azurerm_virtual_network.main.name}"
  address_prefix       = "10.150.1.0/24"
}

resource "azurerm_subnet" "domain-clients" {
  name                 = "subnet_test2"
  resource_group_name  = "${var.resource_group_name}"
  virtual_network_name = "${azurerm_virtual_network.main.name}"
  address_prefix       = "10.150.2.0/24"
}
