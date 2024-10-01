#!/bin/sh

MY_VERSION="1.01"
# ----------------------------------------------------------------------------------------------------------------------
# auto_shutdown.sh - Automatic shutdown script
# Last update: March 17, 2019
# (C) Copyright 2015-2019 by Arno van Amersfoort
# Homepage              : http://rocky.eld.leidenuniv.nl/
# Email                 : a r n o v a AT r o c k y DOT e l d DOT l e i d e n u n i v DOT n l
#                         (note: you must remove all spaces and substitute the @ and the . at the proper locations!)
# ----------------------------------------------------------------------------------------------------------------------
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# version 2 as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
# ----------------------------------------------------------------------------------------------------------------------

CONF_FILE="/etc/auto_shutdown.conf"
VERBOSE=0
BACKGROUND=0

EOL='
'

log_line()
{
  DATE=`LC_ALL=C date +'%b %d %H:%M:%S'`

  printf "$DATE - %s\n" "$1"
#  printf "$DATE - %s\n" "$1" >> "$LOG_FILE"
}


log_error_line()
{
  DATE=`LC_ALL=C date +'%b %d %H:%M:%S'`

  printf "$DATE - %s\n" "$1" >&2
#  printf "$DATE - %s\n" "$1" >> "$LOG_FILE"
}


background_process()
{
  log_line "Starting background thread and waiting for new files..."

  CHECK_COUNT=0
  while true; do
    # Check for active hdds
    HDD_ACTIVE=0
    if [ -n "$CHECK_HDD" ]; then
      IFS=' ,'
      for HDD in $CHECK_HDD; do
        result=`hdparm -C "$HDD"`
        if echo "$result" |grep -q -i 'state.*active'; then
          HDD_ACTIVE=1
          if [ $VERBOSE -eq 1 ]; then
            log_line "HDD $HDD:"
            log_line "$(echo "$result" |grep -i 'state')"
            log_line ""
          fi
        fi
      done
    fi
    if [ $HDD_ACTIVE -eq 0 -a $VERBOSE -eq 1 ]; then
      log_line "No active HDDs detected"
    fi

    # Check for active hdds
    PROC_ACTIVE=0
    if [ -n "$CHECK_PROCESS" ]; then
      ps_list="$(ps -e --no-headers -o "%p %u %a")"
      IFS=' ,'
      for PROC in $CHECK_PROCESS; do
        if printf "%s\n" "$ps_list" |grep -E -i -q "$PROC"; then
          PROC_ACTIVE=1
          log_line "Process active:"
          log_line "$(printf "%s\n" "$ps_list" |grep -E -i "$PROC")"
          log_line ""
        fi
      done
    fi
    if [ $PROC_ACTIVE -eq 0 -a $VERBOSE -eq 1 ]; then
      log_line "No active process(es) detected"
    fi

    # Check for active tcp connections
    NET_ACTIVE=0
    if [ "$CHECK_NETWORK" = "1" ]; then
      IFS=' '
#      for x in `seq 1 $NET_RECHECK`; do
        IFS=$EOL
        FIRST=1
        for LINE in `netstat -ntu |grep '[[:blank:]]ESTABLISHED'`; do
          # Skip empty lines
          if [ -z "$LINE" ]; then
            continue
          fi

          SOURCE="$(echo "$LINE" |awk '{ print $4 }')"
          TARGET="$(echo "$LINE" |awk '{ print $5 }')"
          SOURCE_IP="$(echo "$SOURCE" |cut -d: -f1)"
          SOURCE_PORT="$(echo "$SOURCE" |cut -d: -f2)"
          TARGET_IP="$(echo "$TARGET" |cut -d: -f1)"
          TARGET_PORT="$(echo "$TARGET" |cut -d: -f2)"

          if [ -n "$INCLUDE_IPS" ] && ! echo "$INCLUDE_IPS" |grep -q -E "( |,|;|^)(${SOURCE_IP}|${TARGET_IP})( |,|;|$)"; then
            continue
          fi

          if [ -n "$EXCLUDE_IPS" ] && echo "$EXCLUDE_IPS" |grep -q -E "( |,|;|^)(${SOURCE_IP}|${TARGET_IP})( |,|;|$)"; then
            continue
          fi

          if [ -n "$INCLUDE_PORTS" ] && ! echo "$INCLUDE_PORTS" |grep -q -E "( |,|;|^)(${SOURCE_PORT})( |,|;|$)"; then
            continue
          fi

          if [ -n "$EXCLUDE_PORTS" ] && echo "$EXCLUDE_PORTS" |grep -q -E "( |,|;|^)(${SOURCE_PORT})( |,|;|$)"; then
            continue
          fi

          # Check whether host is actually up and it's not a dead connection. FIXME: This doesn't work for external hosts
          if ping -c 1 -w 3 "$TARGET_IP" >/dev/null 2>&1; then
            NET_ACTIVE=1

            if [ $FIRST -eq 1 ]; then
              log_line "Network connections active:"
              FIRST=0
            fi
            log_line "$LINE"
          fi
#        done
      done

      if [ $VERBOSE -eq 1 ]; then
        if [ $NET_ACTIVE -eq 0 ]; then
          log_line "No active network connections"
        fi
        log_line ""
      fi
    fi

    if [ $HDD_ACTIVE -eq 1 -o $NET_ACTIVE -eq 1 -o $PROC_ACTIVE -eq 1 ]; then
      CHECK_COUNT=0
    else
      CHECK_COUNT=$((CHECK_COUNT + 1))
      if [ $CHECK_COUNT -ge $CHECK_AMOUNT ]; then
        if [ -n "$SHUTDOWN_ACTION" ]; then
          "$SHUTDOWN_ACTION"
        else
          /sbin/poweroff
        fi
      fi
    fi

    if [ $VERBOSE -eq 1 ]; then
      log_line "Count is $CHECK_COUNT (threshold = $CHECK_AMOUNT). Sleeping $CHECK_TIME minutes"
    fi

    sleep $((CHECK_TIME * 60))

    if [ $VERBOSE -eq 1 ]; then
      log_line "*********************************************************************"
    fi
  done
}


sanity_check()
{
  if [ -z "$CHECK_TIME" -o -z "$CHECK_AMOUNT" ]; then
    echo "ERROR: CHECK_TIME and/or CHECK_AMOUNT are not specified in the config file!" >&2
    exit 1
  fi
}


show_help()
{
  echo "Usage: psnapshot-cleanup.sh [options]" >&2
  echo "" >&2
  echo "Options:" >&2
  echo "--help|-h                   - Print this help" >&2
  echo "--background|-b             - Run in background process (daemonised)" >&2
  echo "--verbose                   - Be verbose with displaying info" >&2
  echo "--conf|-c={config_file}     - Specify alternate configuration file (default=~/.psnapshot.conf)" >&2
  echo ""
}


process_commandline_and_load_conf()
{
  # Set environment variables to default
  OPT_VERBOSE=0
  OPT_CONF_FILE=""

  # Check arguments
  while [ -n "$1" ]; do
    ARG="$1"
    ARGNAME=`echo "$ARG" |cut -d= -f1`
    ARGVAL=`echo "$ARG" |cut -d= -f2 -s`

    case "$ARGNAME" in
              --conf|-c) if [ -z "$ARGVAL" ]; then
                           echo "ERROR: Bad command syntax with argument \"$ARG\"" >&2
                           show_help
                           exit 1
                         else
                           OPT_CONF_FILE="$ARGVAL"
                         fi
                         ;;
        --background|-b) BACKGROUND=1;;
           --verbose|-v) OPT_VERBOSE=1;;
              --help|-h) show_help
                         exit 0
                         ;;
                     --) shift
                         # Check for remaining arguments
                         if [ -n "$*" ]; then
                           if [ -z "$OPT_CONF_FILE" ]; then
                             OPT_CONF_FILE="$*"
                           else
                             echo "ERROR: Bad command syntax with argument \"$*\"" >&2
                             show_help
                             exit 1
                           fi
                         fi
                         break # We're done
                         ;;
                     -*) echo "ERROR: Bad argument \"$ARG\"" >&2
                         show_help
                         exit 1
                         ;;
                      *) if [ -z "$OPT_CONF_FILE" ]; then
                           OPT_CONF_FILE="$ARG"
                         else
                           echo "ERROR: Bad command syntax with argument \"$ARG\"" >&2
                           show_help
                           exit 1
                         fi
                         ;;
    esac

    shift # Next argument
  done

  # Fallback to default in case it's not specified
  if [ -n "$OPT_CONF_FILE" ]; then
    CONF_FILE="$OPT_CONF_FILE"
  fi

  if [ -z "$CONF_FILE" -o ! -e "$CONF_FILE" ]; then
    echo "ERROR: Missing config file ($CONF_FILE)!" >&2
    echo "" >&2
    exit 1
  fi

  # Source config file
  . "$CONF_FILE"

  # Special handling for verbose
  if [ "$VERBOSE" != "1" ]; then
    VERBOSE="$OPT_VERBOSE"
  fi
}


# Mainline
##########
echo "auto_shutdown.sh v$MY_VERSION - (C) Copyright 2015-2019 by Arno van Amersfoort"
echo ""

process_commandline_and_load_conf $*

sanity_check

if [ $BACKGROUND -eq 1 ]; then
  background_process &
else
  background_process
fi
