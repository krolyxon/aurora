<div align="center">
  <img src="assets/logo.svg" width="320" alt="aurora">
  <p>My Arch Linux + Hyprland desktop, in a Nothing OS style, themed live from the wallpaper.</p>
</div>

![aurora desktop](assets/aurora-desktop.webp)

**Aurora** is my own desktop on **Arch Linux + Hyprland** (Lua config): a desktop shell written in Quickshell (bar,
control panel, notifications, OSD, dock, runner, settings, ...) plus the configs around it, themed live from the
wallpaper with **matugen** and deployed with **GNU stow**.

## The shell
One shell instead of waybar, dunst, wlogout, fuzzel and a pile of scripts, in a Nothing OS style (Doto dot-matrix type,
pills, LED dots) with Material You colours: everything below is themed from the current wallpaper, which aurora draws
itself as mono dots, colour dots or the plain photo.

<table>
  <tr>
    <td width="50%"><img src="assets/aurora-panel.webp" alt="control panel"><br>
      <sub><b>Control panel</b> · media, volume/mic/brightness, quick toggles, capture, session</sub></td>
    <td width="50%"><img src="assets/aurora-panel-sys.webp" alt="system tab"><br>
      <sub><b>System</b> · cpu, memory, disks, battery, power profile, GPU mode (envycontrol)</sub></td>
  </tr>
  <tr>
    <td><img src="assets/aurora-runner.webp" alt="runner"><br>
      <sub><b>Runner</b> (<kbd>Super</kbd>+<kbd>R</kbd>) · apps, scripts, calc, shell; also a dmenu for scripts</sub></td>
    <td><img src="assets/aurora-wallpicker.webp" alt="wallpaper picker"><br>
      <sub><b>Wallpaper picker</b> · live full-screen preview, folders, search, vim keys, three looks; re-themes everything through matugen</sub></td>
  </tr>
  <tr>
    <td><img src="assets/aurora-chars.webp" alt="glyph picker"><br>
      <sub><b>Glyph picker</b> (<kbd>Super</kbd>+<kbd>`</kbd>) · emoji, nerd icons, symbols, kaomoji, fancy text</sub></td>
    <td><img src="assets/aurora-power.webp" alt="power menu"><br>
      <sub><b>Power menu</b> (<kbd>Super</kbd>+<kbd>Esc</kbd>) · lock, logout, suspend, reboot, ...</sub></td>
  </tr>
  <tr>
    <td><img src="assets/aurora-cal.webp" alt="calendar"><br>
      <sub><b>Calendar</b> · from the clock in the bar</sub></td>
    <td><img src="assets/aurora-settings.webp" alt="settings app"><br>
      <sub><b>Settings</b> (<kbd>Super</kbd>+<kbd>I</kbd>) · searchable (<kbd>Ctrl</kbd>+<kbd>F</kbd>); network, sound, look, Hyprland, keybinds, display, power</sub></td>
  </tr>
  <tr>
    <td colspan="2"><img src="assets/aurora-overview.webp" alt="overview"><br>
      <sub><b>Overview</b> · live previews of every workspace and window, click to jump</sub></td>
  </tr>
</table>

> [!WARNING]
> **This is my personal setup, not a general purpose desktop or dotfiles framework.**
>
> It's built around my hardware (Lenovo Legion, Intel + NVIDIA hybrid graphics, `linux-zen`), my monitors,
> my keyboard and my habits. I'm not trying to make it work for everyone, and I won't be adding options
> or support for other setups. It's public as a **reference**, or for people who want **exactly the same
> setup** as me.
>
> **Only run `install.sh` on a freshly installed, unconfigured Arch Linux system.** It installs a lot of
> packages (NVIDIA drivers included if you pick them), replaces your configs with symlinks, changes your login
> shell and can enable system services. Don't run it on a system you already use.

## Installing (fresh Arch only)
```bash
git clone https://git.krolyxon.com/aurora ~/aurora
cd ~/aurora
./install.sh           # interactive: pick packages per group
./install.sh --yes     # pre-select the default packages, no pickers
./install.sh --check   # only compare installed packages with the lists, changes nothing
```
Clone it anywhere (e.g. `~/dev/aurora`): the repo's `.stowrc` points stow at `$HOME`. Re-stow by hand with `stow .`
from the repo; to move an existing checkout, `stow -D .` first, move it, then `stow .` again.

## Packages
The lists live in `packages/*.txt`: one package per line, `#` for comments, and a trailing `!` means
"listed, but not pre-selected".

| file | |
|---|---|
| `desktop.txt` | always installed: Hyprland, Quickshell, PipeWire, the tools the shell and keybinds call |
| `utils.txt` | CLI tools, fonts, media, small utilities |
| `dev.txt` | development tools |
| `gpu.txt` | Intel + NVIDIA (`nvidia-open-dkms`) drivers. Change this for your hardware |
| `optional.txt` | desktop apps |
| `aur.txt` | AUR packages (installed with paru) |
| `base.txt` | reference only, never installed: what the base install already provides |

## What's inside
| | |
|---|---|
| WM | Hyprland (Lua config), hypridle, hyprlock; aurora draws the wallpaper (mono dots, colour dots or photo) |
| Shell / bar | aurora (Quickshell) |
| Theming | matugen: picking a wallpaper in aurora (or `setwall`) re-themes everything (GTK via adw-gtk3, Qt via qt6ct); accent = the wallpaper's own colour, near-black surfaces. The terminal (foot) too, with ANSI colours tinted toward the wallpaper |
| Terminal / shell | foot, zsh |
| Editor | Neovim (LazyVim) |
| Launcher / menus | aurora's runner (`aurora-run`, also a dmenu replacement for scripts) |
| Files | lf, pcmanfm |
| Music / video | mpd + rmptui , mpv |
| Font / icons | Doto, Space Grotesk, Space Mono (shell UI, vendored in `.local/share/fonts/glyph`), JetBrainsMono Nerd Font, Papirus-Dark |

## Credits
- The dot-matrix shaders and some components started out as ports from
  [glyph-rice](https://github.com/Nebelung-cloud/glyph-rice) (GPL-3.0); those files say so in their header.
- Nothing, Nothing OS and Glyph are trademarks of Nothing Technology Ltd; this is a fan project, not affiliated with Nothing.
- Fonts in `.local/share/fonts/glyph/`: [Doto](https://github.com/oliverlalan/Doto),
  [Space Grotesk](https://github.com/floriankarsten/space-grotesk) and [Space Mono](https://github.com/googlefonts/spacemono),
  under the SIL Open Font License (`OFL.txt` next to them).
