#!/bin/bash
# Sync static files to docroot/files
SYNC_FOLDERS="core modules profiles themes"
SYNC_EXTENSIONS="js css svg png jpg jpeg ico woff ttf"

function rsync() {

  for DIR in $SYNC_FOLDERS; do
    for EXTENSION in $SYNC_EXTENSIONS; do
      rsync -rm --include "*.$EXTENSION" --include "*/" --exclude "*" $DIR/ docroot/$DIR/
    done
  done
}

rsync
inotifywait core modules profiles themes -m -r -e modify -e create -e delete -o -d && rsync