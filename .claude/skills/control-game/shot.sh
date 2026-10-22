#!/bin/bash
# usage: shot.sh <out.png>   focus WoW, wait, screenshot the whole screen
osascript -e 'tell application "System Events" to set frontmost of first process whose name is "World of Warcraft" to true' >/dev/null
sleep 0.5
screencapture -x "$1"
