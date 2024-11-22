#!/bin/sh

if systemctl is-active --quiet kodi.service; then
  systemctl restart kodi.service
elif systemctl is-active --quiet kodi-gbm.service; then
  systemctl restart kodi-gbm.service
elif systemctl is-active --quiet kodi-flatpack-gbm.service; then
  systemctl restart kodi-flatpack-gbm.service
fi

