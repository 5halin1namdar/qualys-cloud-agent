#!/bin/sh

# Variables
ROOT_DIR=/usr/local/qualys/cloud-agent
XDR_DIR="${ROOT_DIR}/xdr"
LOG_DIR=/var/log/qualys/
CONF_DIR=/etc/qualys/cloud-agent
SETUP_DIR=${ROOT_DIR}/setup
PACKAGE_NAME="qualys-xdr"
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

# Validate the environment
parseArguments "$@"
if [ $? -ne 0 ]; then
    exit 4
fi

# Validate the XDR package version
INSTALLED_VERSION=`rpm -q --queryformat='%{VERSION}-%{RELEASE}' "$PACKAGE_NAME"`
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
