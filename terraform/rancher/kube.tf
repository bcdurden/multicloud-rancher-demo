resource "null_resource" "retrieve_config" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]

    command = <<-EOF
    AWS_DEFAULT_REGION=${var.aws_region} ssh -i ${local_sensitive_file.ssh_private_key_pem.filename} -o StrictHostKeyChecking=no -o ProxyCommand='sh -c "aws ssm start-session --target %h --document-name AWS-StartSSHSession"' ubuntu@${aws_instance.rancher_server_master.id} "sudo sed \"s/127.0.0.1/${aws_lb.apiserver_lb.dns_name}/g\" /etc/rancher/rke2/rke2.yaml" > ./kube.yaml

    EOF
  }
}