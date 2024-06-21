#!/bin/sh

# Variables
ROOT_DIR=/usr/local/qualys/cloud-agent
EPP_DIR="${ROOT_DIR}/epp"
LOG_DIR=/var/log/qualys/
CONF_DIR=/etc/qualys/cloud-agent
SETUP_DIR=${ROOT_DIR}/setup
PACKAGE_NAME=
VERSION=
USER=

# Utility functions
getVersionString()
{
    VERSION_MAJOR=$(printf '%s' "$1" |cut -d'.' -f 1)
    VERSION_MINOR=$(printf '%s' "$1" |cut -d'.' -f 2)
    VERSION_PATCH=$(printf '%s' "$1" |cut -d'.' -f 3 |cut -d'-' -f 1)
    VERSION_RELEASE=$(printf '%s' "$1" |cut -d'.' -f 3 |cut -d'-' -f 2)

    # assumed each part of version is less than 100
    VERSION_STRING=$(( 1000000*VERSION_MAJOR + 10000*VERSION_MINOR + 100*VERSION_PATCH + VERSION_RELEASE ))
    printf '%s' "${VERSION_STRING}"
}

parseArguments()
{
    # All options need a value, hence, -gt 1
    while [ $# -gt 1 ];
    do
        case $1 in
            -p)
                PACKAGE_NAME="$2"
                shift 2
                ;;
            -v)
                VERSION="$2"
                shift 2
                ;;
            -u)
                USER="$2"
                shift 2
                ;;
            *)
                return 1
                ;;
        esac
    done

    if [ -z "$VERSION" ]; then
        return 1
    else
        return 0
    fi
}

updatePermissions()
{
    #update any permission that cannot be set in the qualys-cloud-agent.sh here
    return 0
}

# Make sure this is run as root
if [ `id -u` -ne 0 ]; then
    exit 3
fi
# usage of script when script run without argument
if [ $# -eq 0 ]; then
    echo "This script for validating Qualys setup is already installed or not"
    echo "If Qualys setup is aready installed, check version of current installed Qualys setup"
    echo "and if installed Qualys setup is less than install latest version"
    exit 0
fi

# Validate the environment
parseArguments "$@"
if [ $? -ne 0 ]; then
    exit 4
fi

# Validate the EPP package version
OS_ID=""
if [ -f "/etc/os-release" ];then
	OS_ID=`cat /etc/os-release | grep "^ID=" | awk -F= '{print $2}'`
elif [ -f "/etc/lsb-release" ]; then
	 OS_ID=`cat /etc/lsb-release | grep "^DISTRIB_ID=" | awk -F= '{print $2}'`
fi
OS_ID=`echo $OS_ID | tr "[:upper:]" "[:lower:]" | tr -d "\""`

case "$OS_ID" in
        debian|ubuntu|pardus|linuxmint)
            INSTALLED_VERSION=`dpkg-query -f '${Version}' --show "$PACKAGE_NAME" `
        ;;
        *)
            INSTALLED_VERSION=`rpm -q --queryformat='%{VERSION}-%{RELEASE}' "$PACKAGE_NAME"`
        ;;
esac

if [ $? -ne 0 ]; then
    exit 5
fi
if [ $(getVersionString "$INSTALLED_VERSION") -lt $(getVersionString "$VERSION") ]; then
    exit 6
fi
if [ $(getVersionString "$INSTALLED_VERSION") -gt $(getVersionString "$VERSION") ]; then
    exit 7
fi

# Update the permissions
updatePermissions
if [ $? -ne 0 ]; then
    exit 8
fi

# Notify successful completion
exit 0
