#!/bin/bash -ex

# If the TERM environment variable is set to dumb, tput will generate spurrious error messages.
[ "$TERM" == "dumb" ] && export TERM="vt100"

retry() {
  local COUNT=1
  local DELAY=0
  local RESULT=0
  while [[ "${COUNT}" -le 10 ]]; do
    [[ "${RESULT}" -ne 0 ]] && {
      [ "`which tput 2> /dev/null`" != "" ] && [ -n "$TERM" ] && tput setaf 1
      echo -e "\n${*} failed... retrying ${COUNT} of 10.\n" >&2
      [ "`which tput 2> /dev/null`" != "" ] && [ -n "$TERM" ] && tput sgr0
    }
    "${@}" && { RESULT=0 && break; } || RESULT="${?}"
    COUNT="$((COUNT + 1))"

    # Increase the delay with each iteration.
    DELAY="$((DELAY + 10))"
    sleep $DELAY
  done

  [[ "${COUNT}" -gt 10 ]] && {
    [ "`which tput 2> /dev/null`" != "" ] && [ -n "$TERM" ] && tput setaf 1
    echo -e "\nThe command failed 10 times.\n" >&2
    [ "`which tput 2> /dev/null`" != "" ] && [ -n "$TERM" ] && tput sgr0
  }

  return "${RESULT}"
}

# To allow for automated installs, we disable interactive configuration steps.
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

retry apt-get --assume-yes install apt-transport-https ca-certificates curl gnupg lsb-release

mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --batch --yes --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
retry apt-get update
retry apt-get install -y containerd.io

retry systemctl enable containerd

retry curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg

echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list

retry apt-get update
retry apt-get install -y kubelet kubeadm kubectl
retry apt-mark hold kubelet kubeadm kubectl

retry systemctl enable kubelet

# enable br-netfilter module
echo br-netfilter | tee -a /etc/modules >/dev/null
modprobe br-netfilter

# set required sysctls
echo net.bridge.bridge-nf-call-iptables=1 | tee -a /etc/sysctl.conf >/dev/null
echo net.ipv4.ip_forward=1 | tee -a /etc/sysctl.conf >/dev/null
sysctl -p

# work around the cilium issue on systemd >=245: https://docs.cilium.io/en/v1.9/operations/system_requirements/
echo 'net.ipv4.conf.lxc*.rp_filter = 0' >/etc/sysctl.d/99-override_cilium_rp_filter.conf
systemctl restart systemd-sysctl

# prepare containerd config
containerd config default | tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/' /etc/containerd/config.toml
systemctl restart containerd

# disable swap
sed -ri '/\sswap\s/s/^#?/#/' /etc/fstab
swapoff -a

# pre-pull kubernetes images
retry kubeadm config images pull

# install cilium-cli
wget -O /tmp/cilium.tar.gz https://github.com/cilium/cilium-cli/releases/download/v0.11.11/cilium-linux-amd64.tar.gz
tar -xvzf /tmp/cilium.tar.gz -C /usr/local/bin
rm -rf /tmp/cilium.tar.gz

# pre-pull cilium images
ctr image pull quay.io/cilium/operator-generic:v1.11.6
ctr image pull quay.io/cilium/cilium:v1.11.6

# pimp grub
sed -i 's/GRUB_TIMEOUT_STYLE=hidden/GRUB_TIMEOUT_STYLE=menu/' /etc/default/grub
sed -i 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="console=tty0 console=ttyS0,115200n8 systemd.log_level=info systemd.log_target=console"/' /etc/default/grub
sed -i 's/GRUB_TIMEOUT_STYLE=hidden/GRUB_TIMEOUT_STYLE=menu/' /etc/default/grub
sed -i 's/GRUB_TIMEOUT=0/GRUB_TIMEOUT=5/' /etc/default/grub
sed -i 's/#GRUB_TERMINAL=console/GRUB_TERMINAL="console serial"/' /etc/default/grub
echo 'GRUB_SERIAL_COMMAND="serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1"' >> /etc/default/grub
update-grub
