resource "harvester_virtualmachine" "jumpbox" {
  name                 = "ubuntu-jumpbox"
  namespace            = "default"
  restart_after_update = true

  description = "Jumpbox VM"
  tags = {
    ssh-user = "ubuntu"
  }

  cpu    = 2
  memory = "4Gi"

  run_strategy = "RerunOnFailure"
  hostname     = "jumpbox"
  machine_type = "q35"

  network_interface {
    name           = "default"
    network_name   = data.harvester_network.services.id
    wait_for_lease = true
  }

  disk {
    name       = "rootdisk"
    type       = "disk"
    size       = "80Gi"
    bus        = "virtio"
    boot_order = 1

    image       = data.harvester_image.ubuntu2004.id
    auto_delete = true
  }

  cloudinit {
    type      = "noCloud"
    
    user_data    = <<EOT
      #cloud-config
      package_update: true
      packages:
      - qemu-guest-agent
      - make
      runcmd:
      - - systemctl
        - enable
        - '--now'
        - qemu-guest-agent.service
      - snap install helm --classic
      - snap install kubectl --classic
      - snap install terraform --classic
      - wget https://github.com/sigstore/cosign/releases/download/v1.12.1/cosign-linux-amd64
      - install cosign-linux-amd64 /usr/local/bin/cosign
      - rm cosign-linux-amd64
      - wget https://github.com/sunny0826/kubecm/releases/download/v0.21.0/kubecm_v0.21.0_Linux_x86_64.tar.gz
      - tar xvf kubecm_v0.21.0_Linux_x86_64.tar.gz
      - install kubecm /usr/local/bin/kubecm
      - rm LICENSE README kubecm kubecm_v0.21.0_Linux_x86_64.tar.gz
      - git clone https://github.com/ahmetb/kubectx /opt/kubectx
      - ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx
      - ln -s /opt/kubectx/kubens /usr/local/bin/kubens

      ssh_authorized_keys: 
      - ${tls_private_key.rsa_key.public_key_openssh}
    EOT
    network_data = ""
  }
}