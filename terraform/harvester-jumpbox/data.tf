data "harvester_network" "services" {
  name      = "services"
  namespace = "default"
}
data "harvester_network" "sandbox" {
  name      = "sandbox"
  namespace = "default"
}
data "harvester_network" "dev" {
  name      = "dev"
  namespace = "default"
}
data "harvester_network" "prod" {
  name      = "prod"
  namespace = "default"
}
data "harvester_image" "ubuntu2004" {
  name      = "ubuntu-2004"
  namespace = "default"
}