#!/bin/bash
# Script to install DPDK 24.07 and its dependancies on uWaterloo SYN blue servers

# Blue servers have 3 network interfaces - 2 Intel I350 and 1 NVIDIA ConnectX-3
# We want to have two interfaces bound to DPDK to normally run the example DPDK 
# packet forwarding app: testpmd (under /path-to-dpdk-install/build/app)
# WARNING: don't modify the first Intel I350 interface (should be "eno1"). It's for ssh connection.

# IMPORTANT: PRE-REQUISITE
# 1. If want to bind to the second Intel I350 interface:
# Edit /etc/default/grub, add "intel_iommu=on" to GRUB_CMDLINE_LINUX_DEFAULT, then
# sudo reboot

# 2. If want to bind to the NVIDIA ConnectX-3 interface:
# Add "options mlx4_core log_num_mgm_entry_size=-1" to /etc/modprobe.d/mlx4.conf (create
# the file if not exist)

read -p "Have you read and done the PRE-REQUISITE? (y/n)" answer
if [[ $answer != [Yy] ]]; then
    echo "Exiting."
    exit 1
fi


DPDK_VERSION="24.07"

# Update package repositories
sudo apt update
sudo apt-get update

sudo apt upgrade -y

# Install dependencies
sudo apt install -y build-essential meson ninja-build pkg-config
sudo apt install -y linux-headers-$(uname -r)
sudo apt install -y libnuma-dev libpcap-dev libelf-dev
sudo apt install -y libibverbs1 ibverbs-providers libibverbs-dev
sudo apt install -y wget
sudo apt install -y python3-pyelftools

# Download DPDK source code
wget http://fast.dpdk.org/rel/dpdk-${DPDK_VERSION}.tar.xz

# Extract DPDK source code
sudo tar -xf dpdk-${DPDK_VERSION}.tar.xz -C /opt
cd /opt/dpdk-${DPDK_VERSION}

# Build & install DPDK
sudo meson setup build
cd build
sudo ninja
sudo meson install
sudo ldconfig

# Setup hugepages
cd ../usertools
PAGE_SIZE="1G"
TOTAL_SIZE="2G"
sudo dpdk-hugepages.py -p ${PAGE_SIZE} --setup ${TOTAL_SIZE}

# Bind DPDK to network interface
# Bind to the second Intel I350 interface (eno2)
I350_PCI="0000:05:00.1"  # modify this pci if needed
sudo modprobe vfio-pci
echo ${I350_PCI} | sudo tee /sys/bus/pci/drivers/igb/unbind
sudo dpdk-devbind.py --bind=vfio-pci ${I350_PCI}
# Bind to the NVIDIA ConnectX-3 interface (enp130s0)
# You will see this device still "using kernel driver" - that's ok
sudo modprobe -r mlx4_en mlx4_ib mlx4_core
sudo modprobe mlx4_core mlx4_ib mlx4_en

# Verify DPDK installation
echo "DPDK has been installed successfully."
