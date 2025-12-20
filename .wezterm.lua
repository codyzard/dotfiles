-- Pull in the wezterm API
local wezterm = require 'wezterm'

-- This will hold the configuration.
local config = wezterm.config_builder()

config.font = wezterm.font("Fira Code")
config.font_size = 20

config.window_decorations = "RESIZE"
config.color_scheme = 'Apple System Colors'

config.window_background_opacity = 0.4
-- config.window_background_image = wezterm.home_dir .."/Downloads/jayce-arcane-survivor-skin-lol-splash-art-2k-wallpaper-uhdpaper.com-433@3@b.jpg"
config.macos_window_background_blur = 1000

config.keys = {
    -- Kích hoạt khi nhấn Option + Left
    {
        key = "LeftArrow",
        mods = "OPT",
        action = wezterm.action {SendString = "\x1bb"}
    }, -- Kích hoạt khi nhấn Option + Right
    {
        key = "RightArrow",
        mods = "OPT",
        action = wezterm.action {SendString = "\x1bf"}
    }, {
        key = "LeftArrow",
        mods = "CMD",
        action = wezterm.action {SendString = "\x01"} -- Ctrl-A để di chuyển đến đầu dòng trong nhiều shell
    }, -- Kích hoạt khi nhấn CMD + Right
    {
        key = "RightArrow",
        mods = "CMD",
        action = wezterm.action {SendString = "\x05"} -- Ctrl-E để di chuyển đến cuối dòng trong nhiều shell
    }
}

return config
