# Helm resources
resource "local_file" "kube_config_server_yaml" {
  depends_on = [
    null_resource.retrieve_config
  ]
  filename = var.kubeconfig_filename
  source = "./kube.yaml"
}

# Install cert-manager helm chart
resource "helm_release" "cert_manager" {
  depends_on = [
    local_file.kube_config_server_yaml,
    aws_instance.rancher_server_workers
  ]

  name             = "cert-manager"
  chart            = "https://charts.jetstack.io/charts/cert-manager-v${var.cert_manager_version}.tgz"
  namespace        = "cert-manager"
  create_namespace = true
  wait             = true

  set {
    name  = "installCRDs"
    value = "true"
  }
}

# Install Rancher helm chart
resource "helm_release" "rancher_server" {
  depends_on = [
    helm_release.cert_manager
  ]

  name             = "rancher"
  chart            = "https://releases.rancher.com/server-charts/latest/rancher-${var.rancher_version}.tgz"
  namespace        = "cattle-system"
  create_namespace = true
  wait             = true

  set {
    name  = "hostname"
    value = var.rancher_server_dns
  }
  set {
    name  = "replicas"
    value = var.rancher_replicas
  }
  set {
    name  = "bootstrapPassword"
    value = var.rancher_bootstrap_password
  }
  set {
    name  = "certmanager.version"
    value = var.cert_manager_version
  }
  set {
    name = "ingress.tls.source"
    value = "secret"
  }
}
