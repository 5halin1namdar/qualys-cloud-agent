#!/bin/sh

# Variables
PACKAGE_NAME="qualys-swca-datacollector"
VERSION=
PACKAGER=

# Utility functions
getVersionString()
{
    VERSION_MAJOR=$(printf '%s' "${1}" |cut -d'.' -f 1)
    VERSION_MINOR=$(printf '%s' "${1}" |cut -d'.' -f 2)
    VERSION_PATCH=$(printf '%s' "${1}" |cut -d'.' -f 3 |cut -d'-' -f 1)
    VERSION_RELEASE=$(printf '%s' "${1}" |cut -d'.' -f 3 |cut -d'-' -f 2)

    # assumed each part of version is less than 100
    VERSION_STRING=$(( 1000000*VERSION_MAJOR + 10000*VERSION_MINOR + 100*VERSION_PATCH + VERSION_RELEASE ))
    printf '%s' "${VERSION_STRING}"
}

parseArguments()
{
    while getopts v:p: opt
    do
        case $opt in
            v) 
                VERSION="${OPTARG}"
                ;;
            p)
                PACKAGER="${OPTARG}"
                ;;
            *)
                return 1
                ;;
        esac
    done

}

# Make sure this is run as root
if [ "$(id -u)" -ne 0 ]; then
    exit 3
fi

# Validate the environment
parseArguments $@
if [ -z "${VERSION}" ] || [ -z "${PACKAGER}" ]
then
    exit 4
fi

# Validate the XDR package version
if [ "${PACKAGER}" = "rpm" ]
then
    if ( rpm -qi "${PACKAGE_NAME}" )
    then
        INSTALLED_VERSION=$(rpm -q --queryformat='%{VERSION}-%{RELEASE}' "${PACKAGE_NAME}")
    fi
elif [ "${PACKAGER}" = "dpkg" ]
then
    if (dpkg-query -W "${PACKAGE_NAME}" )
    then
        INSTALLED_VERSION=$(dpkg-query --showformat='${Version}' -W "${PACKAGE_NAME}")
    fi
fi
if [ -z "${INSTALLED_VERSION}" ]
then
    exit 5
fi

if [ "$(getVersionString "${INSTALLED_VERSION}")" -lt "$(getVersionString "${VERSION}")" ]
then
    exit 6
fi

if [ "$(getVersionString "${INSTALLED_VERSION}")" -gt "$(getVersionString "${VERSION}")" ]
then
    exit 7
fi

# Notify successful completion
exit 0
