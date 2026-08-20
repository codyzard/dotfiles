-- Pull in the wezterm API
local wezterm = require 'wezterm'

-- This will hold the configuration.
local config = wezterm.config_builder()

config.font = wezterm.font("Fira Code")
config.font_size = 20

config.window_decorations = "RESIZE"
config.color_scheme = 'Apple System Colors'

config.window_background_opacity = 0.4
-- Downloaded by setup.sh (JaKooLit Wallpaper-Bank). Only set if present.
local bg = wezterm.home_dir .. "/.config/wallpapers/wezterm-bg.jpeg"
local f = io.open(bg, "r")
if f then
  f:close()
  config.window_background_image = bg
  -- Dim the wallpaper so terminal text stays readable
  config.window_background_image_hsb = {
    brightness = 0.04, -- lower = darker image, clearer text
    saturation = 0.9,
    hue = 1.0,
  }
end
config.macos_window_background_blur = 1000

config.keys = { -- Kích hoạt khi nhấn Option + Left
    {
        key = "LeftArrow",
        mods = "OPT",
        action = wezterm.action {SendString = "\x1bb"}
    },
    {
        key = "Enter",
        mods = "SHIFT",
        action = wezterm.action {SendString = "\x1b\r"}
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
