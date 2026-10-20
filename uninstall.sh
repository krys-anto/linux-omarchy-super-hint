#!/bin/bash
# Removes the Super Hint install created by install.sh: unlinks the plugin
# (via Omarchy, so shell.json is cleaned up too) and drops the hypr/ and
# bin/ symlinks.
#
# Only symlinks pointing back into THIS repo are touched, so this can never
# delete a file you wrote by hand or a link to a different checkout.
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

plugin_id=kirality.super-hint
plugin_dst=~/.config/omarchy/plugins/$plugin_id

# Prefer Omarchy's own remover: it disables the plugin in shell.json first,
# unlinks the symlink, and rescans the shell -- all the bookkeeping this
# script would otherwise have to duplicate. --yes because the confirmation
# belongs to whoever ran uninstall.sh, not to a second prompt.
if [[ -L "$plugin_dst" ]]; then
  if [[ "$(readlink "$plugin_dst")" == "$repo_dir/omarchy/plugins/$plugin_id" ]]; then
    omarchy plugin remove "$plugin_id" --yes
  else
    echo "skip: $plugin_dst links to $(readlink "$plugin_dst"), not this repo" >&2
  fi
elif [[ -e "$plugin_dst" ]]; then
  echo "skip: $plugin_dst is not a symlink (remove it by hand if you mean to)" >&2
else
  echo "not linked: $plugin_dst"
fi

unlink_if_ours() {
  local dst="$1" want="$2"
  if [[ ! -L "$dst" ]]; then
    if [[ -e "$dst" ]]; then
      echo "skip: $dst is not a symlink (remove it by hand if you mean to)" >&2
    else
      echo "not linked: $dst"
    fi
    return
  fi
  if [[ "$(readlink "$dst")" != "$want" ]]; then
    echo "skip: $dst links to $(readlink "$dst"), not this repo" >&2
    return
  fi
  rm -f "$dst"
  echo "unlinked: $dst"
}

unlink_if_ours ~/.config/hypr/super-hint.lua "$repo_dir/hypr/super-hint.lua"
unlink_if_ours ~/.config/hypr/super-hint-patch.lua "$repo_dir/hypr/super-hint-patch.lua"
unlink_if_ours ~/.local/bin/omarchy-super-hint-data "$repo_dir/bin/omarchy-super-hint-data"
unlink_if_ours ~/.local/bin/omarchy-super-hint-show "$repo_dir/bin/omarchy-super-hint-show"
unlink_if_ours ~/.local/bin/omarchy-super-hint-hide "$repo_dir/bin/omarchy-super-hint-hide"

echo
echo "One manual step remains -- the same one install.sh does not automate,"
echo "because it edits personal config that has your own content in it:"
echo
echo "1. In ~/.config/hypr/hyprland.lua, delete these two lines:"
echo '     require("hypr.super-hint-patch")'
echo '     require("hypr.super-hint")'
echo
echo "Then reload Hyprland ('hyprctl reload'). Leaving them in place after the"
echo "files are gone makes Hyprland's config fail to load, so do this before"
echo "the next reload, not after."
