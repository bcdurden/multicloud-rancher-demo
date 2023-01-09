data "harvester_network" "services" {
  name      = var.target_network_name
  namespace = "default"
}
data "harvester_image" "ubuntu2004" {
  name      = "ubuntu-2004"
  namespace = "default"
}
data "harvester_image" "ubuntu2004-rke2" {
  name      = var.harvester_rke2_image_name
  namespace = "default"
}