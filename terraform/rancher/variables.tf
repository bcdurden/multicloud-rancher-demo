variable "vpc_id" {
  type        = string
  description = "Target VPC"
}

variable "subnet_ids" {
  type = list(string)
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "aws_access_key" {
  type        = string
  description = "AWS access key used to create infrastructure"
}

# Required
variable "aws_secret_key" {
  type        = string
  description = "AWS secret key used to create AWS infrastructure"
}

variable "aws_session_token" {
  type        = string
  description = "AWS session token used to create AWS infrastructure"
  default     = ""
}

variable "aws_region" {
  type        = string
  description = "AWS region used for all resources"
  default     = "us-gov-west-1"
}

variable "prefix" {
  type        = string
  description = "Prefix added to names of all resources"
  default     = "multicloud-demo"
}

variable "control_plane_instance_type" {
  type        = string
  description = "Instance type used for controlplane EC2 instances"
  default     = "t3a.medium"
}
variable "worker_instance_type" {
  type        = string
  description = "Instance type used for worker EC2 instances"
  default     = "t3a.medium"
}

variable "ami_id" {
  type        = string
  default     = "ami-0f1289f37e46c1eff"
}

variable "main_cluster_prefix" {
    type = string
    default = "rke2-mgmt-controlplane"
}
variable "worker_prefix" {
    type = string
    default = "rke2-mgmt-worker"
}
variable "kubeconfig_filename" {
    type = string
    default = "kube_config_server.yaml"
}
variable "cert_manager_version" {
  type        = string
  description = "Version of cert-manager to install alongside Rancher (format: 0.0.0)"
  default     = "1.7.3"
}

variable "rancher_version" {
  type        = string
  description = "Rancher server version (format v0.0.0)"
  default     = "2.6.7"
}
variable "rancher_server_dns" {
  type        = string
  description = "DNS host name of the Rancher server"
  default = "rancher.sienarfleet.systems"
}
variable "rancher_bootstrap_password" {
  type = string
  default = "admin" # TODO: change this once the terraform provider has been updated with the new pw bootstrap logic
}
variable "rancher_replicas" {
  type = string
  default = 1
}
variable "worker_count" {
  type = string
  default = 3
}
variable "node_disk_size" {
  type = string
  default = 20
}
variable "cluster_token" {
    type = string
    default = "my-shared-token"
}
variable "rke2_version" {
  type = string
  default = "v1.24.3+rke2r1"
}