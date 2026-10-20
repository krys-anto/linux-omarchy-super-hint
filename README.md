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
2. Add `{ "id": "kirality.super-hint" }` to the `plugins` array in
   `~/.config/omarchy/shell.json`.

Reload Hyprland afterwards.

## Managing it through Omarchy

The symlinked install is a first-class citizen of Omarchy's own plugin
manager -- the plugin shows up in `omarchy plugin list` as a third-party
`overlay`, and `omarchy menu plugin` lists it for enable/disable/remove:

```sh
omarchy plugin list | grep super-hint
# kirality.super-hint   enabled   third-party   overlay   Super Hint

omarchy plugin disable kirality.super-hint   # keep it installed, stop loading it
omarchy plugin enable  kirality.super-hint
omarchy plugin remove  kirality.super-hint   # unlinks the symlink, repo untouched
```

Two things to know:

- `omarchy plugin remove` handles the symlink correctly (it unlinks rather
  than deleting, so this repo is never touched) and disables the plugin in
  `shell.json` on the way out. But it only knows about the plugin folder --
  the `hypr/` and `~/.local/bin` links and the `hyprland.lua` requires are
  outside its remit. Use `./uninstall.sh` to remove the whole install.
- `omarchy plugin update` does **not** apply here. It requires the plugin
  folder itself to be a git checkout, and ours is a subdirectory of this
  repo. `git pull` in this repo is the update path; the symlinks mean that
  is all it takes.

## Uninstall

```sh
./uninstall.sh
```

It unlinks the plugin through `omarchy plugin remove` (so `shell.json` is
cleaned up and the shell unloads it), then drops the `hypr/` and
`~/.local/bin` symlinks. Only symlinks pointing back into this repo are
touched, so it can never delete a hand-written file or a link to another
checkout.

It leaves one manual step, mirroring the install: delete the two `require`
lines from `~/.config/hypr/hyprland.lua`. Do that **before** the next
Hyprland reload -- requiring a module whose file is gone makes the whole
config fail to load.

## Known issues

- Key events fire through the Lua handler twice per physical press/release
  (visible in `~/.cache/super-hint-debug.log`), which may be related to a
  "sometimes stuck open" report the debug logging in `super-hint.lua` was
  added to investigate. Not yet root-caused.
