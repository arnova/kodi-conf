#!/bin/sh

export PATH=/home/tvh/bin:/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games

##
## Check for active connections, except those from the local machine.
##
if [ "`curl -s http://script:script@localhost:9981/api/status/connections | tr } '\n' | grep peer | grep -v 127.0.0.1`" != "" ]; then
        echo "Not shutting down due to active connections" | logger
        exit 0
fi

##
## Check for active recordings
##
curl -s "http://script:script@localhost:9981/api/dvr/entry/grid_upcoming?limit=99999" | grep -q '"sched_status":"recording",'
match=$?
if [ "$match" != "0" ]; then
        ##
        ## Not recording, can we shutdown?
        ##
        next_recording=`curl -s "http://script:script@localhost:9981/api/dvr/entry/grid_upcoming?limit=99999" | tr , '\n' | grep start_real | sed "s/.*start_real.:\([0-9]*\).*/\1/" | sort -n | head -1`

        ## 
        ## If there are no recordings we should wake up tomorrow
        ##
        if [ "$next_recording" = "" ]; then
          echo "No recordings... wake up tomorrow...." | logger
          next_recording=`date --date "tomorrow" +%s`
        fi


        gap=$(($next_recording-`date +%s`))
        
        echo Next recording: `date -d "1970-01-01 $next_recording sec" "+%F %H:%M:%S" -u` | logger

        if [ $gap -gt 900 ]; then
                ##
                ## The gap to the next recording is more than 15 minutes, so lets shutdown
                ##
                
                ##
                ## Set the wakeup for 10 minutes before the next recording
                ##
                wakeup=$((next_recording-600))
                wakeup_date=`date -d "1970-01-01 $wakeup sec" "+%F %H:%M:%S"`
                echo "Waking up at: $wakeup_date" | logger
                /usr/bin/sudo /usr/sbin/rtcwake -m no -t $wakeup
                ##
                ## Now shutdown
                ##
                /usr/bin/sudo /sbin/shutdown -P now
        fi
else
        ##
        ## Still recording, log the attempt and do nothing.
        ##
        echo "Still recording. Not shutting down." | logger
fi

