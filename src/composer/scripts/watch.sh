#!/bin/sh
# (c) Wolfgang Ziegler // fago
#
# Inotify script to trigger a command on file changes.
#
# The script triggers the command as soon as a file event occurs. Events
# occurring during command execution are aggregated and trigger a single command
# execution only.
#
# Usage example: Trigger rsync for synchronizing file changes.
# ./watch.sh rsync -Cra --out-format='[%t]--%n' --delete SOURCE TARGET
#
# ./watch.sh rsync -Cra --out-format='[%t]--%n' --include core \
#  --WATCH_EXCLUDE=sites/default/files --delete ../web/ vagrant@d8.local:/var/www

######### Configuration #########

EVENTS="CREATE,DELETE,MOVED_FROM,MOVED_TO,MODIFY"
COMMAND="$@"

## The directory to watch.
if [ -z "$WATCH_DIR" ]; then
  WATCH_DIR="core modules profiles themes"
fi

## WATCH_EXCLUDE Git and temporary files from PHPstorm from watching.
if [ -z "$WATCH_EXCLUDE" ]; then
  WATCH_EXCLUDE='(\.git|___jb_)'
fi

##################################

if [ -z "$1" ]; then
 echo "Usage: $0 Command"
 exit 1;
fi

##
## Setup pipes. For usage with read we need to assign them to file descriptors.
##
RUN=$(mktemp -u)
mkfifo "$RUN"
exec 3<>$RUN

RESULT=$(mktemp -u)
mkfifo "$RESULT"
exec 4<>$RESULT

clean_up () {
  ## Cleanup pipes.
  rm $RUN
  rm $RESULT
}

## Execute "clean_up" on exit.
trap "clean_up" EXIT


##
## Run inotifywait in a loop that is not blocked on command execution and ignore
## irrelevant events.
##

inotifywait -m -q -r -e $EVENTS --exclude $WATCH_EXCLUDE --format '%w%f' $WATCH_DIR | \
  while read FILE
  do
    ($($COMMAND $FILE))
done
