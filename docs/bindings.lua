-- Add to ~/.config/hypr/bindings.lua. These replace workspace invocation only;
-- Omarchy's separate Alt+Tab window navigation remains unchanged.
o.rebind("SUPER + TAB", "Workspace previews: next recent", hl.dsp.global("community.window-switcher:next-workspace"))
o.rebind("SUPER + SHIFT + TAB", "Workspace previews: previous recent", hl.dsp.global("community.window-switcher:previous-workspace"))

-- Track modifier release even before the popup receives keyboard focus.
-- These bindings do not consume Super or interfere with other Super chords.
o.bind("Super_L", nil, hl.dsp.global("community.window-switcher:modifier-left"), {
  transparent = true, non_consuming = true, ignore_mods = true,
})
o.bind("Super_R", nil, hl.dsp.global("community.window-switcher:modifier-right"), {
  transparent = true, non_consuming = true, ignore_mods = true,
})

-- Show and dismiss this overlay instantly, without Hyprland's layer fade.
hl.layer_rule({
  match = { namespace = "^omarchy-window-switcher$" },
  no_anim = true,
  animation = "none",
})
