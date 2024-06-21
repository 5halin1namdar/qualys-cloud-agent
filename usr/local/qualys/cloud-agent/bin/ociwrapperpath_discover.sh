#!/bin/bash
prog=oci_wrapper_path_discover
QUALYS_CONFIG_DIR="/etc/qualys"
OCI_WRAPPER_INSTALL_FILE=".ociwrapper_install_path"
WAAGENT="/var/lib/waagent"
OCI_WRAPPER_INSTALL_PATH=""
QCA_ASC_REGEX="lxagent_qualys-[0-9]+.[0-9]+.[0-9]+.[0-9]+"


function find_oci_wrapper_install_path()
{
    if [[ -d $WAAGENT ]];then
	    InstallDirArray=()
	    for f in $WAAGENT/*
	    do
		    if [[ $f =~ $QCA_ASC_REGEX ]];then
			    InstallDirArray+=($f)
		    fi
	    done
	    max=${InstallDirArray[0]}
	    for i in "${InstallDirArray[@]}"
	    do
		     if [[ "$i" > "$max" ]]; then
			    max="$i"
		     fi
	    done
	    echo $max
    fi
}

if [[ -f $QUALYS_CONFIG_DIR/$OCI_WRAPPER_INSTALL_FILE ]];then
    OCI_WRAPPER_INSTALL_PATH=`cat $QUALYS_CONFIG_DIR/$OCI_WRAPPER_INSTALL_FILE`
    if [[ -d $OCI_WRAPPER_INSTALL_PATH ]];then
	    echo $OCI_WRAPPER_INSTALL_PATH
    else 
	find_oci_wrapper_install_path
    fi
else
    find_oci_wrapper_install_path
fi
