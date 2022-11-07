# output "node_vm_ip" {
#     value = module.controlplane-nodes.node_vm_ip

# }
output "ssh_key" {
    value = tls_private_key.global_key.private_key_pem
    sensitive = true
}
output "ssh_pubkey" {
    value = tls_private_key.global_key.public_key_openssh
}
output "kube" {
    value = local_file.kube_config_server_yaml.content
    sensitive = true
}
output "rancher_api_lb_dns" {
    value = aws_lb.apiserver_lb.dns_name
}
output "rancher_ingress_lb_dns" {
    value = aws_lb.ingress_lb.dns_name
}