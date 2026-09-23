-- o.bind is defined inside default.hypr.helpers, which default.hypr.omarchy
-- requires as its own first step -- so we require it ourselves first to get
-- a real `o` table to wrap. require() caches by module name, so omarchy.lua's
-- own later require("default.hypr.helpers") is a no-op returning the same
-- table, already wrapped, not a second fresh load.
require("default.hypr.helpers")

-- Must load BEFORE default.hypr.omarchy (see hyprland.lua). Wraps o.bind so
-- that every real binding gets registered with submap_universal = true.
--
-- This does NOT duplicate, execute, or hardcode any command: the ORIGINAL
-- o.bind call still runs with Omarchy's own real dispatcher, whatever it
-- currently is. We only add one option before it registers, so shortcuts
-- keep firing via Hyprland's own normal dispatch even while the
-- "super_hint" submap (see hypr/super-hint.lua) is active -- the hint
-- overlay should be purely informational and never gate anything, so
-- everything gets this flag, not just a curated subset.

local original_bind = o.bind
o.bind = function(keys, description, dispatcher, options)
  options = options or {}
  options.submap_universal = true
  return original_bind(keys, description, dispatcher, options)
end
