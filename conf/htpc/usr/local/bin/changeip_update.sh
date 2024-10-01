#!/bin/sh

MY_VERSION="1.00-BETA3"
# ----------------------------------------------------------------------------------------------------------------------
# changeip_update.sh - Script to update changeip.org dynamic IP hostname
# Last update: June 2, 2017
# (C) Copyright 2015-2017 by Arno van Amersfoort
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

CONF_FILE="/etc/changeip_update.conf"


# Mainline
##########
echo "changeip_update.sh v$MY_VERSION - (C) Copyright 2015-2017 by Arno van Amersfoort"
echo ""

if [ -z "$CONF_FILE" -o ! -e "$CONF_FILE" ]; then
  echo "ERROR: Missing config file ($CONF_FILE)!" >&2
  echo "" >&2
  exit 1
fi

# Source config file
. "$CONF_FILE"

if [ -z "$CIP_USERNAME" -o -z "$CIP_PASSWORD" -o -z "$CIP_HOSTNAME" ]; then
  echo "ERROR: CIP_USERNAME, CIP_PASSWORD and/or CIP_HOSTNAME are not specified in the config file!" >&2
  exit 1
fi

if [ "$1" = "-v" -o "$1" = "--verbose" ]; then
  VERBOSE=1
else
  VERBOSE=0
fi

IFS=' ,'
for cip_host in $CIP_HOSTNAME; do
  printf "* Updating changeip.com dynamic host: $cip_host... "

  if [ "$VERBOSE" = "1" ]; then
    curl -v --insecure "https://nic.changeip.com/nic/update?u=${CIP_USERNAME}&p=${CIP_PASSWORD}&hostname=${cip_host}"
  else
    curl --insecure "https://nic.changeip.com/nic/update?u=${CIP_USERNAME}&p=${CIP_PASSWORD}&hostname=${cip_host}"
  fi

  echo ""
done

echo ""

