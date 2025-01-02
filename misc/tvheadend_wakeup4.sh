#!/bin/bash
# https://tvheadend.org/d/4956-auto-shutdown-and-wakeup-for-scheduled-recordings
# shutdown vs suspend doesn't create wakeup data for correct re-sleep check

TVHINSTU=hts
TVHWUSER=sleepuser
TVHWPASS=sleeppass
TVHIPADD=127.0.0.1
TVHHPORT=9981

#/etc/sudoers.d/hts
# hts user can shutdown with sudo permission
#hts  ALL= NOPASSWD: /bin/systemctl poweroff,/bin/systemctl halt,/bin/systemctl reboot,/bin/systemctl suspend,/usr/sbin/rtcwake,/bin/journalctl

#sudo crontab -u hts -e 
#*/10 * * * * /home/hts/shutdown_after_rec.sh

#verify suspend compatibility and adjust remove/reload some kernel modules before after suspend
#https://askubuntu.com/questions/226278/run-script-on-wakeup
#/lib/systemd/system-sleep/yoursleepscript

#test system rtcwake abilities
#sudo apt-get install utils-linux
#sudo rtcwake -s 240 -m no #will set a wakeup time 4 minutes from now
#timedatectl #shows local/rtc time
#sudo rtcwake -m show #shows the bios time for waking up -u -l utc local -a auto=default
#sudo systemctl suspend;exit #test and see if the system wakes in 4 minutes
#sudo rtcwake -m no -t $(date +%s -d 'today 19:45')
#sudo rtcwake -m show #check time what has been set if it correlates rtc to utc

#test system wakeonlan abilities
#cat /proc/acpi/wakeup
#sudo ethtool eth0 #pumb if the 'g' is missing it won't wake on magic packet!!! 
#sudo ethtool -set eth0 wol g #sets the 'g' as a condition to wake from lan

#tvheadend sleep user allow / set checkboxes video recording "manage all" to detect recordings
#ok recording realtime takes intro/ending padding in account
#ok rtcwake event takes padding&warmup in account

export PATH=/home/$TVHINSTU:/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games

WAKEDATE=$(sudo journalctl -b 0 -o short-iso MESSAGE="PM: Finishing wakeup." | tail -1 | cut -d" " -f1 | sed -e 's/+.*//')
DATEWAKE=$(date -d"$WAKEDATE" +%s )
DATENOW=$(date +%s)

A=$(($DATENOW-$DATEWAKE))
B=540 #seconds 9 minutes
if (( A < B));
    then
        echo "$TVHINSTU user last suspend request was $A < 540 seconds ago skip suspend" | logger
        exit 0
    else
        echo "$TVHINSTU user last suspend request was $A > 540 seconds ago continue suspend" | logger
##
## Check for active connections, except those from the local machine.
##
if [ "`curl -s http://$TVHWUSER:$TVHWPASS@$TVHIPADD:$TVHHPORT/api/status/connections | tr } '\n' | grep peer | grep -v 127.0.0.1`" != "" ]; then
        echo "$TVHINSTU user detects active TvHeadend connections skip suspend" | logger
        exit 0
fi

##
## Check for active recordings
##
curl -s "http://$TVHWUSER:$TVHWPASS@$TVHIPADD:$TVHHPORT/api/dvr/entry/grid_upcoming?limit=99999" | grep -q '"sched_status":"recording",'
match=$?
if [ "$match" != "0" ]; then
        ##
        ## Not recording, can we shutdown?
        ##
        next_recording=`curl -s "http://$TVHWUSER:$TVHWPASS@$TVHIPADD:$TVHHPORT/api/dvr/entry/grid_upcoming?limit=99999" | tr , '\n' | grep start_real | sed "s/.*start_real.:\([0-9]*\).*/\1/" | sort -n | head -1`

        ## 
        ## If there are no recordings we should wake up tomorrow 
        ## everyday wakeup for epg index?
        if [ "$next_recording" = "" ]; then
          echo "$TVHINSTU user detects no TvHeadend scheduled recordings, set EPG update wake" | logger
          next_recording=`date --date "tomorrow" +%s`
        fi

        gap=$(($next_recording-`date +%s`))

        echo Next recording: `date -d "1970-01-01 $next_recording sec" "+%F %H:%M:%S" -u` | logger

        if [ $gap -gt 2400 ]; then
                ##
                ## The gap to the next recording is more than 40 minutes, so lets shutdown
                ##

                ##
                ## Set the wakeup for 2 minutes before the next recording
                ##
                wakeup=$((next_recording-120))
                wakeup_date=`date -d "1970-01-01 $wakeup sec" "+%F %H:%M:%S"`
                echo "$TVHINSTU user sets wake up for next TvHeadend event at: $wakeup_date" | logger
                /usr/bin/sudo /usr/sbin/rtcwake -m no -t $wakeup
                ##
                ## Now shutdown
                ##
                /usr/bin/sudo /bin/systemctl suspend #poweroff
        fi
else
        ##
        ## Still recording, log the attempt and do nothing.
        ##
        echo "$TVHINSTU user detects active TvHeadend recording(s) skip suspend" | logger
fi
        #exit 0
fi

