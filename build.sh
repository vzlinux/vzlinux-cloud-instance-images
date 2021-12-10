#!/usr/bin/env bash
#
# Create a base Virtuozzo Linux 8 Docker image.
#
# This script is useful on systems with yum installed (e.g., building
# a VzLinux image on Vzlinux itself).
#
# Copyright (c) 2020-2021 Virtuozzo International GmbH. All rights reserved.
#
# Our contact details: Virtuozzo International GmbH, Vordergasse 59, 8200
# Schaffhausen, Switzerland.
#
# Version 1.0.1

set -e

usage() {
    cat <<EOOPTS
$(basename $0) [OPTIONS]
OPTIONS:
  -p "<packages>"  The list of packages to install in the container.
                   The default is blank. Can use multiple times.
  -g "<groups>"    The groups of packages to install in the container.
                   The default is "Core". Can use multiple times.
  -v <version>     Build number
EOOPTS
    exit 1
}

# option defaults
# for names with spaces, use double quotes (") as INSTALL_GROUPS=('Core')
INSTALL_GROUPS=()
INSTALL_PACKAGES=()
VERSION=
while getopts ":p:g:v:h" opt; do
    case $opt in
        h)
            usage
            ;;
        p)
            INSTALL_PACKAGES+=("$OPTARG")
            ;;
        g)
            INSTALL_GROUPS+=("$OPTARG")
            ;;
        v)
            VERSION="$OPTARG"
            ;;
        \?)
            echo "Invalid option: -$OPTARG"
            usage
            ;;
    esac
done
shift $((OPTIND - 1))

if [[ -z $VERSION ]]; then
    usage
fi

target=$(mktemp -d --tmpdir $(basename $0).XXXXXX)

mkdir -p "$target"/etc/dnf/
cat > $target/etc/dnf/dnf.conf <<EOF
[main]
gpgcheck=1
installonly_limit=3
clean_requirements_on_remove=True
best=True
skip_if_unavailable=False
EOF

dnf_config=$target/etc/dnf/dnf.conf

mkdir -p "$target"/etc/yum.repos.d/
cat > "$target"/etc/yum.repos.d/vz-build.repo <<EOF
[vzlinux-build]
name=Virtuozzo Linux $releasever - BaseOS
# mirrorlist=http://repo.virtuozzo.com/vzlinux/mirrorlist/mirrors-8-os
baseurl=http://repo.virtuozzo.com/vzlinux/$VERSION/x86_64/os/
gpgcheck=0
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/VZLINUX_GPG_KEY
EOF

set -x

mkdir -m 755 "$target"/dev
mknod -m 600 "$target"/dev/console c 5 1
mknod -m 600 "$target"/dev/initctl p
mknod -m 666 "$target"/dev/full c 1 7
mknod -m 666 "$target"/dev/null c 1 3
mknod -m 666 "$target"/dev/ptmx c 5 2
mknod -m 666 "$target"/dev/random c 1 8
mknod -m 666 "$target"/dev/tty c 5 0
mknod -m 666 "$target"/dev/tty0 c 4 0
mknod -m 666 "$target"/dev/urandom c 1 9
mknod -m 666 "$target"/dev/zero c 1 5

declare -i MAJOR_VER
MAJOR_VER=`rpm --eval '%{centos_ver}'`

if [[ -n "$INSTALL_GROUPS" ]]
then
    if [[ $MAJOR_VER -lt 8 ]]
    then
        yum -c "$dnf_config" --disablerepo=* --enablerepo=vzlinux-build --installroot="$target" --releasever=/ --setopt=tsflags=nodocs \
            --setopt=group_package_types=mandatory -y groupinstall "${INSTALL_GROUPS[@]}"
    else
        yum -c "$dnf_config" --disablerepo=* --enablerepo=vzlinux-build --installroot="$target" --releasever=/ --setopt=tsflags=nodocs \
            --setopt=group_package_types=mandatory --setopt='module_platform_id=platform:vl8' -y groupinstall "${INSTALL_GROUPS[@]}"
    fi
fi

if [[ -n "$INSTALL_PACKAGES" ]]
then
    if [[ $MAJOR_VER -lt 8 ]]
    then
        yum -c "$dnf_config" --disablerepo=* --enablerepo=vzlinux-build --installroot="$target" --releasever=/ --setopt=tsflags=nodocs \
            --setopt=group_package_types=mandatory -y install ${INSTALL_PACKAGES[@]}
    else
        yum -c "$dnf_config" --disablerepo=* --enablerepo=vzlinux-build --installroot="$target" --releasever=/ --setopt=tsflags=nodocs \
            --setopt=group_package_types=mandatory --setopt='module_platform_id=platform:vl8' -y install ${INSTALL_PACKAGES[@]}
    fi
fi

yum -c "$dnf_config" --installroot="$target" -y clean all

cat > "$target"/etc/sysconfig/network <<EOF
NETWORKING=yes
HOSTNAME=localhost.localdomain
EOF

rm -rf "$target"/var/cache/yum
mkdir -p --mode=0755 "$target"/var/cache/yum
mkdir -p --mode=0755 "$target"/var/cache/ldconfig

cd $target
XZ_OPT='-T0' tar -cJf $HOME/vzlinux-$VERSION.tar.xz .

rm -rf $target
