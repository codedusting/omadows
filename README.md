# Omadows

Omarchy's look and workflow on Windows 11.

[Omarchy](https://omarchy.org) is DHH's omakase setup for Arch Linux (omakase + Arch, after
Omakub for Ubuntu). Omadows is the same idea for Windows: a tiling window manager on the Super
key, a slim transparent top bar, a keyboard launcher, and one-key switching between all of
Omarchy's themes, which recolors everything from the window borders to Explorer's folder icons.

## Install

In a normal (not administrator) PowerShell window:

```powershell
irm https://raw.githubusercontent.com/codedusting/omadows/main/install.ps1 | iex
```

- One administrator prompt appears for the machine-wide installs. Click Yes.
- It takes 10 to 20 minutes, mostly downloads. Sign out and back in once when it finishes.
- Needs Windows 11, an internet connection and winget (App Installer, included in Windows 11).
- Safe to run again: it keeps your current theme, and files it replaces are kept next to them as
  `*.bak-<timestamp>`.

Without PowerShell 7, starship and fastfetch:

```powershell
$env:OMADOWS_SKIP_EXTRAS = 1; irm https://raw.githubusercontent.com/codedusting/omadows/main/install.ps1 | iex
```

Prefer files? Download `omadows-setup.ps1` and `Setup Omadows.cmd` into one folder and
double-click `Setup Omadows.cmd`.

## What you get

| | |
|---|---|
| **Tiling** | [komorebi](https://github.com/LGUG2Z/komorebi) + whkd: BSP tiling, 9 workspaces, 4 px gaps, Omarchy's keys on the Win key |
| **Top bar** | [YASB](https://github.com/amnweb/yasb): transparent, blurred, themed; the Windows taskbar auto-hides |
| **Launcher** | PowerToys Command Palette on Win+Space |
| **Themes** | All of Omarchy's themes. A switch recolors komorebi's borders, the bar, Windows Terminal, the starship prompt, VS Code, Brave, Obsidian, the Windows accent color and light/dark mode, and rotates the theme's wallpapers |
| **Explorer** | Through [Windhawk](https://windhawk.net) mods: Yaru-style folder, drive and This PC icons in the theme's color (folder previews included), a blurred background tinted with the theme, themed drive fill bars |
| **Look** | JetBrainsMono Nerd Font, dark mode, no desktop icons |
| **Terminal** | PowerShell 7, [starship](https://starship.rs) with Omarchy's prompt, fastfetch |

Games are never tiled: anything in a Steam, Epic, Xbox, GOG, EA, Ubisoft or Riot library or a
`X:\Games` folder, plus game folders found on the PC.

## Keys

| | | | |
|---|---|---|---|
| Win+Space launcher | Win+Enter terminal | Win+Shift+B/F/N/O/T | Brave / Files / VS Code / Obsidian / Task Manager |
| Win+W close | Win+F fullscreen | Win+T float/tile | Win+J flip layout |
| Win+arrows focus | Win+Shift+arrows move | Win+1..9 workspace | Win+Shift+1..9 send to workspace |
| Win+Tab next workspace | Win+- / Win+= resize | Win+Shift+P pause | Win+K all shortcuts |
| Win+Ctrl+Shift+Space theme picker | Win+Ctrl+Space next wallpaper | | |

## Settings

- **Omadows Settings** (Start menu): gap size, game libraries and extra folders that aren't tiled.
- **Omadows Theme** (Win+Ctrl+Shift+Space): the theme picker.
- `~/.config/omadows/omadows.ps1` from a terminal: `pick`, `set <theme>`, `next-bg`, `list`,
  `current`, `settings`, `apply-settings`, `restore-folders`.
- At the top of `omadows.ps1`: `$BarOpacity` (top bar tint) and `$ExplorerOpacity` (Explorer
  background tint), from 0 (clear) to 1 (solid).

## What it changes on your PC

**Installs** with winget: komorebi, whkd, YASB, Windhawk, PowerToys (per user), and unless
skipped PowerShell 7, starship and fastfetch. Also the JetBrainsMono Nerd Font (per user).

**Windhawk mods** (installed the way Windhawk itself does, pinned to tested versions):
Resource Redirect 1.3, Translucent Windows 1.8.2 (limited to Explorer), Windows 11 File Explorer
Styler 1.7, Explorer Visual Tweaks Dark 1.0.1 (only the drive fill bars).

**Your files**: `~/komorebi.json`, `~/applications.json`, `~/.config/whkdrc`,
`~/.config/yasb/`, `~/.config/starship.toml`, `~/.config/omadows/` (the theme tool, settings,
theme cache, logs), Windows Terminal's settings, VS Code's color theme setting (plus a generated
`local.omadows-theme` extension for themes without their own), Obsidian vault themes, a line in
your PowerShell profiles for starship, `desktop.ini` icons of Desktop/Documents/Downloads/
Pictures/Music/Videos, and Start menu shortcuts (Omadows Theme, Omadows Next Wallpaper,
Omadows Settings).

**Per-user settings**: dark mode and accent color, wallpaper slideshow, auto-hidden taskbar,
hidden desktop icons, PowerToys (Command Palette on Win+Space, FancyZones off, start with
Windows), script execution policy RemoteSigned for your user if it was unset, and two sign-in
tasks, `Omadows komorebi` and `Omadows YASB`, that start komorebi, whkd and the bar within
seconds of signing in (Windows holds back ordinary startup apps until the desktop is idle).

**Machine-wide** (the one administrator prompt): long path support, and a scheduled task
`\Omadows\Theme colors` that runs as SYSTEM and applies the parts of a theme that need admin.
It only accepts color values from `~/.config/omadows/theme-colors` and draws every icon itself.
It sets Brave's theme color policy, Explorer's folder icon (`Shell Icons`), the Windhawk mods'
settings, and keeps its files in `C:\Program Files\Omadows` and `HKLM\SOFTWARE\Omadows`.

## Uninstall

```powershell
$env:OMADOWS_UNINSTALL = 1; irm https://raw.githubusercontent.com/codedusting/omadows/main/install.ps1 | iex
```

It asks whether to remove the apps as well; set `$env:OMADOWS_REMOVE_APPS = 1` (remove) or `0`
(keep) first to answer in advance. Removed apps also lose the settings, logs and caches their
uninstallers leave behind, and their PATH entries. With the files: `omadows-setup.ps1 -Uninstall`, plus
`-RemoveApps` or `-KeepApps`. One administrator prompt.

It removes the Windhawk mods, the theme colors task, `C:\Program Files\Omadows`,
`HKLM\SOFTWARE\Omadows`, Brave's theme color policy, Explorer's folder icon override, the
sign-in tasks and Start menu shortcuts, `~/.config/omadows`, the Omadows entries in Windows
Terminal, VS Code, Obsidian and your PowerShell profiles; it puts back the special folder icons,
the always-visible taskbar, the desktop icons, Windows' default wallpaper and slideshow options.
The configs the setup replaced (komorebi, whkd, YASB, starship) come back as they were before the first install,
and the ones that didn't exist are deleted. Running programs keep Windhawk's files open; Windows
deletes those at the next restart, so restart once afterwards.

It keeps dark mode and the accent color, long path support, the script execution policy, the
`*.bak-<timestamp>` backups and any VS Code theme extensions a theme installed. Kept apps keep
their settings but no longer start with Windows.

## Testing

`tests/sandbox/run.ps1` installs Omadows on a throwaway Windows in Windows Sandbox (Windows 11
Pro or Enterprise with the Sandbox feature on) and collects checks, logs and screenshots in
`%TEMP%\omadows-sandbox\results`. It uses the published one-line install; `-Local` tests this
checkout's `omadows-setup.ps1` instead.

## Credits

- [Omarchy](https://github.com/basecamp/omarchy) by DHH and 37signals (MIT): the themes,
  colors, wallpapers, prompt and the whole idea.
- [komorebi](https://github.com/LGUG2Z/komorebi) and whkd by LGUG2Z. komorebi is free for
  personal use; commercial use needs a license.
- [YASB](https://github.com/amnweb/yasb), [Windhawk](https://windhawk.net) and the mods by m417z,
  Undisputed00x and VitalS, [PowerToys](https://github.com/microsoft/PowerToys),
  [starship](https://starship.rs), [JetBrains Mono](https://www.jetbrains.com/lp/mono/) /
  [Nerd Fonts](https://www.nerdfonts.com), and Ubuntu's Yaru icon colors.

## License

MIT
