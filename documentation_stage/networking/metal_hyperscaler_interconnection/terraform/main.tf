terraform {
  required_providers {
    equinix = {
      source = "equinix/equinix"
    }
    aws = {
      source  = "hashicorp/aws"
      }
  }
}

provider "equinix" {
  client_id     = var.equinix_provider_client_id
  client_secret = var.equinix_provider_client_secret
}


provider "aws" { 
  region = var.aws_region
}

locals {
  connection_name = format("dlott-conn-metal-aws-%s", lower(var.fabric_destination_metro_code))
}

data "cloudinit_config" "config" {
  gzip          = false # not supported on Equinix Metal
  base64_encode = false # not supported on Equinix Metal

  part {
    content_type = "text/cloud-config"
    content = file("ubuntu_2004_rework.yaml")
    }
}

resource "equinix_metal_vlan" "interconnect_host_local_vlan01" {
  description = "VLAN for hosts purposed for Interconnection"
  metro = var.metal_metro
  project_id = var.metal_project_id
}

resource "equinix_metal_vlan" "interconnect_traffic_local_vlan01" {
  description = "VLAN01 for local Metal traffic that may be destined for GCP interconnect purposed for Interconnection"
  metro = var.metal_metro
  project_id = var.metal_project_id
}

resource "equinix_metal_vlan" "interconnect_traffic_local_vlan02" {
  description = "VLAN02 for local Metal traffic that may be destined for GCP interconnect purposed for Interconnection"
  metro = var.metal_metro
  project_id = var.metal_project_id
}

resource "equinix_metal_vlan" "interconnect_traffic_local_vlan03" {
  description = "VLAN03 for local Metal traffic that may be destined for GCP interconnect purposed for Interconnection"
  metro = var.metal_metro
  project_id = var.metal_project_id
}

resource "equinix_metal_vlan" "interconnect_traffic_gcp_vlan01" {
  description = "VLAN for hosts purposed for Interconnection"
  metro = var.metal_metro
  project_id = var.metal_project_id
}

# ###

resource "equinix_metal_device" "interconnect-gcp01" {
  hostname = "interconnect-gcp01"
  plan = "m3.small.x86"
  metro = var.metal_metro
  operating_system = "ubuntu_22_04"
  billing_cycle = "hourly"
  project_id = var.metal_project_id
  tags = ["interconnect","interconnect-gcp","terraform"]
  user_data = data.cloudinit_config.config.rendered
}

resource "equinix_metal_device_network_type" "interconnect-gcp01_convert_network" {
  device_id  = equinix_metal_device.interconnect-gcp01.id
  type       = "hybrid-bonded"
  depends_on = [equinix_metal_device.interconnect-gcp01]
}

resource "equinix_metal_port_vlan_attachment" "interconnect-gcp01_convert_network_attach" {
  device_id = equinix_metal_device_network_type.interconnect-gcp01_convert_network.id
  port_name = "bond0"
  vlan_vnid = equinix_metal_vlan.interconnect_host_local_vlan01.vxlan
}

resource "equinix_metal_port_vlan_attachment" "interconnect-gcp01_convert_network_attach_traffic_local_vlan01" {
  device_id = equinix_metal_device_network_type.interconnect-gcp01_convert_network.id
  port_name = "bond0"
  vlan_vnid = equinix_metal_vlan.interconnect_traffic_local_vlan01.vxlan
}

# ### 

resource "equinix_metal_device" "interconnect-gcp02" {
  hostname = "interconnect-gcp02"
  plan = "m3.small.x86"
  metro = var.metal_metro
  operating_system = "ubuntu_22_04"
  billing_cycle = "hourly"
  project_id = var.metal_project_id
  tags = ["interconnect","interconnect-gcp","terraform"]
  user_data = data.cloudinit_config.config.rendered
}

resource "equinix_metal_device_network_type" "interconnect-gcp02_convert_network" {
  device_id  = equinix_metal_device.interconnect-gcp02.id
  type       = "hybrid-bonded"
  depends_on = [equinix_metal_device.interconnect-gcp02]
}

resource "equinix_metal_port_vlan_attachment" "interconnect-gcp02_convert_network_attach" {
  device_id = equinix_metal_device_network_type.interconnect-gcp02_convert_network.id
  port_name = "bond0"
  vlan_vnid = equinix_metal_vlan.interconnect_host_local_vlan01.vxlan
}

# ### 

resource "equinix_metal_device" "worker-gcp01" {
  hostname = "worker-gcp01"
  plan = "m3.small.x86"
  metro = var.metal_metro
  operating_system = "ubuntu_22_04"
  billing_cycle = "hourly"
  project_id = var.metal_project_id
  tags = ["interconnect","interconnect-gcp","terraform"]
  user_data = data.cloudinit_config.config.rendered
}

resource "equinix_metal_device_network_type" "worker-gcp01_convert_network" {
  device_id  = equinix_metal_device.worker-gcp01.id
  type       = "hybrid-bonded"
  depends_on = [equinix_metal_device.worker-gcp01]
}

resource "equinix_metal_port_vlan_attachment" "worker-gcp01_convert_network_attach" {
  device_id = equinix_metal_device_network_type.worker-gcp01_convert_network.id
  port_name = "bond0"
  vlan_vnid = equinix_metal_vlan.interconnect_traffic_local_vlan01.vxlan
}

# ###
resource "equinix_metal_connection" "this" {
    name               = local.connection_name
    project_id         = var.metal_project_id
    metro              = var.fabric_destination_metro_code
    redundancy         = var.redundancy_type == "SINGLE" ? "primary" : "redundant"
    type               = "shared"
    service_token_type = "a_side"
    description        = format("connection to AWS in %s", var.fabric_destination_metro_code)
    speed              = format("%dMbps", var.fabric_speed)
    vlans              = [equinix_metal_vlan.interconnect_traffic_local_vlan01.vxlan]
}

## Create an AWS VPC
resource "aws_vpc" "this" {
  cidr_block = "10.0.0.0/16"
}

module "equinix-fabric-connection-aws-primary" {
  source = "equinix-labs/fabric-connection-aws/equinix"
  
  fabric_notification_users     = var.fabric_notification_users
  fabric_connection_name        = local.connection_name
  fabric_destination_metro_code = var.fabric_destination_metro_code
  fabric_speed                  = var.fabric_speed
  fabric_service_token_id       = equinix_metal_connection.this.service_tokens.0.id
  
  aws_account_id = var.aws_account_id

  aws_dx_create_vgw = true
  aws_vpc_id        = aws_vpc.this.id // If not specified 'Default' VPC will be used

  ## BGP and Direct Connect private virtual interface config
  aws_dx_create_vif           = true
  # aws_dx_vif_address_family   = // If unspecified, default value "ipv4" will be used
  aws_dx_vif_amazon_address   = "169.254.0.1/30" // If unspecified, default value "169.254.0.1/30" will be used
  aws_dx_vif_customer_address = "169.254.0.2/30" // If unspecified, default value "169.254.0.2/30" will be used
  # aws_dx_vif_customer_asn     = // If unspecified, default value "65000" will be used
  # aws_dx_mtu_size             = // If unspecified, default value 1500 will be used
  aws_dx_bgp_auth_key         = var.bgp_password
}
