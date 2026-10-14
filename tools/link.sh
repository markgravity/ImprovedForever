#!/bin/sh
# Links every addon folder of the repo into a game's AddOns folder, so the
# game loads the working copy (/reload after an edit).
#   tools/link.sh "/Applications/World of Warcraft/_classic_era_/Interface/AddOns"
set -e
dest="$1"
[ -d "$dest" ] || { echo "usage: tools/link.sh <the game's Interface/AddOns folder>"; exit 1; }
root="$(cd "$(dirname "$0")/.." && pwd)"
for dir in "$root"/ImprovedForever*/; do
    name="$(basename "$dir")"
    [ -f "$dir/$name.toc" ] || continue
    ln -sfn "${dir%/}" "$dest/$name"
    echo "$dest/$name -> ${dir%/}"
done
# (a module renamed: Destroy is Junk since 0.5.0)
if [ -L "$dest/ImprovedForever_Destroy" ]; then
    rm "$dest/ImprovedForever_Destroy"
    echo "removed the old ImprovedForever_Destroy link"
fi
# (Controller is the core's since 0.8.0)
if [ -L "$dest/ImprovedForever_Controller" ]; then
    rm "$dest/ImprovedForever_Controller"
    echo "removed the old ImprovedForever_Controller link"
fi
# (the addon's name before it was split)
if [ -L "$dest/ImprovedController" ]; then
    rm "$dest/ImprovedController"
    echo "removed the old ImprovedController link"
fi
