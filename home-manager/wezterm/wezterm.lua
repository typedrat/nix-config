local wezterm = require 'wezterm'

function get_appearance()
    if wezterm.gui then
        return wezterm.gui.get_appearance()
    end
    return 'Dark'
end

function scheme_for_appearance(appearance)
    if appearance:find 'Dark' then
        return 'catppuccin-frappe'
    else
        return 'catppuccin-latte'
    end
end

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
    "Apple Color Emoji"
}
config.font_size = 14.0

config.color_scheme = scheme_for_appearance(get_appearance())
config.window_background_opacity = 0.85

return config
