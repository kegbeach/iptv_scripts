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
# Set $MAXBACKUPS to the number of backups to keep
# Set $XMLWORK to the guide2go XMLTV file
# Set $JSONWORK to the guide2go cache file
# Leave $LOOPCOUNTER unchanged
#
# Set $DEBUG=1 to enable debugging / 0 to turn off
#

DEBUG=0
BASEDIR=/path/to/guide2go
CONF=guide2go_config.yaml
LOGFILE=guide2go.log
MAILPATH=/usr/bin/mail
RETRIES=5
RETRYDELAY=60s
ALERTEMAIL=your@email.com
SERVERNAME=your.server.com
MAXBACKUPS=5
XMLWORK=guide2go-schedule.xml
JSONWORK=guide2go-cache.json
LOOPCOUNTER=1

checkNumFiles() {
    XMLCOUNT=$(find $BASEDIR/backup -type f -name "$XMLWORK-*" -printf '%f\n' | wc -l)
    JSONCOUNT=$(find $BASEDIR/backup -type f -name "$JSONWORK-*" -printf '%f\n' | wc -l)
}

checkMD5() {
    XMLFILE=$(find $BASEDIR/backup -type f -name "$XMLWORK-*" -printf '%T+ %f\n' | sort -r | cut -d' ' -f2 | sed -n '1 p')
    JSONFILE=$(find $BASEDIR/backup -type f -name "$JSONWORK-*" -printf '%T+ %f\n' | sort -r | cut -d' ' -f2 | sed -n '1 p')

    if [[ -f $BASEDIR/backup/$XMLFILE && ! -z $XMLFILE && -f $BASEDIR/$XMLWORK ]]; then
        MD5XMLBAK=$(md5sum $BASEDIR/backup/$XMLFILE | cut -d' ' -f1)
        MD5XMLWORK=$(md5sum $BASEDIR/$XMLWORK | cut -d' ' -f1)

        if [[ $MD5XMLBAK == $MD5XMLWORK ]]; then
            MD5XML=1
        else
            MD5XML=0
        fi
    fi

    if [[ -f $BASEDIR/backup/$JSONFILE && ! -z $JSONFILE && -f $BASEDIR/$JSONWORK ]]; then
        MD5JSONBAK=$(md5sum $BASEDIR/backup/$JSONFILE | cut -d' ' -f1)
        MD5JSONWORK=$(md5sum $BASEDIR/$JSONWORK | cut -d' ' -f1)

        if [[ $MD5JSONBAK == $MD5JSONWORK ]]; then
            MD5JSON=1
        else
            MD5JSON=0
        fi
    fi
}

trimOldFiles() {
    if checkNumFiles; then
        if [[ $XMLCOUNT -gt $MAXBACKUPS ]]; then
            x=$((XMLCOUNT-MAXBACKUPS))
            for (( c=0; c<$x; c++ )); do
                XMLFILE=$(find $BASEDIR/backup -type f -name "$XMLWORK-*" -printf '%T+ %f\n' | sort | cut -d' ' -f2 | sed -n '1 p')

                rm -rf $BASEDIR/backup/$XMLFILE
            done
        fi

        if [[ $JSONCOUNT -gt $MAXBACKUPS ]]; then
            x=$((JSONCOUNT-MAXBACKUPS))
            for (( c=0; c<$x; c++ )); do
                JSONFILE=$(find $BASEDIR/backup -type f -name "$JSONWORK-*" -printf '%T+ %f\n' | sort | cut -d' ' -f2 | sed -n '1 p')

                rm -rf $BASEDIR/backup/$JSONFILE
            done
        fi
    fi
}

addBackup() {
    if checkMD5; then
        if [[ $MD5XML -eq 1 ]]; then
            :
        else
            if [[ -f $BASEDIR/$XMLWORK ]]; then
                cp $BASEDIR/$XMLWORK $BASEDIR/backup/$XMLWORK-$(date +%m-%d-%Y-%T)
            fi
        fi

        if [[ $MD5JSON -eq 1 ]]; then
            :
        else
            if [[ -f $BASEDIR/$JSONWORK ]]; then
                cp $BASEDIR/$JSONWORK $BASEDIR/backup/$JSONWORK-$(date +%m-%d-%Y-%T)
            fi
        fi
    fi
}

restoreBackup() {
    if checkMD5; then
        if [[ $MD5XML -eq 1 ]]; then
            :
	else
            XMLFILE=$(find $BASEDIR/backup -type f -name "$XMLWORK-*" -printf '%T+ %f\n' | sort -r | cut -d' ' -f2 | sed -n '1 p')

            if [[ -f $BASEDIR/backup/$XMLFILE && ! -z $XMLFILE ]]; then
                cp -f $BASEDIR/backup/$XMLFILE $BASEDIR/$XMLWORK
            fi
        fi

        if [[ $MD5JSON -eq 1 ]]; then
            :
        else
            JSONFILE=$(find $BASEDIR/backup -type f -name "$JSONWORK-*" -printf '%T+ %f\n' | sort -r | cut -d' ' -f2 | sed -n '1 p')

            if [[ -f $BASEDIR/backup/$JSONFILE && ! -z $JSONFILE ]]; then
                cp -f $BASEDIR/backup/$JSONFILE $BASEDIR/$JSONWORK
            fi
        fi
    fi
}

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

        restoreBackup

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

            restoreBackup

            alert "guide2go needs attention"

            exit 0
        fi

        echolog ""
        echolog "----------------------------"
        echolog "[#] - guide2go success - [#]"
        echolog "----------------------------"

        addBackup
        trimOldFiles

        if [[ $DEBUG -eq 1 ]]; then
            alert "guide2go debug log"
        fi

        exit 0
    fi
done
