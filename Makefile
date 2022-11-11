SHELL:=/bin/bash
REQUIRED_BINARIES := kubectl cosign helm terraform kubectx kubecm ytt yq jq
WORKING_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
ROOT_DIR := $(shell git rev-parse --show-toplevel)
BOOTSTRAP_DIR := ${WORKING_DIR}/bootstrap
TERRAFORM_DIR := ${WORKING_DIR}/terraform
WORKLOAD_DIR := ${ROOT_DIR}/workloads
GITOPS_DIR := ${ROOT_DIR}/gitops

BASE_URL=sienarfleet.systems
GITEA_URL=git.$(BASE_URL)
GIT_ADMIN_PASSWORD=""
CLOUD_TOKEN_FILE="key.json"

# Carbide info
CARBIDE_USER="internal-tester-read"
CARBIDE_PASSWORD=""
IMAGES_FILE=""

# Rancher on Harvester Info
RKE2_VIP=10.10.5.4
RANCHER_URL=rancher.home.$(BASE_URL)
RANCHER_HA_MODE=false
RANCHER_WORKER_COUNT=1
RANCHER_NODE_SIZE="20Gi"

# Harbor info
HARBOR_URL=harbor.home.$(BASE_URL)
HARBOR_USER=admin
HARBOR_PASSWORD=""

# workloads vars
WORKLOADS_KAPP_APP_NAME=workloads
WORKLOADS_NAMESPACE=default
LOCAL_CLUSTER_NAME=rancher-aws
HARVESTER_CONTEXT="harvester"

check-tools: ## Check to make sure you have the right tools
	$(foreach exec,$(REQUIRED_BINARIES),\
		$(if $(shell which $(exec)),,$(error "'$(exec)' not found. It is a dependency for this Makefile")))

# airgap targets
pull-rke2: check-tools
	@printf "\n===>Pulling RKE2 Images\n";
	@${BOOTSTRAP_DIR}/airgap_images/pull_carbide_rke2 $(CARBIDE_USER) '$(CARBIDE_PASSWORD)'
	@printf "\nIf successful, your images will be available at /tmp/rke2-images.tar.gz"
pull-rancher: check-tools
	@printf "\n===>Pulling Rancher Images\n";
	@${BOOTSTRAP_DIR}/airgap_images/pull_carbide_rancher $(CARBIDE_USER) '$(CARBIDE_PASSWORD)'
	@printf "\nIf successful, your images will be available at /tmp/rancher-images.tar.gz and /tmp/cert-manager.tar.gz"
pull-misc: check-tools
	@printf "\n===>Pulling Misc Images\n";
	@${BOOTSTRAP_DIR}/airgap_images/pull_misc
push-images: check-tools
	@printf "\n===>Pushing Images to Harbor\n";
	@${BOOTSTRAP_DIR}/airgap_images/push_carbide $(HARBOR_URL) $(HARBOR_USER) '$(HARBOR_PASSWORD)' $(IMAGES_FILE)

# certificate targets
certs: check-tools # needs CLOUDFLARE_TOKEN set and LOCAL_CLUSTER_NAME for non-default contexts
	@printf "\n===>Making Certificates\n";
	@kubectx $(LOCAL_CLUSTER_NAME)
	@kubectl create secret generic clouddns-dns01-solver-svc-acct -n cert-manager --from-file=$(CLOUD_TOKEN_FILE) --dry-run=client -o yaml | kubectl apply -f -
	@kubectl apply -f $(BOOTSTRAP_DIR)/certs/issuer-prod-clouddns.yaml --dry-run=client -o yaml | kubectl apply -f -
	@kubectl create ns harbor --dry-run=client -o yaml | kubectl apply -f -
	@ytt -f $(BOOTSTRAP_DIR)/certs/cert-harbor.yaml -v base_url=$(BASE_URL) | kubectl apply -f -
	@kubectl create ns git --dry-run=client -o yaml | kubectl apply -f -
	@ytt -f $(BOOTSTRAP_DIR)/certs/cert-gitea.yaml -v base_url=$(BASE_URL) | kubectl apply -f -
	@ytt -f $(BOOTSTRAP_DIR)/certs/cert-rancher.yaml -v base_url=$(BASE_URL) | kubectl apply -f -

certs-export: check-tools
	@printf "\n===>Exporting Certificates\n";
	@kubectx $(LOCAL_CLUSTER_NAME)
	@kubectl get secret -n harbor harbor-prod-homelab-certificate -o yaml > harbor_cert.yaml
	@kubectl get secret -n git gitea-prod-homelab-certificate -o yaml > gitea_cert.yaml
	@kubectl get secret -n cattle-system tls-rancher-ingress -o yaml > rancher_cert.yaml
certs-import: check-tools
	@printf "\n===>Importing Certificates\n";
	@kubectx $(LOCAL_CLUSTER_NAME)
	@kubectl apply -f harbor_cert.yaml
	@kubectl apply -f gitea_cert.yaml

# terraform targets
terraform: check-tools
	@$(VARS) terraform -chdir=${TERRAFORM_DIR}/$(COMPONENT) init
	@$(VARS) terraform -chdir=${TERRAFORM_DIR}/$(COMPONENT) apply
terraform-value: check-tools
	@terraform -chdir=${TERRAFORM_DIR}/$(COMPONENT) output -json | jq -r '.jumpbox_ssh_key.value'
terraform-destroy: check-tools
	@terraform -chdir=${TERRAFORM_DIR}/$(COMPONENT) destroy

rancher: check-tools
	@printf "\n====> Terraforming RKE2 + Rancher\n";
	$(MAKE) terraform COMPONENT=rancher
	@cp ${TERRAFORM_DIR}/rancher/kube_config_server.yaml /tmp/$(LOCAL_CLUSTER_NAME).yaml && kubecm add -c -f /tmp/$(LOCAL_CLUSTER_NAME).yaml && rm /tmp/$(LOCAL_CLUSTER_NAME).yaml
	@kubectx $(LOCAL_CLUSTER_NAME)
	$(MAKE) certs
rancher-destroy: check-tools
	@printf "\n====> Destroying RKE2 + Rancher\n";
	$(MAKE) terraform-destroy COMPONENT=rancher
	@kubecm delete $(LOCAL_CLUSTER_NAME)

infra: check-tools
	@printf "\n=====> Terraforming Infra\n";
	$(MAKE) terraform COMPONENT=harvester-infra

harvester-rancher: check-tools
	@printf "\n====> Terraforming RKE2 + Rancher\n";
	$(MAKE) terraform COMPONENT=harvester-rancher
	@cp ${TERRAFORM_DIR}/rancher/kube_config_server.yaml /tmp/$(LOCAL_CLUSTER_NAME).yaml && kubecm add -c -f /tmp/$(LOCAL_CLUSTER_NAME).yaml && rm /tmp/$(LOCAL_CLUSTER_NAME).yaml
	@kubectx $(LOCAL_CLUSTER_NAME)
	$(MAKE) certs
harvester-rancher-destroy: check-tools
	@printf "\n====> Destroying RKE2 + Rancher\n";
	$(MAKE) terraform-destroy COMPONENT=harvester-rancher
	@kubecm delete $(LOCAL_CLUSTER_NAME)

jumpbox: check-tools
	@printf "\n====> Terraforming Jumpbox\n";
	$(MAKE) terraform COMPONENT=harvester-jumpbox
jumpbox-key: check-tools
	@printf "\n====> Grabbing generated SSH key\n";
	$(MAKE) terraform-value COMPONENT=harvester-jumpbox FIELD=".jumpbox_ssh_key.value"
jumpbox-destroy: check-tools
	@printf "\n====> Destroying Jumpbox\n";
	$(MAKE) terraform-destroy COMPONENT=harvester-jumpbox

# registry targets
registry: check-tools
	@printf "\n===> Installing Registry\n";
	@kubectx $(HARVESTER_CONTEXT)
	@helm upgrade --install harbor ${BOOTSTRAP_DIR}/harbor/harbor-1.9.3.tgz \
	--version 1.9.3 -n harbor -f ${BOOTSTRAP_DIR}/harbor/values.yaml --create-namespace
registry-delete: check-tools
	@printf "\n===> Deleting Registry\n";
	@kubectx $(HARVESTER_CONTEXT)
	@helm delete harbor -n harbor
# git targets
git: check-tools
	@kubectx $(HARVESTER_CONTEXT)
	@helm install gitea $(BOOTSTRAP_DIR)/gitea/gitea-6.0.1.tgz \
	--namespace git \
	--set gitea.admin.password=$(GIT_ADMIN_PASSWORD) \
	--set gitea.admin.username=gitea \
	--set persistence.size=10Gi \
	--set postgresql.persistence.size=1Gi \
	--set gitea.config.server.ROOT_URL=https://$(GITEA_URL) \
	--set gitea.config.server.DOMAIN=$(GITEA_URL) \
	--set gitea.config.server.PROTOCOL=http \
	-f $(BOOTSTRAP_DIR)/gitea/values.yaml
git-delete: check-tools
	@kubectx $(HARVESTER_CONTEXT)
	@printf "\n===> Deleting Gitea\n";
	@helm delete gitea -n git

# generation
cluster-generate-aws: check-tools
	@ytt -f ${WORKING_DIR}/templates/cluster/awsgov/aws_cluster_template.yaml -f $(AWS_CLUSTER_VALUES)
cluster-generate-harvester: check-tools
	@ytt -f ${WORKING_DIR}/templates/cluster/harvester/harvester_cluster_template.yaml -f $(HARVESTER_CLUSTER_VALUES)

# gitops
fleet-patch: check-tools
	@printf "\n===> Patching Fleet Bug\n";
	@kubectx $(LOCAL_CLUSTER_NAME)
	@kubectl patch ClusterGroup -n fleet-local default --type=json -p='[{"op": "remove", "path": "/spec/selector/matchLabels/name"}]'

workloads-check: check-tools
	@printf "\n===> Synchronizing Workloads with Fleet (dry-run)\n";
	@kubectx $(LOCAL_CLUSTER_NAME)
	@ytt -f $(WORKLOAD_DIR) | kapp deploy -a $(WORKLOADS_KAPP_APP_NAME) -n $(WORKLOADS_NAMESPACE) -f - 

workloads-yes: check-tools
	@printf "\n===> Synchronizing Workloads with Fleet\n";
	@kubectx $(LOCAL_CLUSTER_NAME)
	@ytt -f $(WORKLOAD_DIR) | kapp deploy -a $(WORKLOADS_KAPP_APP_NAME) -n $(WORKLOADS_NAMESPACE) -f - -y 

workloads-delete: check-tools
	@printf "\n===> Deleting Workloads with Fleet\n";
	@kubectx $(LOCAL_CLUSTER_NAME)
	@kapp delete -a $(WORKLOADS_KAPP_APP_NAME) -n $(WORKLOADS_NAMESPACE)

status: check-tools
	@printf "\n===> Inspecting Running Workloads in Fleet\n";
	@kubectx $(LOCAL_CLUSTER_NAME)
	@kapp inspect -a $(WORKLOADS_KAPP_APP_NAME) -n $(WORKLOADS_NAMESPACE)