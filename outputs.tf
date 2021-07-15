output "l3out_epgs" {
  description = "List of external EPGs created"
  value = [
    for epg in aci_external_network_instance_profile.this : epg.id
  ]
}