#!/bin/sh

LOCAL_PATH="/mnt/archive/backup"
REMOTE_PATH="arnova@nas:/data/backup/dexter/snapshots/"

rsync -av --progress --hard-links "$LOCAL_PATH/" "$REMOTE_PATH/"

