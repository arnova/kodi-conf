#!/bin/sh

cat /dev/input/event2 |while read LINE; do
  print "Button pressed"
done

