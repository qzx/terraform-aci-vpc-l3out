/**
 * # terraform-aci-vpc-l3out
 * 
 * Terraform module to set up an L3Out with two VPCs, one in each DC
 * Defaults will deploy to the DataCenter 1800F Firewalls
 *
 * # Example, over configured
 *
 * ```hcl
 * module "aci_vpc_l3out" {
 *   #source = "github.com/qzx/terraform-aci-vpc-l3out"
 * 
 *   source      = "../terraform-aci-vpc-l3out"
 *   name        = "L3OUT-NAME"
 *   tenant_name = "example"
 *   vrf         = "example"
 *   l3_domain   = "l3 domain name"
 * 
 *   interconnect_subnet = "172.16.0.1/29"
 * 
 *   router_id_as_loopback = true
 * 
 *   paths = {
 *     primary = {
 *       name    = "EXAMPLE-VPC"
 *       pod_id  = 1
 *       nodes   = [101, 102]
 *       is_vpc  = true
 *       vlan_id = 301
 *       mtu     = 1500
 *     }
 *   }
 * 
 *   external_epgs = {
 *     Default = {
 *       subnets = ["0.0.0.0/0"]
 *       scope   = ["import-security"]
 *     }
 *     Privates = {
 *       subnets = ["10.0.0.0/8", "192.168.0.0/16", "172.16.0.0/12"]
 *       scope   = ["shared-rtctrl", "shared-security", "import-security"]
 *     }
 *   }
 * 
 *   static_routes = ["10.0.0.0/8", "192.168.0.0/16", "172.16.0.0/12"]
 * 
 *   ospf_enable = false
 * 
 *   ospf_timers = {
 *     hello_interval      = 5
 *     dead_interval       = 25
 *     retransmit_interval = 3
 *     transmit_delay      = 1
 *     priority            = 1
 *   }
 * 
 *   ospf_area = {
 *     id   = 1
 *     type = "nssa"
 *     cost = 1
 *   }
 * 
 *   bgp_peers = {
 *     primary = {
 *       address   = "1.1.1.1"
 *       local_as  = 10
 *       remote_as = 200
 *       password = ""
 *     },
 *     secondary = {
 *       address   = "2.2.2.2"
 *       local_as  = 10
 *       remote_as = 300
 *       password = "RoutingPassword"
 *     }
 *   }
 * }
 * ```
 */

terraform {
  required_providers {
    aci = {
      source  = "CiscoDevNet/aci"
      version = "~> 0.7.0"
    }
  }
}

### Load in the tenant we're going to be working with as a data source
data "aci_tenant" "this" {
  name = var.tenant_name
}

### Load in the VRF we're deploying into as data source
data "aci_vrf" "this" {
  tenant_dn = data.aci_tenant.this.id
  name      = var.vrf
}

data "aci_l3_domain_profile" "this" {
  name = var.l3_domain
}

resource "aci_l3_outside" "this" {
  tenant_dn              = data.aci_tenant.this.id
  relation_l3ext_rs_ectx = data.aci_vrf.this.id

  name                         = local.name
  relation_l3ext_rs_l3_dom_att = data.aci_l3_domain_profile.this.id
}

resource "aci_logical_node_profile" "this" {
  l3_outside_dn = aci_l3_outside.this.id
  name          = "${local.name}-NodeP"
}

### Subnet configurations
resource "aci_external_network_instance_profile" "this" {
  for_each = var.external_epgs

  l3_outside_dn = aci_l3_outside.this.id
  name          = each.key
}

resource "aci_l3_ext_subnet" "this" {
  for_each = local.external_subnets

  external_network_instance_profile_dn = aci_external_network_instance_profile.this[each.value.external_epg].id
  ip                                   = each.value.subnet
  scope                                = each.value.scope
}

### Nodes
resource "aci_logical_node_to_fabric_node" "this" {
  for_each = local.nodes

  tdn    = each.value.node
  rtr_id = each.value.router_id

  logical_node_profile_dn = aci_logical_node_profile.this.id
  rtr_id_loop_back        = var.router_id_as_loopback
}

### Interfaces
resource "aci_logical_interface_profile" "this" {
  logical_node_profile_dn = aci_logical_node_profile.this.id
  name                    = "${local.name}-Intf"
}

data "aci_fabric_path_ep" "this" {
  for_each = var.paths

  vpc     = each.value.is_vpc
  pod_id  = each.value.pod_id
  node_id = join("-", each.value.nodes)
  name    = each.value.name
}

resource "aci_l3out_path_attachment" "this" {
  for_each = local.paths

  logical_interface_profile_dn = aci_logical_interface_profile.this.id
  target_dn                    = data.aci_fabric_path_ep.this[each.key].id
  if_inst_t                    = "ext-svi"
  encap                        = "vlan-${each.value.vlan_id}"
  mtu                          = each.value.mtu
}


resource "aci_l3out_vpc_member" "this" {
  for_each = local.vpc_ip_addresses

  leaf_port_dn = aci_l3out_path_attachment.this[each.value.path_key].id
  side         = each.value.side
  addr         = each.value.ip_address
}

resource "aci_l3out_path_attachment_secondary_ip" "this" {
  for_each = local.vpc_ip_addresses

  l3out_path_attachment_dn = aci_l3out_vpc_member.this[each.key].id
  addr                     = local.floating_address
}

### Routing
## Static

resource "aci_l3out_static_route" "this" {
  for_each = local.static_routes

  fabric_node_dn = aci_logical_node_to_fabric_node.this[each.value.node].id
  ip             = each.value.subnet
  aggregate      = "no"
  rt_ctrl        = "bfd"
}

resource "aci_l3out_static_route_next_hop" "this" {
  for_each = local.static_routes

  static_route_dn = aci_l3out_static_route.this[each.key].id
  nh_addr         = each.value.next_hop
}

## OSPF

resource "aci_ospf_interface_policy" "this" {
  for_each = local.ospf_timers

  tenant_dn    = data.aci_tenant.this.id
  name         = "${var.tenant_name}-OSPF-Pol"
  hello_intvl  = each.value.hello_interval
  dead_intvl   = each.value.dead_interval
  rexmit_intvl = each.value.retransmit_interval
  xmit_delay   = each.value.transmit_delay
  prio         = each.value.priority
}


resource "aci_l3out_ospf_interface_profile" "this" {
  for_each = local.ospf_timers

  logical_interface_profile_dn = aci_logical_interface_profile.this.id
  auth_key                     = local.ospf_auth.auth.key
  auth_key_id                  = local.ospf_auth.auth.key_id
  auth_type                    = local.ospf_auth.auth.type
  relation_ospf_rs_if_pol      = aci_ospf_interface_policy.this[each.key].id
}

resource "aci_l3out_ospf_external_policy" "this" {
  for_each = local.ospf_area

  l3_outside_dn = aci_l3_outside.this.id
  area_cost     = each.value.cost
  area_id       = each.value.id
  area_type     = each.value.type
}

## BGP 
resource "aci_l3out_bgp_external_policy" "this" {
  for_each = local.bgp_enable

  l3_outside_dn = aci_l3_outside.this.id
}

resource "aci_bgp_peer_connectivity_profile" "this" {
  for_each = local.bgp_peers

  logical_node_profile_dn = aci_logical_node_profile.this.id
  addr                    = each.value.address
  as_number               = each.value.remote_as
  local_asn               = each.value.local_as
}