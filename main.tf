//Create an azure Resource Group
resource "azurerm_resource_group" "xlabsrg" {
  name     = "${var.resourcegroup}"
  location = "${var.location}"
}

//The following section creates a virtual network in the 10.0.0.0/16 address space:
resource "azurerm_virtual_network" "xlabsvn" {
    name = "${var.virtnetname}"
    address_space = ["${var.vnet_addr_space}"]
    location = "${azurerm_resource_group.xlabsrg.location}"
    resource_group_name = "${azurerm_resource_group.xlabsrg.name}"
}

//The following section creates a subnet in the above virtual network:
resource "azurerm_subnet" "xlabssnet" {
    name = "${var.subnetname}"
    resource_group_name = "${azurerm_resource_group.xlabsrg.name}"
    virtual_network_name = "${azurerm_virtual_network.xlabsvn.name}"
    address_prefix = "${var.subnet_addr_prefix}"
}

// Create public IPs
resource "azurerm_public_ip" "xlabsip" {
    name                         = "${var.publicip}"
    location                     = "${azurerm_resource_group.xlabsrg.location}"
    resource_group_name          = "${azurerm_resource_group.xlabsrg.name}"
    allocation_method            = "Dynamic"

    tags = {
        environment = "stage"
    }
}

// Create Network Security Group and rule For Sql Server vm
resource "azurerm_network_security_group" "xlabssecgrp" {
    name                = "${var.sqlsecgrp}"
    location            = "${azurerm_resource_group.xlabsrg.location}"
    resource_group_name = "${azurerm_resource_group.xlabsrg.name}"
    
    security_rule {
        name                       = "${var.sqlserver_port1_name}"
        priority                   = "1001"
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "${var.sql_port_number1}"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "${var.sqlserver_port2_name}"
        priority                   = "1002"
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "${var.sql_port_number2}"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }
}

//Now connect the VM to the  virtual network, public IP address, and network security group.

//This creates a virtual NIC and connects it to the virtual networking resources you have created:

resource "azurerm_network_interface" "xlabsnic" {
    name = "${var.sqlnicnew}"
    location = "${azurerm_resource_group.xlabsrg.location}"
    resource_group_name = "${azurerm_resource_group.xlabsrg.name}"

    network_security_group_id = "${azurerm_network_security_group.xlabssecgrp.id}" 

    ip_configuration {
        name = "${var.sqlvmipnew-configuration}"
        subnet_id = "${azurerm_subnet.xlabssnet.id}"
        private_ip_address_allocation = "dynamic"
      public_ip_address_id = "${azurerm_public_ip.xlabsip.id}"
    }
}

//The following section creates a VM and attaches the virtual NIC to it.
resource "azurerm_virtual_machine" "xlabsvm" {
    name = "${var.sqlvmname}"
    location = "${azurerm_resource_group.xlabsrg.location}"
    resource_group_name = "${azurerm_resource_group.xlabsrg.name}"
    network_interface_ids = ["${azurerm_network_interface.xlabsnic.id}"]
    vm_size = "${var.vm_size}"

//https://docs.microsoft.com/en-us/azure/virtual-machines/linux/cli-ps-findimage
//Search the VM images in the Azure Marketplace using Azure CLI tool

//az vm image list --location westeurope  --publisher MicrosoftSQLServer  --all --output table

    storage_image_reference {
        offer     = "${var.i_offer}" 
        publisher = "${var.i_publisher}"
        sku       = "${var.i_sku}" 
        version   = "${var.i_version}"
        }

//boot diagnosetic: here you can provide  the url of the blob for the boot logs storage
    boot_diagnostics {
        enabled     = true
        storage_uri = "${var.boot_url}"
        }

//Windows OS disk by default it is of 128 GB
    storage_os_disk {
        name              = "${var.os_disk}"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Standard_LRS"
            }

// Adding additional disk for persistent storage (need to be mounted to the VM using diskmanagement )
    storage_data_disk {
        name = "${var.add_disk_name}"
        managed_disk_type = "Standard_LRS"
        create_option = "Empty"
        lun = 0
        disk_size_gb = "${var.add_disk_size}"
        }

//Assign the admin uid/pwd and also comupter name
    os_profile {
        computer_name  = "${var.computer_name}"
        admin_username = "${var.admin_username}"
        admin_password = "${var.admin_password}"
    }

//Here defined autoupdate config and also vm agent config
    os_profile_windows_config {  
    //enable_automatic_upgrades = true  
    provision_vm_agent         = true  
  }  
}

//extension configuration section
resource "azurerm_virtual_machine_extension" "xlabsextension" {
  name                 = "SqlIaasExtension"
  location             = "${azurerm_resource_group.xlabsrg.location}"
  resource_group_name  = "${azurerm_resource_group.xlabsrg.name}"
  virtual_machine_name = "${azurerm_virtual_machine.xlabsvm.name}"
  publisher            = "Microsoft.SqlServer.Management"
  type                 = "SqlIaaSAgent"
  type_handler_version = "1.2"

  settings = <<SETTINGS
  {
    "AutoTelemetrySettings": {
      "Region": "West Europe"
    },
    "AutoPatchingSettings": {
      "PatchCategory": "WindowsMandatoryUpdates",
      "Enable": true,
      "DayOfWeek": "Sunday",
      "MaintenanceWindowStartingHour": "2",
      "MaintenanceWindowDuration": "60"
    },
    "KeyVaultCredentialSettings": {
      "Enable": false,
      "CredentialName": ""
    },
    "ServerConfigurationsManagementSettings": {
      "SQLConnectivityUpdateSettings": {
          "ConnectivityType": "Public",
          "Port": "1433"
      },
      "SQLWorkloadTypeUpdateSettings": {
          "SQLWorkloadType": "GENERAL"
      },
      "AdditionalFeaturesServerConfigurations": {
          "IsRServicesEnabled": "true"
      } ,
       "protectedSettings": {
             
           }
           }}
SETTINGS
  tags = {
    terraform = "true"
    Service = "SQL"
  }

}