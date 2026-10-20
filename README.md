# Super Hint

An [Omarchy](https://omarchy.org) plugin that shows a grouped shortcut HUD
while the Super key is held, with keybindings read live from
`hyprctl binds -j` so the overlay always matches your actual current binds.

## Layout

- `omarchy/plugins/kirality.super-hint/` — the Omarchy overlay plugin
  (`manifest.json` + `SuperHint.qml`)
- `hypr/super-hint.lua` — Hyprland submap that shows/hides the overlay on
  Super press/release and tracks held modifiers
- `hypr/super-hint-patch.lua` — wraps `o.bind` so every real keybinding stays
  reachable while the hint's submap is active (`submap_universal`)
- `bin/omarchy-super-hint-data` — builds the JSON payload the overlay
  renders, from live `hyprctl binds -j`
- `bin/omarchy-super-hint-show` / `bin/omarchy-super-hint-hide` — summon/hide
  wrappers with sequence-number handling to avoid stale show/hide races

## Install

```sh
git clone <this-repo-url> ~/Projects/super-hint
~/Projects/super-hint/install.sh
```

The script symlinks everything into place under `~/.config/omarchy`,
`~/.config/hypr`, and `~/.local/bin`, so `git pull` here keeps a live
install up to date. It prints two manual steps it deliberately does not
automate, since they touch config files that already carry your own content:

1. Add `require("hypr.super-hint-patch")` (before Omarchy's own defaults
   load) and `require("hypr.super-hint")` to `~/.config/hypr/hyprland.lua`.
2. Run `omarchy plugin enable kirality.super-hint`, which writes the
   `plugins` entry in `~/.config/omarchy/shell.json` for you.

Reload Hyprland afterwards.

## Known issues

- Key events fire through the Lua handler twice per physical press/release
  (visible in `~/.cache/super-hint-debug.log`), which may be related to a
  "sometimes stuck open" report the debug logging in `super-hint.lua` was
  added to investigate. Not yet root-caused.
