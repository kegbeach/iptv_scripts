#!/bin/bash
#
# Script to detect errors in guide2go and retry/fail gracefully
#
# Set $BASEDIR to the guide2go directory
# Set $CONF to the guide2go configuration filename
# Set $LOGFILE to the log filename
# Set $MAILPATH to the location of mail program
# Set $RETRIES to the number of retries on error
# Set $RETRYDELAY to the time between retry loops eg: 60s
# Set $ALERTEMAIL to the administrator e-mail
# Set $SERVERNAME to the hostname of this server
# Leave $LOOPCOUNTER unchanged
#
# Set $DEBUG=1 to enable debugging / 0 to turn off
#

DEBUG=1
BASEDIR=/path/to/guide2go
CONF=guide2go_config.yaml
LOGFILE=guide2go.log
MAILPATH=/usr/bin/mail
RETRIES=5
RETRYDELAY=60s
ALERTEMAIL=your@email.com
SERVERNAME=your.server.com
LOOPCOUNTER=1

echolog() {
    echo "$@" | tee -a $BASEDIR/$LOGFILE
}

alert() {
    if [[ -f $MAILPATH ]]; then
        mail -s "$@" -r "guide2go <guide2go@$SERVERNAME>" $ALERTEMAIL < $BASEDIR/$LOGFILE
    else
        echolog "*** WARNING: UNABLE TO SEND LOG FILE. $MAILPATH NOT FOUND! ***"
    fi
}

while true; do
    if [[ -f $BASEDIR/$LOGFILE ]]; then
        truncate -s 0 $BASEDIR/$LOGFILE

        echolog "------------------------------------"
        echolog "[#] - cleared log file: loop $LOOPCOUNTER - [#]"
        echolog "------------------------------------"
        echolog ""
    else
        touch $BASEDIR/$LOGFILE

        echolog "------------------------------------"
        echolog "[#] - created log file: loop $LOOPCOUNTER - [#]"
        echolog "------------------------------------"
        echolog ""
    fi

    if [[ -f $BASEDIR/guide2go && -f $BASEDIR/$CONF ]]; then
        $BASEDIR/guide2go -config $BASEDIR/$CONF 2>&1 | tee -a $BASEDIR/$LOGFILE
    else
        echolog ""
        echolog "------------------------------------------------"
        echolog "[#] - missing guide2go core files, exiting - [#]"
        echolog "------------------------------------------------"
        echolog ""

        alert "guide2go needs attention"

        exit 0
    fi

    if [[ $LOOPCOUNTER -lt $RETRIES ]] && grep -q "\[ERROR\]" $BASEDIR/$LOGFILE; then
        echolog ""
        echolog "----------------------------------------------------"
        echolog "[#] - error detected in the log file, retrying - [#]"
        echolog "----------------------------------------------------"
        echolog ""

        if [[ $DEBUG -eq 1 ]]; then
            alert "guide2go retry log"
        fi

        ((LOOPCOUNTER++))
        sleep $RETRYDELAY
    else
        if [[ $LOOPCOUNTER -eq $RETRIES ]] && grep -q "\[ERROR\]" $BASEDIR/$LOGFILE; then
            echolog ""
            echolog "--------------------------------------------------------"
            echolog "[#] - error detected after loop threshold, exiting - [#]"
            echolog "--------------------------------------------------------"

            alert "guide2go needs attention"

            exit 0
        fi

        echolog ""
        echolog "----------------------------"
        echolog "[#] - guide2go success - [#]"
        echolog "----------------------------"

        if [[ $DEBUG -eq 1 ]]; then
            alert "guide2go debug log"
        fi

        exit 0
    fi
done
