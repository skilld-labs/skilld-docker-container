#!/bin/sh
  SYNC_FOLDERS="core modules profiles themes"
  SYNC_EXTENSIONS="js css svg png jpg jpeg ico woff ttf"
if [ ! -z "$1" ]; then
  SYNC_FOLDERS=$(dirname $1 | cut -c3-0)
  SYNC_FOLDERS=$(dirname $1 | cut -c3-0)
fi
for DIR in $SYNC_FOLDERS; do
  for EXTENSION in $SYNC_EXTENSIONS; do
    rsync -rm --ignore-existing --recursive --delete $DIR/ docroot/$DIR/
    rsync -rm --include "*.$EXTENSION" --include "*/" --exclude "*" $DIR/ docroot/$DIR/
  done
done
