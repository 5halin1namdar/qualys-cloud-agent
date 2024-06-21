#!/usr/bin/env bash

## File Names and ENV var in CAPITAL with underscore. 
## other variables in camel case.
PROG_PATH=/usr/local/qualys/cloud-agent/bin/qualys-cloud-agent
INSTALL_ROOT_DATA=/usr/local/qualys
INSTALL_MAIN_DIR=${INSTALL_ROOT_DATA}/cloud-agent 
INSTALL_ROOT_CONFIG=/etc/qualys
INSTALL_CONFIG_DIR=${INSTALL_ROOT_CONFIG}/cloud-agent

INSTALL_ONDEMANDSCAN_OUTPUT=${INSTALL_MAIN_DIR}/.on-demand-scan

#mandaotory param
eval actionDefined=0
eval typeDefined=0
eval cpuThrottleDefined=0

manifestTypeArray=(vm pc inv udc sca vmpc swca)
actionArray=(demand ondemand)

fileSequenceId=0
lastTimeStampinId=-1
LAST_CONTROLID_FILE="${INSTALL_ONDEMANDSCAN_OUTPUT}/.ondemand_last_controlid_file";

## Function prints usage of script.
usage()
{
  echo "Usage:"
  echo "cloudagentctl.sh action={demand/ondemand} type={vm|pc|inv|udc|sca|vmpc} cputhrottle={0-1000} in milliseconds"
  echo "cloudagentctl.sh show type {to see types of manifest supported by agent.}"
}

## Function is used to change the permissions of on-demand request files 
## according to configure user/group.
changePermission()
{
	username=`cat "${INSTALL_CONFIG_DIR}/qualys-cloud-agent.conf" | grep "^SudoUser=" | awk -F= '{print $2}'`
	group=`cat "${INSTALL_CONFIG_DIR}/qualys-cloud-agent.conf" | grep "^UserGroup=" | awk -F= '{print $2}'`
	chmod 700 "${INSTALL_ONDEMANDSCAN_OUTPUT}"
	# This checks whether username is empty || " ".
	# picked similar condition as in qualys-cloud-agent.sh
	if [[ ! -z "${username}" && "${username}" != " " ]]; then
		chown -R ${username} "${INSTALL_ONDEMANDSCAN_OUTPUT}"
		if [[ -f "${LAST_CONTROLID_FILE}" ]]; then
			chown "${username}" "${LAST_CONTROLID_FILE}"
			chgrp root "${LAST_CONTROLID_FILE}"
			chmod 600 "${LAST_CONTROLID_FILE}"
		fi
	fi
	chgrp -R root "${INSTALL_ONDEMANDSCAN_OUTPUT}"
	find "${INSTALL_ONDEMANDSCAN_OUTPUT}" -type f -name "on-demand-scan_*.conf" -exec chmod 600 {} \; 1>/dev/null 2>&1
}
## Function to get key from key=value.
getKey()
{
  echo $1|awk -F= '{printf $1}'
}
## Function to get value from key=value.
getVal()
{
  echo $1|awk -F= '{printf $2}'
}
## Function to validate whether provided input is valid or not.
validate()
{
  if [[ $# < 1 ]]; then 
    echo "missing parameter to validate"
    return 255;
  fi
  key=$(getKey "$*")
  val=$(getVal "$*")
  if [[ "$key" != "action" && 
        "$key" != "type" && 
        "$key" != "cputhrottle" ]]; then  
    echo "Error: Invalid key name in $1"
    return 255
  fi
  if [[ "x$key" == "x" || "x$val" == "x" ]]; then
    echo "Error: Key or Value missing in [$1]"
    return 255;
  fi
  return 0
}
## Function is used to validate action value provided in input of on-demand-request
## provided by user.
validateAction()
{
	if [[ $# < 1 ]]; then
		echo "missing parameters to validateAction."
		return 1 
	fi
	actionValue=$1
	actionCount=${#actionArray[@]}
	for (( i=0;i<$actionCount;i++ )); do
		if [[ "${actionArray[$i]}" = "${actionValue}" ]]; then 	
			return 0
		fi
	done
	return 1 
}

## Function is used to validate type of manifest provided in input of on-demand-request
## provided by user.
validateType() 
{
	if [[ $# < 1 ]]; then
		echo "missing parameters to validateType."
		return 1 
	fi
	manifestType=$1
	count=${#manifestTypeArray[@]}
	for (( i=0;i<$count;i++ )); do

		if [[ "${manifestTypeArray[$i]}" = "swca" ]]; then
			echo "On demand scan is not supported for manifest of type SWCA"
			return 1	
		fi
		if [[ "${manifestTypeArray[$i]}" = $manifestType ]]; then
			return 0	
		fi
	done
	return 1 
}
## Function is used to print manifest supported list in ondemand request. 
showSupportedManifestList()
{
	manifestTypeDisplay=(vm=Vulnerability pc=PolicyCompliance inv=Inventory/Discovery udc=User-Defined-Control sca=Security-Compliance-Audit vmpc=Vulnerability-PolicyCompliance)
	count=${#manifestTypeDisplay[@]}
	for (( i=0;i<$count;i++ )); do
		temp="${manifestTypeDisplay[$i]}"
		if [[ $i != 0 ]]; then
			message="$message|$temp"
		else
			message=$temp
		fi
	done
	echo "supported manifests: $message"
}
## Function is used to print valid manifest types in help for user. 
printValidManifestTypes()
{
	message="valid values:"
	count=${#manifestTypeArray[@]}
	for (( i=0;i<$count;i++ )); do
		temp="${manifestTypeArray[$i]}"

		if [[ "${manifestTypeArray[$i]}" = "swca" ]]; then
			continue
		fi

		if [[ $i != 0 ]]; then
			message="$message|$temp"
		else
			message="$message $temp"
		fi
	done
	echo "$message"
}
## Function is used to remove the file given in the argument of function.
removeFile() 
{
	if [[ $# < 1 ]]; then
		echo "Invalid no of param passed to removeFile."
		exit 1
	fi

	filetoRemove="$1";

	if [[ -f "$filetoRemove" ]]; then
		rm -rf "$filetoRemove";
	fi

}
## Function is used to send usr1 signal to Qagent process if running after submitting 
## on-demand request.
sendSigUsr1ToQagent()
{
	## Pgrep,pidof not supported on aix.
	## macos:instead using ps -efc |grep progPath.
	qAgentPid=`ps -ef|grep -E "(^|\s)$PROG_PATH($|\s)"|grep -v grep|awk -F' ' '{print $2}'`
	if [[ ! -z "$qAgentPid" && "$qAgentPid" != " " ]]; then
		# write requestId as combination to file.
		echo "controlid=${FILE_SEQUENCE_ID}" >> "${TEMPLATE}"
		echo "On-Demand-Request ControlId: ${FILE_SEQUENCE_ID}"
		echo "${FILE_SEQUENCE_ID}" > "${LAST_CONTROLID_FILE}" 
		mv "${TEMPLATE}" "${OUTPUT_FILE}"
		changePermission
		# if process gets shutdown before sending signal to process, we have staging area to store these requests.
		# so once agent is up, it can catch all those pending requests.
		`kill -USR1 ${qAgentPid}`
	else
		echo "qualys-cloud-agent Process is not running so cant take on-demand-scan request now."
	fi	
}

## main processing .
if [[ $@ < 2 ]]; then 
  usage
  exit 1
fi

if [[ ! -d "${INSTALL_ONDEMANDSCAN_OUTPUT}" ]]; then
	mkdir -p "${INSTALL_ONDEMANDSCAN_OUTPUT}"
	changePermission
fi

if [[ -f "${LAST_CONTROLID_FILE}" ]]; then
	lastTimeStampinId=`cat "${LAST_CONTROLID_FILE}"|sed -n 's/\([0-9]\+\).\([0-9]\+\)/\1/p'`
	lastControlId=`cat "${LAST_CONTROLID_FILE}"`
fi

#create file name based on timestamp.
currentTimeStamp=`date +%Y%m%d%H%M%S` 

if [[ "${lastTimeStampinId}" != -1 ]]; then
	seqNo=`echo "${lastControlId}" |sed -n 's/\([0-9]*\).\([0-9]*\)/\2/p'`
	if [[ "${lastTimeStampinId}" = "${currentTimeStamp}" ]]; then
		fileSequenceId=$(( seqNo + 1 ))
	fi
fi

FILE_SEQUENCE_ID="${currentTimeStamp}.${fileSequenceId}"
TEMPLATE="${INSTALL_ONDEMANDSCAN_OUTPUT}/on-demand-scan_${FILE_SEQUENCE_ID}.conf.tmp"
OUTPUT_FILE="${INSTALL_ONDEMANDSCAN_OUTPUT}/on-demand-scan_${FILE_SEQUENCE_ID}.conf"

#regex for validation checks
integerReg='^([0-9]+$)'

#regex for validation checks
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
   myArray[$index]=`echo ${myArray[$index]} | sed "s/\"//g"`
   myArray[$index]=`echo ${myArray[$index]} |tr '[[:upper:]]' '[[:lower:]]'`
   index=$(( $index + 1 ))
done

numArgs=${#myArray[@]} 

for (( index=0;index<$numArgs;index++)); do 
	arg=`echo ${myArray[$index]}`
	if [[ "$arg" = "show"  ]]; then
		# check next argument is type or config.
		argNext=`echo ${myArray[$index+1]}`
		if [[ "$argNext" = "type" ]]; then
			showSupportedManifestList		
			exit 0 
		else
			echo "Error: Invalid input."
			usage
			exit 1 
		fi

	fi
done

# echo each element in array  
# for loop 
success=true
for (( index=0;index<$numArgs;index++)); do 
  arg=`echo ${myArray[$index]}`
  validate $arg
  if [[ $? == 0 ]]; then 
    case $key in
    "action")
		validateAction $val		  
		ret=$?
		if [[ $ret != 0 ]]; then	
			echo "Invalid action type provided"
			echo "valid values: demand/ondemand"
			success=false	
			break
		fi
		actionDefined=1
    ;;
    "type")
		validateType $val
		ret=$?
		if [[ $ret != 0 ]]; then
			echo "Invalid manifest type provided."
			printValidManifestTypes
			success=false	
			break
		fi
		typeDefined=1
     ;;
	 "cputhrottle")
	 	if [[ ! ($val =~ $integerReg) ]]; then
			echo "Invalid input for cpu throttle."
			success=false	
			break
		fi
		if [[ $val -lt 0 || $val -gt 1000 ]]; then
			echo "Invalid input: $key value should lie within range from 0 to 1000";
			success=false	
			break
		fi
	;;
    esac
  	#echo "$key=$val" >> "${TEMPLATE}"
	(grep "$key=" "${TEMPLATE}" && sed "s/^$key=.*/$key=$val/" -i "${TEMPLATE}")  1>/dev/null 2>&1 || echo "$key=$val" >> "${TEMPLATE}" 
  else
  	removeFile "${TEMPLATE}"
  	exit 255
  fi
done

if [[ "$success" = "false" ]]; then
	removeFile "${TEMPLATE}"
	exit 1
fi

if [[ "$actionDefined" = 0 || "$typeDefined" = 0 ]]; then
	echo "mandatory parameters action,type should be provided."
	usage
	removeFile "${TEMPLATE}"
	exit 2 
fi

sendSigUsr1ToQagent

#remove file is present.
removeFile "${TEMPLATE}"

exit 0
