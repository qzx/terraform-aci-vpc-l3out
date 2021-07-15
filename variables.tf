variable "name" {
  type        = string
  description = "Affix to use for our generated L3Out name"
}

variable "tenant_name" {
  type        = string
  description = "The tenant we want to deploy our L3Out into"
}

variable "vrf" {
  type        = string
  description = "The associated VRF we are deploying into"
}

variable "vrf_id" {
  type        = number
  description = "The ID of the VRF being used, this is required for the router ID generation if the module is already managing an L3Out in the same tenant but different VRF"
  default     = 1
}

variable "l3_domain" {
  type        = string
  description = "The Layer3 domain this L3Out belongs to"
}

variable "router_id_as_loopback" {
  type        = bool
  description = "Set to true if router IDs should be installed as loopback addresses to respective switches"
  default     = false
}

variable "static_subnets" {
  type        = list(string)
  description = "List of subnets that are to be statically routed to the bottom address"
  default     = []
}

variable "interconnect_subnet" {
  type        = string
  description = "The interconnect subnet to use, the module will increment by 1 before each IP allocation, and take the last address as floating IP for static routing"
}

variable "paths" {
  type = map(object({
    name    = string,
    pod_id  = number,
    nodes   = list(number),
    is_vpc  = bool,
    vlan_id = number,
    mtu     = number,
  }))
  description = "The interface path to which we will deploy the L3Out"
}

variable "external_epgs" {
  type = map(object({
    subnets = list(string),
    scope   = list(string),
  }))
  description = "Map of external EPGs to create as network objects"
  default = {
    default = {
      subnets = ["0.0.0.0/0"],
      scope   = ["import-security"]
    }
  }
}

variable "static_routes" {
  type        = list(string)
  description = "List of subnets in CIDR notation to be statically routed to the first IP address of the interconnect subnet"
  default     = []
}

variable "ospf_enable" {
  type        = bool
  description = "Enable OSPF, timers and area settings can be over written with ospf_area and ospf_timers"
  default     = false
}

variable "ospf_area" {
  type = object({
    id   = number,
    type = string,
    cost = number,
  })
  description = "OSPF Area settings"
  default = {
    id   = 0
    type = "regular"
    cost = 1
  }
}

variable "ospf_timers" {
  type = object({
    hello_interval      = number,
    dead_interval       = number,
    retransmit_interval = number,
    transmit_delay      = number,
    priority            = number,
  })
  description = "Optional ospf timing configuration to pass on, sensible defaults are provided"
  default = {
    hello_interval      = 10
    dead_interval       = 40
    retransmit_interval = 5
    transmit_delay      = 1
    priority            = 1
  }
}

variable "ospf_auth" {
  type = object({
    key    = string,
    key_id = number,
    type   = string,
  })
  description = "OSPF authentication settings if ospf is enabled, key_id can range from 1-255 and key_type can be: md5, simple or none"
  default = {
    key    = ""
    key_id = 1
    type   = "none"
  }
}

variable "bgp_peers" {
  type = map(object({
    address   = string,
    local_as  = number,
    remote_as = number,
    password  = string,
  }))
  description = "BGP Neighbour configuration, having a neighbour causes BGP to be enabled, nodes must have loopbacks (enable router_id_as_loopback)"
  default     = {}
}

locals {
  ospf_area   = var.ospf_enable ? { area = var.ospf_area } : {}
  ospf_timers = var.ospf_enable ? { timers = var.ospf_timers } : {}
  ospf_auth   = var.ospf_enable ? { auth = var.ospf_auth } : {}
}

locals {
  bgp_peers  = var.bgp_peers
  bgp_enable = length(var.bgp_peers) > 0 ? { "enable" = "yes" } : {}
}

locals {
  interconnect_subnet  = var.interconnect_subnet
  interconnect_bitmask = split("/", var.interconnect_subnet)[1]
}

locals {
  node_list = distinct(
    flatten([
      for path_key, path in var.paths : [
        for node in path.nodes : {
          node      = "topology/pod-${path.pod_id}/node-${node}"
          router_id = "1.${path.pod_id}.${node}.${var.vrf_id}"
          path_key  = path_key
          node_id   = node
          is_vpc    = path.is_vpc
        }
      ]
    ])
  )
}

locals {
  vpc_ip_addresses = {
    for node in local.nodes : node.node => {
      path_key   = node.path_key
      ip_address = join("/", [cidrhost(local.interconnect_subnet, (index(local.node_list, node) + 2)), local.interconnect_bitmask])
      side       = (node.node_id % 2 == 0 ? "B" : "A")
    } if node.is_vpc == true
  }
  ip_addresses = {
    for node in local.nodes : node.node => {
      path_key   = node.path_key
      ip_address = join("/", [cidrhost(local.interconnect_subnet, (index(local.node_list, node) + 2)), local.interconnect_bitmask])
    } if node.is_vpc == false
  }
}

locals {
    paths =  var.paths
}


locals {
  external_subnet_list = flatten([
    for epg_key, epg in var.external_epgs : [
      for subnet in epg.subnets : {
        external_epg = epg_key
        subnet       = subnet
        scope        = epg.scope
        key          = "${epg_key}/${subnet}"
      }
    ]
  ])
  domain           = var.l3_domain
  name             = var.name
  static_gateway   = cidrhost(local.interconnect_subnet, 1)
  floating_address = join("/", [cidrhost(local.interconnect_subnet, length(local.nodes) + 2), local.interconnect_bitmask])
}

locals {
  static_route_list = flatten([
    for node in local.nodes : [
      for subnet in var.static_routes : {
        key      = join("/", [node.node, subnet])
        subnet   = subnet
        next_hop = local.static_gateway
        node     = node.node
      }
    ]
  ])
}

locals {
  static_routes = {
    for route in local.static_route_list : route.key => route
  }
  nodes = {
    for node in local.node_list : node.node => node
  }
  external_subnets = {
    for subnet in local.external_subnet_list : subnet.key => subnet
  }
}
 