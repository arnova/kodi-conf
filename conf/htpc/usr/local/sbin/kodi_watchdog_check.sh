#!/bin/sh

POWER_OFF_FILE="/home/kodi/.kodi/temp/.pbc_poweroff"
WD_FILE="/home/kodi/.kodi/temp/.watchdog"
SLEEP_TIME=90

echo "Checking watchdog file every $SLEEP_TIME seconds"

WD_TIME_LAST=""
while true; do
  # Check every $SLEEP_TIME seconds
  sleep $SLEEP_TIME

  WD_TIME_CUR="$(cat "$WD_FILE" 2>/dev/null)"
  echo "$(date +'%Y-%m-%d %H:%M') LAST=$WD_TIME_LAST CUR=$WD_TIME_CUR"

  if [ -n "$WD_TIME_CUR" -a -n "$WD_TIME_LAST" ]; then
    if [ "$WD_TIME_CUR" = "$WD_TIME_LAST" ]; then
      echo "Kodi lockup detected, restarting"
      WD_TIME_LAST=""
#      service kodi stop
      systemctl stop kodi.service
      killall kodi.bin

      sleep 5

#      touch "$POWER_OFF_FILE"
#      chown kodi:kodi "$POWER_OFF_FILE"
#      service kodi start
      systemctl start kodi.service
    fi
  fi

  WD_TIME_LAST="$WD_TIME_CUR"
done

