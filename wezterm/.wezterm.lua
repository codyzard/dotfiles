-- Pull in the wezterm API
local wezterm = require 'wezterm'

-- This will hold the configuration.
local config = wezterm.config_builder()
local is_macos = wezterm.target_triple:find("darwin") ~= nil

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

if is_macos then
  config.macos_window_background_blur = 1000
end

local keys = {
  -- Option/Alt + Left: move backward one word
  {
    key = "LeftArrow",
    mods = "ALT",
    action = wezterm.action { SendString = "\x1bb" },
  },
  -- Shift + Enter: insert newline in CLI apps
  {
    key = "Enter",
    mods = "SHIFT",
    action = wezterm.action { SendString = "\x1b\r" },
  },
  -- Option/Alt + Right: move forward one word
  {
    key = "RightArrow",
    mods = "ALT",
    action = wezterm.action { SendString = "\x1bf" },
  },
}

if is_macos then
  -- CMD + Left: move to beginning of line (Ctrl-A)
  table.insert(keys, {
    key = "LeftArrow",
    mods = "CMD",
    action = wezterm.action { SendString = "\x01" },
  })
  -- CMD + Right: move to end of line (Ctrl-E)
  table.insert(keys, {
    key = "RightArrow",
    mods = "CMD",
    action = wezterm.action { SendString = "\x05" },
  })
end

config.keys = keys

return config
