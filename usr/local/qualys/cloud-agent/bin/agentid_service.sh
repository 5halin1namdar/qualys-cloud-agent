#!/bin/bash

prog="/usr/local/qualys/cloud-agent/bin/agentid-service"

echoerr() {
    echo "$@" 1>&2
}

start() {
    if [ $# -ne 4 ]; then
        echoerr "usage: -config <config file path> -logdir <log directory path>"
        exit -1
    fi

    nohup $prog "$@" 0<&- &>/dev/null &
}

stop() {
    echoerr "Process terminate..."
    pkill -15 -f ${prog}
    counter=15
    while [ $counter -gt 0 ] && pgrep -f ${prog} 0<&- &>/dev/null; do
        echoerr "Process terminating..."
        ((counter--))
        sleep 2;
    done
    if pgrep -f ${prog} 0<&- &>/dev/null; then
        pkill -9 -f ${prog}
        echoerr "Process killed..."
        return
    fi
    echoerr "Process terminated..."
}

args=("$@")
cmd=${args[0]}
$cmd "${args[@]:1}"
