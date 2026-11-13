#!/bin/sh
# Copies every addon folder of the repo to the gaming PC's WoW Forever, so the game there loads
# the working copy (/reload after). The PC dual-boots: Windows (ssh alias `winpc`) is tried
# first, then Bazzite (ssh alias `bazzite`, same game folder through the NTFS mount). Each
# addon's folder there is emptied first, so a file deleted or renamed here is gone there too.
#   tools/sync_pc.sh
# (the PC has no symlink to the repo, which lives on the Mac: a copy; see the winpc-remote
# and bazzite-remote skills)
set -e
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
dirs=""
for dir in ImprovedForever*/; do
    name="${dir%/}"
    [ -f "$name/$name.toc" ] && dirs="$dirs $name"
done
[ -n "$dirs" ] || { echo "no addon folder found in $root"; exit 1; }

pack() { COPYFILE_DISABLE=1 tar --exclude='.DS_Store' -czf - $dirs 2>/dev/null; }

sync_win() {
    dest='C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns'
    ssh -o ConnectTimeout=5 winpc "cd /d \"$dest\"" >/dev/null 2>&1 || return 1
    cmd=""
    for name in $dirs; do
        cmd="$cmd if exist \"$dest\\$name\" rmdir /s /q \"$dest\\$name\" &"
    done
    ssh winpc "$cmd echo." >/dev/null
    pack | ssh winpc "cd /d \"$dest\" && tar -xzf - 2>/dev/null"
    echo "synced to the PC (Windows):$dirs"
}

sync_bazzite() {
    dest='/var/mnt/windows/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns'
    ssh -o ConnectTimeout=5 bazzite "cd \"$dest\"" >/dev/null 2>&1 || return 1
    ssh bazzite "cd \"$dest\" && rm -rf $dirs"
    pack | ssh bazzite "cd \"$dest\" && tar -xzf - 2>/dev/null"
    echo "synced to the PC (Bazzite):$dirs"
}

sync_win || sync_bazzite || { echo "the PC isn't reachable (ssh winpc / ssh bazzite)"; exit 1; }
