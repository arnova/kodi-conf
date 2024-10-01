#!/bin/sh

cmake --build . -- VERBOSE=1 -j$(getconf _NPROCESSORS_ONLN)

