## Prep Harvester's Ubuntu OS Image
To make this special image, we'll need to pull down the previously mentioned OS image to our local workstation and then do some work upon it using `guestfs` tools. This is slightly involved, but once finished, you'll have 80% of the manual steps above canned into a single image making it very easy to automate in an airgap. If you are not using Harvester, this image is in qcow2 format and should be usable in different HCI solutions, however your Terraform code will look different. Try to follow along, regardless, so the process around how you would bootstrap the cluster (and Rancher) from Terraform is understood at a high-level.

```bash
wget http://cloud-images.ubuntu.com/releases/focal/release/ubuntu-20.04-server-cloudimg-amd64.img
sudo apt install -y libguestfs-tools
```

Before we get started, we'll need to expand the filesystem of the cloud image because some of the files we are downloading are a little large. I'm using 3 gigs here, but if you're going to install something large like nvidia-drivers, use as much space as you like. We'll condense the image back down later.
```bash
sudo virt-filesystems --long -h --all -a ubuntu-20.04-server-cloudimg-amd64.img
truncate -r ubuntu-20.04-server-cloudimg-amd64.img ubuntu-rke2.img
truncate -s +3G ubuntu-rke2.img
sudo virt-resize --expand /dev/sda1 ubuntu-20.04-server-cloudimg-amd64.img ubuntu-rke2.img
```

Unfortunately `virt-resize` will also rename the partitions, which will screw up the bootloader. We now have to fix that by using virt-rescue and calling grub-install on the disk.
```console
sudo virt-rescue ubuntu-rke2.img 
WARNING: Image format was not specified for '/home/ubuntu/ubuntu-rke2.img' and probing guessed raw.
         Automatically detecting the format is dangerous for raw images, write operations on block 0 will be restricted.
         Specify the 'raw' format explicitly to remove the restrictions.
Could not access KVM kernel module: No such file or directory
qemu-system-x86_64: failed to initialize KVM: No such file or directory
qemu-system-x86_64: Back to tcg accelerator
supermin: mounting /proc
supermin: ext2 mini initrd starting up: 5.1.20
...

The virt-rescue escape key is ‘^]’.  Type ‘^] h’ for help.

------------------------------------------------------------

Welcome to virt-rescue, the libguestfs rescue shell.

Note: The contents of / (root) are the rescue appliance.
You have to mount the guest’s partitions under /sysroot
before you can examine them.

groups: cannot find name for group ID 0
><rescue> mkdir /mnt
><rescue> mount /dev/sda3 /mnt
><rescue> mount --bind /dev /mnt/dev
><rescue> mount --bind /proc /mnt/proc
><rescue> mount --bind /sys /mnt/sys
><rescue> chroot /mnt
><rescue> grub-install /dev/sda
Installing for i386-pc platform.
Installation finished. No error reported.
```

Now we can inject both packages as well as run commands within the context of the image. We'll borrow some of the manual provisioning steps above and copy those pieces into the image. Follow hte recipe guide to build your custom image and then follow that up with the finishing steps. Be aware that the `qemu-guest-agent` package is needed by Harvester to get status back for kubevirt. It has a side effect of setting the `/etc/machine-id` field which is used by many DHCP clients to identify the machine (as opposed to the MAC ID). In each of the recipes you'll see the clearing of that file for this reason.

### RKE2 + kubevip on Harvester, Control-Plane and Worker Nodes

```bash
sudo virt-customize -a ubuntu-rke2.img --install qemu-guest-agent
sudo virt-customize -a ubuntu-rke2.img --run-command "mkdir -p /var/lib/rancher/rke2-artifacts && wget https://get.rke2.io -O /var/lib/rancher/install.sh && chmod +x /var/lib/rancher/install.sh"
sudo virt-customize -a ubuntu-rke2.img --run-command "wget https://kube-vip.io/k3s -O /var/lib/rancher/kube-vip-k3s && chmod +x /var/lib/rancher/kube-vip-k3s"
sudo virt-customize -a ubuntu-rke2.img --run-command "mkdir -p /var/lib/rancher/rke2/server/manifests && wget https://kube-vip.io/manifests/rbac.yaml -O /var/lib/rancher/rke2/server/manifests/kube-vip-rbac.yaml"
sudo virt-customize -a ubuntu-rke2.img --run-command "cd /var/lib/rancher/rke2-artifacts && curl -sLO https://github.com/rancher/rke2/releases/download/v1.24.8+rke2r1/rke2.linux-amd64.tar.gz"
sudo virt-customize -a ubuntu-rke2.img --run-command "cd /var/lib/rancher/rke2-artifacts && curl -sLO https://github.com/rancher/rke2/releases/download/v1.24.8+rke2r1/sha256sum-amd64.txt"
sudo virt-customize -a ubuntu-rke2.img --run-command "cd /var/lib/rancher/rke2-artifacts && curl -sLO https://github.com/rancher/rke2/releases/download/v1.24.8+rke2r1/rke2-images.linux-amd64.tar.zst"
sudo virt-customize -a ubuntu-rke2.img --run-command "echo -n > /etc/machine-id"
```

### RKE2 + Nvidia Drivers/Toolkit, Worker Nodes only

This image would likely never be wasted on a control-plane due to limited GPU availability. It will also be quite large.

```bash
sudo virt-customize -a ubuntu-rke2-nvidia.img --install qemu-guest-agent
sudo virt-customize -a ubuntu-rke2-nvidia.img --run-command "mkdir -p /var/lib/rancher/rke2-artifacts && wget https://get.rke2.io -O /var/lib/rancher/install.sh && chmod +x /var/lib/rancher/install.sh"
sudo virt-customize -a ubuntu-rke2-nvidia.img --run-command "mkdir -p /var/lib/rancher/rke2/server/manifests"
sudo virt-customize -a ubuntu-rke2-nvidia.img --run-command "cd /var/lib/rancher/rke2-artifacts && curl -sLO https://github.com/rancher/rke2/releases/download/v1.24.8+rke2r1/rke2.linux-amd64.tar.gz"
sudo virt-customize -a ubuntu-rke2-nvidia.img --run-command "cd /var/lib/rancher/rke2-artifacts && curl -sLO https://github.com/rancher/rke2/releases/download/v1.24.8+rke2r1/sha256sum-amd64.txt"
sudo virt-customize -a ubuntu-rke2-nvidia.img --run-command "cd /var/lib/rancher/rke2-artifacts && curl -sLO https://github.com/rancher/rke2/releases/download/v1.24.8+rke2r1/rke2-images.linux-amd64.tar.zst"
sudo virt-customize -a ubuntu-rke2-nvidia.img --install nvidia-driver-520
sudo virt-customize -a ubuntu-rke2-nvidia.img --install nvidia-cuda-toolkit
sudo virt-customize -a ubuntu-rke2-nvidia.img --run-command "echo -n > /etc/machine-id"
```

### Temporary Docker Registry VM

This image would be designed to start up a docker-hosted registry2 image.

```bash
sudo virt-customize -a ubuntu-rke2-nvidia.img --install qemu-guest-agent
sudo virt-customize -a ubuntu-rke2-nvidia.img --install docker.io
sudo virt-customize -a ubuntu-rke2-nvidia.img --run-command "mkdir /var/lib/images && docker image save registry:2 -o /var/lib/images/registry.tar"
sudo virt-customize -a ubuntu-rke2-nvidia.img --run-command "echo -n > /etc/machine-id"
```


## Finishing Steps

These finishing steps will follow the first recipe where we are building a custom airgapped image with RKE2 and kubevip scripts/binaries pre-installed.

If we look at the image we just created, we can see it is quite large!
```console
ubuntu@jumpbox:~$ ll ubuntu*
-rw-rw-r-- 1 ubuntu ubuntu  637927424 Dec 13 22:16 ubuntu-20.04-server-cloudimg-amd64.img
-rw-rw-r-- 1 ubuntu ubuntu 3221225472 Dec 19 14:40 ubuntu-rke2.img
```

We need to shrink it back using virt-sparsify. This looks for any unused space (most of what we expanded) and then removes that from the physical image. Along the way we'll want to convert and then compress this image:
```bash
sudo virt-sparsify --convert qcow2 --compress ubuntu-rke2.img ubuntu-rke2-airgap-harvester.img
```

Example of our current image and cutting the size in half:
```console
ubuntu@jumpbox:~$ sudo virt-sparsify --convert qcow2 --compress ubuntu-rke2.img ubuntu-rke2-airgap-harvester.img
[   0.0] Create overlay file in /tmp to protect source disk
[   0.0] Examine source disk
 100% ⟦▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒⟧ --:--
[  14.4] Fill free space in /dev/sda2 with zero
 100% ⟦▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒⟧ --:--
[  17.5] Fill free space in /dev/sda3 with zero
 100% ⟦▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒⟧ 00:00
[  21.8] Copy to destination and make sparse
[ 118.8] Sparsify operation completed with no errors.
virt-sparsify: Before deleting the old disk, carefully check that the 
target disk boots and works correctly.
ubuntu@jumpbox:~$ ll ubuntu*
-rw-rw-r-- 1 ubuntu ubuntu  637927424 Dec 13 22:16 ubuntu-20.04-server-cloudimg-amd64.img
-rw-r--r-- 1 root   root   1562816512 Dec 19 15:00 ubuntu-rke2-airgap-harvester.img
-rw-rw-r-- 1 ubuntu ubuntu 3221225472 Dec 19 14:40 ubuntu-rke2.img
```

What we have now is a customized image named `ubuntu-rke2-airgap-harvester.img` containing the RKE2 binaries and install scripts that we can later invoke in cloud-init. Let's upload this to Harvester now. The easiest way to upload into Harvester is host the image somewhere so Harvester can pull it. If you want to manually upload it from your web session, you stand the risk of it being interrupted by your web browser and having to start over.