local wezterm = require 'wezterm'

local config = {}
if wezterm.config_builder then
    config = wezterm.config_builder()
end

config.font = wezterm.font_with_fallback {
    "TX-02",
    "Miriam Mono CLM",
    "M PLUS 1 Code",
    "JuliaMono",
    "Symbols Nerd Font",
    "Apple Color Emoji",
    "Noto Sans Devanagari"
}
config.font_size = 14.0

config.color_scheme = "catppuccin-frappe"
config.window_background_opacity = 0.75

return config
