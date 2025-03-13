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

config.color_scheme = 'catppuccin-frappe'
config.window_frame = {
    font = wezterm.font { family = 'SF Pro Display' },
    font_size = 10,
    active_titlebar_bg = 'rgb(48, 52, 70 / 62.5%)',
    inactive_titlebar_bg = 'rgb(48, 52, 70 / 62.5%)'
}
config.colors = {
    tab_bar = {
        inactive_tab_edge = '#232634',
        active_tab = {
            bg_color = 'none',
            fg_color = '#babbf1'
        },
        inactive_tab = {
            bg_color = 'none',
            fg_color = '#c6d0f5'
        },
        inactive_tab_hover = {
            bg_color = 'none',
            fg_color = '#babbf1'
        },
        new_tab = {
            bg_color = 'none',
            fg_color = '#c6d0f5'
        },
        new_tab_hover = {
            bg_color = 'none',
            fg_color = '#babbf1'
        },
    },
}
config.window_background_opacity = 0.625

return config
