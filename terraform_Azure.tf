provider "tfe" {
}

provider "azurerm" {
  subscription_id = "8a7e8272-23b7-41d5-80a6-9fa61e8e2095"
  client_id = "52d98a92-7886-4f9e-85dd-18219097157a"
  client_secret     = "qs0AWJFD6eTQMzESEfBgbzZ/awzuARxamRb2dNNXuHc="
  tenant_id     = "697b7e2d-b3a4-41e1-9cfd-17607b83b7b3"
} 

resource "azurerm_resource_group" "myterraformgroup" {
    name     = "myResourceGroup"
    location = "Southeast Asia"

    tags {
        environment = "Terraform Demo"
    }
}

resource "azurerm_virtual_network" "myterraformnetwork" {
    name                = "myVnet"
    address_space       = ["10.0.0.0/16"]
    location            = "Southeast Asia"
    resource_group_name = "${azurerm_resource_group.myterraformgroup.name}"

    tags {
        environment = "Terraform Demo"
    }
}

resource "azurerm_subnet" "myterraformsubnet" {
    name                 = "mySubnet"
    resource_group_name  = "${azurerm_resource_group.myterraformgroup.name}"
    virtual_network_name = "${azurerm_virtual_network.myterraformnetwork.name}"
    address_prefix       = "10.0.2.0/24"
}

resource "azurerm_public_ip" "myterraformpublicip" {
    name                         = "myPublicIP"
    location                     = "Southeast Asia"
    resource_group_name          = "${azurerm_resource_group.myterraformgroup.name}"
    public_ip_address_allocation = "dynamic"

    tags {
        environment = "Terraform Demo"
    }
}

resource "azurerm_network_security_group" "myterraformnsg" {
    name                = "myNetworkSecurityGroup"
    location            = "Southeast Asia"
    resource_group_name = "${azurerm_resource_group.myterraformgroup.name}"
    
    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }
	
	security_rule {
        name                       = "HTTP"
        priority                   = 1001
        direction                  = "Outbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }
	
	tags {
        environment = "Terraform Demo"
    }
}

resource "azurerm_network_interface" "myterraformnic" {
    name                = "myNIC"
    location            = "Southeast Asia"
    resource_group_name = "${azurerm_resource_group.myterraformgroup.name}"
    network_security_group_id = "${azurerm_network_security_group.myterraformnsg.id}"

    ip_configuration {
        name                          = "myNicConfiguration"
        subnet_id                     = "${azurerm_subnet.myterraformsubnet.id}"
        private_ip_address_allocation = "dynamic"
		public_ip_address_id          = "${azurerm_public_ip.myterraformpublicip.id}"
    }

    tags {
        environment = "Terraform Demo"
    }
}

resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = "${azurerm_resource_group.myterraformgroup.name}"
    }
    
    byte_length = 8
}

resource "azurerm_storage_account" "mystorageaccount" {
    name                = "diag${random_id.randomId.hex}"
    resource_group_name = "${azurerm_resource_group.myterraformgroup.name}"
    location            = "Southeast Asia"
    account_replication_type = "LRS"
    account_tier = "Standard"

    tags {
        environment = "Terraform Demo"
    }
}

# Create virtual machine
resource "azurerm_virtual_machine" "myterraformgroup" {
  name                  = "myVM"
  location              = "${azurerm_resource_group.myterraformgroup.location}"
  resource_group_name   = "${azurerm_resource_group.myterraformgroup.name}"
  network_interface_ids = ["${azurerm_network_interface.myterraformnic.id}"]
  vm_size               = "Standard_B1s"
  
  storage_image_reference {
   id= "/subscriptions/8a7e8272-23b7-41d5-80a6-9fa61e8e2095/resourceGroups/terraform_hardened/providers/Microsoft.Compute/images/myVM-CISCentos-image-20190326161934"
 }

    storage_os_disk {
    name              = "myosdisk"
	os_type           = "Linux"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    }
  
  os_profile {
        computer_name  = "myVM"
        admin_username = "cloudxsupport"
		admin_password = "Abcd@123456789"
    }
	
	os_profile_linux_config {
	disable_password_authentication = false
	ssh_keys = [{
        path     = "/home/cloudxsupport/.ssh/authorized_keys"
        key_data = "${file("~/.ssh/id_rsa.pub")}"
      }]
    }

     boot_diagnostics {
        enabled = "true"
        storage_uri = "${azurerm_storage_account.mystorageaccount.primary_blob_endpoint}"
    }

    tags {
        environment = "Terraform Demo"
		}
		
	connection {
	type = "ssh"
        private_key = "${file("~/.ssh/id_rsa")}"
        user = "cloudxsupport"
        password = "Abcd@123456789"  
        agent = false		
        }	
	    	
	provisioner "remote-exec" {
	    inline = [
        "echo Abcd@123456789 | sudo -S su - cloudxsupport",
		"sudo wget https://s3.ap-south-1.amazonaws.com/terraformautomationpackages/Linux/CentOS/mongoDB/4.0/mongodb-org.repo -P /etc/yum.repos.d/",
		"sudo yum repolist",
		"sudo yum install mongodb-org -y",
		"sudo systemctl start mongod"
		]
    }
}
