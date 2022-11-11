resource "harvester_network" "services" {
  name      = "services"
  namespace = "default"

  vlan_id = 5
}
resource "harvester_network" "sandbox" {
  name      = "sandbox"
  namespace = "default"

  vlan_id = 6
}
resource "harvester_network" "dev" {
  name      = "dev"
  namespace = "default"

  vlan_id = 7
}
resource "harvester_network" "prod" {
  name      = "prod"
  namespace = "default"

  vlan_id = 8
}