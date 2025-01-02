#!/bin/bash

# USER, PASS and HOST needs to be in config file only readable to root
. /etc/autoff.conf

logit()
{
    # add --stderr to output the message to standard error as well as to the
    # system log
    logger --priority local0.notice --tag autoff -- $*
    return 0
}

IsBusy()
{
    # check for active tvh connections
    TVHCONNS=$(curl --silent --show-error --digest --user "${USER}:${PASS}" \
    "http://${HOST}:9981/api/status/connections" | jq ".totalCount")
    if [ $TVHCONNS -gt 0 ]; then
        logit "${TVHCONNS} tvh connection(s) found"
        return 1
    fi

    # check for active tvh subscriptions
    TVHSUBS=$(curl --silent --show-error --digest --user "${USER}:${PASS}" \
    "http://${HOST}:9981/api/status/subscriptions" | jq ".totalCount")
    if [ $TVHSUBS -gt 0 ]; then
        logit "${TVHSUBS} tvh substription(s) found"
        return 1
    fi

    # check for running comskip processes
    CSPROCS=$(ps --no-headers -C comskip | wc --lines)
    if [ $CSPROCS -gt 0 ]; then
        logit "${CSPROCS} comskip processe(s) found"
        return 1
    fi

    # check for established ssh connections
    IP=$(hostname --ip-address)
    SSHCONNS=$(LANG=C netstat --tcp --numeric | grep "${IP}:22" | wc --lines)
    if [ $SSHCONNS -gt 0 ]; then
        logit "${SSHCONNS} ssh connection(s) found"
        return 1
    fi

    # check for logged in users
    USERS=$(who | wc --lines)
    if [ $USERS -gt 0 ]; then
        logit "$USERS logged in user(s) found"
        return 1
    fi

    # idle
    logit "system is idle"
    return 0
}

IsBusy
BUSY=$?
if [ $BUSY -eq 0 ]; then
    # get start time for next recording
    NEXTREC=$(curl --silent --show-error --digest --user "${USER}:${PASS}" \
    --data-urlencode "limit=999" \
    "http://${HOST}:9981/api/dvr/entry/grid_upcoming" | \
    jq "[ .entries[] | {start_real,status} | \
    select(.status!=\"Invalid\") ] | min_by(.start_real) | .start_real")
    if [ "$NEXTREC" == "null" ]; then
        logit "no planned recording found"
    else
        logit "next recording time: $(date --date=@${NEXTREC})"
    fi

    # set wakeup time
    if [ "$NEXTREC" == "null" ] || \
        [ $NEXTREC -gt $(($(date +%s) + 86400)) ]; then
        WAKEUP=$(date --date='02:00 tomorrow' +%s)
        logit "no planned recording in the next 24 hours found"
        logit "wakelarm set to $(date --date=@$WAKEUP)"
        echo 0 > /sys/class/rtc/rtc0/wakealarm
        echo $WAKEUP > /sys/class/rtc/rtc0/wakealarm
    elif [ $NEXTREC -lt $(date +%s) ]; then
        logit "error, next planned recording seems to be in the past"
        exit 1
    elif [ $NEXTREC -lt $(($(date +%s) + 1800)) ]; then
        logit "next planned recording starts in less than 30 minutes"
        logit "shutdown aborted"
        exit 0
    else
        WAKEUP=$(($NEXTREC - 600))
        logit "wakelarm set to $(date --date=@$WAKEUP)"
        echo 0 > /sys/class/rtc/rtc0/wakealarm
        echo $WAKEUP > /sys/class/rtc/rtc0/wakealarm
    fi

    # shutdown
    logit "initiate shutdown"
    /sbin/halt -p
    exit 0
else
    # aborted
    logit "shutdown aborted"
    exit 0
fi

logit "error"
exit 1