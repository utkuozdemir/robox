#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

USERNAME=$USER
BOX_NAME=ubuntu2204-kube

sudo rm -rf output/

sudo ./robox.sh box generic-ubuntu2204-libvirt

sudo chown -R "$USERNAME:$USERNAME" output/

vagrant box remove --force $BOX_NAME || true
virsh vol-delete --pool default ubuntu2204-kube_vagrant_box_image_0_box.img

vagrant box add --force $BOX_NAME output/generic-ubuntu2204-libvirt-4.0.4.box
