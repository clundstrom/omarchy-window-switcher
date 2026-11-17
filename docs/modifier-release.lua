-- Append once to ~/.config/hypr/bindings.lua, then reload/validate Hyprland.
-- Existing workspace invocation and Alt+Tab bindings stay unchanged.
o.bind("Super_L", nil, hl.dsp.global("community.window-switcher:modifier-left"), {
  transparent = true, non_consuming = true, ignore_mods = true,
})
o.bind("Super_R", nil, hl.dsp.global("community.window-switcher:modifier-right"), {
  transparent = true, non_consuming = true, ignore_mods = true,
})
