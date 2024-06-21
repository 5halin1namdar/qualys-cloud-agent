#!/bin/bash
prog=qualys-cloud-agent
INSTALL_ROOT_DATA=/usr/local/qualys
INSTALL_ROOT_CONFIG=/etc/qualys
INSTALL_MAIN_DIR=${INSTALL_ROOT_DATA}/cloud-agent 
INSTALL_CONFIG_DIR=${INSTALL_ROOT_CONFIG}/cloud-agent
INSTALL_LOG_DIR=/var/log/qualys
INSTALL_SPOOL_DIR=/var/spool/qualys
PROPFNAME=$INSTALL_CONFIG_DIR/${prog}.properties
TEMPLATE=$INSTALL_CONFIG_DIR/${prog}.conf
LOG_FILE_PATH=${INSTALL_CONFIG_DIR}/qagent-log.conf
REMEDIATION_LOG_FILE_PATH=${INSTALL_CONFIG_DIR}/qagent-remediation-log.conf
UDC_LOG_FILE_PATH=${INSTALL_CONFIG_DIR}/qagent-udc-log.conf
SCAN_PROCESS_LOG_FILE_PATH=${INSTALL_CONFIG_DIR}/qagent-scan-process-log.conf
PATCH_LOG_FILE_PATH=${INSTALL_CONFIG_DIR}/qagent-patchmgmt-log.conf
HOST_ID_DEFAULT_PATH=/etc
DEFAULT_INSTALL_ROOT_DATA_PERM=""

eval Activationid_defined=0

usage()
{
  echo "Usage:"
  echo "qualys-cloud-agent.sh ActivationId=\"xxxx-xx-xxxxxxx\" CustomerId=\"xxxx-xx-xxxxxxx\""
  echo "qualys-cloud-agent.sh InstallDirPermission=<to be set to octal value 0755> Sets the installation directory permission (/usr/local/qualys) non-recursively to given value"
  echo "qualys-cloud-agent.sh LogLevel=<a number between 0 and 5> LogDestType=<syslog|file> specifies log destination type"
  echo "qualys-cloud-agent.sh LogFileDir=directory where the log file should be created.Please make sure this directory should be accessible for agent user."
  echo "qualys-cloud-agent.sh UseSudo=<0 or 1> User=<scanuser> Group=<scangroup> SudoCommand=<cmd>"
  echo "qualys-cloud-agent.sh CmdMaxTimeOut=<command max wait-time in seconds>  ProcessPriority=<-20 to 19> sets agent process priority"
  echo "qualys-cloud-agent.sh HostIdSearchDir=<Qualys Scanner hostid file dir> ActivationId=\"xxxx-xx-xxxxxxx\""
  echo "qualys-cloud-agent.sh ServerUri=\"https://<pod url>/CloudAgent\""
  echo "qualys-cloud-agent.sh ProviderName=specify the provider name. <value can be AWS or AZURE or GCP or IBM or ALIBABA or ORACLE or NONE (to skip the provider checks)>"
  echo "qualys-cloud-agent.sh UseAuditDispatcher=<0 or 1>"
  echo "qualys-cloud-agent.sh QualysProxyOrder=<sequential|seq (default), random>"
  echo "qualys-cloud-agent.sh CmdStdOutSize=<command std output size in KB, default value is 1024 and max limit is 5120>"
  echo "qualys-cloud-agent.sh MaxRandomScanIntervalVM=<0 to 43200 seconds, default value is 0 (No randomization). Applicable for VM scans only>"
  echo "qualys-cloud-agent.sh MaxRandomScanIntervalPC=<0 to 43200 seconds, default value is 0 (No randomization). Applicable for PC scans only>"
  echo "qualys-cloud-agent.sh ScanDelayVM=<0 to 43200 seconds, default value is 0 (No delay). Applicable for VM scans only>"
  echo "qualys-cloud-agent.sh ScanDelayPC=<0 to 43200 seconds, default value is 0 (No delay). Applicable for PC scans only>"
  echo "qualys-cloud-agent.sh EDRCPULimit=<2 to 100%, default value is 5 (Peak CPU utilisation for EDR/FIM)>"
  echo "qualys-cloud-agent.sh EDRMemoryLimit=<2 to 100%, default value is 5 (Peak Memory utilisation for EDR/FIM(RSS))>"
  echo "qualys-cloud-agent.sh AuditBacklogLimit=<min value 320, number of audit events, default value is 8192>"
  # DisableAHS is hidden for now as it does not disable AHS reporting from all modules just Core, Scan and SM.
  # This capability is currently only requested by Amazon.
  #echo "qualys-cloud-agent.sh DisableAHS=<0 or 1> default value is 0 (AHS is enabled)."
  echo ""
  echo "For backwards compatibility the following aliases are supported:"
  echo "SudoUser for User"
  echo "UserGroup for Group"
}
get_key()
{
  echo $1|awk -F= '{printf $1}'
}
get_val()
{
  echo $1|awk -F= '{printf $2}'
}

validate()
{
  if [[ $# < 1 ]]; then
    echo "missing parameter to validate"
    return 255;
  fi
  key=$(get_key "$*")
  val=$(get_val "$*")
  if [[ "$key" != "ActivationId" &&
    "$key" != "CustomerId" &&
    "$key" != "LogFileDir" &&
    "$key" != "LogLevel" &&
    "$key" != "UseSudo" &&
    "$key" != "SudoUser" &&
    "$key" != "User" &&
    "$key" != "UserGroup" &&
    "$key" != "Group" &&
    "$key" != "SudoCommand" &&
    "$key" != "InstallDirPermission" &&
    "$key" != "LogDestType" &&
    "$key" != "HostIdSearchDir" &&
    "$key" != "CmdMaxTimeOut" &&
    "$key" != "KillProcessHierarchy" &&
    "$key" != "ProcessPriority" &&
    "$key" != "UseAuditDispatcher" &&
    "$key" != "QualysProxyOrder" &&
    "$key" != "ServerUri" &&
    "$key" != "CmdStdOutSize" &&
    "$key" != "ProviderName" &&
    "$key" != "MaxRandomScanIntervalVM" &&
    "$key" != "MaxRandomScanIntervalPC" &&
    "$key" != "ScanDelayVM" &&
    "$key" != "ScanDelayPC" &&
    "$key" != "EDRCPULimit" &&
    "$key" != "EDRMemoryLimit" &&
    "$key" != "AuditBacklogLimit" &&
    "$key" != "DisableAHS" ]]; then
    echo "Error: Invalid key name in $1"
    return 255
  fi
  if [[ "x$key" == "x" || "x$val" == "x" ]]; then
    echo "Error: Key or Value missing in [$1]"
    return 255;
  fi
  return 0
}

UserExist()
{
   user=$1
   `id "$user" > /dev/null 2>&1`
   return $?
}
GroupExist()
{
   group=$1
	grep "$group:"	/etc/group 1>/dev/null 2>&1;
	if [[ $? -ne 0 ]];then
		echo "Invalid group provided:$group"
		exit 1;
	fi
   `chgrp $group "$TEMPLATE" > /dev/null 2>&1`
   return $?
}

change_permission()
{

    username=`cat ${INSTALL_ROOT_CONFIG}/cloud-agent/qualys-cloud-agent.conf | grep "^SudoUser=" | awk -F= '{print $2}'`
    group=`cat ${INSTALL_ROOT_CONFIG}/cloud-agent/qualys-cloud-agent.conf | grep "^UserGroup=" | awk -F= '{print $2}'`
    LogDir=`cat ${INSTALL_ROOT_CONFIG}/cloud-agent/qualys-cloud-agent.conf | grep "^LogFileDir=" | awk -F= '{print $2}'`

	#first change and username and group perm.
    if [[ ! -z "$username" && "$username" != " " ]]; then

		chown -R ${username} ${INSTALL_MAIN_DIR}	1>/dev/null 2>&1
		chown -R ${username} ${INSTALL_CONFIG_DIR}	1>/dev/null 2>&1

		if [ "$LogDir" != "$INSTALL_LOG_DIR" -a "$LogDir" != "$INSTALL_LOG_DIR/" ];then
			echo "Setting change owner for $LogDir"
			chown -RH ${username} "$LogDir"
		fi	

	fi

	if [[ ! -z "$group" && "$group" != " " ]]; then

		chgrp  ${group} ${INSTALL_ROOT_DATA}    1>/dev/null 2>&1
		chgrp  ${group} ${INSTALL_ROOT_CONFIG}  1>/dev/null 2>&1
		chgrp  ${group} "${INSTALL_LOG_DIR}"    1>/dev/null 2>&1
		chgrp  ${group} "${INSTALL_SPOOL_DIR}"  1>/dev/null 2>&1
		
		find ${INSTALL_ROOT_CONFIG} -type f -name 'hostid' -exec chgrp ${group} {} \; 1>/dev/null 2>&1
		find ${INSTALL_ROOT_DATA}   -type f -name 'hostid' -exec chgrp ${group} {} \; 1>/dev/null 2>&1
	
	fi

	if [ "$LogDir" != "$INSTALL_LOG_DIR" -a "$LogDir" != "$INSTALL_LOG_DIR/" ];then
		echo "Setting group for $LogDir"
		chgrp -RH root "$LogDir"
	fi
		
	#change group/mode of all dynamic files under 
	find ${INSTALL_MAIN_DIR} -type f ! -name 'hostid' -exec chgrp root {} \; 1>/dev/null 2>&1
    find "$LogDir" -type f \( -name "qualys-*.log*" -o -name "fimc.log*" \)  -exec chgrp root {} \; 1>/dev/null 2>&1
    find "$LogDir" -type f \( -name "qualys-*.log*" -o -name "fimc.log*" \)  -exec chown ${username} {} \; 1>/dev/null 2>&1
    find "$LogDir" -type f \( -name "qualys-*.log*" -o -name "fimc.log*" \)  -exec chmod 600 {} \; 1>/dev/null 2>&1

	#change log file perm=600;	
	if [ "$LogDir" != "$INSTALL_LOG_DIR" -a "$LogDir" != "$INSTALL_LOG_DIR/" ];then
        	chmod 700 "$LogDir";
    fi

	#now change cloud-agent dir perm.Set everything again.
	chmod 770 ${INSTALL_ROOT_CONFIG} 1>/dev/null 2>&1
#	Update permissions if InstallDirPermission option is provided, otherwise use already configured permissions
#	from qualys-cloud-agent.conf
#	This also takes care of the fresh installation condition.
	if [[ -n $DEFAULT_INSTALL_ROOT_DATA_PERM ]]
	then
		chmod $DEFAULT_INSTALL_ROOT_DATA_PERM ${INSTALL_ROOT_DATA} 1>/dev/null 2>&1
	else
		oldperms=`cat ${INSTALL_ROOT_CONFIG}/cloud-agent/qualys-cloud-agent.conf | grep "^InstallDirPermission=" | awk -F= '{print $2}'`
		if [[ -n $oldperms ]]
		then
			chmod $oldperms ${INSTALL_ROOT_DATA} 1>/dev/null 2>&1
		fi
	fi
	chmod 770 ${INSTALL_LOG_DIR}    1>/dev/null 2>&1
	chmod 770 ${INSTALL_SPOOL_DIR}  1>/dev/null 2>&1

	find ${INSTALL_MAIN_DIR} ! -path '*/epp/engine/*' | xargs -I {} chmod 700 {} 2>&1
	chmod -R 700 ${INSTALL_CONFIG_DIR} 1>/dev/null 2>&1

	DIR_LIST=`find ${INSTALL_MAIN_DIR} -type d ! -name 'bin' 2>/dev/null`;
	for i in $DIR_LIST
	do
		# Set File Permission to any depth to 600.
		find $i -type f ! -name 'hostid' ! -path  "${INSTALL_MAIN_DIR}/epp/engine/*" -exec chmod 600 {} \; 1>/dev/null 2>&1
	done

	# change files perm under /etc/
	find ${INSTALL_CONFIG_DIR} -type f -exec chmod 600 {} \; 1>/dev/null 2>&1

	find ${INSTALL_ROOT_CONFIG} -type f -name 'hostid' -exec chmod 660 {} \; 1>/dev/null 2>&1
	find ${INSTALL_ROOT_DATA}   -type f -name 'hostid' -exec chmod 660 {} \; 1>/dev/null 2>&1

	chmod -R 700 ${INSTALL_MAIN_DIR}/bin/ 1>/dev/null 2>&1

    #In the last change fim_plugin file ownership to root always.
    if [ -f "${INSTALL_ROOT_DATA}/cloud-agent/bin/edr-plugin" ]; then
	chown root ${INSTALL_ROOT_DATA}/cloud-agent/bin/edr-plugin
	chmod 750 ${INSTALL_ROOT_DATA}/cloud-agent/bin/edr-plugin
    fi
    chown root "${INSTALL_ROOT_DATA}/cloud-agent/edr/SnapshotEdr.db" > /dev/null 2>&1 || true;

    #XDR related directories and folders
    find "${INSTALL_MAIN_DIR}"/xdr/bin -type f -exec chmod 700 {} \; 1>/dev/null 2>&1
    find "${INSTALL_MAIN_DIR}"/xdr/* -type d -regextype posix-extended ! -regex '.*(setup|manifest).*' -exec chown -R root {} \; 1>/dev/null 2>&1

    #SWCA related directories and folders
    find "${INSTALL_MAIN_DIR}"/swca/bin -type f -exec chmod 700 {} \; 1>/dev/null 2>&1

    #EPP related directories and folders
    find "${INSTALL_MAIN_DIR}"/epp/bin -type f -exec chmod 700 {} \; 1>/dev/null 2>&1
    find "${INSTALL_MAIN_DIR}"/epp/* -type d -regextype posix-extended ! -regex '.*(setup|manifest|bin|lib).*' -exec chown -R root {} \; 1>/dev/null 2>&1

}

adjust_group()
{

       username=`cat ${INSTALL_ROOT_CONFIG}/cloud-agent/qualys-cloud-agent.conf | grep "^SudoUser=" | awk -F= '{print $2}'`
       group=`cat ${INSTALL_ROOT_CONFIG}/cloud-agent/qualys-cloud-agent.conf | grep "^UserGroup=" | awk -F= '{print $2}'`

       if [ -z "$group" -o "$group" = " " ]; then
               group=root
               sed -i "/UserGroup=/d"  $TEMPLATE
               sed -i "\$aUserGroup=$group" $TEMPLATE
               sed -i "/UserGroup=/d"  $PROPFNAME
               sed -i "\$aUserGroup=$group" $PROPFNAME
       fi

}
adjust_permission()
{
	username=`cat ${INSTALL_ROOT_CONFIG}/cloud-agent/qualys-cloud-agent.conf | grep "^SudoUser=" | awk -F= '{print $2}'`
	group=`cat ${INSTALL_ROOT_CONFIG}/cloud-agent/qualys-cloud-agent.conf | grep "^UserGroup=" | awk -F= '{print $2}'`
	if [ ! -z "$username" -a "$username" != " " ]; then
		chown -R ${username} $PROPFNAME  
		     
		# Adjust hostid file permission 
		hostid_dir=`cat ${INSTALL_ROOT_CONFIG}/cloud-agent/qualys-cloud-agent.conf | grep "^HostIdSearchDir=" | awk -F= '{print $2}'`
	   	if [ "x$hostid_dir" = "x" -o "$hostid_dir" = " " ]; then 
			hostid_dir=$HOST_ID_DEFAULT_PATH
	   	fi
	   	
	   	echo "hostid search path: $hostid_dir"
	   	if [ ! -d "$hostid_dir" ]; then
			echo "Error: HostID directory:"$hostid_dir" doesn't exist"
			return 255
	   	fi
	   	
	   	if [ ! -d "$hostid_dir/qualys" ]; then
			echo "Creating directory:$hostid_dir/qualys"
			mkdir "$hostid_dir/qualys"
			chmod 770 "$hostid_dir/qualys"
	   	fi
	   	
		if [ -d "$hostid_dir/qualys" ]; then
           	#echo "Set permission on hostid search directory : $hostid_dir/qualys"
           	#chown -RH ${username} $hostid_dir/qualys  	#-RH for recursive and symlink
		if [ ! -z "$group" -a "$group" != " " ]; then chgrp -H ${group} "$hostid_dir/qualys"; 
		
			if [ ! -f "$hostid_dir/qualys/hostid" ]; then touch "$hostid_dir/qualys/hostid"; fi
			chgrp -H ${group} "$hostid_dir/qualys/hostid"; 
			chmod 660 "$hostid_dir/qualys/hostid";	
		fi
		
		fi
	fi 
}

if [[ $# -lt 1 ]]; then 
  usage
  exit
fi

# LXAG-2069 Creating the .properties file here, so that any new parameters configured would get added 
# in .properties file at the time of reading only, instead of copying the .conf file contents.
touch $PROPFNAME

#enum for cloud provider check
PROVIDERINFO=(AWS AZURE GCP IBM ALIBABA ORACLE AUTO NONE UNSUPPORTED)
count=${#PROVIDERINFO[@]}

#regex for validation checks
id_reg="^([A-Za-z0-9]{8}-[A-Za-z0-9]{4}-[A-Za-z0-9]{4}-[A-Za-z0-9]{4}-[A-Za-z0-9]{12})$"
integer_reg='^([0-9]+$)'
neg_integer_reg='^-?[0-9]*(\.\d+)?$'
#delete the CmdTimeout line from conf file,if exists
if [[ -n $(grep "CmdTimeOut" $TEMPLATE) ]]; then
    sed -i '/CmdTimeOut/d' $TEMPLATE
fi
myArray=()
index=0
whitespace="[[:space:]]"
for i in "$@"
do
    if [[ $i =~ $whitespace ]]
    then
        i=\"$i\"
    fi
   myArray[$index]="$i"
   index=$(( $index + 1 ))
done

num_args=${#myArray[@]} 

# echo each element in array  
# for loop 
# Delete the .properties file in case of any validation error occurs.
for (( i=0;i<$num_args;i++)); do 
  arg=`echo ${myArray[$i]} | sed "s/\"//g"`
  validate $arg
  if [[ $? == 0 ]]; then 
    case $key in
    "CustomerId"|"ActivationId")
	if [[ ! ($val =~ $id_reg) ]]; then
	    echo "Error: Invalid $key"
        rm -rf $PROPFNAME
	    exit 1
        fi
     ;;
    "LogLevel")
        if [[ $val != [0-5] ]]; then
	    echo "Invalid input: $key value should lie within range from 0 to 5"; 
        rm -rf $PROPFNAME
	    exit 1
        fi
     ;;
    "LogFileDir")
       if [[ ! -d "$val" ]]; then
          mkdir -p "$val"; 
       fi
     ;;	
    "UseSudo"|"KillProcessHierarchy"|"DisableAHS")
	if [[ $val != [0-1] ]]; then
	    echo "Invalid input: $key value should be either 0 or 1." ;
        rm -rf $PROPFNAME
        exit 1
	fi
     ;;
    "CmdMaxTimeOut")
        if ! [[ "$val" =~ $integer_reg ]] ; then
            echo "Invalid input: $key value should be an integer";
            rm -rf $PROPFNAME
            exit 1
        fi
     ;;
    "ProcessPriority")
	if ! [[ "$val" =~ $neg_integer_reg ]] ; then
            echo "Invalid input: $key value should lie within range from -20 to 19";
            rm -rf $PROPFNAME
            exit 1
	elif ! [ "$val" -ge -20 -a "$val" -le 19 ]; then
	    echo "Invalid input: $key value should lie within range from -20 to 19";
        rm -rf $PROPFNAME
   	    exit 1
	fi
     ;;
    "SudoUser"|"User")
    	key="SudoUser"
        UserExist $val
        if [ $? = 0 ]; then
	    echo "Setting necessary permission for user: $val"
            chown -R $val $INSTALL_MAIN_DIR
            chown -R $val $INSTALL_CONFIG_DIR
		    if [ -f "${INSTALL_ROOT_DATA}/cloud-agent/bin/edr-plugin" ]; then
			    chown root ${INSTALL_ROOT_DATA}/cloud-agent/bin/edr-plugin
		    fi
        else
            echo "Invalid input: user '$val' does not exists";
            rm -rf $PROPFNAME
	        exit 1
        fi
     ;;
	"UseAuditDispatcher")
	 if [[ $val != [0-1] ]]; then
		 echo "Invalid input: $key value should be either 0 or 1." ;
         rm -rf $PROPFNAME
         exit 1
	 fi	
	;;
	"CmdStdOutSize")
        if ! [ "$val" -ge 1024 -a "$val" -le 5120 ] ; then
            echo "Invalid input: $key value should lie within range from 1024 KB to 5120 KB";
        rm -rf $PROPFNAME
   	    exit 1
        fi
     ;;

    "UserGroup"|"Group")
    	key="UserGroup"
	GroupExist $val
	if [ $? = 0 ]; then
            echo "Setting necessary permission for group: $val"
            #-H; if a command line argument is a symbolic link to a directory, traverse it
            chgrp -H $val $INSTALL_LOG_DIR
            chgrp $val $INSTALL_ROOT_CONFIG
            chgrp $val $INSTALL_ROOT_DATA
            chgrp root $TEMPLATE;	
	else
            echo "Invalid input: group '$val' does not exists";
            rm -rf $PROPFNAME
            exit 1
	fi
	
     ;;
    "InstallDirPermission")
	distro=$(lsb_release -ds 2>/dev/null || cat /etc/*release 2>/dev/null | head -n1 || uname -om)
	isdeb=$(echo $distro | grep -e ubuntu -e debian -i)
	if [[ -z $isdeb ]]
	then
	    if ! [[ "x$val" =~ x[0-7]{3,4}$ ]]
	    then
		echo "Error: Incorrect $key value: $val"
        rm -rf $PROPFNAME
		exit 1
	    fi
	    DEFAULT_INSTALL_ROOT_DATA_PERM=$val
	else
	    echo "Error: Invalid key name $key" 
        rm -rf $PROPFNAME
	    exit 1
	fi
    ;;
    "LogDestType")
	if [[ "$val" == "syslog" || "$val" == "file" ]]; then
  	    echo "Changing Log destination type to: $val" 
	    if [[ "$val" == "syslog" ]]; then
    	       	sed -i 's/^logging.loggers.l1.channel.*c.$/logging.loggers.l1.channel = c2/' $LOG_FILE_PATH
    	       	sed -i 's/^logging.loggers.l1.channel.*c.$/logging.loggers.l1.channel = c2/' $REMEDIATION_LOG_FILE_PATH
    	       	sed -i 's/^logging.loggers.l1.channel.*c.$/logging.loggers.l1.channel = c2/' $UDC_LOG_FILE_PATH
                sed -i 's/^logging.loggers.l1.channel.*c.$/logging.loggers.l1.channel = c2/' $SCAN_PROCESS_LOG_FILE_PATH
				## LXAG-8303: suppressing error, file not present part of ubuntu/debian.
				sed -i 's/^logging.loggers.l1.channel.*c.$/logging.loggers.l1.channel = c2/' $PATCH_LOG_FILE_PATH 1>/dev/null 2>&1
	    else
		sed -i 's/^logging.loggers.l1.channel.*c.$/logging.loggers.l1.channel = c3/' $LOG_FILE_PATH	
		sed -i 's/^logging.loggers.l1.channel.*c.$/logging.loggers.l1.channel = c3/' $REMEDIATION_LOG_FILE_PATH	
		sed -i 's/^logging.loggers.l1.channel.*c.$/logging.loggers.l1.channel = c3/' $UDC_LOG_FILE_PATH	
		sed -i 's/^logging.loggers.l1.channel.*c.$/logging.loggers.l1.channel = c3/' $SCAN_PROCESS_LOG_FILE_PATH
		## LXAG-8303: suppressing error, file not present part of ubuntu/debian. 
		sed -i 's/^logging.loggers.l1.channel.*c.$/logging.loggers.l1.channel = c3/' $PATCH_LOG_FILE_PATH 1>/dev/null 2>&1
	    fi
	else
	    echo "Error: Incorrect $key value: $val";
        rm -rf $PROPFNAME
	    exit 1
	fi
     ;;
     "HostIdSearchDir")
        if [[ ! -d $val ]]; then
       	    echo "Error: specified path in $key does not exist";    
            rm -rf $PROPFNAME
	    exit 1
    	fi
     ;;
     "ProviderName")
     	num=0
        while [ $num -lt $count ]
        do
        if [[ "$val" == "${PROVIDERINFO[$num]}" ]]; then
           	break
        fi
        num=`expr $num + 1`
        done
        if [[ $num == $count ]]; then
        	echo "Error: specified value in $key does not exist";
            rm -rf $PROPFNAME
        	exit 1
        fi
     ;;
     "MaxRandomScanIntervalVM")
        if ! [[ "$val" =~ $integer_reg ]] || ! [ "$val" -ge 0 -a "$val" -le 43200 ] ; then
            echo "Invalid input: $key value should lie within range from 0 and 43200";
            rm -rf $PROPFNAME
   	        exit 1
        fi
     ;;
     "MaxRandomScanIntervalPC")
        if ! [[ "$val" =~ $integer_reg ]] || ! [ "$val" -ge 0 -a "$val" -le 43200 ] ; then
            echo "Invalid input: $key value should lie within range from 0 and 43200";
            rm -rf $PROPFNAME
   	        exit 1
        fi
     ;;
     "ScanDelayVM")
        if ! [[ "$val" =~ $integer_reg ]] || ! [ "$val" -ge 0 -a "$val" -le 43200 ] ; then
            echo "Invalid input: $key value should lie within range from 0 and 43200";
            rm -rf $PROPFNAME
   	        exit 1
        fi
     ;;
     "ScanDelayPC")
        if ! [[ "$val" =~ $integer_reg ]] || ! [ "$val" -ge 0 -a "$val" -le 43200 ] ; then
            echo "Invalid input: $key value should lie within range from 0 and 43200";
            rm -rf $PROPFNAME
   	        exit 1
        fi
     ;;
     "EDRCPULimit")
        if ! [[ "$val" =~ $integer_reg ]] || ! [ "$val" -ge 2 -a "$val" -le 100 ] ; then
            echo "Invalid input: $key value should lie within range from 2 and 100";
            rm -rf $PROPFNAME
   	        exit 1
        fi
     ;;
     "EDRMemoryLimit")
        if ! [[ "$val" =~ $integer_reg ]] || ! [ "$val" -ge 2 -a "$val" -le 100 ] ; then
            echo "Invalid input: $key value should lie within range from 2 and 100";
            rm -rf $PROPFNAME
   	        exit 1
        fi
     ;;
     "AuditBacklogLimit")
        if ! [[ "$val" =~ $integer_reg ]] || ! [ "$val" -ge 320 ] ; then
            echo "Invalid input: $key value should be an integer above 320";
            rm -rf $PROPFNAME
   	        exit 1
        fi
     ;;

     esac
  sed -i "/^$key=/d" $TEMPLATE
  sed -i "\$a$key=$val" $TEMPLATE

  # LXAG-2069 Modifying qualys-cloud-agent.properties to contain values of only the changed parameters
  # .properties file should contain latest of the set value, if same param is set multiple times consecutively.
  # 'sed' removes the old entry (if any) and 'echo' adds the new entry.
  sed -i "/^$key=/d" $PROPFNAME
  echo "$key=$val" >> $PROPFNAME
  else
    rm -rf $PROPFNAME
    exit 255
  fi
  eval "$key"_defined=1
done

if [[ $HostIdSearchDir_defined && ! $ActivationId_defined ]]; then  
  echo "Error: HostIdSearchDir must be defined with ActivationId";
  rm -rf $PROPFNAME
  exit 1
fi
 
grep  "ActivationId=" $TEMPLATE >/dev/null
have_activation_id=$?
grep  "CustomerId=" $TEMPLATE >/dev/null
have_customer_id=$?

adjust_group

if [[ $have_activation_id && $have_customer_id ]]; then
  adjust_permission
  returnValue=$?
  if [ "$returnValue" != 0 ]; then
    exit 1
  fi
else
  usage;
  rm -rf $PROPFNAME
  exit
fi

#Make sure backward compatibility
chmod 770 ${INSTALL_ROOT_CONFIG}
chmod 770 ${INSTALL_ROOT_DATA}

#change Mode of .conf file.
chmod 600 $TEMPLATE;

change_permission

${INSTALL_MAIN_DIR}/bin/qagent_restart.sh "cmd"
