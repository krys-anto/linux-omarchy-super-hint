-- Bare-Super hint overlay, submap-based.
--
-- Entering/exiting the "super_hint" submap is a real Hyprland native bind
-- (hl.bind on the Super_L/Super_R keysym), not a raw event observer -- this
-- sidesteps every interference issue found while debugging the
-- input.keyboard.key approach (confirmed live: a raw hook reacting to keys
-- alongside Hyprland's own concurrent top-level dispatch corrupted
-- movefocus; this never runs two independent handlers against the same
-- keystroke).
--
-- Curated shortcuts (see super-hint-patch.lua, loaded earlier) are flagged
-- submap_universal, so they keep firing via Hyprland's own normal dispatch
-- while this submap is active -- nothing here re-executes any command.
-- Everything else is inert while Super is held, by ordinary submap
-- semantics (only explicitly-bound or universal keys respond).
--
-- The overlay's show/hide is driven by the "keybinds.submap" event, not by
-- input.keyboard.key, so it only reacts to actual submap transitions, not
-- every raw keystroke.

-- Exit bind for Escape lives INSIDE the submap definition -- a bind
-- declared outside it is global-scope and, like any non-universal bind, is
-- unreachable once "super_hint" is the active submap.
--
-- Super's own release is NOT handled the same way: a { release = true }
-- bind placed inside the submap for Super_L/Super_R never fired (confirmed
-- live -- hyprctl submap stayed stuck on "super_hint" after releasing
-- Super, with no way found to make a submap-scoped release bind work for
-- the same key that entered the submap). Instead it's detected via a
-- narrow input.keyboard.key hook watching only Super's own XKB keycodes
-- (133/134, evdev + 8) -- the same pattern already confirmed to cause zero
-- dispatch interference when it does nothing but track Super's state -- and
-- resets the submap with a direct, native hl.dispatch call (not
-- hl.exec_cmd/hl.timer, which are what caused interference earlier; a bare
-- dispatch is a first-class Hyprland operation with no process spawn).
hl.define_submap("super_hint", function()
  hl.bind("ESCAPE", hl.dsp.submap("reset"))
end)

hl.bind("Super_L", hl.dsp.submap("super_hint"))
hl.bind("Super_R", hl.dsp.submap("super_hint"))

-- Temporary debug logging while investigating a "sometimes stuck open"
-- report. Remove once resolved.
local log_path = os.getenv("HOME") .. "/.cache/super-hint-debug.log"
local log_seq = 0
local function log(msg)
  log_seq = log_seq + 1
  local f = io.open(log_path, "a")
  if f then
    f:write(string.format("#%04d %s lua %s\n", log_seq, os.date("%H:%M:%S"), msg))
    f:close()
  end
end

-- Confirmed live root cause of "sometimes stuck open": fire() spawns each
-- show/hide as an independent background process with no ordering
-- guarantee between them. A duplicate "show" (from the same double-firing
-- behavior confirmed for Super, apparently shared by modifier keys) can
-- finish its IPC round-trip AFTER a "hide" that was fired later, silently
-- reopening the overlay. Fixed with a monotonic sequence number: written
-- synchronously the instant each fire() is issued (so it reflects true
-- issue order regardless of background scheduling), and checked by the
-- show/hide script itself before acting -- a call superseded by a later
-- one detects it and skips, regardless of real-world completion timing.
local seq_path = os.getenv("HOME") .. "/.cache/super-hint-seq"
local last_key_path = os.getenv("HOME") .. "/.cache/super-hint-last-key"
local seq = 0
local function fire(cmd)
  seq = seq + 1
  local f = io.open(seq_path, "w")
  if f then f:write(tostring(seq)); f:close() end
  log("fire[" .. seq .. "]: " .. cmd)
  os.execute("SUPER_HINT_SEQ=" .. seq .. " " .. cmd .. " >/dev/null 2>&1 &")
end

-- Live "keys held" readout: track Shift/Ctrl/Alt (XKB keycodes, evdev + 8)
-- the same narrow way Super's own release is tracked, and re-summon with
-- the current set whenever one of them changes while the hint is open.
-- This is safe for the same reason tracking Super's release is safe: none
-- of these, held alone alongside Super with no third key, has any
-- competing native dispatch of its own to race against -- every real bind
-- needs an actual letter/action key too, which this never reacts to.
local SUPER_L = 133
local SUPER_R = 134

local MOD_KEYCODES = {
  [50] = "SHIFT", [62] = "SHIFT",   -- Left/Right Shift
  [37] = "CTRL",  [105] = "CTRL",   -- Left/Right Ctrl
  [64] = "ALT",   [108] = "ALT",    -- Left/Right Alt
}
local MOD_ORDER = { "SHIFT", "CTRL", "ALT" }
local held = { SHIFT = false, CTRL = false, ALT = false }

local function held_mods_args()
  local out = {}
  for _, name in ipairs(MOD_ORDER) do
    if held[name] then table.insert(out, name) end
  end
  return table.concat(out, " ")
end

-- The overlay's show/hide is driven by the "keybinds.submap" event, which
-- only fires on actual submap transitions, not every raw keystroke.
--
-- `held` is reset here on every fresh entry, not just declared once at
-- startup: if Super is released before a modifier held alongside it (e.g.
-- Alt), that modifier's own release event fires after we've already left
-- the submap, so the tracking hook below (gated on being inside the
-- submap) never sees it and it would otherwise stay stuck "held" into the
-- next press -- confirmed live as a real bug (readout kept showing ALT
-- when only Ctrl was actually down).
hl.on("keybinds.submap", function()
  local sub = hl.get_current_submap()
  log("keybinds.submap event, current=" .. tostring(sub))
  if sub == "super_hint" then
    held.SHIFT = false
    held.CTRL = false
    held.ALT = false
    fire("omarchy-super-hint-show")
  else
    fire("omarchy-super-hint-hide")
  end
end)

-- The previous "safety net" queried hl.is_key_down("Super_L"/"Super_R") to
-- double check Super's real state. Confirmed live via logging that this is
-- itself unreliable: is_key_down still reported Super as held DURING the
-- handling of Super's own state=0 (release) event for that same key --
-- Hyprland hadn't yet committed the state update at the point our
-- synchronous callback ran for that event, so the query returned stale
-- (pre-release) data. Fixed by never querying is_key_down at all: track
-- Super's state ourselves from the `state` param of ITS OWN events, which
-- is authoritative for that event, and use our own flag everywhere instead.
local super_down = false

local function exit_if_super_released(reason)
  local sub = hl.get_current_submap()
  if sub == "super_hint" and not super_down then
    log("exit_if_super_released(" .. reason .. "): submap=" .. sub .. " super_down=" .. tostring(super_down) .. " -> DISPATCHING RESET")
    hl.dispatch(hl.dsp.submap("reset"))
  elseif sub == "super_hint" then
    log("exit_if_super_released(" .. reason .. "): submap=" .. sub .. " super_down=" .. tostring(super_down) .. " -> still held, no-op")
  end
end

hl.on("input.keyboard.key", function(keycode, _timestamp, state)
  log("key event keycode=" .. tostring(keycode) .. " state=" .. tostring(state) .. " submap=" .. tostring(hl.get_current_submap()))

  if keycode == SUPER_L or keycode == SUPER_R then
    super_down = (state == 1)
    if state == 0 then exit_if_super_released("super-release") end
    return
  end

  local mod_name = MOD_KEYCODES[keycode]
  if mod_name and hl.get_current_submap() == "super_hint" then
    held[mod_name] = (state == 1)
    fire("omarchy-super-hint-show " .. held_mods_args())
  elseif not mod_name and state == 1 and hl.get_current_submap() == "super_hint" then
    -- Remember the last real (non-modifier) key pressed while the hint was
    -- open, so the NEXT time it's shown it can display what that command
    -- was. This only observes -- it never binds/intercepts the key, so it
    -- can't affect whether the real action fires (that's still entirely
    -- Hyprland's own submap_universal dispatch, untouched). Plain local
    -- file write, no exec/IPC, same as the debug log -- safe in this hot
    -- path for the same reason that logging already is.
    local f = io.open(last_key_path, "w")
    if f then
      f:write(tostring(keycode) .. "\t" .. held_mods_args() .. "\n")
      f:close()
    end
  end

  exit_if_super_released("other-key")
end)
