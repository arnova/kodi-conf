#!/bin/sh

if [ -z "$1" ]; then
  echo "ERROR: Provide path to GIT repo!"
  exit 1
fi

#cmake $1 -DCMAKE_INSTALL_PREFIX=/usr/local -DX11_RENDER_SYSTEM=gl
cmake $1 -DCMAKE_INSTALL_PREFIX=/usr/local -DCORE_PLATFORM_NAME=x11 -DAPP_RENDER_SYSTEM=gl

 
