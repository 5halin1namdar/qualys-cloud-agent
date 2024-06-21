#!/bin/bash

## This script may also be invoked from cloud-agent daemon

prog=qualys-cloud-agent

checksystemd=`ps -p1 | grep systemd | awk '{ print $4}'`
if [[ "$checksystemd" == "systemd" ]]; then
    systemctl restart ${prog}
else
    if [ -f "/etc/lsb-release" ];then
	osname=`cat /etc/lsb-release | grep "^DISTRIB_ID=" | awk -F= '{print $2}'` || true
    elif [ -f "/etc/os-release" ]; then
	osname=`cat /etc/os-release | grep "^ID=" | awk -F= '{print $2}'` || true
    fi
    osname=`echo $osname | tr "[:upper:]" "[:lower:]"`
    case "$osname" in
        "ubuntu")
		/sbin/status qualys-cloud-agent | grep start >/dev/null
	   	if [ $? -eq 0 ]; then
	    		/sbin/restart ${prog}
	   	else       
	    		/sbin/start ${prog}
	   	fi
           	;;
	"debian")
 		if [[ "$1" == "cmd" ]];then
                	/usr/sbin/service ${prog} restart
            	else
                	nohup /usr/sbin/service ${prog} restart 0<&- &>/dev/null &
                	sleep 5s
            	fi
          	;;    
         *)
            	/sbin/service ${prog} restart
            	;;
    esac
fi
