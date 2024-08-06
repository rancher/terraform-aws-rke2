#!/bin/sh
set -e
set -x

if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root" >&2
  exit 1
fi
#https://docs.rke2.io/known_issues

systemctl disable --now firewalld || true
systemctl stop firewalld || true

systemctl stop nm-cloud-setup.service || true
systemctl disable nm-cloud-setup.service || true
systemctl stop nm-cloud-setup.timer || true
systemctl disable nm-cloud-setup.timer || true

if [ "ipv6" = "${ip_family}" ]; then
  if [ "" != "$(which NetworkManager)" ]; then
    echo "Found NetworkManager, configuring interface using key file in /etc/NetworkManager/system-connections..."
    DEVICE="$(ip -6 -o a show scope global | awk '{print $2}')"
    IPV6="$(ip -6 a show $DEVICE | grep inet6 | head -n1 | awk '{ print $2 }' | awk -F/ '{ print $1 }')"
    IPV6_GW="$(echo "$IPV6" | awk -F: '{gw=$1":"$2":"$3":"$4"::1"; print gw}')"
    DATA="[connection]\ntype=ethernet\n[ipv4]\nmethod=disabled\n[ipv6]\naddresses=$IPV6/64\ngateway=$IPV6_GW\nmethod=manual\ndns=2001:4860:4860::8888\nnever-default=false"

    rm -f /etc/sysconfig/network-scripts/ifcfg-eth0
    echo -e "$DATA" > /etc/NetworkManager/system-connections/$DEVICE.nmconnection
    chmod 0600 /etc/NetworkManager/system-connections/$DEVICE.nmconnection

    nmcli connection reload
    nmcli connection up eth0
    systemctl restart NetworkManager
    nmcli -f TYPE,FILENAME,NAME connection | grep ethernet
  fi
fi

if [ "rpm" = "${install_method}" ]; then
  PYTHON_VERSION="$(ls -l /usr/lib | grep '^d' | grep python | awk '{print $9}')"

  if [ "rhel-9" = "${image}" ]; then
    # adding Rocky 9 repos because they are RHEL 9 compatible and support ipv6 native
    DATA="[RockyLinux-AppStream]\nname=Rocky Linux - AppStream\nbaseurl=https://dl.rockylinux.org/pub/rocky/9/AppStream/x86_64/os/\nenabled=1\nmetadata_expire=7d\ngpgcheck=1\ngpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-rocky\nsslverify=1\nsslcacert=/etc/pki/tls/certs/ca-bundle.crt"
    echo -e "$DATA" > /etc/yum.repos.d/Rocky-AppStream.repo
    DATA="[RockyLinux-BaseOS]\nname=Rocky Linux - BaseOS\nbaseurl=https://dl.rockylinux.org/pub/rocky/9/BaseOS/x86_64/os\nenabled=1\nmetadata_expire=7d\ngpgcheck=1\ngpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-rocky\nsslverify=1\nsslcacert=/etc/pki/tls/certs/ca-bundle.crt"
    echo -e "$DATA" > /etc/yum.repos.d/Rocky-BaseOS.repo
    curl -s https://dl.rockylinux.org/pub/rocky/RPM-GPG-KEY-Rocky-9 -o /etc/pki/rpm-gpg/RPM-GPG-KEY-rocky
    rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-rocky
    dnf config-manager --set-enabled RockyLinux-AppStream
    dnf config-manager --set-enabled RockyLinux-BaseOS
    rm -rf /usr/lib/$PYTHON_VERSION/site-packages/dnf-plugins/amazon-id.py # we are manually adding users, no need to use amazon-id which has problems with ipv6
    rm -rf /etc/yum.repos.d/redhat-* # redhat repos only support ipv4
    rm -rf /etc/dnf/plugins/amazon-id.conf
    dnf clean all
    dnf makecache
    dnf repolist
  fi
  if [ "rhel-8" = "${image}" ]; then
    # adding Rocky 8 repos because they are RHEL 8 compatible and support ipv6 native
    DATA="[RockyLinux-AppStream]\nname=Rocky Linux - AppStream\nbaseurl=https://dl.rockylinux.org/pub/rocky/8/AppStream/x86_64/os/\nenabled=1\nmetadata_expire=7d\ngpgcheck=1\ngpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-rocky\nsslverify=1\nsslcacert=/etc/pki/tls/certs/ca-bundle.crt"
    echo -e "$DATA" > /etc/yum.repos.d/Rocky-AppStream.repo
    DATA="[RockyLinux-BaseOS]\nname=Rocky Linux - BaseOS\nbaseurl=https://dl.rockylinux.org/pub/rocky/8/BaseOS/x86_64/os\nenabled=1\nmetadata_expire=7d\ngpgcheck=1\ngpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-rocky\nsslverify=1\nsslcacert=/etc/pki/tls/certs/ca-bundle.crt"
    echo -e "$DATA" > /etc/yum.repos.d/Rocky-BaseOS.repo
    curl -s https://dl.rockylinux.org/pub/rocky/RPM-GPG-KEY-Rocky-8 -o /etc/pki/rpm-gpg/RPM-GPG-KEY-rocky
    rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-rocky
    dnf config-manager --set-enabled RockyLinux-AppStream
    dnf config-manager --set-enabled RockyLinux-BaseOS
    rm -rf /usr/lib/$PYTHON_VERSION/site-packages/dnf-plugins/amazon-id.py # we are manually adding users, no need to use amazon-id which has problems with ipv6
    rm -rf /etc/yum.repos.d/redhat-* # redhat repos only support ipv4
    rm -rf /etc/dnf/plugins/amazon-id.conf
    dnf clean all
    dnf makecache 
    dnf repolist
  fi
  if [ "liberty-7" = "${image}" ]; then
    # adding Rocky 8 repos because they are RHEL 8 compatible and support ipv6 native
    # DATA="[Fedora-Archive-26]\nname=Fedora-Archive-26\nbaseurl=https://archives.fedoraproject.org/pub/archive/fedora/linux/releases/26/Everything/x86_64/os/\nenabled=1\ngpgcheck=0"
    # echo -e "$DATA" > /etc/yum.repos.d/Fedora-Archive-26.repo
    # DATA="[Fedora-Archive-38]\nname=Fedora-Archive\nbaseurl=https://archives.fedoraproject.org/pub/archive/fedora/linux/releases/38/Everything/x86_64/os/\nenabled=1\ngpgcheck=0"
    # echo -e "$DATA" > /etc/yum.repos.d/Fedora-Archive-38.repo

    # yum -y install https://archives.fedoraproject.org/pub/archive/fedora/linux/releases/25/Everything/x86_64/os/Packages/p/policycoreutils-python-utils-2.5-17.fc25.x86_64.rpm
    # yum -y install https://archives.fedoraproject.org/pub/archive/fedora/linux/releases/25/Everything/x86_64/os/Packages/c/container-selinux-1.12.2-5.git8f1975c.fc25.x86_64.rpm

    # DATA="[Fedora-Archive-34]\nname=Fedora-Archive\nbaseurl=https://archives.fedoraproject.org/pub/archive/fedora/linux/releases/34/Everything/x86_64/os/\nenabled=1\ngpgcheck=0"
    # echo -e "$DATA" > /etc/yum.repos.d/Fedora-Archive-34.repo
    # cat /etc/yum.repos.d/Fedora-Archive-34.repo
    # cat /etc/yum.repos.d/rke2

    # yum -y install https://archives.fedoraproject.org/pub/archive/fedora/linux/releases/34/Everything/x86_64/os/Packages/p/python-pip-wheel-21.0.1-2.fc34.noarch.rpm
    # yum -y install https://archives.fedoraproject.org/pub/archive/fedora/linux/releases/34/Everything/x86_64/os/Packages/p/python3-libs-3.9.2-1.fc34.x86_64.rpm
    # yum -y install https://archives.fedoraproject.org/pub/archive/fedora/linux/releases/34/Everything/x86_64/os/Packages/p/python3-3.9.2-1.fc34.x86_64.rpm
    # yum -y install https://archives.fedoraproject.org/pub/archive/fedora/linux/releases/34/Everything/x86_64/os/Packages/p/policycoreutils-python-utils-3.2-1.fc34.noarch.rpm
    # yum -y install https://archives.fedoraproject.org/pub/archive/fedora/linux/releases/34/Everything/x86_64/os/Packages/c/container-selinux-2.158.0-1.gite78ac4f.fc34.noarch.rpm
    # rm -rf /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
    # rm -rf /etc/yum.repos.d/base.repo
    # curl -s https://vault.centos.org/7.9.2009/os/x86_64/RPM-GPG-KEY-CentOS-7 -o /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
    # DATA="[base]\nname=CentOS-7-Base\n#baseurl=https://vault.centos.org/7.9.2009/os/x86_64/\ngpgcheck=1\nenabled=1\ngpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7"
    # echo -e "$DATA" >> /etc/yum.repos.d/base.repo
    # rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

    # DATA="#released updates\n[updates]\nname=CentOS-$releasever - Updates\nmirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=updates&infra=$infra\n#baseurl=http://mirror.centos.org/centos/$releasever/updates/$basearch/\ngpgcheck=1\nenabled=1\ngpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7"
    # echo -e "$DATA" >> /etc/yum.repos.d/updates.repo
    # DATA="#additional packages that may be useful\n[extras]\nname=CentOS-$releasever - Extras\nmirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=extras&infra=$infra\n#baseurl=http://mirror.centos.org/centos/$releasever/extras/$basearch/\ngpgcheck=1\nenabled=1\ngpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7\n"
    # echo -e "$DATA" >> /etc/yum.repos.d/extras.repo

    subscription-manager repos --enable=rhel-7-server-extras-rpms
    yum clean all
    yum repolist
  fi
fi
