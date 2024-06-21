#!/bin/sh

# This script is invoked from cloud-agent
# DO NOT write anything other than AgentUUID to stdout in non-error path

INSTALL_CONFIG_DIR="/etc/qualys/cloud-agent"
DEFAULT_HOSTID_DIR="/etc"

HOST_ID_DIR=$2
AGENT_UUID=$3

hostid_dir=$(sed -n -e "/^HostIdSearchDir=/{s/^.*=//g;p}" "${INSTALL_CONFIG_DIR}/qualys-cloud-agent.conf")
group=$(sed -n -e "/^UserGroup=/{s/^.*=//g;p}" "${INSTALL_CONFIG_DIR}/qualys-cloud-agent.conf")
user=root

if [ -z "${hostid_dir}" ]; then
    hostid_dir="${DEFAULT_HOSTID_DIR}"
fi

hostid_dir="${hostid_dir}/qualys"

if [ -z "$HOST_ID_DIR" ] || [ "${hostid_dir}" != "${HOST_ID_DIR}" ]; then
    echo "Invalid HOST_ID_DIR"
    exit 1
fi

if [ "$1" = "1" ]; then
    if [ -z "$AGENT_UUID" ]; then
        echo "Invalid AGENT_UUID"
        exit 1
    fi

    if [ ! -d "${hostid_dir}" ]; then
        mkdir "${hostid_dir}"
    fi

    chmod 770 "${hostid_dir}"
    echo "${AGENT_UUID}" > "${hostid_dir}/hostid"
    chmod 660 "${hostid_dir}/hostid"
    if [ -n "${group}" ] && [ "$group" != " " ]; then
        chown "${user}" "${hostid_dir}/hostid";
        chgrp -H "${group}" "${hostid_dir}/hostid";
	fi
fi

if [ ! -f "${hostid_dir}/hostid" ]; then
    #check the permission on dir
    #mkdir ${hostid_dir} 2>/dev/null
    chmod 770 "${hostid_dir}" 2>/dev/null
    touch "${hostid_dir}/hostid"
    chmod 660 "${hostid_dir}/hostid"
	if [ -n "${group}" ] && [ "${group}" != " " ]; then
        chown "${user}" "${hostid_dir}/hostid";
        chgrp -H "${group}" "${hostid_dir}/hostid";
    fi
    exit $?
fi

cat "${hostid_dir}/hostid"
