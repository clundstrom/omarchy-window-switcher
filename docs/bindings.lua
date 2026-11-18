-- Add to ~/.config/hypr/bindings.lua. These replace Omarchy's Alt+Tab window
-- navigation with workspace switching. Use logical Super instead if swapped.
o.rebind("ALT + TAB", "Workspace previews: next recent", hl.dsp.global("community.window-switcher:next-workspace"), { dont_inhibit = true })
o.rebind("ALT + SHIFT + TAB", "Workspace previews: previous recent", hl.dsp.global("community.window-switcher:previous-workspace"), { dont_inhibit = true })

-- Track modifier release even before the popup receives keyboard focus.
-- These bindings do not consume Alt or interfere with other Alt chords.
o.bind("Alt_L", nil, hl.dsp.global("community.window-switcher:modifier-left"), {
  transparent = true, non_consuming = true, ignore_mods = true, dont_inhibit = true,
})
o.bind("Alt_R", nil, hl.dsp.global("community.window-switcher:modifier-right"), {
  transparent = true, non_consuming = true, ignore_mods = true, dont_inhibit = true,
})

-- Show and dismiss this overlay instantly, without Hyprland's layer fade.
hl.layer_rule({
  match = { namespace = "^omarchy-window-switcher$" },
  no_anim = true,
  animation = "none",
})
