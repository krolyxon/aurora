terminal = "foot"
menu = "aurora-run"   -- aurora's runner
browser = "librewolf"
mainMod = "SUPER"

-- -----------------------------------------------------
-- Path to home
-- -----------------------------------------------------
HOME = os.getenv("HOME")


-- Theme (matugen, run by aurora on every wallpaper change; fallback until it has run once)
local ok, c = pcall(dofile, HOME .. "/.cache/matugen/hyprland-colors.lua")
colors = ok and c or { primary = "rgba(80d5cbff)", surface = "rgba(0e1514ff)", surface_highest = "rgba(2f3635ff)",
                       on_surface = "rgba(dde4e2ff)", outline_variant = "rgba(3f4947ff)" }

-- -----------------------------------------------------
-- Autostart
-- -----------------------------------------------------
hl.on("hyprland.start", function()
    -- tty1 autologs in, so hyprlock is the login screen: its password unlocks the GNOME keyring
    -- (/etc/pam.d/login has pam_gnome_keyring, hyprlock includes it; system/etc/pam.d)
    hl.exec_cmd("pidof hyprlock || hyprlock")
    -- GTK3 on Wayland reads its theme + icons from gsettings, not settings.ini (colours: gtk-3.0/gtk.css, matugen)
    hl.exec_cmd("gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3-dark")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface icon-theme Papirus-Dark")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface font-name 'JetBrainsMonoNL Nerd Font Mono 11'")   -- Space fonts are aurora's only
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    -- aurora is a systemd unit: hand it the login env (.zprofile: SUDO_ASKPASS, EDITOR, XDG dirs, ...)
    hl.exec_cmd("dbus-update-activation-environment --systemd --all && systemctl --user start aurora-shell")
    -- hl.exec_cmd("waybar")
    -- hl.exec_cmd("swaync")
    hl.exec_cmd("gammastep")
    hl.exec_cmd("hypridle")
    -- hl.exec_cmd("blueman-applet")
    -- no hyprpaper: aurora draws the wallpaper itself (Back.qml / WallView.qml)
    -- polkit agent: aurora (Agents.qml); it starts hyprpolkitagent itself if it can't register
end)

--------------------------------------------------
-- Plugins
--------------------------------------------------
package.path = package.path .. ";./?.lua;./?/init.lua"
-- split-monitor-workspaces is a git checkout in ~/.config/hypr/plugins, not in this repo (hypr_update_plugins.sh).
-- Missing (fresh install) = plain workspaces 1-10 with the same API for keybinds.lua, and fetch it + reload,
-- instead of a require error that leaves Hyprland in emergency mode with no binds.
local smw_ok, smw_mod = pcall(require, "plugins.split-monitor-workspaces")
if smw_ok then
    smw = smw_mod
    smw.setup({
        workspace_count = 10,
    })
else
    local function ws(n) return n == "0" and "10" or n end   -- keybinds.lua binds workspace 10 to SUPER+0
    smw = {
        get_amount_of_workspaces = function() return 10 end,
        workspace = function(n) return hl.dsp.focus({ workspace = ws(n) }) end,
        move_to_workspace_silent = function(n) return hl.dsp.window.move({ workspace = ws(n), follow = false }) end,
    }
    hl.exec_cmd(HOME .. "/.local/bin/hypr/hypr_update_plugins.sh && hyprctl reload")
end

-- -----------------------------------------------------
-- SOURCE FILES
-- -----------------------------------------------------
require("source.monitors")
require("source.environment_variables")
require("source.permissions")
require("source.appearance")
require("source.input")
require("source.keybinds")
require("source.window_rules")

-- aurora's settings app: overrides on top of everything above (~/.config/aurora/hypr.lua, generated, not in the repo).
-- Missing or broken file = the defaults from the files above.
local ok, overrides = pcall(dofile, HOME .. "/.config/aurora/hypr.lua")
if ok and type(overrides) == "table" then hl.config(overrides) end
