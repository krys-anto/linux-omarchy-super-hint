#!/bin/bash
# Installs Super Hint by symlinking this repo's files into place, so future
# edits here take effect immediately (and `git pull` updates a live install).
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

plugin_dst=~/.config/omarchy/plugins/kirality.super-hint
mkdir -p ~/.config/omarchy/plugins ~/.config/hypr ~/.local/bin

link() {
  local src="$1" dst="$2"
  if [[ -e "$dst" && ! -L "$dst" ]]; then
    echo "skip: $dst already exists and is not a symlink (remove or back it up first)" >&2
    return
  fi
  ln -sfn "$src" "$dst"
  echo "linked: $dst -> $src"
}

link "$repo_dir/omarchy/plugins/kirality.super-hint" "$plugin_dst"
link "$repo_dir/hypr/super-hint.lua" ~/.config/hypr/super-hint.lua
link "$repo_dir/hypr/super-hint-patch.lua" ~/.config/hypr/super-hint-patch.lua
link "$repo_dir/bin/omarchy-super-hint-data" ~/.local/bin/omarchy-super-hint-data
link "$repo_dir/bin/omarchy-super-hint-show" ~/.local/bin/omarchy-super-hint-show
link "$repo_dir/bin/omarchy-super-hint-hide" ~/.local/bin/omarchy-super-hint-hide

# Tell the running shell to pick up the newly linked plugin directory. Without
# this, the plugin does not exist as far as omarchy-shell is concerned yet, so
# `omarchy plugin enable` below fails with "plugin is not known" -- linking the
# folder alone is not discovery.
if command -v omarchy-shell >/dev/null 2>&1; then
  omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
  echo "rescanned: omarchy-shell now sees kirality.super-hint"
fi

echo
echo "Files linked. Two manual steps remain (not automated -- they edit"
echo "personal config that already has your own content in it):"
echo
echo "1. In ~/.config/hypr/hyprland.lua, add:"
echo '     require("hypr.super-hint-patch")   -- BEFORE require("default.hypr.omarchy")'
echo '     require("hypr.super-hint")         -- anywhere after the omarchy defaults load'
echo
echo "2. Enable the plugin:"
echo "     omarchy plugin enable kirality.super-hint"
echo
echo "   (That writes the \"plugins\" entry in ~/.config/omarchy/shell.json for you."
echo "   Adding { \"id\": \"kirality.super-hint\" } there by hand does the same thing.)"
echo
echo "Then reload Hyprland (or log out/in) for the submap binds and plugin to take effect."
