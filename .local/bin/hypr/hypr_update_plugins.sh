#!/bin/env bash
# Hyprland Lua plugins in ~/.config/hypr/plugins: clone the missing ones, update the rest.
# hyprland.lua runs this by itself when split-monitor-workspaces is missing, install.sh after stowing.

dir="$HOME/.config/hypr/plugins"
mkdir -p "$dir" || exit 1

status=0
for url in https://github.com/zjeffer/split-monitor-workspaces; do
    name="$(basename "$url")"
    if [ -d "$dir/$name/.git" ]; then
        git -C "$dir/$name" pull --ff-only --quiet || status=1
    else
        git clone --quiet "$url" "$dir/$name" || status=1
    fi
done
exit "$status"
