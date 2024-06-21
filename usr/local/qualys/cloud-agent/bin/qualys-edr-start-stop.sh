#!/bin/sh

###====================================
### Common functions to both operations
###====================================

AUDITD_MAJOR_VERSION="1"

PLUGIN_BASE="/etc/qualys/cloud-agent/"
PLUGIN_TE="$PLUGIN_BASE/qualys-agent-plugin.te"
PLUGIN_TE_CENTOS_5="$PLUGIN_BASE/qualys-agent-plugin_centos_5.te"
PLUGIN_FC="$PLUGIN_BASE/qualys-agent-plugin.fc"
PLUGIN_MOD="$PLUGIN_BASE/qualys-agent-plugin.mod"
PLUGIN_PP="$PLUGIN_BASE/qualys-agent-plugin.pp"
PLUGIN_CONF="$PLUGIN_BASE/edr-plugin.conf"

IS_UBUNTU=$(cat /etc/*elease | grep "[Uu]buntu" 2>/dev/null);
LOG_LEVEL="debug"
logFileSize=`wc -l /var/log/qualys/edr-script.log 2>/dev/null | awk '{ print $1; }'`
## if file size is more than 500 lines, delete top 50 lines.
if [ $((logFileSize)) -ge 500 ]; then
	sed -i -e 1,50d /var/log/qualys/edr-script.log
fi
	
LOG()
{
	[ -d "/var/log/qualys" ] || return;
	[ "$LOG_LEVEL" = "debug" ] && echo "$(date): $1" >> /var/log/qualys/edr-script.log
}

isEDRRunning()
{ 
	pid=`pidof qualys-edr`;
	if [ ! -z $pid ]; then
		LOG "qualys-edr found running"
		return 1; 
	else
		return 0;
	fi;
}

getAuditdVersion()
{
	#check auditctl exists or not
	AUDITCTL_PATH=`which auditctl 2>/dev/null` || true
	if [ ! -z $AUDITCTL_PATH ]; then
		AUDITD_VERSION=`auditctl -v|awk -F " " '{print $3}'|sed -n 's/\([0-9]\+\).*/\1/p'`
		LOG "audit vesion: $AUDITD_VERSION"
		return $AUDITD_VERSION;
	else
		# auditctl is not present. Can't determine version no.
		LOG "auditctl not found. Assuming audit version 1";
		exit 200;
	fi;
}

isAuditdRunning()
{
	pidaud=$(pidof `which auditd 2>/dev/null` || true);
	if [ ! -z "$pidaud" ]; then 
		LOG "Auditd running. pid: $pidaud"; 
		return 1;
	else 
		LOG "Auditd not running";
		return 0;
	fi
}

isSELinuxInstalled()
{
	if [ ! -z "$IS_UBUNTU" ]; then
		LOG "Ubuntu OS detected. Skipping SELinux settings.";
		return 0;
	fi
	SELStatus=$(sestatus 2>/dev/null |grep "SELinux status:" |awk '{print $NF; }')
	if [ -z "$SELStatus" ]; then
		# sestatus command not found. Try getenforce
		# Even if getenforce returns just 1 word output, don't remove awk part from below. 
		#	It masks non-zero return code in case getenforce is also not installed.
		SELStatus=$(getenforce 2>/dev/null |awk '{print $NF;}')
	fi;
	if [ "$SELStatus" = "enabled" -o "$SELStatus" = "Enabled" -o "$SELStatus" = "Permissive" -o "$SELStatus" = "Enforcing" ]; then
		LOG "SELinux found enabled"
		return 1;
	else
		# SELStatus=Disabled means it was disabled from config at boot time. Treat as if not installed.
		LOG "SELinux found disabled"
		return 0;
	fi;
}
		

###==========================
### Functions related to STOP
###==========================

StopEdr()
{
	isEDRRunning
	EDRRun=$?
	if [ $EDRRun -ne 0 ]; then 
		LOG "Trying to kill qualys-edr with SIGTERM"
		pkill -SIGTERM -x qualys-edr
		
		## Give it 5 seconds to shut down cleanly
		count=0;
		while [ $count -le 5 -a $EDRRun -ne 0 ]; do
			sleep 1;
			count=$((count+1));
			isEDRRunning
			EDRRun=$?
		done
		if [ $EDRRun -ne 0 ]; then
			LOG "qualys-edr not terminated. Sending SIGKILL"
			pkill -SIGKILL -x qualys-edr
		fi
	fi
}

StopPlugin()
{
	# instead of determining version and path, just remove file whereever we find it. Easier and less time consuming.
    [ -f /etc/audit/plugins.d/edr-plugin.conf ] && rm /etc/audit/plugins.d/edr-plugin.conf || true
    [ -f /etc/audisp/plugins.d/edr-plugin.conf ] && rm /etc/audisp/plugins.d/edr-plugin.conf || true
    service auditd restart
}

UninstallSELinuxPolicy()
{
	isSELinuxInstalled
	SELinux=$?
	if [ $SELinux -ne 0 ]; then
		chkpkg=`semodule -l 2>/dev/null | grep "qualys-agent-plugin" | awk '{ print $1; }'`
		if [ -z "$chkpkg" ]; then
			LOG "Plugin not installed."
			return;
		fi
		## Uninstalling the policy from the store
		## can take a few seconds and can lead to timeouts
		## when shutting down the agent. And if this is moved
		## to the background, in case of agent restarts, it is
		## likely that the policy will be removed after the
		## plugin starts, leading to all sorts of weirdness.
		semodule -r qualys-agent-plugin
		restorecon -R "/usr/local/qualys/cloud-agent/sock"
		rm -f $PLUGIN_PP $PLUGIN_MOD
	fi;
}

###==========================
### Functions related to START
###==========================

InstallSELinuxPolicy()
{
	LOG "Trying to install SELinux policy.."
	isSELinuxInstalled
	SELinux=$?
	if [ $SELinux -ne 0 ]; then
		if [ -z "$(which checkmodule 2>/dev/null)" \
		  -o -z "$(which semodule_package 2>/dev/null)" \
		  -o -z "$(which semodule 2>/dev/null)" \
		  -o -z "$(which restorecon 2>/dev/null)" ]; then
			LOG "One of critical semodule tools missing. Exiting."
			exit 201
		fi;

		## Choose the TE file based on the OS version
		version=$(cat /etc/redhat-release | grep "[cC]ent[oO][sS].*release [0-9]" | awk '{ print $(NF-1); }' |awk -F. '{ print $1; }')
		if [ "$version" = "5" ]; then
			PLUGIN_TE=$PLUGIN_TE_CENTOS_5
		fi
		## Use audisp_t or auditd_t depending on the auditd version
		if [ "$AUDITD_MAJOR_VERSION" -ge 3 ] ; then
			sed -i 's/audisp_t/auditd_t/' $PLUGIN_TE
		else
			sed -i 's/auditd_t/audisp_t/' $PLUGIN_TE
		fi;
		## Install the policy. This will overwrite it if
		## already installed.
		checkmodule -M -m -o $PLUGIN_MOD $PLUGIN_TE
		semodule_package -o $PLUGIN_PP -m $PLUGIN_MOD -f $PLUGIN_FC
		semodule -i $PLUGIN_PP
		chkpkg=`semodule -l 2>/dev/null | grep "^qualys-agent-plugin\b" | awk '{ print $1; }'`
		if [ -z "$chkpkg" ]; then
			LOG "Plugin install failed. Aborting.."
			exit 202;
		fi;
		
		## This fails if 'sock' dir not created. QCA or edr-plugin should have it created already by now.
		restorecon -R "/usr/local/qualys/cloud-agent/sock" || exit 203
	fi;
}
	
StartPlugin()
{
    ## Copy the plugin conf file to the correct directory
    ## based on auditd version
    if [ "$AUDITD_MAJOR_VERSION" -ge 3 ] ; then
        cp $PLUGIN_CONF /etc/audit/plugins.d/edr-plugin.conf
    else
        cp $PLUGIN_CONF /etc/audisp/plugins.d/edr-plugin.conf
    fi;
    ## Restart auditd to enable the plugin
    LOG "About to restart auditd"
    service auditd restart
}
	
StartEdr()
{
	LOG "About to start qualys-edr"
	/usr/local/qualys/cloud-agent/bin/qualys-edr &
}

## If never,task rule is present, no audit records will be generated. 
CheckNeverTaskRulePresence()
{
	rule=$(auditctl -l | grep task | awk '{print $NF; }')
	if [ "$rule" = "never,task" -o "$rule" = "task,never" ]; then
		LOG "Never,task rule exists in Audit, Exiting."
		exit 206
	fi;
}

## If enablesd flag is set to 2, audit configuration is locked.
CheckAuditMutableState()
{
	state1=$(auditctl -s | awk -F " " '{print $2}' |  awk -F "=" '{ print $2 }')
	state2=$(auditctl -s | grep enabled | head -n1 | awk -F " " '{print $2}')
	if [ "$state1" = 2 -o "$state2" = 2 ]; then 
		LOG "Audit is in immutable state. Exiting."
		exit 205 
	fi;
}

###==============
### Main script
###==============

COMMAND=$1
MODE=$2
LOG "==============="
LOG "Got command:: $1"

getAuditdVersion >/dev/null 2>&1
AUDITD_MAJOR_VERSION=$?

if [ "$COMMAND" = "stop" ]; then
	StopEdr >/dev/null 2>&1;

    if [ "$MODE" = "dispatcher" ]; then
	    StopPlugin >/dev/null 2>&1;
    fi

	UninstallSELinuxPolicy >/dev/null 2>&1;
elif [ "$COMMAND" = "start" ]; then
	## Verify the auditd state matches the
	## requested mode of operation
	isAuditdRunning >/dev/null 2>&1
	AuditRun=$?
	if [ "$MODE" != "dispatcher" ]; then
		if [ $AuditRun -ne 0 ]; then
			LOG "auditd found running and dispatcher mode is off. Can't launch EDR."
			exit 204
		fi
	elif [ $AuditRun -eq 0 ]; then
		LOG "auditd is not running and dispatcher mode is requested. auditd will be launched."
	fi
	
	CheckAuditMutableState >/dev/null 2>&1
	isEDRRunning >/dev/null 2>&1
	EDRRun=$?
	if [ $EDRRun -ne 0 ]; then
		## If edr is already running, just restart it
		StopEdr >/dev/null 2>&1;
		StartEdr >/dev/null 2>&1;
	else
		InstallSELinuxPolicy >/dev/null 2>&1;

        if [ "$MODE" = "dispatcher" ]; then
		    StartPlugin >/dev/null 2>&1;
			CheckNeverTaskRulePresence >/dev/null 2>&1
        fi

		StartEdr >/dev/null 2>&1;
	fi

elif [ "$COMMAND" = "CHECK" ]; then
	LOG "Checking plugin install.. $(semodule -l |grep qualys)"
	LOG "Getenforce: $(getenforce)"
	isAuditdRunning >/dev/null 2>&1
	LOG "Running process.. "
		ps aux | grep -P "audit|qualys|edr" 2>&1 1>>/var/log/qualys/edr-script.log
	LOG "Files.."
		ls -lZ /usr/local/qualys/cloud-agent 2>&1 1>>/var/log/qualys/edr-script.log
		ls -lZ /usr/local/qualys/cloud-agent/sock 2>&1 1>>/var/log/qualys/edr-script.log
		echo ""
		ls -ltr /etc/au*/**/*.conf 2>&1 1>>/var/log/qualys/edr-script.log
else
	echo "Invalid option provided. Valid are: (START|STOP)";
	exit 1;
fi
LOG "=== script complete ==="
