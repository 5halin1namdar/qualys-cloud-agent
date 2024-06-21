#!/bin/bash
prog=ascpath_discover
QUALYS_CONFIG_DIR="/etc/qualys"
AZUREGL_INSTALL_FILE=".azureasc_install_path"
WAAGENT="/var/lib/waagent"
AZUREGL_INSTALL_PATH=""
QCA_ASC_REGEX="Qualys.QualysAgentLinux-[0-9]+.[0-9]+.[0-9]+.[0-9]+"


function find_azureasc_install_path()
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

if [[ -f $QUALYS_CONFIG_DIR/$AZUREGL_INSTALL_FILE ]];then
    AZUREGL_INSTALL_PATH=`cat $QUALYS_CONFIG_DIR/$AZUREGL_INSTALL_FILE`
    if [[ -d $AZUREGL_INSTALL_PATH ]];then
	    echo $AZUREGL_INSTALL_PATH
    else 
	find_azureasc_install_path
    fi
else
    find_azureasc_install_path
fi
