#!/bin/bash

## This script may also be invoked from cloud-agent daemon

echo "Uninstalling cloud agent"

prog=qualys-cloud-agent-uninstall

#LXAG-1253: Registering signal handler for SIGTERM
trap '' TERM
## Detect host OS platform
if [ -f "/etc/lsb-release" ];then
        osname=`cat /etc/lsb-release | grep "^DISTRIB_ID=" | awk -F= '{print $2}'` || true
elif [ -f "/etc/os-release" ]; then
        osname=`cat /etc/os-release | grep "^ID=" | awk -F= '{print $2}'` || true
fi
osname=`echo $osname | tr "[:upper:]" "[:lower:]" | tr -d "\""`

checksystemd=`ps -p1 | grep systemd | awk '{ print $4}'`
if [ "$checksystemd" = "systemd" ];then
   if [[ "$osname" = "ubuntu" || "$osname" = "debian" ]];then
        apt-get purge -qq -y qualys-epp-helper
        apt-get purge -qq -y qualys-epp
        apt-get purge -qq -y qualys-swca-datacollector
        if [ -f "/usr/local/qualys/cloud-agent/epp/engine/bin/uninstall" ];then
               /usr/local/qualys/cloud-agent/epp/engine/bin/uninstall
        fi
        cp /etc/qualys/cloud-agent/.systemd/${prog}.service /lib/systemd/system/
        chmod 644 /lib/systemd/system/${prog}.service
        systemctl daemon-reload
        systemctl start ${prog}
        systemctl daemon-reload
   elif [[ "$osname" != "sles" && "$osname" != "opensuse" ]];then
        cp /etc/qualys/cloud-agent/.systemd/${prog}.service /usr/lib/systemd/system/
        chmod 644 /usr/lib/systemd/system/${prog}.service
        systemctl daemon-reload
        rpm -e qualys-xdr 1>/dev/null 2>&1
        rpm -e qualys-epp-helper 1>/dev/null 2>&1
        rpm -e qualys-epp 1>/dev/null 2>&1
        rpm -e qualys-swca-datacollector 1>/dev/null 2>&1
        systemctl start ${prog}
        systemctl daemon-reload
        if [ -f "/usr/local/qualys/cloud-agent/epp/engine/bin/uninstall" ];then
                 /usr/local/qualys/cloud-agent/epp/engine/bin/uninstall
        fi
   else
       if [ "$osname" = "sles" ];then
            rpm -e qualys-epp-helper 1>/dev/null 2>&1
            rpm -e qualys-epp 1>/dev/null 2>&1
            rpm -e qualys-swca-datacollector 1>/dev/null 2>&1
            nohup rpm -ev qualys-cloud-agent 0<&- &>/dev/null &
            if [ -f "/usr/local/qualys/cloud-agent/epp/engine/bin/uninstall" ];then
                     /usr/local/qualys/cloud-agent/epp/engine/bin/uninstall
            fi
       fi
       nohup rpm -ev qualys-cloud-agent 0<&- &>/dev/null &
   fi
 else
     case "$osname" in
        "ubuntu")
            apt-get purge -qq -y qualys-epp-helper
            apt-get purge -qq -y qualys-epp
            apt-get purge -qq -y qualys-swca-datacollector
            if [ -f "/usr/local/qualys/cloud-agent/epp/engine/bin/uninstall" ];then
                  /usr/local/qualys/cloud-agent/epp/engine/bin/uninstall
            fi
            cp /etc/qualys/cloud-agent/.upstart/${prog}.conf /etc/init/
            chmod 644 /etc/init/${prog}.conf
            start  ${prog} 0<&- &>/dev/null
            ;;

          "debian")
            apt-get purge -qq -y qualys-epp-helper
            apt-get purge -qq -y qualys-epp
            apt-get purge -qq -y qualys-swca-datacollector
            if [ -f "/usr/local/qualys/cloud-agent/epp/engine/bin/uninstall" ];then
                  /usr/local/qualys/cloud-agent/epp/engine/bin/uninstall
            fi
            nohup dpkg -P qualys-cloud-agent 0<&- &>/dev/null &
            ;;

         *)
            #Uninstall the qualys rpm and all of its modules
            rpm -e qualys-xdr 1>/dev/null 2>&1
            rpm -e qualys-epp 1>/dev/null 2>&1
            rpm -e qualys-epp-helper 1>/dev/null 2>&1
            rpm -e qualys-swca-datacollector 1>/dev/null 2>&1
            if [ -f "/usr/local/qualys/cloud-agent/epp/engine/bin/uninstall" ];then
               /usr/local/qualys/cloud-agent/epp/engine/bin/uninstall
            fi
            
            nohup rpm -ev qualys-cloud-agent 0<&- &>/dev/null &
            ;;
    esac
fi
