#!/bin/bash

EOL='
'

if [ -z "$1" ]; then
  XBMC_LINUX_SRC="."
else
  XBMC_LINUX_SRC="$1"
fi

show_rev()
{
  result="$(svn log -r $1 |sed '1,3d' |grep -v -e "^$" -e "^-----" |sed s/'$'/''/)"
  if [ -n "$result" ]; then
    printf "%s:" "$1"
    echo "$result" |while IFS=$EOL read LINE; do printf " %s" "$LINE"; done
    printf "\n"
  fi
}

cd "$XBMC_LINUX_SRC"
REV_LIST="" 
unset IFS
while read LINE; do
  IFS=','
  for ITEM in $LINE; do
    if echo "$ITEM" |grep -q -e '-'; then
      start_rev=$(echo $ITEM |cut -f1 -d-)
      end_rev=$(echo $ITEM |cut -f2 -d-)
      unset IFS
      for rev in `seq $start_rev $end_rev`; do
        REV_LIST="$rev $REV_LIST"
      done
    else
      REV_LIST="$ITEM $REV_LIST"
    fi
  done
done

unset IFS
for rev in $REV_LIST; do
  show_rev $rev
done


