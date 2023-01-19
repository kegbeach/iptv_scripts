#!/bin/bash
#
# Script to modify stream URL's
#
# Set $DESTINATION to the playlist directory
# Set $FILE to the original playlist
# Set $FILENEW to the modified playlist
#

DEBUG=0
DESTINATION=/path/to/playlists
FILE=${DESTINATION}/playlist-original.m3u
FILENEW=${DESTINATION}/playlist.m3u

if [ -f "$FILE" ]; then
    echo "Copying $FILE to $FILENEW"
    cp -f $FILE $FILENEW

    if [ -f "$FILENEW" ]; then
        echo ""
        echo "Modifying stream URL's in file $FILENEW"

        sed -i '/your.server.com/s/^/pipe:\/\/\/usr\/bin\/ffmpeg -hide_banner -loglevel error -i /' $FILENEW
        sed -i '/your.server.com/s/$/ -c:v copy -c:a copy -c:s copy -f mpegts pipe:1/' $FILENEW
    else
        echo "$FILENEW was not created successfully, exiting..."

        exit 0
    fi

    echo ""
    echo "Done"

    exit 0
else
    echo "$FILE does not exist, exiting..."

    exit 0
fi
