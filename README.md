# terraform-aci-vpc-l3out

Terraform module to set up an L3Out with one or more VPCs, one in each DC

# Example, over configured

```hcl
module "aci_vpc_l3out" {
  #source = "github.com/qzx/terraform-aci-vpc-l3out"

  source      = "../terraform-aci-vpc-l3out"
  name        = "L3OUT-NAME"
  tenant_name = "example"
  vrf         = "example"
  l3_domain   = "l3 domain name"

  interconnect_subnet = "172.16.0.1/29"

  router_id_as_loopback = true

  paths = {
    primary = {
      name    = "EXAMPLE-VPC"
      pod_id  = 1
      nodes   = [101, 102]
      is_vpc  = true
      vlan_id = 301
      mtu     = 1500
    }
  }

  external_epgs = {
    Default = {
      subnets = ["0.0.0.0/0"]
      scope   = ["import-security"]
    }
    Privates = {
      subnets = ["10.0.0.0/8", "192.168.0.0/16", "172.16.0.0/12"]
      scope   = ["shared-rtctrl", "shared-security", "import-security"]
    }
  }

  static_routes = ["10.0.0.0/8", "192.168.0.0/16", "172.16.0.0/12"]

  ospf_enable = false

  ospf_timers = {
    hello_interval      = 5
    dead_interval       = 25
    retransmit_interval = 3
    transmit_delay      = 1
    priority            = 1
  }

  ospf_area = {
    id   = 1
    type = "nssa"
    cost = 1
  }

  bgp_peers = {
    primary = {
      address   = "1.1.1.1"
      local_as  = 10
      remote_as = 200
      password = ""
    },
    secondary = {
      address   = "2.2.2.2"
      local_as  = 10
      remote_as = 300
      password = "RoutingPassword"
    }
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_aci"></a> [aci](#requirement\_aci) | ~> 0.7.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aci"></a> [aci](#provider\_aci) | ~> 0.7.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aci_bgp_peer_connectivity_profile.this](https://registry.terraform.io/providers/CiscoDevNet/aci/latest/docs/resources/bgp_peer_connectivity_profile) | resource |
| [aci_external_network_instance_profile.this](https://registry.terraform.io/providers/CiscoDevNet/aci/latest/docs/resources/external_network_instance_profile) | resource |
| [aci_l3_ext_subnet.this](https://registry.terraform.io/providers/CiscoDevNet/aci/latest/docs/resources/l3_ext_subnet) | resource |
| [aci_l3_outside.this](https://registry.terraform.io/providers/CiscoDevNet/aci/latest/docs/resources/l3_outside) | resource |
| [aci_l3out_bgp_external_policy.this](https://registry.terraform.io/providers/CiscoDevNet/aci/latest/docs/resources/l3out_bgp_external_policy) | resource |
| [aci_l3out_ospf_external_policy.this](https://registry.terraform.io/providers/CiscoDevNet/aci/latest/docs/resources/l3out_ospf_external_policy) | resource |
| [aci_l3out_ospf_interface_profile.this](https://registry.terraform.io/providers/CiscoDevNet/aci/latest/docs/resources/l3out_ospf_interface_profile) | resource |
| [aci_l3out_path_attachment.this](https://registry.terraform.io/providers/CiscoDevNet/aci/latest/docs/resources/l3out_path_attachment) | resource |
| [aci_l3out_path_attachment_secondary_ip.this](https://registry.terraform.io/providers/CiscoDevNet/aci/latest/docs/resources/l3out_path_attachment_secondary_ip) | resource |
| [aci_l3out_static_route.this](https://registry.terraform.io/providers/CiscoDevNet/aci/latest/docs/resources/l3out_static_route) | resource |
| [aci_l3out_static_route_next_hop.this](https://registry.terraform.io/providers/CiscoDevNet/aci/latest/docs/resources/l3out_static_route_next_hop) | resource |
| [aci_l3out_vpc_member.this](https://registry.terraform.io/providers/CiscoDevNet/aci/latest/docs/resources/l3out_vpc_member) | resource |
| [aci_logical_interface_profile.this](https://registry.terraform.io/providers/CiscoDevNet/aci/latest/docs/resources/logical_interface_profile) | resource |
| [aci_logical_node_profile.this](https://registry.terraform.io/providers/CiscoDevNet/aci/latest/docs/resources/logical_node_profile) | resource |
| [aci_logical_node_to_fabric_node.this](https://registry.terraform.io/providers/CiscoDevNet/aci/latest/docs/resources/logical_node_to_fabric_node) | resource |
| [aci_ospf_interface_policy.this](https://registry.terraform.io/providers/CiscoDevNet/aci/latest/docs/resources/ospf_interface_policy) | resource |
| [aci_fabric_path_ep.this](https://registry.terraform.io/providers/CiscoDevNet/aci/latest/docs/data-sources/fabric_path_ep) | data source |
| [aci_l3_domain_profile.this](https://registry.terraform.io/providers/CiscoDevNet/aci/latest/docs/data-sources/l3_domain_profile) | data source |
| [aci_tenant.this](https://registry.terraform.io/providers/CiscoDevNet/aci/latest/docs/data-sources/tenant) | data source |
| [aci_vrf.this](https://registry.terraform.io/providers/CiscoDevNet/aci/latest/docs/data-sources/vrf) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bgp_peers"></a> [bgp\_peers](#input\_bgp\_peers) | BGP Neighbour configuration, having a neighbour causes BGP to be enabled, nodes must have loopbacks (enable router\_id\_as\_loopback) | <pre>map(object({<br>    address   = string,<br>    local_as  = number,<br>    remote_as = number,<br>    password  = string,<br>  }))</pre> | `{}` | no |
| <a name="input_external_epgs"></a> [external\_epgs](#input\_external\_epgs) | Map of external EPGs to create as network objects | <pre>map(object({<br>    subnets = list(string),<br>    scope   = list(string),<br>  }))</pre> | <pre>{<br>  "default": {<br>    "scope": [<br>      "import-security"<br>    ],<br>    "subnets": [<br>      "0.0.0.0/0"<br>    ]<br>  }<br>}</pre> | no |
| <a name="input_interconnect_subnet"></a> [interconnect\_subnet](#input\_interconnect\_subnet) | The interconnect subnet to use, the module will increment by 1 before each IP allocation, and take the last address as floating IP for static routing | `string` | n/a | yes |
| <a name="input_l3_domain"></a> [l3\_domain](#input\_l3\_domain) | The Layer3 domain this L3Out belongs to | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Affix to use for our generated L3Out name | `string` | n/a | yes |
| <a name="input_ospf_area"></a> [ospf\_area](#input\_ospf\_area) | OSPF Area settings | <pre>object({<br>    id   = number,<br>    type = string,<br>    cost = number,<br>  })</pre> | <pre>{<br>  "cost": 1,<br>  "id": 0,<br>  "type": "regular"<br>}</pre> | no |
| <a name="input_ospf_auth"></a> [ospf\_auth](#input\_ospf\_auth) | OSPF authentication settings if ospf is enabled, key\_id can range from 1-255 and key\_type can be: md5, simple or none | <pre>object({<br>    key    = string,<br>    key_id = number,<br>    type   = string,<br>  })</pre> | <pre>{<br>  "key": "",<br>  "key_id": 1,<br>  "type": "none"<br>}</pre> | no |
| <a name="input_ospf_enable"></a> [ospf\_enable](#input\_ospf\_enable) | Enable OSPF, timers and area settings can be over written with ospf\_area and ospf\_timers | `bool` | `false` | no |
| <a name="input_ospf_timers"></a> [ospf\_timers](#input\_ospf\_timers) | Optional ospf timing configuration to pass on, sensible defaults are provided | <pre>object({<br>    hello_interval      = number,<br>    dead_interval       = number,<br>    retransmit_interval = number,<br>    transmit_delay      = number,<br>    priority            = number,<br>  })</pre> | <pre>{<br>  "dead_interval": 40,<br>  "hello_interval": 10,<br>  "priority": 1,<br>  "retransmit_interval": 5,<br>  "transmit_delay": 1<br>}</pre> | no |
| <a name="input_paths"></a> [paths](#input\_paths) | The interface path to which we will deploy the L3Out | <pre>map(object({<br>    name    = string,<br>    pod_id  = number,<br>    nodes   = list(number),<br>    is_vpc  = bool,<br>    vlan_id = number,<br>    mtu     = number,<br>  }))</pre> | n/a | yes |
| <a name="input_router_id_as_loopback"></a> [router\_id\_as\_loopback](#input\_router\_id\_as\_loopback) | Set to true if router IDs should be installed as loopback addresses to respective switches | `bool` | `false` | no |
| <a name="input_static_routes"></a> [static\_routes](#input\_static\_routes) | List of subnets in CIDR notation to be statically routed to the first IP address of the interconnect subnet | `list(string)` | `[]` | no |
| <a name="input_static_subnets"></a> [static\_subnets](#input\_static\_subnets) | List of subnets that are to be statically routed to the bottom address | `list(string)` | `[]` | no |
| <a name="input_tenant_name"></a> [tenant\_name](#input\_tenant\_name) | The tenant we want to deploy our L3Out into | `string` | n/a | yes |
| <a name="input_vrf"></a> [vrf](#input\_vrf) | The associated VRF we are deploying into | `string` | n/a | yes |
| <a name="input_vrf_id"></a> [vrf\_id](#input\_vrf\_id) | The ID of the VRF being used, this is required for the router ID generation if the module is already managing an L3Out in the same tenant but different VRF | `number` | `1` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_l3out_epgs"></a> [l3out\_epgs](#output\_l3out\_epgs) | List of external EPGs created |
