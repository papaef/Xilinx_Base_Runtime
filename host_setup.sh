#!/usr/bin/env bash
#
# (C) Copyright 2019, Xilinx, Inc.
#
#!/usr/bin/env bash

usage() {
    echo "Running host_setup.sh to install XRT and flash Shell on host machine. "
    echo ""
    echo "Usage:"
    echo "  ./host_setup.sh --platform <platform> --version <version>"
    echo "  ./host_setup.sh  -p <platform>         -v       <version>"
    echo "  <platform>       : alveo-u200 / alveo-u250 / alveo-u280"
    echo "  <version>        : 2018.3 / 2019.1"
    echo "  --skip-xrt-install    : skip install XRT"
    echo "  --skip-shell-flash    : skip flash Shell"
    echo ""
    echo "Example:"
    echo "Install 2019.1 XRT for Alveo U200 and flash Shell "
    echo "  ./install.sh -p alveo-u200 -v 2019.1"

}

list() {
    echo "Available Docker Images:"
    echo ""
    echo "Image Name                     Support Platform              Version      OS Version"
    echo "alveo-2018-3-centos            Alveo U200 / U250             2018.3       CentOS"
    echo "alveo-2018-3-ubuntu-1604       Alveo U200 / U250             2018.3       Ubuntu 16.04"
    echo "alveo-2018-3-ubuntu-1804       Alveo U200 / U250             2018.3       Ubuntu 18.04"
    echo "alveo-2019-1-centos            Alveo U200 / U250 / U280      2019.1       CentOS"
    echo "alveo-2019-1-ubuntu-1604       Alveo U200 / U250 / U280      2019.1       Ubuntu 16.04"
    echo "alveo-2019-1-ubuntu-1804       Alveo U200 / U250 / U280      2019.1       Ubuntu 18.04"
}


if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

XRT=1
SHELL=1

while true
do
case "$1" in
    --skip-xrt-install   ) XRT=0             ; shift 1 ;;
    --skip-shell-flash   ) SHELL=0           ; shift 1 ;;
    -p|--platform        ) PLATFORM="$2"     ; shift 2 ;;
    -v|--version         ) VERSION="$2"      ; shift 2 ;;
    -h|--help            ) usage             ; exit  1 ;;
*) break ;;
esac
done

if [ $? != 0 ] ; then echo "Failed parsing options." >&2 ; usage; exit 1 ; fi

OSVERSION=`grep '^ID=' /etc/os-release | awk -F= '{print $2}'`
OSVERSION=`echo $OSVERSION | tr -d '"'`
if [[ "$OSVERSION" == "ubuntu" ]]; then
    VERSION_ID=`grep '^VERSION_ID=' /etc/os-release | awk -F= '{print $2}'`
    VERSION_ID=`echo $VERSION_ID | tr -d '"'`
    OSVERSION="$OSVERSION-$VERSION_ID"
fi

COMB="${PLATFORM}_${VERSION}_${OSVERSION}"

if grep -q $COMB "conf/spec.txt"; then
    XRT_PACKAGE=`grep ^$COMB: conf/spec.txt | awk -F':' '{print $2}' | awk -F';' '{print $1}' | awk -F= '{print $2}'`
    SHELL_PACKAGE=`grep ^$COMB: conf/spec.txt | awk -F':' '{print $2}' | awk -F';' '{print $2}' | awk -F= '{print $2}'`
    DSA=`grep ^$COMB: conf/spec.txt | awk -F':' '{print $2}' | awk -F';' '{print $3}' | awk -F= '{print $2}'`
    TIMESTAMP=`grep ^$COMB: conf/spec.txt | awk -F':' '{print $2}' | awk -F';' '{print $4}' | awk -F= '{print $2}'`
fi

wget --help > /dev/null
if [ $? != 0 ] ; then
    if [[ "$OSVERSION" == "ubuntu-16.04" ]] || [[ "$OSVERSION" == "ubuntu-18.04" ]]; then
        apt-get install -y wget
    elif [[ "$OSVERSION" == "centos" ]]; then
        yum install -y wget
    fi
fi

if [ "$XRT" == 0 &&  "$SHELL" == 0] ; then echo "Please do NOT skip both XRT installation and card flashing." >&2 ; usage; exit 1 ; fi

if [[ "$XRT" == 1 ]]; then
    echo "Download XRT installation package"
    wget -cO - "https://www.xilinx.com/bin/public/openDownload?filename=$XRT_PACKAGE" > /tmp/$XRT_PACKAGE

    echo "Install XRT"
    if [[ "$OSVERSION" == "ubuntu-16.04" ]] || [[ "$OSVERSION" == "ubuntu-18.04" ]]; then
        apt-get install --reinstall /tmp/$XRT_PACKAGE
    # elif [[ "$OSVERSION" == "redhat" ]]; then
    #       yum-config-manager --enable rhel-7-server-optional-rpms
    #       yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
    elif [[ "$OSVERSION" == "centos" ]]; then
        yum install epel-release
        yum install /tmp/$XRT_PACKAGE
    fi
    rm /tmp/$XRT_PACKAGE
fi

if [[ "$SHELL" == 1 ]]; then
    echo "Download Shell package"
    wget -cO - "https://www.xilinx.com/bin/public/openDownload?filename=$SHELL_PACKAGE" > /tmp/$SHELL_PACKAGE

    echo "Install Shell"
    if [[ "$OSVERSION" == "ubuntu-16.04" ]] || [[ "$OSVERSION" == "ubuntu-18.04" ]]; then
        apt-get install /tmp/$SHELL_PACKAGE
    elif [[ "$OSVERSION" == "centos" ]]; then
        rpm -i /tmp/$SHELL_PACKAGE
    fi
    rm /tmp/$SHELL_PACKAGE
    
    echo "Flash Card"
    /opt/xilinx/xrt/bin/xbutil flash -a $DSA  $TIMESTAMP
fi
