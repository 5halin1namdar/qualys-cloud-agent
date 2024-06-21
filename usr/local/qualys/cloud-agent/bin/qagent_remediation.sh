#!/bin/bash

checksystemd=$(ps -p1 | grep systemd | awk '{ print $4}')

echoerr() {
    echo "$@" 1>&2
}

wait_file() {
    local file="$1"
    shift
    local wait_seconds="${1:-10}"
    shift # 10 seconds as default timeout

    until test $((wait_seconds--)) -eq 0 -o -e "$file"; do sleep 1; done

    ((++wait_seconds))
}

start() {
    if [ $# -lt 11 ]; then
        echoerr "usage: manifestId customerId agentId baseDir ipv4 ipv6 os user group cputhrottle proxyDetails [LogLevel]"
        exit -1
    fi

    local -a func_args=("$@")
    local manifestId=${func_args[0]}
    local customerId=${func_args[1]}
    local agentId=${func_args[2]}
    local baseDir=${func_args[3]}
    local ipv4=${func_args[4]}
    local ipv6=${func_args[5]}
    local os=${func_args[6]}
    local user=${func_args[7]}
    local group=${func_args[8]}
    local cputhrottle=${func_args[9]}
    local proxyDetails=${func_args[10]}
    local loglevel=${func_args[11]}

    local pidfile=$baseDir/$manifestId.pid
    if [ -f "$pidfile" ]; then
        rm -f $pidfile
    fi

    local remediation_tool="/usr/local/qualys/cloud-agent/bin/qualys-remediation-tool"

    case "$checksystemd" in
    "systemd")
        # reset failed status from previous run for qualys-remediation-tool.service
        systemctl reset-failed qualys-remediation-tool.service 0<&- &>/dev/null

        systemd_args="--unit=qualys-remediation-tool --service-type=oneshot"

        # check and use if systemd-run suppport --no-block option
        if /usr/bin/systemd-run --no-block --version 0<&- &>/dev/null; then
            systemd_args="$systemd_args --no-block"
        fi

        /usr/bin/systemd-run \
            $systemd_args \
            $remediation_tool "$@" &
        ;;

    *)
        nohup $remediation_tool "$@" \
            0<&- &>/dev/null &
        ;;
    esac

    wait_file "$pidfile" 10 || {
        echoerr "$pidfile missing after waiting for 10 seconds"
        exit 1
    }

    # let process update pidfile to avoid reading corrupted file by agent service.
    sleep 2
}

args=("$@")
cmd=${args[0]}
$cmd "${args[@]:1}"
