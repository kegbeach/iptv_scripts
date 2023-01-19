#!/bin/bash

echo "-------------------------------------"
echo "Enter usernames separated by a space:"
echo "-------------------------------------"
echo ""
echo -n "usernames: "

read usernames;

if [[ -z $usernames ]]; then
    echo ""
    echo "Input can't be NULL, exiting..."

    exit 0
else
    for user in $usernames; do
        echo "#EXTINF:-1 tvg-name=\"$user\" tvg-logo=\"https://your.server.com/iptv/icons/chaturbate.png\" group-title=\"Chaturbate\",$user" >> chaturbate.m3u
        echo "pipe:///usr/bin/streamlink --stdout --default-stream best --url https://chaturbate.com/$user" >> chaturbate.m3u
    done

    exit 0
fi
