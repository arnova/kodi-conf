#!/bin/bash
#
# set ACPI Wakeup alarm
# safe_margin - minutes to start up system before the earliest timer
# script does not check if recording is in progress
#
#
echo 1 > /timer

# bootup system 60 sec. before timer
safe_margin=60

# modify if different location for tvheadend dvr/log path
cd ~hts/.hts/tvheadend/dvr/log

######################
start_date=0
stop_date=0
current_date=`date +%s`
for i in $( ls ); do
  tmp_start=`cat $i | grep '"start":' | cut -f 2 -d " " | cut -f 1 -d ","`
  tmp_stop=`cat $i | grep '"stop":' | cut -f 2 -d " " | cut -f 1 -d ","`

  echo "^$tmp_start*$tmp_stop!"
  # check for outdated timer
  if [ $((tmp_stop)) -gt $((current_date)) -a $((tmp_start)) -gt $((current_date)) ]; then

    # take lower value (tmp_start or start_date)
    if [ $((start_date)) -eq 0 -o $((tmp_start)) -lt $((start_date)) ]; then
      start_date=$tmp_start
      stop_date=$tmp_stop
    fi
  fi
done

wake_date=$((start_date-safe_margin))
echo $start date >> /timerecho $start_date >> /timer
echo $wake_date >> /timer

set_alarm="$(cat /sys/class/rtc/rtc0/wakealarm)"

if [ -n "$set_alarm" -a $set_alarm -lt $wake_date ]; then
  exit # Set timer lower than new one
fi

# set up wakeup alarm
if [ $((start_date)) -ne 0 ]; then
  echo 2 >> /timer
  echo 0 > /sys/class/rtc/rtc0/wakealarm
  echo $wake_date > /sys/class/rtc/rtc0/wakealarm
fi

