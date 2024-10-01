#!/bin/sh

MY_VERSION="1.32"
# status_report.sh - Generate a status report about a Linux machine
#
# Last update: November 2, 2020
# (C) Copyright 2005-2020 by Arno van Amersfoort
# Homepage              : http://rocky.eld.leidenuniv.nl/
# Email                 : a r n o v a AT r o c k y DOT e l d DOT l e i d e n u n i v DOT n l
#                         (note: you must remove all spaces and substitute the @ and the . at the proper locations!)
# ----------------------------------------------------------------------------------------------------------------------
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# version 2 as published by the Free Software Foundation.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
# ----------------------------------------------------------------------------------------------------------------------

# Set path
PATH=/usr/local/sbin:/usr/local/bin:/usr/bin:/sbin:/usr/sbin:/bin

# Specify custom (source) script, if used
CUSTOM_SCRIPT="/usr/local/sbin/sr_custom_script"

ALMOST_FULL_PERCENT=97

EOL='
'

human_size()
{
  echo "$1" |awk '{
    SIZE=$1
    TB_SIZE=(SIZE / 1024 / 1024 / 1024 / 1024)
    if (TB_SIZE > 1.0)
    {
      printf("%.2f TiB\n", TB_SIZE)
    }
    else
    {
      GB_SIZE=(SIZE / 1024 / 1024 / 1024)
      if (GB_SIZE > 1.0)
      {
        printf("%.2f GiB\n", GB_SIZE)
      }
      else
      {
        MB_SIZE=(SIZE / 1024 / 1024)
        if (MB_SIZE > 1.0)
        {
          printf("%.2f MiB\n", MB_SIZE)
        }
        else
        {
          KB_SIZE=(SIZE / 1024)
          if (KB_SIZE > 1.0)
          {
            printf("%.2f KiB\n", KB_SIZE)
          }
          else
          {
            printf("%u B\n", SIZE)
          }
        }
      }
    }
  }'
}


check_command()
{
  local path IFS

  IFS=' '
  for cmd in $*; do
    if [ -n "$(which "$cmd" 2>/dev/null)" ]; then
      return 0
    fi
  done

  return 1
}


############
# Mainline #
############
echo "Status report v$MY_VERSION - (C) Copyright 2005-2020 by Arno van Amersfoort"
echo "--------------------------------------------------------------------"

printf "$(curl --silent -4 ifconfig.co) - "
uname -a

[ -e /etc/issue ] && grep -v '^$' /etc/issue
uptime

#echo "$(date +'%b %d') $(uptime)"
#echo ""
#free

#export TERM=vt100; /usr/bin/top -b -n 1 |grep -i '^CPU'
#echo ""

if [ -e /proc/mdstat ]; then
  echo ""
  echo "---------------"
  echo "| RAID status |"
  echo "---------------"
#  if [ -x /sbin/mdadm ]; then
#    /sbin/mdadm --detail --scan 2>&1
#    echo ""
#  fi
  FAIL=0
  DEGRADED=0
  MISMATCH=0
  unset IFS
  while read LINE; do
    printf "%s" "$LINE"
    DEV=""
    if echo "$LINE" |grep -q '[[:blank:]]active[[:blank:]]'; then
      DEV="$(echo "$LINE" |awk '{ print $1 }')"

      printf " (mismatch_cnt=%s)" "$(cat /sys/block/$DEV/md/mismatch_cnt)"
      if [ "$(cat /sys/block/$DEV/md/mismatch_cnt)" != "0" ]; then
        MISMATCH=$(($MISMATCH + 1))
        printf " (WARNING: Unsynchronised (mismatch) blocks!)"
      fi

      if echo "$LINE" |grep -q '\(F\)'; then
        FAIL=$(($FAIL + 1))
        printf " (WARNING: FAILED DISK(S)!)"
      fi

      if echo "$LINE" |grep -q '\(S\)'; then
        printf " (Hotspare(s) available)"
      else
        printf " (NOTE: No hotspare?!)"
      fi
    fi

    if echo "$LINE" |grep -q 'blocks'; then
      if echo "$LINE" |grep -q '_'; then
        DEGRADED=$(($DEGRADED + 1))
        printf " (DEGRADED!!!)"
      fi
    fi

    echo ""
    if [ -n "$DEV" ]; then
      blkid -o full -s LABEL -s PTTYPE -s TYPE -s UUID "/dev/${DEV}" |cut -d' ' -f1 --complement
    fi
  done < /proc/mdstat

  echo ""

  if [ $FAIL -gt 0 ]; then
    echo "***********************************************************"
    echo "** WARNING: $FAIL MD(RAID) array(s) have FAILED disk(s)! **"
    echo "***********************************************************"
    echo ""
  fi

  if [ $DEGRADED -gt 0 ]; then
    echo "************************************************************************"
    echo "** WARNING: $DEGRADED MD(RAID) array(s) are running in degraded mode! **"
    echo "************************************************************************"
    echo ""
  fi

  if [ $MISMATCH -gt 0 ]; then
    echo "*********************************************************************************"
    echo "** WARNING: $MISMATCH MD(RAID) array(s) have unsynchronized (mismatch) blocks! **"
    echo "*********************************************************************************"
    echo ""
  fi
fi


echo ""
echo "---------------------"
echo "| S.M.A.R.T. status |"
echo "---------------------"
if check_command smartctl; then
  IFS=$EOL
  for BLK_DEVICE in /sys/block/*; do
    DEVICE="$(echo "$BLK_DEVICE" |sed s,'^/sys/block/','/dev/',)"
    if [ ! -b "$DEVICE" -o ! -e "${BLK_DEVICE}/device" ]; then
      continue # Ignore this one
    fi

    if echo "$DEVICE" |grep -q -e '/loop[0-9]' -e '/sr[0-9]' -e '/fd[0-9]' -e '/ram[0-9]'; then
      continue
    fi

    echo "$DEVICE: "

    result="$(smartctl -i $DEVICE)"
    retval=$?

    if [ $retval -ne 0 ]; then
      echo "Skipped"
      echo ""
      continue
    fi

    for LINE in $result; do
      KEY="$(echo "$LINE" |cut -d: -f1 |sed s,' *$',,)"
      VAL="$(echo "$LINE" |cut -d: -f1 --complement |sed s,'^ *',,)"

      case "$KEY" in
            "Model Family"*) printf "$VAL ";;
            "Device Model"*) printf "$VAL ";;
           "Serial Number"*) printf "S/N:$VAL ";;
        "Firmware Version"*) printf "F/W:$VAL ";;
           "User Capacity"*) printf "Size:$VAL ";;
      esac
    done
    echo ""

    # Explicity turn on SMART on device & show info:
    smartctl -q silent -s on "$DEVICE"

    printf "$(smartctl -H $DEVICE 2>&1 |grep -v -i -e '^$' -e '^Copyright' -e '^smartctl ' -e 'http:' -e '^=== START' -e '^SMART Status not supported')\n"

    errors_logged=`smartctl -l error "$DEVICE" |grep -i '^Error' |wc -l`
    printf "SMART errors logged: $errors_logged\n"

    for LINE in `smartctl -A $DEVICE`; do
      if echo "$LINE" |grep -q -E '^ *(5|9|10|12|187|188|196|197|198|199) '; then
        #   5 = Reallocated Sectors Count. Non-zero indicates higher failure risk
        #   9 = Power On Hours
        #  10 = Spin Retry Count. An increase of this attribute value is a sign
        #       of problems in the hard disk mechanical subsystem
        #  12 = Power Cycle Count
        # 187 = Reported Uncorrectable Errors
        # 188 = Command timeout. Should be zero
        # 196 = Reallocation Event Count
        # 197 = Current Pending Sector Count. Should be zero
        # 198 = (Offline) Uncorrectable Sector Count. A rise in the value of this
        #       attribute indicates defects of the disk surface and/or problems in the mechanical subsystem
        # 199 = The total count of uncorrectable errors when reading/writing a sector. A rise in the value
        #       of this attribute indicates defects of the disk surface and/or problems in the mechanical
        #       subsystem
        RAW=`echo "$LINE" |awk '{ print $10 }'`
        if [ $RAW -ne 0 ]; then
          echo "$LINE" |awk '{ printf "%s(%s): %s\n",$2,$1,$10 }'
        fi
      fi
    done

    echo ""
  done
else
  echo "NOTE: smartctl binary not found (smartmontools not installed?)"
fi


if check_command btrfs; then
  echo ""
  echo "--------------"
  echo "| BTRFS info |"
  echo "--------------"
  IFS=$EOL
  while read LINE; do
    FS_TYPE="$(echo "$LINE" |cut -d' ' -f3)"
    if [ "$FS_TYPE" = "btrfs" ]; then
      MPATH="$(echo "$LINE" |cut -d' ' -f1)"

      btrfs device stats "$MPATH" # | grep -vE ' 0$'
      echo ""
    fi
  done < /etc/mtab
fi

echo ""
echo "------------------"
echo "| Diskspace info |"
echo "------------------"
DF_WARNING=0
IFS=$EOL
for LINE in `df -h -T -P --exclude-type=devtmpfs --sync`; do
  printf "%s" "$LINE"
  if echo "$LINE" |grep -q -v "Use%"; then
    free_perc=`echo "$LINE" |awk '{ print $6 }' |sed s,'%',,`
    if [ $free_perc -ge $ALMOST_FULL_PERCENT ]; then
      echo ' (At or near max. capacity!)'
      DF_WARNING=1
    fi
  fi
  echo ""
done
if [ $DF_WARNING -eq 1 ]; then
  echo "***********************************************************************"
  echo "** WARNING: One or more filesystems are at or near maximum capacity! **"
  echo "***********************************************************************"
  echo ""
fi


echo ""
echo "--------------"
echo "| Kernel log |"
echo "--------------"
KERNEL_LOG="kwarnings.log"
if [ ! -f "/var/log/$KERNEL_LOG" ]; then
  echo "NOTE: /var/log/$KERNEL_LOG does NOT exist. Consider adding a line like"
  echo "      'kern.warn    /var/log/$KERNEL_LOG' to your (r)syslog.conf"
else
  cat "/var/log/$KERNEL_LOG.0" >"/tmp/$KERNEL_LOG" 2>/dev/null
  cat "/var/log/$KERNEL_LOG" >>"/tmp/$KERNEL_LOG"
  filesize=$(ls -l "/tmp/$KERNEL_LOG" |awk '{ print $5 }')

  if [ $filesize -eq 0 ]; then
    echo "(Empty)"
  else
    cat "/tmp/$KERNEL_LOG"
  fi

  # Remove temp file
  rm -f "/tmp/$KERNEL_LOG"

  # Remove log files
  rm -f "/var/log/$KERNEL_LOG.1" &&
  mv "/var/log/$KERNEL_LOG.0" "/var/log/$KERNEL_LOG.1" 2>/dev/null &&
  mv "/var/log/$KERNEL_LOG" "/var/log/$KERNEL_LOG.0" 2>/dev/null &&
  printf "" >|"/var/log/$KERNEL_LOG"
fi


echo ""
echo "------------------------"
echo "| Available OS updates |"
echo "------------------------"
if check_command apt-get; then
  apt-get update -q=2 2>&1
  echo "** Testing what packages could be upgraded: **"
  apt-get upgrade -u --download-only -y -q -V 2>&1
elif check_command yum >/dev/null 2>&1; then
  echo "** Checking for important yum (security) updates"
  yum list-security |grep -i -E 'important'
else
  echo "NOTE: apt-get or yum binary not found (not installed?!)"
fi
echo ""

if [ -d /var/log/fsck ]; then
  echo ""
  echo "------------------"
  echo "| Fsck boot logs |"
  echo "------------------"
  cat /var/log/fsck/*
  echo ""
fi


echo ""
echo "--------------------"
echo "| Hardware sensors |"
echo "--------------------"
if check_command sensors; then
  # Re-read configuration:
  if [ -n "$(sensors -s 2>&1)" ]; then
    echo "** WARNING: Unable to read hardware sensors (/etc/sensors.conf incorrect/missing?) **"
  else
    result=`sensors 2>&1`
    printf "%s\n" "$result"
    if printf "%s\n" "$result" |grep -q "ALARM"; then
      echo ""
      echo "** WARNING: One or more sensors show ALARM! **"
    fi
  fi
else
  echo "NOTE: sensors binary not found (lm-sensors not installed?)"
fi
echo ""


if check_command clamscan; then
  echo ""
  echo "-----------------"
  echo "| ClamAV status |"
  echo "-----------------"

  # Show clam version:
  clamscan --version 2>&1

  # Dummy run to see whether we're not out-of-date:
  echo "" |clamscan --quiet - 2>&1
  echo ""
fi


if [ -x "$CUSTOM_SCRIPT" ]; then
 . "$CUSTOM_SCRIPT"
fi

