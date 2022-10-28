# AWS infrastructure resources

# Security group to allow all traffic
resource "aws_security_group" "rancher_sg_allowall" {
  name        = "${var.prefix}-rancher-allowall"
  description = "Rancher multicloud demo - allow all traffic"
  vpc_id = var.vpc_id

  ingress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Creator = "terraform"
    owner   = "brian"
    KeepRunning = "true"
  }
}

# AWS EC2 instance for creating a single node RKE cluster and installing the Rancher server
resource "aws_instance" "rancher_server_master" {
  ami           = var.ami_id
  instance_type = var.control_plane_instance_type
  subnet_id = var.private_subnet_ids[0]
  associate_public_ip_address = false 
  iam_instance_profile = aws_iam_instance_profile.ssm_profile.name
  depends_on = [
    aws_lb.apiserver_lb
  ]

  key_name               = aws_key_pair.aws_terraform_keypair.key_name
  vpc_security_group_ids = [aws_security_group.rancher_sg_allowall.id]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]

    command = <<-EOF
    set -Ee -o pipefail
    export AWS_DEFAULT_REGION=${var.aws_region}
    sleep 20

    ssh -i ${local_sensitive_file.ssh_private_key_pem.filename} -o StrictHostKeyChecking=no -o ProxyCommand='sh -c "aws ssm start-session --target %h --document-name AWS-StartSSHSession"' ubuntu@${self.id} "cloud-init status --wait > /dev/null"
    
    if [ $? -eq 0 ]; then
      echo "Cloud-init detected to finish"
    else
      echo "Cloud-init detected to fail"
      exit 1
    fi

    EOF
  }

  root_block_device {
    volume_size = var.node_disk_size
  }

  user_data    = <<EOT
        #cloud-config
        package_update: true
        write_files:
        - path: /etc/rancher/rke2/config.yaml
          owner: root
          content: |
            token: ${var.cluster_token}
            tls-san:
            - ${var.rancher_server_dns}
            - ${aws_lb.apiserver_lb.dns_name}
        packages:
        - qemu-guest-agent
        runcmd:
        - - systemctl
          - enable
          - '--now'
          - qemu-guest-agent.service
        - curl -sfL https://get.rke2.io | INSTALL_RKE2_VERSION=${var.rke2_version} sh -
        - systemctl enable rke2-server.service
        - systemctl start rke2-server.service
        ssh_authorized_keys: 
        - ${tls_private_key.global_key.public_key_openssh}
      EOT

  tags = {
    Name    = "${var.prefix}-rancher-server"
    Creator = "terraform"
    owner   = "brian"
    KeepRunning = "true"
  }
}

resource "aws_instance" "rancher_server_workers" {
  count = var.worker_count
  depends_on = [
    aws_lb.apiserver_lb
  ]

  ami           = var.ami_id
  instance_type = var.worker_instance_type
  subnet_id = var.private_subnet_ids[count.index]
  associate_public_ip_address = false 
  iam_instance_profile = aws_iam_instance_profile.ssm_profile.name

  key_name               = aws_key_pair.aws_terraform_keypair.key_name
  vpc_security_group_ids = [aws_security_group.rancher_sg_allowall.id]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]

    command = <<-EOF
    set -Ee -o pipefail
    export AWS_DEFAULT_REGION=${var.aws_region}
    sleep 20

    ssh -i ${local_sensitive_file.ssh_private_key_pem.filename} -o StrictHostKeyChecking=no -o ProxyCommand='sh -c "aws ssm start-session --target %h --document-name AWS-StartSSHSession"' ubuntu@${self.id} "cloud-init status --wait > /dev/null"

    if [ $? -eq 0 ]; then
      echo "Cloud-init detected to finish"
    else
      echo "Cloud-init detected to fail"
      exit 1
    fi

    EOF
  }


  root_block_device {
    volume_size = var.node_disk_size
  }

  user_data    = <<EOT
        #cloud-config
        package_update: true
        write_files:
        - path: /etc/rancher/rke2/config.yaml
          owner: root
          content: |
            token: ${var.cluster_token}
            server: https://${aws_instance.rancher_server_master.private_ip}:9345
        packages:
        - qemu-guest-agent
        runcmd:
        - - systemctl
          - enable
          - '--now'
          - qemu-guest-agent.service
        - curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE="agent" INSTALL_RKE2_VERSION=${var.rke2_version} sh -
        - systemctl enable rke2-agent.service
        - systemctl start rke2-agent.service
        ssh_authorized_keys: 
        - ${tls_private_key.global_key.public_key_openssh}
      EOT

  tags = {
    Name    = "${var.prefix}-rancher-server-worker-${count.index}"
    Creator = "terraform"
    owner   = "brian"
    KeepRunning = "true"
  }
}