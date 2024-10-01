#!/bin/sh

TVH_LOG_PATH="/home/hts/.hts/tvheadend/dvr/log"

IFS='
'

for LOG_FILE in "$TVH_LOG_PATH/"*; do
  DVR_FILES="$(grep "\"filename\":" "$LOG_FILE" |sed -e 's,.*\"filename\": \",,' -e 's/\",$//')"

  if [ -n "$DVR_FILES" ]; then
    RM_LOG=1
    # Log files can hold multiple recordings
    for DVR_FN in $DVR_FILES; do
      if [ -e "$DVR_FN" ]; then
        RM_LOG=0
      fi
    done
    if [ $RM_LOG -eq 1 ]; then
      echo ">>>Removing: $LOG_FILE"
      rm -f "$LOG_FILE"
    fi
  fi
done

