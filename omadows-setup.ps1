#Requires -Version 5.1
<#
  omadows-setup.ps1 - Omadows: Omarchy's look and workflow on Windows 11

  Recreates the Omarchy-style Windows 11 desktop in one go:
    - komorebi + whkd   tiling window manager, Omarchy keybindings on the Win (Super) key, 4 px gaps
    - YASB              Omarchy-style transparent top bar; the Windows taskbar is set to auto-hide
    - PowerToys         Command Palette launcher on Win+Space; FancyZones off (it fights tiling)
    - Windhawk          with four mods: Resource Redirect (Yaru-style folder, drive and This PC
                        icons, folder previews included), Translucent Windows + Windows 11 File
                        Explorer Styler (Explorer's background blurred and tinted with the theme)
                        and Explorer Visual Tweaks Dark (the drive fill bars)
    - Themes            omadows.ps1, Omarchy's one-key theme switching: all 23 Omarchy
                        themes recolor the borders, bar, Windows Terminal, prompt, VS Code,
                        Brave, Explorer's icons, background and fill bars, Obsidian, the Windows
                        accent color and light/dark mode, and each theme's wallpapers rotate as
                        a slideshow. Win+Ctrl+Shift+Space picks a theme, Win+Ctrl+Space skips to
                        the next wallpaper. Starts on Tokyo Night.
    - Look              JetBrainsMono Nerd Font, dark mode, desktop icons hidden
    - Extras            PowerShell 7, starship (Omarchy's prompt), fastfetch
                        (skip them with -SkipTerminalExtras)

  One line in PowerShell (see README.md), or double-click "Setup Omadows.cmd" next to it, or run
  it from a normal (not admin) PowerShell window:

      powershell -ExecutionPolicy Bypass -File .\omadows-setup.ps1

  One UAC prompt appears for the machine-wide installs. Click Yes.
  Safe to re-run: any file it replaces is kept next to it as *.bak-<timestamp>.

  To undo everything, run it with -Uninstall (add -RemoveApps or -KeepApps to answer whether the
  apps go too; otherwise it asks). The configs it replaced come back as they were before the
  first install.

  Games are never tiled: anything in a Steam, Epic, Xbox, GOG, EA, Ubisoft or Riot library or a
  X:\Games folder, plus game folders found on the PC. Gaps are 4 screen pixels on any display.
  Both can be changed later in "Omadows Settings" (Start menu).
#>
[CmdletBinding()]
param(
    [switch]$SkipTerminalExtras,
    # undo everything; -RemoveApps / -KeepApps answer whether the apps go too (otherwise it asks)
    [switch]$Uninstall,
    [switch]$RemoveApps,
    [switch]$KeepApps,
    # internal: the elevated halves of the script, and the account they set things up for
    [switch]$InstallPhase,
    [switch]$UninstallPhase,
    [string]$UserProfile = $env:USERPROFILE,
    [string]$UserSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
# Windows PowerShell 5.1 otherwise serializes some arrays as {"value": [...], "Count": n}
Remove-TypeData System.Array -ErrorAction SilentlyContinue

$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$Utf8NoBom = New-Object System.Text.UTF8Encoding $false
$Failures = New-Object System.Collections.Generic.List[string]

# ---------------------------------------------------------------------------------------------
# Config files
# ---------------------------------------------------------------------------------------------

# Padding 1/2 measures exactly 4 physical px between tiles and at the screen edges
# (2560x1600 panel at 150% scaling; komorebi's padding-to-gap mapping is not linear).
$KomorebiJson = @'
{
  "$schema": "https://raw.githubusercontent.com/LGUG2Z/komorebi/v0.1.41/schema.json",
  "app_specific_configuration_path": "$Env:USERPROFILE/applications.json",
  "window_hiding_behaviour": "Cloak",
  "cross_monitor_move_behaviour": "Insert",
  "default_workspace_padding": 2,
  "default_container_padding": 1,
  "border": true,
  "border_width": 2,
  "border_offset": -1,
  "border_implementation": "Komorebi",
  "border_style": "System",
  "animation": {
    "enabled": true,
    "duration": 220,
    "style": "EaseOutQuint",
    "fps": 60
  },
  "border_colours": {
    "single": "#7aa2f7",
    "stack": "#9ece6a",
    "monocle": "#ad8ee6",
    "floating": "#e0af68",
    "unfocused": "#595959",
    "unfocused_locked": "#f7768e"
  },
  "ignore_rules": [
    {
      "kind": "Exe",
      "id": "yasb.exe",
      "matching_strategy": "Equals"
    },
    {
      "kind": "Title",
      "id": "Omadows Theme",
      "matching_strategy": "Equals"
    },
    {
      "kind": "Title",
      "id": "Omadows Settings",
      "matching_strategy": "Equals"
    }
  ],
  "monitors": [
    {
      "workspaces": [
        { "name": "1", "layout": "BSP" },
        { "name": "2", "layout": "BSP" },
        { "name": "3", "layout": "BSP" },
        { "name": "4", "layout": "BSP" },
        { "name": "5", "layout": "BSP" },
        { "name": "6", "layout": "BSP" },
        { "name": "7", "layout": "BSP" },
        { "name": "8", "layout": "BSP" },
        { "name": "9", "layout": "BSP" }
      ]
    }
  ]
}
'@

$Whkdrc = @'
.shell powershell

# Omarchy-style keybindings for komorebi. "win" is the Super key.

# Help and reload
win + k                 : komorebic toggle-shortcuts
win + alt + r           : komorebic reload-configuration
win + alt + shift + r   : taskkill /f /im whkd.exe; Start-Process whkd -WindowStyle hidden

# Themes, like Omarchy: theme picker and next wallpaper
win + ctrl + shift + space : Start-Process "$Env:APPDATA\Microsoft\Windows\Start Menu\Programs\Omadows Theme.lnk"
win + ctrl + space         : Start-Process "$Env:APPDATA\Microsoft\Windows\Start Menu\Programs\Omadows Next Wallpaper.lnk"

# Apps (Win+Space opens the PowerToys Command Palette launcher)
win + return            : Start-Process wt
win + shift + b         : Start-Process brave.exe
win + shift + f         : Start-Process explorer
win + shift + n         : Start-Process Code.exe
win + shift + o         : Start-Process "$Env:LOCALAPPDATA\Programs\Obsidian\Obsidian.exe"
win + shift + t         : Start-Process taskmgr

# Windows
win + w                 : komorebic close
win + f                 : komorebic toggle-monocle
win + t                 : komorebic toggle-float
win + j                 : komorebic flip-layout horizontal
win + shift + return    : komorebic promote
win + shift + p         : komorebic toggle-pause

# Focus
win + left              : komorebic focus left
win + right             : komorebic focus right
win + up                : komorebic focus up
win + down              : komorebic focus down

# Swap / move
win + shift + left      : komorebic move left
win + shift + right     : komorebic move right
win + shift + up        : komorebic move up
win + shift + down      : komorebic move down

# Resize
win + oem_minus         : komorebic resize-axis horizontal decrease
win + oem_plus          : komorebic resize-axis horizontal increase
win + shift + oem_minus : komorebic resize-axis vertical decrease
win + shift + oem_plus  : komorebic resize-axis vertical increase

# Workspaces
win + tab               : komorebic cycle-workspace next
win + shift + tab       : komorebic cycle-workspace previous
win + 1                 : komorebic focus-workspace 0
win + 2                 : komorebic focus-workspace 1
win + 3                 : komorebic focus-workspace 2
win + 4                 : komorebic focus-workspace 3
win + 5                 : komorebic focus-workspace 4
win + 6                 : komorebic focus-workspace 5
win + 7                 : komorebic focus-workspace 6
win + 8                 : komorebic focus-workspace 7
win + 9                 : komorebic focus-workspace 8

# Move window to workspace
win + shift + 1         : komorebic move-to-workspace 0
win + shift + 2         : komorebic move-to-workspace 1
win + shift + 3         : komorebic move-to-workspace 2
win + shift + 4         : komorebic move-to-workspace 3
win + shift + 5         : komorebic move-to-workspace 4
win + shift + 6         : komorebic move-to-workspace 5
win + shift + 7         : komorebic move-to-workspace 6
win + shift + 8         : komorebic move-to-workspace 7
win + shift + 9         : komorebic move-to-workspace 8
'@

$YasbConfig = @'
watch_stylesheet: true
watch_config: true
debug: false
update_check: true
show_systray: true

komorebi:
  start_command: "komorebic start --whkd"
  stop_command: "komorebic stop --whkd"
  reload_command: "komorebic reload-configuration"

bars:
  omadows-bar:
    enabled: true
    screens: ['*']
    class_name: "yasb-bar"
    style: "bar"
    alignment:
      position: "top"
      align: "center"
    blur_effect:
      enabled: true
      dark_mode: false
      round_corners: false
      border_color: "None"
    window_flags:
      always_on_top: false
      windows_app_bar: true
      hide_on_fullscreen: true
    dimensions:
      width: "100%"
      height: 30
    padding:
      top: 0
      left: 0
      bottom: 0
      right: 0
    animation:
      enabled: true
      duration: 300
    widgets:
      left: ["logo", "komorebi_workspaces"]
      center: ["clock"]
      right: ["systray", "cpu", "wifi", "volume", "battery"]

widgets:
  logo:
    type: "yasb.custom.CustomWidget"
    options:
      label: "\uf17a"
      label_alt: "\uf17a"
      class_name: "logo-widget"
      tooltip: false
      callbacks:
        on_left: "exec cmd /c start x-cmdpal:"
        on_right: "exec cmd /c start ms-settings:"

  komorebi_workspaces:
    type: "komorebi.workspaces.WorkspaceWidget"
    options:
      label_offline: ""
      label_workspace_btn: "{index}"
      label_workspace_active_btn: "{index}"
      label_workspace_populated_btn: "{index}"
      label_default_name: ""
      label_zero_index: false
      hide_empty_workspaces: true
      hide_if_offline: true
      enable_scroll_switching: true

  clock:
    type: "yasb.clock.ClockWidget"
    options:
      label: "{%A %#I:%M %p}"
      label_alt: "{%A, %d %B %Y}"
      update_interval: 1000
      calendar:
        blur: true
        round_corners: true
        round_corners_type: "normal"
        border_color: "None"
        alignment: "center"
        direction: "down"
        offset_top: 6
        show_week_numbers: false
      callbacks:
        on_left: "toggle_calendar"
        on_right: "toggle_label"

  systray:
    type: "yasb.systray.SystrayWidget"
    options:
      class_name: "systray"
      label_collapsed: "\uf104"
      label_expanded: "\uf105"
      label_position: "left"
      icon_size: 15
      pin_click_modifier: "alt"
      show_unpinned: false
      show_unpinned_button: true

  cpu:
    type: "yasb.cpu.CpuWidget"
    options:
      label: "<span>\uf4bc</span> {info[percent][total]}%"
      label_alt: "<span>\uf4bc</span> {info[freq][current]} MHz"
      update_interval: 2000
      callbacks:
        on_left: "exec cmd /c start taskmgr"
        on_right: "toggle_label"

  wifi:
    type: "yasb.wifi.WifiWidget"
    options:
      label: "<span>{wifi_icon}</span>"
      label_alt: "<span>{wifi_icon}</span> {wifi_name}"
      update_interval: 5000
      ethernet_label: "<span>{wifi_icon}</span>"
      ethernet_label_alt: "<span>{wifi_icon}</span> {ip_addr}"
      ethernet_icon: "\ueba9"
      wifi_icons: [
        "\udb82\udd2e",
        "\udb82\udd1f",
        "\udb82\udd22",
        "\udb82\udd25",
        "\udb82\udd28"
      ]
      callbacks:
        on_left: "toggle_menu"
        on_right: "toggle_label"

  volume:
    type: "yasb.volume.VolumeWidget"
    options:
      label: "<span>{icon}</span>"
      label_alt: "<span>{icon}</span> {level}"
      icons:
        "muted": "\ueee8"
        "10": "\uf026"
        "30": "\uf027"
        "60": "\uf027"
        "100": "\uf028"
      audio_menu:
        blur: true
        round_corners: true
        round_corners_type: "normal"
        border_color: "None"
        alignment: "right"
        direction: "down"
      callbacks:
        on_left: "toggle_volume_menu"
        on_right: "toggle_mute"

  battery:
    type: "yasb.battery.BatteryWidget"
    options:
      label: "<span>{icon}</span> {percent}%"
      label_alt: "<span>{icon}</span> {percent}% | {time_remaining}"
      update_interval: 5000
      hide_unsupported: true
      charging_options:
        icon_format: "{charging_icon}"
        blink_charging_icon: false
      status_icons:
        icon_charging: "\uf0e7"
        icon_critical: "\uf244"
        icon_low: "\uf243"
        icon_medium: "\uf242"
        icon_high: "\uf241"
        icon_full: "\uf240"
'@

# The theme switcher (omadows.ps1): Omarchy's themes, wallpaper slideshows and the colors of every app.
# Setup writes it to ~/.config/omadows and uses it to apply Tokyo Night.
$ThemeTool = @'
#Requires -Version 5.1
<#
  omadows.ps1 - Omadows: Omarchy-style theme switching and settings for this Windows desktop.

    omadows.ps1 pick          theme picker window             (Win+Ctrl+Shift+Space)
    omadows.ps1 next-bg       next wallpaper of the theme     (Win+Ctrl+Space)
    omadows.ps1 set <name>    apply a theme, e.g. tokyo-night
    omadows.ps1 list          list the available themes
    omadows.ps1 current       print the current theme
    omadows.ps1 restore-folders   put back the original Desktop/Documents/... folder icons
    omadows.ps1 settings      gap size and untiled (game) folders  (Start menu: Omadows Settings)
    omadows.ps1 apply-settings    write settings.json into komorebi.json (finds games the first time)
    omadows.ps1 refresh-explorer  drop the icons and folder previews Explorer cached (used by -Uninstall)

  A theme recolors the komorebi borders, the YASB bar, Windows Terminal (and with it the
  starship prompt), VS Code, Brave, Explorer's folder icons, Obsidian vaults and the Windows
  accent color and light/dark mode, and turns the theme's wallpapers into a slideshow. Colors are derived from each theme's colors.toml
  the same way Omarchy does it. Themes come from Omarchy's GitHub repo and are cached in
  ~/.config/omadows/themes.
#>
param(
    [Parameter(Position = 0)][string]$Command = 'pick',
    [Parameter(Position = 1)][string]$Name
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
# Windows PowerShell 5.1 otherwise serializes some arrays as {"value": [...], "Count": n}
Remove-TypeData System.Array -ErrorAction SilentlyContinue

$SlideshowMinutes = 5
$BarOpacity = 0.3   # tint over the blurred wallpaper: 0 = fully clear bar, 1 = solid
$ExplorerOpacity = 0.95   # the same for Explorer's background (Windhawk's Translucent Windows mod)

$Root = Join-Path $env:USERPROFILE '.config\omadows'
$ThemesDir = Join-Path $Root 'themes'
$TemplatesDir = Join-Path $Root 'templates'
$StateFile = Join-Path $Root 'current-theme'
$LogFile = Join-Path $Root 'omadows.log'
$RawBase = 'https://raw.githubusercontent.com/basecamp/omarchy/HEAD'
$ApiBase = 'https://api.github.com/repos/basecamp/omarchy/contents'
$Utf8NoBom = New-Object System.Text.UTF8Encoding $false

$YasbTemplate = @"
/* Generated by omadows.ps1 from the current Omarchy theme; edits are overwritten */
* {
    font-size: 13px;
    color: {{ foreground }};
    font-weight: 600;
    font-family: "JetBrainsMono NFP";
    margin: 0;
    padding: 0;
}

.yasb-bar {
    padding: 0;
    margin: 0;
    background-color: rgba({{ background_rgb }}, {{ bar_opacity }});
}

.widget {
    padding: 0 8px;
    margin: 0;
}

.widget .label {
    padding: 0 2px;
}

.widget .label.alt {
    padding: 0 2px;
}

.logo-widget .label {
    font-size: 15px;
    color: {{ accent }};
    padding: 0 4px 0 6px;
}

.logo-widget .label:hover {
    color: {{ mix accent bright_foreground 30% }};
}

.komorebi-workspaces {
    padding: 0 4px;
}

.komorebi-workspaces .widget-container {
    padding: 0;
}

.komorebi-workspaces .ws-btn {
    font-size: 13px;
    background-color: transparent;
    color: {{ dark_foreground }};
    border: none;
    padding: 0 7px;
    margin: 4px 1px;
    border-radius: 4px;
}

.komorebi-workspaces .ws-btn.populated {
    color: {{ foreground }};
}

.komorebi-workspaces .ws-btn.active {
    color: {{ background }};
    background-color: {{ accent }};
}

.komorebi-workspaces .ws-btn:hover {
    color: {{ bright_foreground }};
    background-color: {{ selection_background }};
}

.komorebi-workspaces .ws-btn.active:hover {
    color: {{ background }};
    background-color: {{ mix accent bright_foreground 30% }};
}

.systray {
    padding: 0 4px;
}

.systray .button {
    padding: 0 3px;
    border-radius: 4px;
}

.systray .button:hover {
    background-color: {{ selection_background }};
}

.systray .unpinned-visibility-btn {
    color: {{ dark_foreground }};
    border: none;
    padding: 0 4px;
}

/* Status widgets stay monochrome like Omarchy's bar; only low battery is coloured */
.battery-widget .widget-container .label.status-low,
.battery-widget .widget-container .label.status-critical {
    color: {{ red }};
}

.calendar,
.audio-menu,
.wifi-menu {
    background-color: rgba({{ background_rgb }}, 0.6);
}
"@

$PickerXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Omadows Theme" Width="920" Height="540" WindowStyle="None" ResizeMode="NoResize"
        WindowStartupLocation="CenterScreen" Topmost="True" ShowInTaskbar="False" Background="__BG__">
  <Border BorderBrush="__ACCENT__" BorderThickness="2">
    <Grid Margin="18">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="230"/>
        <ColumnDefinition Width="*"/>
      </Grid.ColumnDefinitions>
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="*"/>
        <RowDefinition Height="Auto"/>
      </Grid.RowDefinitions>
      <TextBlock Grid.ColumnSpan="2" Text="Theme" Foreground="__ACCENT__" FontFamily="JetBrainsMono NFP" FontSize="18" FontWeight="Bold" Margin="0,0,0,12"/>
      <ListBox x:Name="List" Grid.Row="1" Background="Transparent" Foreground="__FG__" BorderThickness="0" FontFamily="JetBrainsMono NFP" FontSize="15"
               ScrollViewer.VerticalScrollBarVisibility="Hidden">
        <ListBox.ItemContainerStyle>
          <Style TargetType="ListBoxItem">
            <Setter Property="Padding" Value="8,4"/>
            <Setter Property="Template">
              <Setter.Value>
                <ControlTemplate TargetType="ListBoxItem">
                  <Border x:Name="Bd" Background="Transparent" CornerRadius="4" Padding="{TemplateBinding Padding}">
                    <ContentPresenter/>
                  </Border>
                  <ControlTemplate.Triggers>
                    <Trigger Property="IsMouseOver" Value="True">
                      <Setter TargetName="Bd" Property="Background" Value="__SEL__"/>
                    </Trigger>
                    <Trigger Property="IsSelected" Value="True">
                      <Setter TargetName="Bd" Property="Background" Value="__ACCENT__"/>
                      <Setter Property="Foreground" Value="__BG__"/>
                    </Trigger>
                  </ControlTemplate.Triggers>
                </ControlTemplate>
              </Setter.Value>
            </Setter>
          </Style>
        </ListBox.ItemContainerStyle>
      </ListBox>
      <Image x:Name="Preview" Grid.Row="1" Grid.Column="1" Margin="18,0,0,0" Stretch="Uniform"/>
      <TextBlock x:Name="Status" Grid.Row="2" Grid.ColumnSpan="2" Foreground="__MUTED__" FontFamily="JetBrainsMono NFP" FontSize="13" Margin="0,12,0,0" Text="Enter: apply    Esc: close"/>
    </Grid>
  </Border>
</Window>
"@

$SettingsXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Omadows Settings" Width="720" Height="580" WindowStyle="None" ResizeMode="NoResize"
        WindowStartupLocation="CenterScreen" Background="__BG__">
  <Window.Resources>
    <Style TargetType="TextBlock">
      <Setter Property="FontFamily" Value="JetBrainsMono NFP"/>
      <Setter Property="Foreground" Value="__FG__"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="TextWrapping" Value="Wrap"/>
    </Style>
    <Style TargetType="Button">
      <Setter Property="Foreground" Value="__FG__"/>
      <Setter Property="FontFamily" Value="JetBrainsMono NFP"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="Margin" Value="0,0,8,0"/>
      <Setter Property="Padding" Value="14,6"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="Bd" Background="__SEL__" CornerRadius="4" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Bd" Property="Background" Value="__ACCENT__"/>
                <Setter Property="Foreground" Value="__BG__"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Window.Resources>
  <Border BorderBrush="__ACCENT__" BorderThickness="2">
    <Grid Margin="22">
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="*"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
      </Grid.RowDefinitions>
      <TextBlock Text="Settings" Foreground="__ACCENT__" FontSize="18" FontWeight="Bold" Margin="0,0,0,14"/>
      <TextBlock Grid.Row="1" Text="Gaps" Foreground="__ACCENT__" FontWeight="Bold"/>
      <TextBlock Grid.Row="2" Foreground="__MUTED__" Margin="0,2,0,6" Text="Space between tiled windows and at the screen edges, in screen pixels. Between windows it rounds down to an even number."/>
      <DockPanel Grid.Row="3" Margin="0,0,0,18">
        <TextBlock x:Name="GapValue" DockPanel.Dock="Right" Width="230" Margin="14,0,0,0" VerticalAlignment="Center"/>
        <Slider x:Name="Gap" Minimum="2" Maximum="24" TickFrequency="1" IsSnapToTickEnabled="True" VerticalAlignment="Center"/>
      </DockPanel>
      <TextBlock Grid.Row="4" Text="Not tiled" Foreground="__ACCENT__" FontWeight="Bold"/>
      <StackPanel Grid.Row="5" Margin="0,2,0,8">
        <TextBlock Foreground="__MUTED__" Margin="0,0,0,8" Text="Programs started from these places keep their own windows, so games aren't squeezed into tiles."/>
        <CheckBox x:Name="Libraries" VerticalContentAlignment="Top">
          <TextBlock Text="Game libraries, wherever they are: Steam, Epic, Xbox, GOG, EA, Ubisoft, Riot, and any X:\Games folder"/>
        </CheckBox>
      </StackPanel>
      <ListBox x:Name="Folders" Grid.Row="6" Background="__SEL__" Foreground="__FG__" BorderThickness="0" FontFamily="JetBrainsMono NFP" FontSize="13" Padding="4"/>
      <StackPanel Grid.Row="7" Orientation="Horizontal" Margin="0,10,0,0">
        <Button x:Name="Add" Content="Add folder..."/>
        <Button x:Name="Remove" Content="Remove"/>
        <Button x:Name="Find" Content="Find games"/>
      </StackPanel>
      <DockPanel Grid.Row="8" Margin="0,18,0,0">
        <Button x:Name="Close" DockPanel.Dock="Right" Content="Close" Margin="0"/>
        <Button x:Name="Apply" DockPanel.Dock="Right" Content="Apply"/>
        <TextBlock x:Name="Status" Foreground="__MUTED__" VerticalAlignment="Center" Text="Esc: close"/>
      </DockPanel>
    </Grid>
  </Border>
</Window>
"@

# ---------------------------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------------------------

if (-not ('Omadows.Wallpaper' -as [type])) {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
namespace Omadows {
    [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left, Top, Right, Bottom; }

    [ComImport, Guid("B92B56A9-8B55-4E14-9A89-0199BBB6F93B"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IDesktopWallpaper {
        void SetWallpaper([MarshalAs(UnmanagedType.LPWStr)] string monitorID, [MarshalAs(UnmanagedType.LPWStr)] string wallpaper);
        [return: MarshalAs(UnmanagedType.LPWStr)] string GetWallpaper([MarshalAs(UnmanagedType.LPWStr)] string monitorID);
        [return: MarshalAs(UnmanagedType.LPWStr)] string GetMonitorDevicePathAt(uint monitorIndex);
        uint GetMonitorDevicePathCount();
        Rect GetMonitorRECT([MarshalAs(UnmanagedType.LPWStr)] string monitorID);
        void SetBackgroundColor(uint color);
        uint GetBackgroundColor();
        void SetPosition(int position);
        int GetPosition();
        void SetSlideshow(IntPtr items);
        IntPtr GetSlideshow();
        void SetSlideshowOptions(int options, uint slideshowTick);
        void GetSlideshowOptions(out int options, out uint slideshowTick);
        void AdvanceSlideshow([MarshalAs(UnmanagedType.LPWStr)] string monitorID, int direction);
        int GetStatus();
        void Enable(int enable);
    }

    [ComImport, Guid("C2CF3110-460E-4fc1-B9D0-8A1C0C9CC4BD")] public class DesktopWallpaperClass { }

    public static class Wallpaper {
        [DllImport("shell32.dll", CharSet = CharSet.Unicode, PreserveSig = false)]
        static extern void SHCreateItemFromParsingName(string path, IntPtr bindCtx, ref Guid riid, out IntPtr item);
        [DllImport("shell32.dll", PreserveSig = false)]
        static extern void SHCreateShellItemArrayFromShellItem(IntPtr item, ref Guid riid, out IntPtr array);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint msg, UIntPtr wParam, string lParam, uint flags, uint timeout, out UIntPtr result);

        static IDesktopWallpaper Get() { return (IDesktopWallpaper)new DesktopWallpaperClass(); }

        // Rotate through every image in a folder (fill, optionally shuffled)
        public static void Slideshow(string folder, uint tickMs, bool shuffle) {
            Guid iidItem = new Guid("43826d1e-e718-42ee-bc55-a1e261c37bfe");
            Guid iidArray = new Guid("b63ea76d-1f85-456f-a19c-48159efa858b");
            IntPtr item, array;
            SHCreateItemFromParsingName(folder, IntPtr.Zero, ref iidItem, out item);
            try {
                SHCreateShellItemArrayFromShellItem(item, ref iidArray, out array);
                try {
                    IDesktopWallpaper w = Get();
                    w.SetPosition(4);
                    w.SetSlideshow(array);
                    w.SetSlideshowOptions(shuffle ? 1 : 0, tickMs);
                } finally { Marshal.Release(array); }
            } finally { Marshal.Release(item); }
        }

        public static void Next() { Get().AdvanceSlideshow(null, 0); }
        public static int Status() { return Get().GetStatus(); }
        public static string Current() { IDesktopWallpaper w = Get(); return w.GetWallpaper(w.GetMonitorDevicePathAt(0)); }

        public static void BroadcastThemeChange() {
            UIntPtr r;
            SendMessageTimeout((IntPtr)0xffff, 0x1A, UIntPtr.Zero, "ImmersiveColorSet", 2, 5000, out r);
        }

        [DllImport("shell32.dll")]
        static extern void SHChangeNotify(int eventId, uint flags, IntPtr item1, IntPtr item2);

        // SHCNE_ASSOCCHANGED: Explorer reloads its icons
        public static void RefreshIcons() { SHChangeNotify(0x08000000, 0, IntPtr.Zero, IntPtr.Zero); }

        [DllImport("shell32.dll", CharSet = CharSet.Unicode, EntryPoint = "SHChangeNotify")]
        static extern void SHChangeNotifyPath(int eventId, uint flags, string item1, IntPtr item2);

        // SHCNE_UPDATEITEM + SHCNE_UPDATEDIR with SHCNF_PATHW: Explorer rereads the folder's desktop.ini
        public static void RefreshFolder(string path) {
            SHChangeNotifyPath(0x00002000, 0x0005, path, IntPtr.Zero);
            SHChangeNotifyPath(0x00001000, 0x0005, path, IntPtr.Zero);
        }
    }

    // Explorer keeps finished folder previews (folder art included) in its thumbnail cache. Disk
    // Cleanup's "Thumbnails" handler empties it while Explorer runs; deleting the files can't.
    public static class ThumbCache {
        [ComImport, Guid("02b7e3ba-4db3-11d2-b2d9-00c04f8eec8c"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
        interface IEmptyVolumeCache2 {
            [PreserveSig] int Initialize(IntPtr hkey, [MarshalAs(UnmanagedType.LPWStr)] string volume, out IntPtr displayName, out IntPtr description, out uint flags);
            [PreserveSig] int GetSpaceUsed(out ulong used, IEmptyVolumeCacheCallBack cb);
            [PreserveSig] int Purge(ulong toFree, IEmptyVolumeCacheCallBack cb);
            [PreserveSig] int ShowProperties(IntPtr hwnd);
            [PreserveSig] int Deactivate(out uint flags);
            [PreserveSig] int InitializeEx(IntPtr hkey, [MarshalAs(UnmanagedType.LPWStr)] string volume, [MarshalAs(UnmanagedType.LPWStr)] string keyName, out IntPtr displayName, out IntPtr description, out IntPtr btnText, out uint flags);
        }
        [ComImport, Guid("6E793361-73C6-11D0-8469-00AA00442901"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
        public interface IEmptyVolumeCacheCallBack {
            [PreserveSig] int ScanProgress(ulong used, uint flags, [MarshalAs(UnmanagedType.LPWStr)] string status);
            [PreserveSig] int PurgeProgress(ulong freed, ulong toFree, uint flags, [MarshalAs(UnmanagedType.LPWStr)] string status);
        }
        [ComVisible(true), ClassInterface(ClassInterfaceType.None)]
        public class Progress : IEmptyVolumeCacheCallBack {
            public int ScanProgress(ulong used, uint flags, string status) { return 0; }
            public int PurgeProgress(ulong freed, ulong toFree, uint flags, string status) { return 0; }
        }
        [DllImport("advapi32.dll", CharSet = CharSet.Unicode)] static extern int RegOpenKeyEx(IntPtr root, string sub, uint opts, int sam, out IntPtr key);
        [DllImport("advapi32.dll")] static extern int RegCloseKey(IntPtr key);

        public static void Purge(string volume) {
            IntPtr key;
            if (RegOpenKeyEx(new IntPtr(unchecked((int)0x80000002)), "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer\\VolumeCaches\\Thumbnail Cache", 0, 0x20019, out key) != 0)
                throw new Exception("Disk Cleanup's thumbnail handler is not registered");
            try {
                var cache = (IEmptyVolumeCache2)Activator.CreateInstance(Type.GetTypeFromCLSID(new Guid("889900c3-59f3-4c2f-ae21-a409ea01e605")));
                IntPtr name, desc, btn; uint flags; ulong used;
                Marshal.ThrowExceptionForHR(cache.InitializeEx(key, volume, "Thumbnail Cache", out name, out desc, out btn, out flags));
                var cb = new Progress();
                Marshal.ThrowExceptionForHR(cache.GetSpaceUsed(out used, cb));
                Marshal.ThrowExceptionForHR(cache.Purge(used, cb));
                cache.Deactivate(out flags);
            } finally { RegCloseKey(key); }
        }
    }
}
"@
}

function Write-Log([string]$Message) {
    $line = '{0:yyyy-MM-dd HH:mm:ss} {1}' -f (Get-Date), $Message
    try { Add-Content -Path $LogFile -Value $line } catch { }
    Write-Host $Message
}

function Invoke-Native([string]$Exe, [string[]]$Arguments) {
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { & $Exe @Arguments 2>&1 | Out-Null; return $LASTEXITCODE } finally { $ErrorActionPreference = $old }
}

function Write-TextFile([string]$Path, [string]$Content) {
    $dir = Split-Path $Path
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
    [IO.File]::WriteAllText($Path, $Content, $Utf8NoBom)
}

function Get-Url([string]$Url, [string]$OutFile) {
    $dir = Split-Path $OutFile
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
    Invoke-WebRequest $Url -OutFile $OutFile -UseBasicParsing -Headers @{ 'User-Agent' = 'omadows' }
}

# Windows PowerShell 5.1 returns a JSON array as one object, so enumerate it explicitly
function Read-JsonArray([string]$Path) {
    $parsed = [IO.File]::ReadAllText($Path) | ConvertFrom-Json
    foreach ($item in $parsed) { $item }
}

function Get-DisplayName([string]$Theme) {
    (Get-Culture).TextInfo.ToTitleCase(($Theme -replace '-', ' '))
}

# ---------------------------------------------------------------------------------------------
# Colors (port of Omarchy's bin/omarchy-theme-color)
# ---------------------------------------------------------------------------------------------

function Get-Mix([string]$Start, [string]$End, [string]$Amount) {
    $a = [double]($Amount.TrimEnd('%'))
    if ($Amount.EndsWith('%') -or $a -gt 1) { $a = $a / 100 }
    $a = [Math]::Min(1.0, [Math]::Max(0.0, $a))   # double literals, or PowerShell picks the int overloads
    $s = $Start.TrimStart('#'); $e = $End.TrimStart('#')
    $parts = foreach ($i in 0, 2, 4) {
        $x = [Convert]::ToInt32($s.Substring($i, 2), 16); $y = [Convert]::ToInt32($e.Substring($i, 2), 16)
        '{0:x2}' -f [int][Math]::Floor($x * (1 - $a) + $y * $a + 0.5)
    }
    '#' + ($parts -join '')
}

function Read-ThemeColors([string]$File) {
    $c = @{}
    foreach ($line in [IO.File]::ReadAllLines($File)) {
        if ($line -notmatch '^\s*([A-Za-z0-9_-]+)\s*=\s*(.*)$') { continue }
        $key = $Matches[1]; $value = $Matches[2]
        if ($value -match '^\s*["'']([^"'']*)["'']') { $value = $Matches[1] } else { $value = ($value -replace '\s+#.*$', '').Trim() }
        $c[$key] = $value
    }

    function Set-Default([string]$Key, $Value) { if (-not $c[$Key] -and $Value) { $c[$Key] = $Value } }
    function First { foreach ($v in $args) { if ($v) { return $v } } }

    $legacyPalette = [ordered]@{ background = 'bg'; dark_background = 'dark_bg'; darker_background = 'darker_bg'; lighter_background = 'lighter_bg'; foreground = 'fg'; dark_foreground = 'dark_fg'; light_foreground = 'light_fg'; bright_foreground = 'bright_fg' }
    foreach ($k in $legacyPalette.Keys) { Set-Default $k $c[$legacyPalette[$k]] }

    Set-Default 'background' $c['color0']
    Set-Default 'foreground' $c['color7']
    if ($c['background']) { $c['color0'] = $c['background'] }
    if ($c['foreground']) { $c['color7'] = $c['foreground'] }

    $legacyAnsi = [ordered]@{ red = 'color1'; green = 'color2'; yellow = 'color3'; blue = 'color4'; magenta = 'color5'; cyan = 'color6'; bright_red = 'color9'; bright_green = 'color10'; bright_yellow = 'color11'; bright_blue = 'color12'; bright_magenta = 'color13'; bright_cyan = 'color14' }
    foreach ($k in $legacyAnsi.Keys) { Set-Default $k $c[$legacyAnsi[$k]] }
    Set-Default 'magenta' $c['purple']
    Set-Default 'bright_magenta' $c['bright_purple']

    Set-Default 'light_foreground' (First $c['color7'] $c['foreground'])
    Set-Default 'bright_foreground' (First $c['color15'] $c['foreground'])
    $c['cursor'] = $c['bright_foreground']
    Set-Default 'lighter_background' (First $c['color0'] $c['background'])
    Set-Default 'dark_foreground' (First $c['color8'] $c['foreground'])
    Set-Default 'muted' (First $c['color8'] $c['dark_foreground'])
    Set-Default 'selection' (First $c['selection_background'] $c['color8'] $c['color0'] $c['background'])
    Set-Default 'selection_background' $c['selection']
    Set-Default 'selection_foreground' $c['bright_foreground']
    Set-Default 'orange' $c['yellow']
    Set-Default 'brown' (Get-Mix $c['orange'] '#000000' '50%')
    Set-Default 'dark_background' (Get-Mix $c['background'] '#000000' '25%')
    Set-Default 'darker_background' (Get-Mix $c['background'] '#000000' '50%')
    foreach ($k in 'red', 'yellow', 'green', 'cyan', 'blue', 'magenta') { Set-Default "bright_$k" (Get-Mix $c[$k] '#ffffff' '20%') }
    Set-Default 'purple' $c['magenta']
    Set-Default 'bright_purple' $c['bright_magenta']
    # Omarchy's templates assume an accent; every shipped theme defines one
    Set-Default 'accent' $c['blue']

    $ansi = 'background', 'red', 'green', 'yellow', 'blue', 'magenta', 'cyan', 'foreground', 'muted', 'bright_red', 'bright_green', 'bright_yellow', 'bright_blue', 'bright_magenta', 'bright_cyan', 'bright_foreground'
    for ($i = 0; $i -lt 16; $i++) { Set-Default "color$i" $c[$ansi[$i]] }
    foreach ($k in $legacyPalette.Keys) { if ($c[$k]) { $c[$legacyPalette[$k]] = $c[$k] } }

    if (-not $c['mode']) { $c['mode'] = $c['theme_type'] }
    if (-not $c['mode']) {
        if ((Test-Path (Join-Path (Split-Path $File) 'light.mode'))) { $c['mode'] = 'light' }
        elseif ($c['background'] -match '^#[0-9A-Fa-f]{6}$') {
            $h = $c['background'].Substring(1)
            $lum = [Convert]::ToInt32($h.Substring(0, 2), 16) + [Convert]::ToInt32($h.Substring(2, 2), 16) + [Convert]::ToInt32($h.Substring(4, 2), 16)
            $c['mode'] = if ($lum -gt 382) { 'light' } else { 'dark' }
        } else { $c['mode'] = 'dark' }
    }
    $c['theme_type'] = $c['mode']
    $c['bar_opacity'] = $BarOpacity.ToString([Globalization.CultureInfo]::InvariantCulture)
    return $c
}

# First color of a value that may be a hex, rgb(...)/rgba(...) or a Hyprland gradient
function Get-GradientStart([hashtable]$Colors, [string]$Key, [string]$Fallback) {
    $spec = if ($Colors[$Key]) { $Colors[$Key] } else { $Fallback }
    $first = ($spec -split '\s+' | Where-Object { $_ -and $_ -notmatch 'deg$' } | Select-Object -First 1)
    if ($Colors[$first]) { $first = $Colors[$first] }
    if ($first -match '^#([0-9A-Fa-f]{6})') { return '#' + $Matches[1].ToLower() }
    if ($first -match '^rgba?\(([0-9A-Fa-f]{6})') { return '#' + $Matches[1].ToLower() }
    if ($first -match '^rgba?\((\d+),\s*(\d+),\s*(\d+)') { return '#{0:x2}{1:x2}{2:x2}' -f [int]$Matches[1], [int]$Matches[2], [int]$Matches[3] }
    if ($first -match '^0x[0-9A-Fa-f]{2}([0-9A-Fa-f]{6})$') { return '#' + $Matches[1].ToLower() }
    return $Fallback
}

# Fills {{ key }}, {{ key_strip }}, {{ key_rgb }} and {{ mix a b N% }} like Omarchy's templates
function Expand-Template([string]$Text, [hashtable]$Colors) {
    [regex]::Replace($Text, '\{\{\s*([^}]+?)\s*\}\}', {
        param($m)
        $token = $m.Groups[1].Value
        $parts = $token -split '\s+'
        if ($parts[0] -in 'mix', 'mix_strip', 'mix_rgb' -and $parts.Count -eq 4 -and $Colors[$parts[1]] -match '^#[0-9A-Fa-f]{6}$' -and $Colors[$parts[2]] -match '^#[0-9A-Fa-f]{6}$') {
            $v = Get-Mix $Colors[$parts[1]] $Colors[$parts[2]] $parts[3]
            if ($parts[0] -eq 'mix_strip') { return $v.Substring(1) }
            if ($parts[0] -eq 'mix_rgb') { return '{0},{1},{2}' -f [Convert]::ToInt32($v.Substring(1, 2), 16), [Convert]::ToInt32($v.Substring(3, 2), 16), [Convert]::ToInt32($v.Substring(5, 2), 16) }
            return $v
        }
        if ($Colors.ContainsKey($token)) { return $Colors[$token] }
        if ($token -match '^(.+)_strip$' -and $Colors[$Matches[1]]) { return $Colors[$Matches[1]].TrimStart('#') }
        if ($token -match '^(.+)_rgb$' -and $Colors[$Matches[1]] -match '^#([0-9A-Fa-f]{6})$') {
            $h = $Matches[1]
            return '{0},{1},{2}' -f [Convert]::ToInt32($h.Substring(0, 2), 16), [Convert]::ToInt32($h.Substring(2, 2), 16), [Convert]::ToInt32($h.Substring(4, 2), 16)
        }
        return $m.Value
    })
}

# ---------------------------------------------------------------------------------------------
# Theme files
# ---------------------------------------------------------------------------------------------

function Get-ThemeList {
    $cache = Join-Path $Root 'themes.json'
    try {
        $items = Invoke-RestMethod "$ApiBase/themes" -UseBasicParsing -Headers @{ 'User-Agent' = 'omadows' }
        $names = @($items | Where-Object { $_.type -eq 'dir' } | ForEach-Object { $_.name } | Sort-Object)
        if ($names.Count) { Write-TextFile $cache (ConvertTo-Json -InputObject $names); return $names }
    } catch { }
    if (Test-Path $cache) { return @(Read-JsonArray $cache) }
    return @(Get-ChildItem $ThemesDir -Directory -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
}

function Get-ThemeDir([string]$Theme) {
    if ($Theme -notmatch '^[a-z0-9][a-z0-9-]*$') { throw "invalid theme name '$Theme'" }
    $dir = Join-Path $ThemesDir $Theme
    $colors = Join-Path $dir 'colors.toml'
    if (-not (Test-Path $colors)) {
        try { Get-Url "$RawBase/themes/$Theme/colors.toml" $colors }
        catch { Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue; throw "theme '$Theme' not found" }
    }
    # optional per-theme overrides; most themes don't ship them, so the marker records that we looked
    $marker = Join-Path $dir '.optional-files-v2'
    if (-not (Test-Path $marker)) {
        foreach ($f in 'vscode.json', 'chromium.theme', 'icons.theme') {
            $target = Join-Path $dir $f
            try { Get-Url "$RawBase/themes/$Theme/$f" $target } catch { Remove-Item $target -ErrorAction SilentlyContinue }
        }
        Write-TextFile $marker ''
    }
    return $dir
}

function Get-Preview([string]$Theme) {
    $file = Join-Path (Join-Path $ThemesDir $Theme) 'preview.png'
    if (-not (Test-Path $file)) { Get-Url "$RawBase/themes/$Theme/preview.png" $file }
    return $file
}

function Get-Template([string]$FileName) {
    $file = Join-Path $TemplatesDir $FileName
    if (-not (Test-Path $file)) { Get-Url "$RawBase/default/themed/$FileName" $file }
    return [IO.File]::ReadAllText($file)
}

# Downloads the theme's wallpapers once, as JPEG (Windows can't use .webp as wallpaper)
function Sync-Backgrounds([string]$Theme, [string]$Dir) {
    $bgDir = Join-Path $Dir 'backgrounds'
    $listFile = Join-Path $Dir 'backgrounds.json'
    if (-not (Test-Path $listFile)) {
        $items = Invoke-RestMethod "$ApiBase/themes/$Theme/backgrounds" -UseBasicParsing -Headers @{ 'User-Agent' = 'omadows' }
        $names = @($items | Where-Object { $_.type -eq 'file' -and $_.name -match '\.(webp|jpe?g|png)$' -and $_.name -notmatch '^omarchy\.' } | ForEach-Object { $_.name })
        Write-TextFile $listFile (ConvertTo-Json -InputObject $names)
    }
    $names = @(Read-JsonArray $listFile)
    New-Item -ItemType Directory -Force $bgDir | Out-Null
    Add-Type -AssemblyName PresentationCore
    foreach ($n in $names) {
        $jpg = Join-Path $bgDir ([IO.Path]::GetFileNameWithoutExtension($n) + '.jpg')
        if (Test-Path $jpg) { continue }
        $src = Join-Path $env:TEMP ("omadows-" + [guid]::NewGuid().ToString('n') + [IO.Path]::GetExtension($n))
        try {
            Get-Url "$RawBase/themes/$Theme/backgrounds/$n" $src
            if ($n -match '\.jpe?g$') { Copy-Item $src $jpg; continue }
            $in = [IO.File]::OpenRead($src)
            try {
                $decoder = [Windows.Media.Imaging.BitmapDecoder]::Create($in, [Windows.Media.Imaging.BitmapCreateOptions]::None, [Windows.Media.Imaging.BitmapCacheOption]::OnLoad)
                $encoder = New-Object Windows.Media.Imaging.JpegBitmapEncoder
                $encoder.QualityLevel = 95
                $encoder.Frames.Add($decoder.Frames[0])
                $out = [IO.File]::Create($jpg)
                try { $encoder.Save($out) } finally { $out.Close() }
            } finally { $in.Close() }
        } catch {
            Remove-Item $jpg -ErrorAction SilentlyContinue
            Write-Log "  ! wallpaper $n skipped: $($_.Exception.Message)"
        } finally {
            Remove-Item $src -ErrorAction SilentlyContinue
        }
    }
    return $bgDir
}

# ---------------------------------------------------------------------------------------------
# Appliers
# ---------------------------------------------------------------------------------------------

# The theme's accent drives Windows' accent palette (Start, Settings, toggles, focus rings, Command Palette)
function Set-Accent([hashtable]$Colors) {
    $accent = $Colors['accent']
    if ($accent -notmatch '^#[0-9A-Fa-f]{6}$') { return }
    $rgb = { param($hex) $h = $hex.TrimStart('#'); 0, 2, 4 | ForEach-Object { [Convert]::ToByte($h.Substring($_, 2), 16) } }
    # Windows stores these as 0xAABBGGRR
    $abgr = { param($hex) $r, $g, $b = & $rgb $hex; [BitConverter]::ToInt32([byte[]]@($r, $g, $b, 255), 0) }
    # palette order: light3, light2, light1, base, dark1, dark2, dark3, spare
    $shades = @((Get-Mix $accent '#ffffff' '70%'), (Get-Mix $accent '#ffffff' '45%'), (Get-Mix $accent '#ffffff' '20%'), $accent,
                (Get-Mix $accent '#000000' '15%'), (Get-Mix $accent '#000000' '35%'), (Get-Mix $accent '#000000' '60%'), (Get-Mix $accent '#000000' '60%'))
    $palette = [byte[]]@(foreach ($s in $shades) { & $rgb $s; 0 })
    $k = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent'
    if (-not (Test-Path $k)) { New-Item $k -Force | Out-Null }
    Set-ItemProperty $k -Name AccentPalette -Value $palette -Type Binary
    Set-ItemProperty $k -Name AccentColorMenu -Value (& $abgr $accent) -Type DWord
    Set-ItemProperty $k -Name StartColorMenu -Value (& $abgr $shades[4]) -Type DWord
    $d = 'HKCU:\Software\Microsoft\Windows\DWM'
    $r, $g, $b = & $rgb $accent
    Set-ItemProperty $d -Name AccentColor -Value (& $abgr $accent) -Type DWord
    Set-ItemProperty $d -Name ColorizationColor -Value ([BitConverter]::ToInt32([byte[]]@($b, $g, $r, 0xc4), 0)) -Type DWord
    Set-ItemProperty $d -Name ColorizationAfterglow -Value ([BitConverter]::ToInt32([byte[]]@($b, $g, $r, 0xc4), 0)) -Type DWord
    [Omadows.Wallpaper]::BroadcastThemeChange()
}

# Omarchy pairs each theme with a Yaru icon color (icons.theme, e.g. "Yaru-magenta");
# these are Yaru's own accent colors, from common/accent-colors.scss.in
$YaruColors = @{
    'default' = '#E95420'; 'bark' = '#787859'; 'sage' = '#657B69'; 'olive' = '#4B8501'; 'viridian' = '#03875B'
    'prussiangreen' = '#308280'; 'blue' = '#0073E5'; 'purple' = '#7764D8'; 'magenta' = '#B34CB3'; 'mate' = '#87a556'
    'red' = '#DA3450'; 'yellow' = '#C88800'; 'wartybrown' = '#B39169'
}

function Get-FolderColor([hashtable]$Colors, [string]$Dir) {
    $file = Join-Path $Dir 'icons.theme'
    if (Test-Path $file) {
        $name = [IO.File]::ReadAllText($file).Trim().ToLower()
        if ($name -eq 'yaru') { return $YaruColors['default'].ToLower() }
        if ($name -match '^yaru-([a-z]+)' -and $YaruColors[$Matches[1]]) { return $YaruColors[$Matches[1]].ToLower() }
    }
    return $Colors['accent'].ToLower()
}

# Yaru-style special folder icons: the plain folder (same art as the system folder icon the
# "Theme colors" task draws) with a symbol in a darker shade, details cut out in a lighter one.
# Paths are on a 256 grid.
$FolderGlyphs = @{
    desktop   = @{ dark = @('M 100,134 Q 100,128 106,128 L 150,128 Q 156,128 156,134 L 156,168 Q 156,174 150,174 L 106,174 Q 100,174 100,168 Z', 'M 122,174 L 134,174 L 136,184 L 120,184 Z', 'M 110,184 L 146,184 Q 150,184 150,188 L 150,190 L 106,190 L 106,188 Q 106,184 110,184 Z'); light = @('M 106,134 L 150,134 L 150,168 L 106,168 Z') }
    documents = @{ dark = @('M 108,126 L 138,126 L 154,142 L 154,186 Q 154,192 148,192 L 108,192 Q 102,192 102,186 L 102,132 Q 102,126 108,126 Z'); light = @('M 138,126 L 138,142 L 154,142 Z', 'M 112,152 L 144,152 L 144,157 L 112,157 Z', 'M 112,164 L 144,164 L 144,169 L 112,169 Z', 'M 112,176 L 134,176 L 134,181 L 112,181 Z') }
    downloads = @{ dark = @('M 121,124 L 135,124 L 135,152 L 150,152 L 128,176 L 106,152 L 121,152 Z', 'M 104,182 L 152,182 Q 156,182 156,186 L 156,188 Q 156,192 152,192 L 104,192 Q 100,192 100,188 L 100,186 Q 100,182 104,182 Z'); light = @() }
    pictures  = @{ dark = @('M 106,128 L 150,128 Q 156,128 156,134 L 156,184 Q 156,190 150,190 L 106,190 Q 100,190 100,184 L 100,134 Q 100,128 106,128 Z'); light = @('M 106,180 L 122,158 L 134,172 L 140,165 L 150,180 Z', 'M 136,146 A 6,6 0 1 1 148,146 A 6,6 0 1 1 136,146 Z') }
    music     = @{ dark = @('M 124,130 L 152,122 L 152,172 A 11,10 0 1 1 145,163 L 145,140 L 131,144 L 131,180 A 11,10 0 1 1 124,171 Z'); light = @() }
    videos    = @{ dark = @('M 106,134 L 150,134 Q 156,134 156,140 L 156,180 Q 156,186 150,186 L 106,186 Q 100,186 100,180 L 100,140 Q 100,134 106,134 Z'); light = @('M 120,145 L 142,160 L 120,175 Z') }
}

function New-FolderPng([int]$Size, [string]$Accent, [string]$Glyph) {
    $brush = { param($hex) $b = New-Object Windows.Media.SolidColorBrush ([Windows.Media.ColorConverter]::ConvertFromString($hex)); $b.Freeze(); $b }
    $front = New-Object Windows.Media.LinearGradientBrush ([Windows.Media.ColorConverter]::ConvertFromString((Get-Mix $Accent '#ffffff' '18%'))), ([Windows.Media.ColorConverter]::ConvertFromString($Accent)), 90
    $front.Freeze()
    $dv = New-Object Windows.Media.DrawingVisual
    $dc = $dv.RenderOpen()
    $dc.PushTransform((New-Object Windows.Media.ScaleTransform ($Size / 256.0), ($Size / 256.0)))
    $dc.DrawGeometry((& $brush (Get-Mix $Accent '#000000' '28%')), $null, [Windows.Media.Geometry]::Parse('M 28,62 Q 28,44 46,44 L 98,44 Q 108,44 114,52 L 122,62 L 210,62 Q 228,62 228,80 L 228,196 Q 228,214 210,214 L 46,214 Q 28,214 28,196 Z'))
    $dc.DrawRoundedRectangle((& $brush '#F4F4F4'), $null, (New-Object Windows.Rect 44, 74, 168, 90), 6, 6)
    $dc.DrawRoundedRectangle($front, $null, (New-Object Windows.Rect 28, 96, 200, 118), 16, 16)
    $dc.DrawRectangle((& $brush '#40FFFFFF'), $null, (New-Object Windows.Rect 44, 96, 168, 3))
    if ($Glyph) {
        # small icons get a bigger symbol so it stays readable
        $k = if ($Size -le 48) { 1.45 } else { 1.0 }
        $dc.PushTransform((New-Object Windows.Media.ScaleTransform $k, $k, 128, 158))
        foreach ($p in $FolderGlyphs[$Glyph].dark) { $dc.DrawGeometry((& $brush (Get-Mix $Accent '#000000' '38%')), $null, [Windows.Media.Geometry]::Parse($p)) }
        foreach ($p in $FolderGlyphs[$Glyph].light) { $dc.DrawGeometry((& $brush (Get-Mix $Accent '#ffffff' '30%')), $null, [Windows.Media.Geometry]::Parse($p)) }
        $dc.Pop()
    }
    $dc.Pop()
    $dc.Close()
    $rtb = New-Object Windows.Media.Imaging.RenderTargetBitmap $Size, $Size, 96, 96, ([Windows.Media.PixelFormats]::Pbgra32)
    $rtb.Render($dv)
    $enc = New-Object Windows.Media.Imaging.PngBitmapEncoder
    $enc.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($rtb))
    $ms = New-Object IO.MemoryStream
    $enc.Save($ms)
    return , $ms.ToArray()
}

# ICO container with PNG-compressed entries (supported since Windows Vista)
function Write-FolderIco([string]$Path, [string]$Accent, [string]$Glyph) {
    $sizes = 16, 20, 24, 32, 40, 48, 64, 96, 128, 256
    $images = foreach ($s in $sizes) { , (New-FolderPng $s $Accent $Glyph) }
    $ms = New-Object IO.MemoryStream
    $w = New-Object IO.BinaryWriter $ms
    $w.Write([uint16]0); $w.Write([uint16]1); $w.Write([uint16]$sizes.Count)
    $offset = 6 + 16 * $sizes.Count
    for ($i = 0; $i -lt $sizes.Count; $i++) {
        $dim = if ($sizes[$i] -ge 256) { 0 } else { $sizes[$i] }
        $w.Write([byte]$dim); $w.Write([byte]$dim); $w.Write([byte]0); $w.Write([byte]0)
        $w.Write([uint16]1); $w.Write([uint16]32)
        $w.Write([uint32]$images[$i].Length); $w.Write([uint32]$offset)
        $offset += $images[$i].Length
    }
    foreach ($img in $images) { $w.Write($img) }
    $w.Flush()
    $dir = Split-Path $Path
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
    [IO.File]::WriteAllBytes($Path, $ms.ToArray())
}

# The sidebar, Home and This PC show these folders through shell classes whose icon (DefaultIcon)
# Windows lets each user override under HKCU\...\Explorer\CLSID, no admin needed
$FolderClasses = [ordered]@{
    desktop   = @('{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}')
    documents = @('{A8CDFF1C-4878-43be-B5FD-F8091C1C60D0}', '{d3162b92-9365-467a-956b-92703aca08af}')
    downloads = @('{374DE290-123F-4565-9164-39C4925E467B}', '{088e3905-0323-4b02-9826-5d99428e115f}')
    pictures  = @('{3ADD1653-EB32-4CB0-BBD7-DFA0ABB5ACCA}', '{24ad3ad4-a569-4530-98e1-ab02f9417aa8}')
    music     = @('{1CF1260C-4DD0-4EBB-811F-33C572699FDE}', '{3dfdf296-dbec-4fb4-81d1-6a3438bcf4de}')
    videos    = @('{A0953C92-50DC-43BF-BE83-3742FED03C9C}', '{f86fa3ab-70d2-4fc7-9c99-fcbf05467f3a}')
}
$ClassOverrides = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\CLSID'

function Get-SpecialFolders {
    $downloads = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders' -ErrorAction SilentlyContinue).'{374DE290-123F-4565-9164-39C4925E467B}'
    [ordered]@{
        desktop   = [Environment]::GetFolderPath('Desktop')
        documents = [Environment]::GetFolderPath('MyDocuments')
        downloads = if ($downloads) { [Environment]::ExpandEnvironmentVariables($downloads) } else { Join-Path $env:USERPROFILE 'Downloads' }
        pictures  = [Environment]::GetFolderPath('MyPictures')
        music     = [Environment]::GetFolderPath('MyMusic')
        videos    = [Environment]::GetFolderPath('MyVideos')
    }
}

# desktop.ini is hidden+system and usually UTF-16; keep its encoding and attributes intact
function Write-DesktopIni([string]$Path, [string[]]$Lines, [Text.Encoding]$Encoding) {
    $attrs = if (Test-Path -LiteralPath $Path) { (Get-Item -LiteralPath $Path -Force).Attributes } else { [IO.FileAttributes]'Hidden, System, Archive' }
    if (Test-Path -LiteralPath $Path) { (Get-Item -LiteralPath $Path -Force).Attributes = 'Normal' }
    [IO.File]::WriteAllLines($Path, $Lines, $Encoding)
    (Get-Item -LiteralPath $Path -Force).Attributes = $attrs
}

function Set-SpecialFolders([hashtable]$Colors, [string]$Dir) {
    $color = (Get-FolderColor $Colors $Dir).TrimStart('#')
    $iconDir = Join-Path $Root "icons\$color"
    $backupDir = Join-Path $Root 'special-folders-backup'
    Add-Type -AssemblyName PresentationCore, WindowsBase
    $folders = Get-SpecialFolders
    foreach ($name in $folders.Keys) {
        $folder = $folders[$name]
        if (-not $folder -or -not (Test-Path -LiteralPath $folder)) { continue }
        $ico = Join-Path $iconDir "$name.ico"
        if (-not (Test-Path $ico)) { Write-FolderIco $ico ('#' + $color) $name }
        $ini = Join-Path $folder 'desktop.ini'
        $backup = Join-Path $backupDir "$name.ini"
        if (-not (Test-Path $backup)) {
            New-Item -ItemType Directory -Force $backupDir | Out-Null
            if (Test-Path -LiteralPath $ini) { Copy-Item -LiteralPath $ini $backup -Force; (Get-Item $backup -Force).Attributes = 'Normal' }
            else { Write-TextFile $backup '' }
        }
        $encoding = New-Object System.Text.UnicodeEncoding $false, $true
        $lines = @('[.ShellClassInfo]')
        if (Test-Path -LiteralPath $ini) {
            $bytes = [IO.File]::ReadAllBytes($ini)
            if (-not ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE)) { $encoding = New-Object System.Text.UTF8Encoding $false }
            $lines = @([IO.File]::ReadAllLines($ini))
        }
        $entry = "IconResource=$ico,0"
        $i = [Array]::FindIndex([string[]]$lines, [Predicate[string]] { param($l) $l -match '^\s*IconResource\s*=' })
        if ($i -ge 0) { $lines[$i] = $entry }
        else {
            $h = [Array]::FindIndex([string[]]$lines, [Predicate[string]] { param($l) $l -match '^\s*\[\.ShellClassInfo\]' })
            if ($h -lt 0) { $lines = @('[.ShellClassInfo]', $entry) + $lines } else { $lines = @($lines[0..$h]) + $entry + @($lines | Select-Object -Skip ($h + 1)) }
        }
        Write-DesktopIni $ini $lines $encoding
        # desktop.ini is only honored on read-only or system folders (special folders already are)
        $fi = Get-Item -LiteralPath $folder -Force
        if (-not ($fi.Attributes -band [IO.FileAttributes]::ReadOnly)) { $fi.Attributes = $fi.Attributes -bor [IO.FileAttributes]::ReadOnly }
        foreach ($clsid in $FolderClasses[$name]) {
            $k = "$ClassOverrides\$clsid\DefaultIcon"
            if (-not (Test-Path $k)) { New-Item $k -Force | Out-Null }
            Set-ItemProperty $k -Name '(default)' -Value "$ico,0"
        }
        [Omadows.Wallpaper]::RefreshFolder($folder)
    }
    [Omadows.Wallpaper]::RefreshIcons()
    # icons of earlier themes are no longer referenced
    Get-ChildItem (Join-Path $Root 'icons') -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne $color } | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}

function Restore-SpecialFolders {
    $backupDir = Join-Path $Root 'special-folders-backup'
    $folders = Get-SpecialFolders
    foreach ($name in $folders.Keys) {
        $backup = Join-Path $backupDir "$name.ini"
        $folder = $folders[$name]
        if (-not (Test-Path $backup) -or -not $folder -or -not (Test-Path -LiteralPath $folder)) { continue }
        $ini = Join-Path $folder 'desktop.ini'
        if ((Get-Item $backup).Length -eq 0) {
            if (Test-Path -LiteralPath $ini) { (Get-Item -LiteralPath $ini -Force).Attributes = 'Normal'; Remove-Item -LiteralPath $ini -Force }
        } else {
            $attrs = if (Test-Path -LiteralPath $ini) { (Get-Item -LiteralPath $ini -Force).Attributes } else { [IO.FileAttributes]'Hidden, System, Archive' }
            if (Test-Path -LiteralPath $ini) { (Get-Item -LiteralPath $ini -Force).Attributes = 'Normal' }
            Copy-Item $backup $ini -Force
            (Get-Item -LiteralPath $ini -Force).Attributes = $attrs
        }
        [Omadows.Wallpaper]::RefreshFolder($folder)
    }
    # drop only the overrides this script adds; Windows keeps its own in the same place
    foreach ($clsid in ($FolderClasses.Values | ForEach-Object { $_ })) {
        $k = "$ClassOverrides\$clsid"
        Remove-Item "$k\DefaultIcon" -Recurse -Force -ErrorAction SilentlyContinue
        if ((Test-Path $k) -and -not (Get-ChildItem $k) -and -not (Get-Item $k).Property) { Remove-Item $k -Force }
    }
    [Omadows.Wallpaper]::RefreshIcons()
    [void](Invoke-Native "$env:SystemRoot\System32\ie4uinit.exe" @('-show'))
}

function Set-WindowsMode([hashtable]$Colors) {
    $light = [int]($Colors['mode'] -eq 'light')
    $k = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
    if (-not (Test-Path $k)) { New-Item $k -Force | Out-Null }
    Set-ItemProperty $k -Name AppsUseLightTheme -Value $light -Type DWord
    Set-ItemProperty $k -Name SystemUsesLightTheme -Value $light -Type DWord
    [Omadows.Wallpaper]::BroadcastThemeChange()
}

function Set-Komorebi([hashtable]$Colors) {
    $file = Join-Path $env:USERPROFILE 'komorebi.json'
    if (-not (Test-Path $file)) { return }
    $block = @(
        '"border_colours": {'
        ('  "single": "{0}",' -f (Get-GradientStart $Colors 'hyprland_active_border' $Colors['accent']))
        ('  "stack": "{0}",' -f $Colors['green'])
        ('  "monocle": "{0}",' -f $Colors['magenta'])
        ('  "floating": "{0}",' -f $Colors['yellow'])
        ('  "unfocused": "{0}",' -f (Get-GradientStart $Colors 'hyprland_inactive_border' '#595959'))
        ('  "unfocused_locked": "{0}"' -f $Colors['red'])
        '}'
    ) -join "`n  "
    $text = [IO.File]::ReadAllText($file)
    # an explicit theme overrides border_colours, so drop it
    $text = [regex]::Replace($text, '\s*"theme"\s*:\s*\{[^{}]*\},?', '')
    if ($text -match '"border_colours"\s*:\s*\{[^{}]*\}') {
        $text = [regex]::Replace($text, '"border_colours"\s*:\s*\{[^{}]*\}', { param($m) $block })
    } else {
        $text = ([regex]'\{').Replace($text, "{`n  $block,", 1)
    }
    Write-TextFile $file $text
    $komorebic = Join-Path $env:ProgramFiles 'komorebi\bin\komorebic.exe'
    if ((Test-Path $komorebic) -and (Get-Process komorebi -ErrorAction SilentlyContinue)) { [void](Invoke-Native $komorebic @('reload-configuration')) }
}

# ---------------------------------------------------------------------------------------------
# Layout settings (settings.json): the gap size and the folders whose programs komorebi leaves
# untiled, so games keep their own window. "settings" edits them in a window.
# ---------------------------------------------------------------------------------------------

$SettingsFile = Join-Path $Root 'settings.json'

# Game launchers' library folders, matched anywhere in a program's path, so games installed later
# are covered too
$GameLibraryPatterns = @(
    '\\steamapps\\common\\', '\\Epic Games\\', '\\XboxGames\\', '\\GOG (Games|Galaxy\\Games)\\',
    '\\EA Games\\', '\\Ubisoft Game Launcher\\games\\', '\\Riot Games\\', '^[a-z]:\\Games\\'
)

function Read-LayoutSettings {
    $s = [ordered]@{ gap = 4; gameLibraries = $true; untiledFolders = @() }
    if (Test-Path $SettingsFile) {
        $j = Get-Content $SettingsFile -Raw | ConvertFrom-Json
        if ($null -ne $j.gap) { $s.gap = [int]$j.gap }
        if ($null -ne $j.gameLibraries) { $s.gameLibraries = [bool]$j.gameLibraries }
        if ($j.untiledFolders) { $s.untiledFolders = @($j.untiledFolders | ForEach-Object { [string]$_ }) }
    } else {
        $s.untiledFolders = @(Find-GameFolders)
    }
    return $s
}

function Write-LayoutSettings($Settings) {
    Write-TextFile $SettingsFile ([pscustomobject]$Settings | ConvertTo-Json)
}

function Test-GameLibraryPath([string]$Folder) {
    $probe = $Folder.TrimEnd('\') + '\game\game.exe'
    foreach ($p in $GameLibraryPatterns) { if ($probe -match "(?i)$p") { return $true } }
    return $false
}

# Install folders of games the library patterns miss (custom Epic, GOG, EA and Ubisoft locations):
# the folder holding the game, or the game's own folder when that would be a system-wide one
function Find-GameFolders {
    $games = @()
    $epic = Join-Path $env:ProgramData 'Epic\EpicGamesLauncher\Data\Manifests'
    if (Test-Path $epic) {
        foreach ($f in Get-ChildItem $epic -Filter *.item -ErrorAction SilentlyContinue) {
            try { $games += (Get-Content $f.FullName -Raw | ConvertFrom-Json).InstallLocation } catch { }
        }
    }
    $keys = @(
        @('HKLM:\SOFTWARE\WOW6432Node\GOG.com\Games', 'path'),
        @('HKLM:\SOFTWARE\WOW6432Node\EA Games', 'Install Dir'),
        @('HKLM:\SOFTWARE\WOW6432Node\Electronic Arts', 'Install Dir'),
        @('HKLM:\SOFTWARE\WOW6432Node\Ubisoft\Launcher\Installs', 'InstallDir')
    )
    foreach ($k in $keys) {
        foreach ($sub in Get-ChildItem $k[0] -ErrorAction SilentlyContinue) {
            $v = (Get-ItemProperty $sub.PSPath -ErrorAction SilentlyContinue).($k[1])
            if ($v) { $games += [string]$v }
        }
    }
    $broad = @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:ProgramData, $env:USERPROFILE, $env:SystemRoot, "$env:LOCALAPPDATA\Programs") |
        Where-Object { $_ } | ForEach-Object { $_.TrimEnd('\') }
    $found = foreach ($g in $games) {
        if (-not $g) { continue }
        $g = $g.Replace('/', '\').TrimEnd('\')
        if (-not (Test-Path -LiteralPath $g)) { continue }
        $parent = Split-Path $g
        $folder = if (-not $parent -or $parent.Length -le 3 -or $broad -contains $parent) { $g } else { $parent }
        if (-not (Test-GameLibraryPath $folder)) { $folder }
    }
    @($found | Sort-Object -Unique)
}

# Replaces one top-level value in a JSON text, keeping the rest of the file as written
function Set-JsonValue([string]$Text, [string]$Key, [string]$Value) {
    $m = [regex]::Match($Text, '"' + [regex]::Escape($Key) + '"\s*:\s*')
    if (-not $m.Success) { return ([regex]'\{').Replace($Text, "{`n  `"$Key`": $Value,", 1) }
    $start = $m.Index + $m.Length
    $i = $start; $depth = 0; $inString = $false
    for (; $i -lt $Text.Length; $i++) {
        $ch = $Text[$i]
        if ($inString) {
            if ($ch -eq '\') { $i++ } elseif ($ch -eq '"') { $inString = $false; if ($depth -eq 0) { $i++; break } }
            continue
        }
        if ($ch -eq '"') { $inString = $true }
        elseif ($ch -eq '{' -or $ch -eq '[') { $depth++ }
        elseif ($ch -eq '}' -or $ch -eq ']') { $depth--; if ($depth -eq 0) { $i++; break }; if ($depth -lt 0) { break } }
        elseif ($depth -eq 0 -and ($ch -eq ',' -or $ch -eq "`n")) { break }
    }
    $Text.Substring(0, $start) + $Value + $Text.Substring($i)
}

# Writes the gap and untiled folders into komorebi.json. Each tile edge moves in by container
# padding + border width + border offset, the screen edge also by workspace padding, all in screen
# pixels: between windows 2 x (container + border width + offset), at the edges workspace padding
# plus that once. Rules of other kinds (programs, window titles) are kept.
function Set-LayoutSettings($Settings) {
    $file = Join-Path $env:USERPROFILE 'komorebi.json'
    if (-not (Test-Path $file)) { throw 'komorebi.json not found' }
    $text = [IO.File]::ReadAllText($file)
    $cfg = $text | ConvertFrom-Json
    $border = [int]$cfg.border_width + [int]$cfg.border_offset
    $gap = [Math]::Max(2, [int]$Settings.gap)
    $half = [int][Math]::Floor($gap / 2)
    $text = Set-JsonValue $text 'default_container_padding' ([string]($half - $border))
    $text = Set-JsonValue $text 'default_workspace_padding' ([string]($gap - $half))

    $rules = @($cfg.ignore_rules | Where-Object { $_ -and $_.kind -ne 'Path' })
    foreach ($title in 'Omadows Theme', 'Omadows Settings') {
        if (-not ($rules | Where-Object { $_.kind -eq 'Title' -and $_.id -eq $title })) { $rules += [pscustomobject]@{ kind = 'Title'; id = $title; matching_strategy = 'Equals' } }
    }
    $paths = @()
    if ($Settings.gameLibraries) { $paths += $GameLibraryPatterns | ForEach-Object { "(?i)$_" } }
    foreach ($f in $Settings.untiledFolders) {
        $escaped = [regex]::Replace($f.TrimEnd('\'), '[\\.+*?()|\[\]{}^$#&~-]', { param($m) '\' + $m.Value })
        $paths += "(?i)^$escaped\\"
    }
    $paths = @($paths | ForEach-Object { [pscustomobject]@{ kind = 'Path'; id = $_; matching_strategy = 'Regex' } })
    $items = foreach ($r in @($paths) + @($rules)) {
        '    { "kind": ' + (ConvertTo-Json ([string]$r.kind)) + ', "id": ' + (ConvertTo-Json ([string]$r.id)) + ', "matching_strategy": ' + (ConvertTo-Json ([string]$r.matching_strategy)) + ' }'
    }
    $text = Set-JsonValue $text 'ignore_rules' ("[`n" + ($items -join ",`n") + "`n  ]")
    $null = $text | ConvertFrom-Json   # never write a file komorebi can't read
    Write-TextFile $file $text
    $komorebic = Join-Path $env:ProgramFiles 'komorebi\bin\komorebic.exe'
    if ((Test-Path $komorebic) -and (Get-Process komorebi -ErrorAction SilentlyContinue)) {
        [void](Invoke-Native $komorebic @('reload-configuration'))
        # running workspaces keep the padding they started with; the reload only sets new ones
        $state = (& $komorebic state) -join "`n" | ConvertFrom-Json
        for ($m = 0; $m -lt @($state.monitors.elements).Count; $m++) {
            for ($w = 0; $w -lt @($state.monitors.elements[$m].workspaces.elements).Count; $w++) {
                [void](Invoke-Native $komorebic @('container-padding', "$m", "$w", "$($half - $border)"))
                [void](Invoke-Native $komorebic @('workspace-padding', "$m", "$w", "$($gap - $half)"))
            }
        }
    }
}

function Set-Yasb([hashtable]$Colors) {
    $dir = Join-Path $env:USERPROFILE '.config\yasb'
    if (-not (Test-Path $dir)) { return }
    Write-TextFile (Join-Path $dir 'styles.css') (Expand-Template $YasbTemplate $Colors)
    $yasbc = Join-Path $env:ProgramFiles 'YASB\yasbc.exe'
    # the file watcher does not always pick up stylesheet changes
    if ((Test-Path $yasbc) -and (Get-Process yasb -ErrorAction SilentlyContinue)) { [void](Invoke-Native $yasbc @('reload')) }
}

function Set-Prop($Object, [string]$PropName, $Value) {
    if ($Object.PSObject.Properties[$PropName]) { $Object.$PropName = $Value }
    else { $Object | Add-Member -NotePropertyName $PropName -NotePropertyValue $Value }
}

# Same mapping as Omarchy's alacritty template; the starship prompt uses these ANSI colors
function Set-WindowsTerminal([hashtable]$Colors) {
    $path = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    if (-not (Test-Path $path)) { return }
    $raw = [IO.File]::ReadAllText($path)
    try { $s = $raw | ConvertFrom-Json }
    catch { $s = (($raw -split "`r?`n") | Where-Object { $_ -notmatch '^\s*//' }) -join "`n" | ConvertFrom-Json }
    $scheme = [ordered]@{
        name = 'Omadows'; background = $Colors['background']; foreground = $Colors['foreground']
        cursorColor = $Colors['cursor']; selectionBackground = $Colors['selection_background']
        black = $Colors['color0']; red = $Colors['red']; green = $Colors['green']; yellow = $Colors['yellow']
        blue = $Colors['blue']; purple = $Colors['magenta']; cyan = $Colors['cyan']; white = $Colors['foreground']
        brightBlack = $Colors['muted']; brightRed = $Colors['bright_red']; brightGreen = $Colors['bright_green']
        brightYellow = $Colors['bright_yellow']; brightBlue = $Colors['bright_blue']; brightPurple = $Colors['bright_magenta']
        brightCyan = $Colors['bright_cyan']; brightWhite = $Colors['bright_foreground']
    }
    $theme = [ordered]@{
        name = 'Omadows'
        tab = [ordered]@{ background = $Colors['background'] + 'FF'; showCloseButton = 'hover'; unfocusedBackground = $null }
        tabRow = [ordered]@{ background = $Colors['dark_background'] + 'FF'; unfocusedBackground = $Colors['darker_background'] + 'FF' }
        window = [ordered]@{ applicationTheme = $Colors['mode'] }
    }
    [object[]]$schemes = @($s.schemes | Where-Object { $_ -and $_.name -ne 'Omadows' }) + @([pscustomobject]$scheme)
    [object[]]$themes = @($s.themes | Where-Object { $_ -and $_.name -ne 'Omadows' }) + @([pscustomobject]$theme)
    Set-Prop $s 'schemes' $schemes
    Set-Prop $s 'themes' $themes
    Set-Prop $s 'theme' 'Omadows'
    if (-not $s.profiles.defaults) { Set-Prop $s.profiles 'defaults' ([pscustomobject]@{}) }
    Set-Prop $s.profiles.defaults 'colorScheme' 'Omadows'
    Write-TextFile $path (ConvertTo-Json -InputObject $s -Depth 32)
}

function Get-CodeCli {
    foreach ($p in "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd", "$env:ProgramFiles\Microsoft VS Code\bin\code.cmd") { if (Test-Path $p) { return $p } }
    $cmd = Get-Command code.cmd -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

function Test-VsCodeExtension([string]$Registry, [string]$Id) {
    if (-not (Test-Path $Registry)) { return $false }
    return [bool](Read-JsonArray $Registry | Where-Object { $_.identifier.id -and $_.identifier.id.ToLower() -eq $Id.ToLower() })
}

# Omarchy's approach: the theme's preferred extension when it names one, else a generated "Omadows" theme
function Set-VsCode([hashtable]$Colors, [string]$Dir) {
    $code = Get-CodeCli
    if (-not $code) { return }
    $extBase = Join-Path $env:USERPROFILE '.vscode\extensions'
    $registry = Join-Path $extBase 'extensions.json'
    $settings = Join-Path $env:APPDATA 'Code\User\settings.json'
    $themeName = $null
    $descriptor = Join-Path $Dir 'vscode.json'
    if (Test-Path $descriptor) {
        $d = Get-Content $descriptor -Raw | ConvertFrom-Json
        if ($d.name -match '^[^"\\\x00-\x1f]+$') { $themeName = $d.name }
        if ($d.extension -match '^[A-Za-z0-9._-]+$' -and -not (Test-VsCodeExtension $registry $d.extension)) {
            Write-Log "  installing VS Code extension $($d.extension)"
            [void](Invoke-Native $code @('--install-extension', $d.extension))
        }
    } else {
        $json = Expand-Template (Get-Template 'vscode-theme.json.tpl') $Colors
        $extDir = Join-Path $extBase 'omadows-theme'
        $sha = [Security.Cryptography.SHA1]::Create()
        $hash = [BitConverter]::ToUInt32($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($json)), 0)
        $version = "1.0.$hash"
        $uiTheme = if ($Colors['mode'] -eq 'light') { 'vs' } else { 'vs-dark' }
        Write-TextFile (Join-Path $extDir 'themes\omadows-color-theme.json') $json
        Write-TextFile (Join-Path $extDir 'package.json') ((ConvertTo-Json -Depth 8 -InputObject ([ordered]@{
            name = 'omadows-theme'; displayName = 'Omadows'; description = 'Omadows color theme (follows the current Omarchy theme)'; publisher = 'local'; version = $version
            engines = [ordered]@{ vscode = '^1.70.0' }; categories = @('Themes')
            contributes = [ordered]@{ themes = @([ordered]@{ label = 'Omadows'; uiTheme = $uiTheme; path = './themes/omadows-color-theme.json'; _watch = $true }) }
        })))
        # register it the way VS Code records installed extensions
        $entries = @()
        if (Test-Path $registry) { $entries = @(Read-JsonArray $registry | Where-Object { $_.identifier.id -ne 'local.omadows-theme' }) }
        $p = $extDir -replace '\\', '/'
        $uriPath = '/' + $p.Substring(0, 1).ToLower() + $p.Substring(1)
        $entries += [pscustomobject][ordered]@{
            identifier = [pscustomobject]@{ id = 'local.omadows-theme' }; version = $version
            location = [pscustomobject][ordered]@{ '$mid' = 1; path = $uriPath; scheme = 'file' }; relativeLocation = 'omadows-theme'
        }
        Write-TextFile $registry (ConvertTo-Json -InputObject ([object[]]$entries) -Depth 16)
        $themeName = 'Omadows'
    }
    if (-not $themeName) { return }
    # settings.json is JSONC (comments, trailing commas), so edit it in place like Omarchy does
    if (-not (Test-Path $settings)) { Write-TextFile $settings "{`n}`n" }
    $text = [IO.File]::ReadAllText($settings)
    if ($text -notmatch '"workbench\.colorTheme"') { $text = ([regex]'\{').Replace($text, "{`n    `"workbench.colorTheme`": `"`",", 1) }
    $text = [regex]::Replace($text, '("workbench\.colorTheme"\s*:\s*")[^"]*(")', { param($m) $m.Groups[1].Value + $themeName + $m.Groups[2].Value })
    Write-TextFile $settings $text
}

# Brave's theme color (Omarchy's approach: the BrowserThemeColor / BrowserColorScheme policies, then a
# policy refresh), Explorer's icons and the Windhawk mods' settings live in machine-wide keys that
# need admin. The "Omadows\Theme colors" task (created by the setup, runs as SYSTEM) applies the
# colors written here and accepts nothing else.
function Set-SystemColors([hashtable]$Colors, [string]$Dir) {
    $svc = New-Object -ComObject Schedule.Service
    $svc.Connect()
    $task = $null
    try { $task = $svc.GetFolder('\Omadows').GetTask('Theme colors') } catch { }
    if (-not $task) { Write-Log '  Brave, Explorer icons and background skipped: the Omadows theme colors task is missing; run the Omadows install again (one admin prompt)'; return }

    $appPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\App Paths\brave.exe'
    $exe = (Get-ItemProperty $appPath -ErrorAction SilentlyContinue).'(default)'
    if (-not $exe) { $exe = (Get-ItemProperty ($appPath -replace '^HKCU', 'HKLM') -ErrorAction SilentlyContinue).'(default)' }
    $brave = $null
    if ($exe -and (Test-Path $exe)) {
        $brave = $Colors['background']
        # a theme's chromium.theme overrides the color as "r,g,b"
        $custom = Join-Path $Dir 'chromium.theme'
        if (Test-Path $custom) {
            $rgb = ([IO.File]::ReadAllText($custom).Trim() -split '\s*,\s*') | ForEach-Object { [int]$_ }
            if ($rgb.Count -eq 3) { $brave = '#{0:x2}{1:x2}{2:x2}' -f $rgb[0], $rgb[1], $rgb[2] }
        }
        $brave = if ($brave -match '^#[0-9A-Fa-f]{6}$') { $brave.ToLower() } else { $null }
    }
    $folder = Get-FolderColor $Colors $Dir
    $colorFile = Join-Path $Root 'theme-colors'
    $oldFolder = if (Test-Path $colorFile) { [string](Get-Content $colorFile | Where-Object { $_ -like 'folder *' }) -replace '^folder ', '' }

    $lines = @()
    if ($brave) { $lines += "brave $brave" }
    $lines += "folder $folder"
    if ($Colors['background'] -match '^#[0-9A-Fa-f]{6}$') {
        # Explorer's background tint and its opacity
        $lines += "explorer $($Colors['background'].ToLower()) " + ('{0:x2}' -f [int][Math]::Round([Math]::Min(1.0, [Math]::Max(0.0, $ExplorerOpacity)) * 255))
    }
    # drive fill bars (Windhawk's Explorer Visual Tweaks Dark): fill, nearly-full fill, and the track
    $bars = @($Colors['accent'], $Colors['red'], $Colors['background'], $Colors['foreground'])
    if (-not ($bars | Where-Object { $_ -notmatch '^#[0-9A-Fa-f]{6}$' })) { $lines += 'bars ' + (($bars | ForEach-Object { $_.ToLower() }) -join ' ') }
    Write-TextFile $colorFile (($lines -join "`n") + "`n")
    [void]$task.Run($null)

    $braveKey = 'HKLM:\SOFTWARE\Policies\BraveSoftware\Brave'
    $iconKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Icons'
    $wantIcon = '\folder-' + $folder.Substring(1) + '.ico,0'
    # the helper may still be building Windhawk's icons when the keys above already match
    $done = {
        ((-not $brave) -or (Get-ItemProperty $braveKey -ErrorAction SilentlyContinue).BrowserThemeColor -eq $brave) -and
        ([string](Get-ItemProperty $iconKey -ErrorAction SilentlyContinue).'3').EndsWith($wantIcon) -and
        ($svc.GetFolder('\Omadows').GetTask($task.Name).State -notin 2, 4)
    }
    # the first run of a color also draws its icons, which takes a few seconds
    $deadline = (Get-Date).AddSeconds(30)
    while (-not (& $done) -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 300 }
    if (-not (& $done)) { throw 'the theme colors task did not apply the colors' }

    # with Windhawk's Resource Redirect mod the folder previews follow the theme too, but the
    # cached ones keep the old color until the thumbnail cache is emptied
    if ($oldFolder -ne $folder -and (Test-Path 'HKLM:\SOFTWARE\Windhawk\Engine\Mods\icon-resource-redirect')) {
        [Omadows.ThumbCache]::Purge("$env:SystemDrive\")
    }
    [Omadows.Wallpaper]::RefreshIcons()
    [void](Invoke-Native "$env:SystemRoot\System32\ie4uinit.exe" @('-show'))
    # a running Brave picks the new policy up without a restart
    if ($brave -and (Get-Process brave -ErrorAction SilentlyContinue)) {
        Start-Process $exe -ArgumentList '--refresh-platform-policy', '--no-startup-window'
    }
}

function Set-Obsidian([hashtable]$Colors) {
    $registry = Join-Path $env:APPDATA 'obsidian\obsidian.json'
    if (-not (Test-Path $registry)) { return }
    $vaults = (Get-Content $registry -Raw | ConvertFrom-Json).vaults
    if (-not $vaults) { return }
    $css = Expand-Template (Get-Template 'obsidian.css.tpl') $Colors
    foreach ($v in $vaults.PSObject.Properties.Value) {
        $dotDir = Join-Path $v.path '.obsidian'
        if (-not (Test-Path $dotDir)) { continue }
        $themeDir = Join-Path $dotDir 'themes\Omadows'
        $manifest = Join-Path $themeDir 'manifest.json'
        if (-not (Test-Path $manifest)) {
            Write-TextFile $manifest '{ "name": "Omadows", "version": "1.0.0", "minAppVersion": "0.16.0", "description": "Synced with the current Omarchy theme", "author": "Omadows" }'
        }
        Write-TextFile (Join-Path $themeDir 'theme.css') $css
    }
}

# Windows rejects "next" (E_UNEXPECTED) for a moment after a new slideshow is set
function Step-Slideshow {
    for ($i = 0; $i -lt 5; $i++) {
        try { [Omadows.Wallpaper]::Next(); return } catch { Start-Sleep -Milliseconds 800 }
    }
    Write-Log '  slideshow set; it will show the new wallpapers at the next change'
}

function Set-Theme([string]$Theme) {
    Write-Log "Applying theme $Theme"
    $dir = Get-ThemeDir $Theme
    $colors = Read-ThemeColors (Join-Path $dir 'colors.toml')
    $steps = [ordered]@{
        'Windows light/dark' = { Set-WindowsMode $colors }
        'Windows accent'     = { Set-Accent $colors }
        'komorebi borders'   = { Set-Komorebi $colors }
        'YASB bar'           = { Set-Yasb $colors }
        'Windows Terminal'   = { Set-WindowsTerminal $colors }
        'VS Code'            = { Set-VsCode $colors $dir }
        'Brave, folder icons' = { Set-SystemColors $colors $dir }
        'special folder icons' = { Set-SpecialFolders $colors $dir }
        'Obsidian'           = { Set-Obsidian $colors }
        'wallpapers'         = {
            $bg = Sync-Backgrounds $Theme $dir
            if (-not (Get-ChildItem $bg -Filter *.jpg)) { throw 'no wallpapers available' }
            [Omadows.Wallpaper]::Slideshow($bg, [uint32]($SlideshowMinutes * 60000), $true)
            Step-Slideshow
        }
    }
    $failed = @()
    foreach ($k in $steps.Keys) {
        try { & $steps[$k] | Out-Null } catch { $failed += $k; Write-Log "  ! $k failed: $($_.Exception.Message)" }
    }
    Write-TextFile $StateFile $Theme
    if ($failed) { Write-Log "Applied $Theme with problems in: $($failed -join ', ')" } else { Write-Log "Applied $Theme" }
    return $failed
}

# ---------------------------------------------------------------------------------------------
# Picker
# ---------------------------------------------------------------------------------------------

function Show-Picker {
    Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
    $current = if (Test-Path $StateFile) { (Get-Content $StateFile -Raw).Trim() } else { 'tokyo-night' }
    $c = @{ background = '#1a1b26'; foreground = '#a9b1d6'; accent = '#7aa2f7'; muted = '#565f89'; selection_background = '#292e42' }
    try { $c = Read-ThemeColors (Join-Path (Get-ThemeDir $current) 'colors.toml') } catch { }
    $xaml = $PickerXaml.Replace('__BG__', $c['background']).Replace('__FG__', $c['foreground']).Replace('__ACCENT__', $c['accent']).Replace('__MUTED__', $c['muted']).Replace('__SEL__', $c['selection_background'])
    $window = [Windows.Markup.XamlReader]::Parse($xaml)
    $list = $window.FindName('List'); $preview = $window.FindName('Preview'); $status = $window.FindName('Status')

    $themes = @(Get-ThemeList)
    foreach ($t in $themes) {
        $item = New-Object Windows.Controls.ListBoxItem
        $item.Content = Get-DisplayName $t
        $item.Tag = $t
        [void]$list.Items.Add($item)
        if ($t -eq $current) { $list.SelectedItem = $item }
    }

    $showPreview = {
        $sel = $list.SelectedItem
        if (-not $sel) { return }
        try {
            $bmp = New-Object Windows.Media.Imaging.BitmapImage
            $bmp.BeginInit()
            $bmp.CacheOption = [Windows.Media.Imaging.BitmapCacheOption]::OnLoad
            $bmp.DecodePixelWidth = 1200
            $bmp.UriSource = New-Object Uri (Get-Preview $sel.Tag)
            $bmp.EndInit()
            $preview.Source = $bmp
        } catch { $preview.Source = $null }
    }
    $list.Add_SelectionChanged($showPreview)

    $apply = {
        $sel = $list.SelectedItem
        if (-not $sel) { return }
        $status.Text = "Applying $($sel.Content)... (first use of a theme downloads its wallpapers)"
        $window.Dispatcher.Invoke([Action] { }, [Windows.Threading.DispatcherPriority]::Render)
        $failed = @(Set-Theme $sel.Tag)
        if ($failed.Count) { $status.Text = "Applied with problems in: $($failed -join ', ')  (see $LogFile)" } else { $window.Close() }
    }
    $window.Add_KeyDown({
        param($s, $e)
        if ($e.Key -eq 'Escape') { $window.Close() }
        elseif ($e.Key -eq 'Return') { & $apply }
    })
    $list.Add_MouseDoubleClick({ & $apply })
    $window.Add_ContentRendered({
        if ($list.SelectedItem) { $list.ScrollIntoView($list.SelectedItem) } else { $list.SelectedIndex = 0 }
        & $showPreview
        $window.Activate() | Out-Null
        ($list.ItemContainerGenerator.ContainerFromItem($list.SelectedItem)).Focus() | Out-Null
    })
    [void]$window.ShowDialog()
}

function Show-Settings {
    Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms
    $current = if (Test-Path $StateFile) { (Get-Content $StateFile -Raw).Trim() } else { 'tokyo-night' }
    $c = @{ background = '#1a1b26'; foreground = '#a9b1d6'; accent = '#7aa2f7'; muted = '#565f89'; selection_background = '#292e42' }
    try { $c = Read-ThemeColors (Join-Path (Get-ThemeDir $current) 'colors.toml') } catch { }
    $xaml = $SettingsXaml.Replace('__BG__', $c['background']).Replace('__FG__', $c['foreground']).Replace('__ACCENT__', $c['accent']).Replace('__MUTED__', $c['muted']).Replace('__SEL__', $c['selection_background'])
    $window = [Windows.Markup.XamlReader]::Parse($xaml)
    $gap = $window.FindName('Gap'); $gapValue = $window.FindName('GapValue'); $libraries = $window.FindName('Libraries')
    $folders = $window.FindName('Folders'); $status = $window.FindName('Status')

    $s = Read-LayoutSettings
    $gap.Value = $s.gap
    $libraries.IsChecked = $s.gameLibraries
    foreach ($f in $s.untiledFolders) { [void]$folders.Items.Add($f) }
    $showGap = {
        $g = [int]$gap.Value
        $gapValue.Text = if ($g % 2) { "$g px  ($($g - 1) between windows)" } else { "$g px" }
    }
    $gap.Add_ValueChanged($showGap)
    & $showGap

    $window.FindName('Add').Add_Click({
        $d = New-Object System.Windows.Forms.FolderBrowserDialog
        $d.Description = "Programs in this folder won't be tiled"
        if ($d.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK -and -not $folders.Items.Contains($d.SelectedPath)) { [void]$folders.Items.Add($d.SelectedPath) }
    })
    $window.FindName('Remove').Add_Click({ if ($folders.SelectedItem) { $folders.Items.Remove($folders.SelectedItem) } })
    $window.FindName('Find').Add_Click({
        $added = 0
        foreach ($f in @(Find-GameFolders)) { if (-not $folders.Items.Contains($f)) { [void]$folders.Items.Add($f); $added++ } }
        $status.Text = if ($added) { "Found $added game folder(s); Apply to use them" } else { 'Nothing new: the game libraries above cover the usual places' }
    })
    $window.FindName('Apply').Add_Click({
        try {
            $new = [ordered]@{ gap = [int]$gap.Value; gameLibraries = [bool]$libraries.IsChecked; untiledFolders = @($folders.Items | ForEach-Object { [string]$_ }) }
            Write-LayoutSettings $new
            Set-LayoutSettings $new
            $status.Text = 'Applied'
        } catch { $status.Text = "Couldn't apply: $($_.Exception.Message)" }
    })
    $window.FindName('Close').Add_Click({ $window.Close() })
    $window.Add_KeyDown({ param($sender, $e) if ($e.Key -eq 'Escape') { $window.Close() } })
    # borderless, so drag it by its background
    $window.Add_MouseLeftButtonDown({ try { $window.DragMove() } catch { } })
    [void]$window.ShowDialog()
}

# ---------------------------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------------------------

New-Item -ItemType Directory -Force $Root | Out-Null
switch ($Command) {
    'pick' { Show-Picker }
    'set' {
        if (-not $Name) { throw 'usage: omadows.ps1 set <theme>' }
        $failed = @(Set-Theme $Name)
        if ($failed.Count) { exit 1 }
    }
    'next-bg' {
        # DSS_SLIDESHOW (2) is off when a wallpaper was set by hand: restart the theme's slideshow
        if (([Omadows.Wallpaper]::Status() -band 2) -eq 0) {
            $t = if (Test-Path $StateFile) { (Get-Content $StateFile -Raw).Trim() } else { 'tokyo-night' }
            $bg = Sync-Backgrounds $t (Get-ThemeDir $t)
            [Omadows.Wallpaper]::Slideshow($bg, [uint32]($SlideshowMinutes * 60000), $true)
        }
        Step-Slideshow
    }
    'list' { Get-ThemeList | ForEach-Object { '{0,-20} {1}' -f $_, (Get-DisplayName $_) } }
    'current' { if (Test-Path $StateFile) { (Get-Content $StateFile -Raw).Trim() } }
    'restore-folders' { Restore-SpecialFolders; 'Original special folder icons restored.' }
    'settings' { Show-Settings }
    'refresh-explorer' {
        # once Windhawk's icon mod is gone, Explorer still shows the themed icons and previews it cached
        [Omadows.ThumbCache]::Purge("$env:SystemDrive\")
        [Omadows.Wallpaper]::RefreshIcons()
        [void](Invoke-Native "$env:SystemRoot\System32\ie4uinit.exe" @('-show'))
    }
    'apply-settings' {
        $s = Read-LayoutSettings
        Write-LayoutSettings $s
        Set-LayoutSettings $s
        "Gap $($s.gap) px; untiled: " + $(if ($s.gameLibraries) { 'game libraries' } else { 'no game libraries' }) + $(if ($s.untiledFolders) { ', ' + ($s.untiledFolders -join ', ') })
    }
    default { throw "unknown command '$Command' (pick, set, next-bg, list, current, restore-folders, settings, apply-settings, refresh-explorer)" }
}
'@

# ---------------------------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------------------------

if (-not ('Win32.Native' -as [type])) {
    Add-Type -Namespace Win32 -Name Native -MemberDefinition @'
[DllImport("gdi32.dll", CharSet = CharSet.Unicode)] public static extern int AddFontResource(string file);
[DllImport("gdi32.dll", CharSet = CharSet.Unicode)] public static extern bool RemoveFontResource(string file);
[DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] public static extern bool MoveFileEx(string existing, string target, int flags);
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint msg, UIntPtr wParam, IntPtr lParam, uint flags, uint timeout, out UIntPtr result);
[DllImport("user32.dll", CharSet = CharSet.Unicode, EntryPoint = "SendMessageTimeout")] public static extern IntPtr SendMessageTimeoutText(IntPtr hWnd, uint msg, UIntPtr wParam, string lParam, uint flags, uint timeout, out UIntPtr result);
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern bool SystemParametersInfo(uint action, uint param, string value, uint flags);
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr FindWindow(string cls, string title);
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr FindWindowEx(IntPtr parent, IntPtr after, string cls, string title);
[DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam);
[StructLayout(LayoutKind.Sequential)] public struct APPBARDATA { public int cbSize; public IntPtr hWnd; public uint uCallbackMessage; public uint uEdge; public int left, top, right, bottom; public IntPtr lParam; }
[DllImport("shell32.dll")] public static extern UIntPtr SHAppBarMessage(uint msg, ref APPBARDATA data);
'@
}

function Write-Step([string]$Message) { Write-Host "`n==> $Message" -ForegroundColor Magenta }
function Write-Info([string]$Message) { Write-Host "    $Message" -ForegroundColor Gray }
function Write-Warn([string]$Message) { Write-Host "    ! $Message" -ForegroundColor Yellow }

function Invoke-Step([string]$Name, [scriptblock]$Body) {
    Write-Step $Name
    try { & $Body } catch { Write-Warn "$Name failed: $($_.Exception.Message)"; $Failures.Add($Name) }
}

function Test-Admin {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Update-SessionPath {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
}

# Runs a native exe without letting its stderr trip $ErrorActionPreference = 'Stop' on PowerShell 5.1
function Invoke-Native([string]$Exe, [string[]]$Arguments) {
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { & $Exe @Arguments 2>&1 | Out-Null; return $LASTEXITCODE } finally { $ErrorActionPreference = $old }
}

function Set-Prop($Object, [string]$Name, $Value) {
    if ($Object.PSObject.Properties[$Name]) { $Object.$Name = $Value }
    else { $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value }
}

function Backup-File([string]$Path) {
    if (Test-Path $Path) { Copy-Item $Path "$Path.bak-$Stamp" -Force }
}

function Write-TextFile([string]$Path, [string]$Content, [switch]$NoBackup) {
    $dir = Split-Path $Path
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
    if (-not $NoBackup) { Backup-File $Path }
    [IO.File]::WriteAllText($Path, $Content, $Utf8NoBom)
}

function Write-JsonFile([string]$Path, $Object) {
    Backup-File $Path
    [IO.File]::WriteAllText($Path, ($Object | ConvertTo-Json -Depth 32), $Utf8NoBom)
}

function Ensure-Winget {
    if (Get-Command winget -ErrorAction SilentlyContinue) { return }
    Write-Info 'winget not found; registering App Installer...'
    try { Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe } catch { }
    Start-Sleep -Seconds 5
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw 'winget is not available. Update "App Installer" from the Microsoft Store, then run this script again.'
    }
}

# Installers to ask for first. winget picks PowerShell's MSIX package by default, which Windows
# downloads by itself (it timed out on a fresh PC) and which lives outside Program Files.
$InstallerTypes = @{ 'Microsoft.PowerShell' = 'wix' }

function Install-Package([string]$Id, [string]$Scope) {
    $wgArgs = @('install', '--id', $Id, '--exact', '--source', 'winget', '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity')
    if ($Scope) { $wgArgs += @('--scope', $Scope) }
    # a second try for downloads that time out; then winget's own choice of installer
    $tries = if ($InstallerTypes[$Id]) { $InstallerTypes[$Id], $InstallerTypes[$Id], '' } else { '', '' }
    for ($i = 0; $i -lt $tries.Count; $i++) {
        if ($i) { Write-Info "$Id failed (winget exit code $code); trying again ..."; Start-Sleep -Seconds 5 }
        else { Write-Info "installing $Id ..." }
        $extra = if ($tries[$i]) { @('--installer-type', $tries[$i]) } else { @() }
        $code = Invoke-Native 'winget' ($wgArgs + $extra)
        # 0 = installed; 0x8A15002B / 0x8A150061 = already installed, nothing newer
        if ($code -eq 0 -or $code -eq -1978335189 -or $code -eq -1978335135) { Write-Info "$Id ok"; return $true }
    }
    Write-Warn "$Id failed (winget exit code $code)"
    return $false
}

# Display names to fall back on when winget no longer finds a package by its id (PowerShell 7
# after Microsoft Update has updated it)
$UninstallNames = @{ 'Microsoft.PowerShell' = '^PowerShell 7(\.\d+)*-(x64|x86|arm64)$' }

# Returns 'removed', 'absent', 'user' (installed for the user only: winget won't remove it as
# admin) or why it failed
function Uninstall-Package([string]$Id, [string]$Scope) {
    $common = @('--silent', '--disable-interactivity', '--accept-source-agreements')
    if ($Scope) { $common += @('--scope', $Scope) }
    $code = Invoke-Native 'winget' (@('uninstall', '--id', $Id, '--exact') + $common)
    if ($code -eq -1978335212 -and $UninstallNames[$Id]) {
        $arp = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
        $names = @(Get-ItemProperty $arp -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match $UninstallNames[$Id] -and $_.SystemComponent -ne 1 } | ForEach-Object DisplayName | Sort-Object -Unique)
        foreach ($n in $names) { $code = Invoke-Native 'winget' (@('uninstall', '--name', $n, '--exact') + $common); if ($code -ne 0) { break } }
    }
    switch ($code) {
        0 { Write-Info "$Id removed"; return 'removed' }
        -1978334967 { Write-Info "$Id removed; Windows finishes at the next restart"; return 'removed' }   # 0x8A150109
        -1978335212 { return 'absent' }   # 0x8A150014: not installed
        -1978335107 { return 'user' }     # 0x8A15007D
    }
    Write-Warn "$Id was not removed (winget exit code $code)"
    return "winget exit code $code"
}

# Drops PATH entries into the removed apps' folders (starship's uninstaller leaves its own)
function Remove-StalePathEntries([string]$Scope) {
    $dirs = @('komorebi', 'whkd', 'YASB', 'starship', 'PowerShell\7', 'Windhawk') | ForEach-Object { Join-Path $env:ProgramFiles $_ }
    $key = if ($Scope -eq 'Machine') { [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey('SYSTEM\CurrentControlSet\Control\Session Manager\Environment', $true) }
           else { [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment', $true) }
    if (-not $key) { return }
    try {
        $raw = [string]$key.GetValue('Path', '', 'DoNotExpandEnvironmentNames')
        if (-not $raw) { return }
        $entries = $raw -split ';'
        $keep = @($entries | Where-Object {
            $full = [Environment]::ExpandEnvironmentVariables($_).TrimEnd('\')
            $ours = @($dirs | Where-Object { $full -eq $_ -or $full -like "$_\*" }).Count
            -not ($full -and $ours -and -not (Test-Path $full))
        })
        if ($keep.Count -eq $entries.Count) { return }
        $key.SetValue('Path', ($keep -join ';'), $key.GetValueKind('Path'))
        $r = [UIntPtr]::Zero
        [void][Win32.Native]::SendMessageTimeoutText([IntPtr]0xffff, 0x1A, [UIntPtr]::Zero, 'Environment', 2, 5000, [ref]$r)   # WM_SETTINGCHANGE
        Write-Info "removed $($entries.Count - $keep.Count) PATH entries of removed apps"
    } finally { $key.Close() }
}

# ---------------------------------------------------------------------------------------------
# Elevated half: machine-wide packages
# ---------------------------------------------------------------------------------------------

# Brave's theme color, Explorer's folder icon and the known-folder icons live in machine-wide keys,
# which need admin. This creates a scheduled task (runs as SYSTEM, startable by this user) whose
# helper reads a few colors written by the theme switcher and accepts nothing else, like the narrow
# sudoers rule Omarchy uses for its browser-policy script. The helper draws every icon itself, so no
# file from the user is ever installed machine-wide.
function Install-ThemeColorsTask([string]$ColorFile, [string]$UserSid) {
    $dir = Join-Path $env:ProgramFiles 'Omadows'
    New-Item -ItemType Directory -Force $dir | Out-Null
    $helper = Join-Path $dir 'set-theme-colors.ps1'
    $code = @'
# Runs as SYSTEM from the "Omadows\Theme colors" task. Its only input is the colors the Omadows
# theme switcher writes: "brave", "folder", "special" and "explorer" (Explorer's background), each
# "#rrggbb" or "default" (which puts the original back); "explorer" may add the tint's opacity as
# two hex digits ("explorer #1a1b26 f2"). "bars" is the drive fill bars' accent, red, background
# and foreground ("bars #7aa2f7 #f7768e #1a1b26 #a9b1d6"). Any other content is rejected. Errors
# go to last-error.txt next to it.
$file = '__COLOR_FILE__'
if (-not (Test-Path -LiteralPath $file -PathType Leaf) -or (Get-Item -LiteralPath $file).Length -gt 256) { exit 1 }
$colors = @{}
$ExplorerAlpha = 'D0'
$BarColors = $null
foreach ($line in [IO.File]::ReadAllLines($file)) {
    if (-not $line.Trim()) { continue }
    if ($line.Trim() -match '^explorer (#[0-9a-fA-F]{6}|default) ([0-9a-fA-F]{2})$') {
        $colors['explorer'] = $Matches[1].ToLower(); $ExplorerAlpha = $Matches[2].ToUpper(); continue
    }
    if ($line.Trim() -match '^bars (#[0-9a-fA-F]{6}) (#[0-9a-fA-F]{6}) (#[0-9a-fA-F]{6}) (#[0-9a-fA-F]{6})$') {
        $BarColors = @{ accent = $Matches[1].ToLower(); red = $Matches[2].ToLower(); background = $Matches[3].ToLower(); foreground = $Matches[4].ToLower() }; continue
    }
    if ($line.Trim() -notmatch '^(brave|folder|special|explorer) (#[0-9a-fA-F]{6}|default)$') { exit 1 }
    $colors[$Matches[1]] = $Matches[2].ToLower()
}
$iconRoot = Join-Path $PSScriptRoot 'icons'

function Get-Mix([string]$Start, [string]$End, [double]$a) {
    $s = $Start.TrimStart('#'); $e = $End.TrimStart('#')
    '#' + ((0, 2, 4 | ForEach-Object { '{0:x2}' -f [int][Math]::Floor([Convert]::ToInt32($s.Substring($_, 2), 16) * (1 - $a) + [Convert]::ToInt32($e.Substring($_, 2), 16) * $a + 0.5) }) -join '')
}

# Yaru-style symbols for the known folders, on the folder's 256 grid: a darker shade of the folder
# color with details cut out in a lighter one
$Glyphs = @{
    desktop   = @{ dark = @('M 100,134 Q 100,128 106,128 L 150,128 Q 156,128 156,134 L 156,168 Q 156,174 150,174 L 106,174 Q 100,174 100,168 Z', 'M 122,174 L 134,174 L 136,184 L 120,184 Z', 'M 110,184 L 146,184 Q 150,184 150,188 L 150,190 L 106,190 L 106,188 Q 106,184 110,184 Z'); light = @('M 106,134 L 150,134 L 150,168 L 106,168 Z') }
    documents = @{ dark = @('M 108,126 L 138,126 L 154,142 L 154,186 Q 154,192 148,192 L 108,192 Q 102,192 102,186 L 102,132 Q 102,126 108,126 Z'); light = @('M 138,126 L 138,142 L 154,142 Z', 'M 112,152 L 144,152 L 144,157 L 112,157 Z', 'M 112,164 L 144,164 L 144,169 L 112,169 Z', 'M 112,176 L 134,176 L 134,181 L 112,181 Z') }
    downloads = @{ dark = @('M 121,124 L 135,124 L 135,152 L 150,152 L 128,176 L 106,152 L 121,152 Z', 'M 104,182 L 152,182 Q 156,182 156,186 L 156,188 Q 156,192 152,192 L 104,192 Q 100,192 100,188 L 100,186 Q 100,182 104,182 Z'); light = @() }
    pictures  = @{ dark = @('M 106,128 L 150,128 Q 156,128 156,134 L 156,184 Q 156,190 150,190 L 106,190 Q 100,190 100,184 L 100,134 Q 100,128 106,128 Z'); light = @('M 106,180 L 122,158 L 134,172 L 140,165 L 150,180 Z', 'M 136,146 A 6,6 0 1 1 148,146 A 6,6 0 1 1 136,146 Z') }
    music     = @{ dark = @('M 124,130 L 152,122 L 152,172 A 11,10 0 1 1 145,163 L 145,140 L 131,144 L 131,180 A 11,10 0 1 1 124,171 Z'); light = @() }
    videos    = @{ dark = @('M 106,134 L 150,134 Q 156,134 156,140 L 156,180 Q 156,186 150,186 L 106,186 Q 100,186 100,180 L 100,140 Q 100,134 106,134 Z'); light = @('M 120,145 L 142,160 L 120,175 Z') }
    home      = @{ dark = @('M 128,120 L 164,150 L 154,150 L 154,186 Q 154,190 150,190 L 138,190 L 138,166 L 118,166 L 118,190 L 106,190 Q 102,190 102,186 L 102,150 L 92,150 Z'); light = @() }
    gallery   = @{ dark = @('M 112,124 L 156,124 Q 162,124 162,130 L 162,172 L 155,172 L 155,131 L 112,131 Z', 'M 102,138 L 142,138 Q 148,138 148,144 L 148,184 Q 148,190 142,190 L 102,190 Q 96,190 96,184 L 96,144 Q 96,138 102,138 Z'); light = @('M 102,182 L 116,164 L 126,175 L 132,169 L 142,182 Z', 'M 128,154 A 5,5 0 1 1 138,154 A 5,5 0 1 1 128,154 Z') }
}

# Known folders by FOLDERID; their Icon value is what the navigation pane and Home show
$KnownFolders = [ordered]@{
    desktop = '{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}'; documents = '{FDD39AD0-238F-46AF-ADB4-6C85480369C7}'
    downloads = '{374DE290-123F-4565-9164-39C4925E467B}'; pictures = '{33E28130-4E1E-4676-835A-98395C3BC3BB}'
    music = '{4BD8D571-6D19-48D3-BE97-422220080E43}'; videos = '{18989B1D-99B5-455B-841C-AB7C74E4DDFC}'
}

# Yaru-style folder drawn on a 256 grid, rendered separately at each size so small icons stay crisp.
# $Part: folder (the whole icon), back / front (the layers Explorer puts a folder's previews between),
# or drive / computer in the same style, laid out like Windows' own so its badges still fit
function New-FolderPng([int]$Size, [string]$Accent, [string]$Glyph, [string]$Part = 'folder') {
    $brush = { param($hex) $b = New-Object Windows.Media.SolidColorBrush ([Windows.Media.ColorConverter]::ConvertFromString($hex)); $b.Freeze(); $b }
    $gradient = { param($from, $to, $angle) $b = New-Object Windows.Media.LinearGradientBrush ([Windows.Media.ColorConverter]::ConvertFromString($from)), ([Windows.Media.ColorConverter]::ConvertFromString($to)), $angle; $b.Freeze(); $b }
    $front = & $gradient (Get-Mix $Accent '#ffffff' 0.18) $Accent 90
    $dv = New-Object Windows.Media.DrawingVisual
    $dc = $dv.RenderOpen()
    $dc.PushTransform((New-Object Windows.Media.ScaleTransform ($Size / 256.0), ($Size / 256.0)))
    if ($Part -eq 'drive') {
        # grey top plate, the front in the folder color with an activity light
        $dc.DrawRoundedRectangle((& $gradient '#F2F2F2' '#C4C4C4' 90), $null, (New-Object Windows.Rect 20, 80, 216, 76), 18, 18)
        $dc.DrawRoundedRectangle($front, $null, (New-Object Windows.Rect 20, 124, 216, 64), 18, 18)
        $dc.DrawRectangle((& $brush '#40FFFFFF'), $null, (New-Object Windows.Rect 36, 124, 184, 3))
        $dc.DrawRoundedRectangle((& $brush (Get-Mix $Accent '#ffffff' 0.7)), $null, (New-Object Windows.Rect 184, 150, 28, 10), 5, 5)
    } elseif ($Part -eq 'computer') {
        # dark bezel, a screen in the folder color, grey stand
        $dc.DrawRoundedRectangle((& $brush '#3A3A3A'), $null, (New-Object Windows.Rect 18, 32, 220, 150), 14, 14)
        $dc.DrawRoundedRectangle((& $gradient (Get-Mix $Accent '#ffffff' 0.3) $Accent 45), $null, (New-Object Windows.Rect 30, 44, 196, 126), 6, 6)
        $dc.DrawRectangle((& $brush '#8C8C8C'), $null, (New-Object Windows.Rect 112, 182, 32, 24))
        $dc.DrawRoundedRectangle((& $brush '#B4B4B4'), $null, (New-Object Windows.Rect 72, 204, 112, 16), 8, 8)
    } elseif ($Part -ne 'front') {
        $dc.DrawGeometry((& $brush (Get-Mix $Accent '#000000' 0.28)), $null, [Windows.Media.Geometry]::Parse('M 28,62 Q 28,44 46,44 L 98,44 Q 108,44 114,52 L 122,62 L 210,62 Q 228,62 228,80 L 228,196 Q 228,214 210,214 L 46,214 Q 28,214 28,196 Z'))
    }
    if ($Part -eq 'folder') {
        $dc.DrawRoundedRectangle((& $brush '#F4F4F4'), $null, (New-Object Windows.Rect 44, 74, 168, 90), 6, 6)
        $dc.DrawRoundedRectangle($front, $null, (New-Object Windows.Rect 28, 96, 200, 118), 16, 16)
        $dc.DrawRectangle((& $brush '#40FFFFFF'), $null, (New-Object Windows.Rect 44, 96, 168, 3))
    } elseif ($Part -eq 'front') {
        # lower than the closed folder's front so the previews show above it
        $dc.DrawRoundedRectangle($front, $null, (New-Object Windows.Rect 28, 130, 200, 84), 16, 16)
        $dc.DrawRectangle((& $brush '#40FFFFFF'), $null, (New-Object Windows.Rect 44, 130, 168, 3))
    }
    if ($Glyph) {
        # small icons get a bigger symbol so it stays readable
        $k = if ($Size -le 48) { 1.45 } else { 1.0 }
        $dc.PushTransform((New-Object Windows.Media.ScaleTransform $k, $k, 128, 158))
        foreach ($p in $Glyphs[$Glyph].dark) { $dc.DrawGeometry((& $brush (Get-Mix $Accent '#000000' 0.38)), $null, [Windows.Media.Geometry]::Parse($p)) }
        foreach ($p in $Glyphs[$Glyph].light) { $dc.DrawGeometry((& $brush (Get-Mix $Accent '#ffffff' 0.3)), $null, [Windows.Media.Geometry]::Parse($p)) }
        $dc.Pop()
    }
    $dc.Pop()
    $dc.Close()
    $rtb = New-Object Windows.Media.Imaging.RenderTargetBitmap $Size, $Size, 96, 96, ([Windows.Media.PixelFormats]::Pbgra32)
    $rtb.Render($dv)
    $enc = New-Object Windows.Media.Imaging.PngBitmapEncoder
    $enc.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($rtb))
    $ms = New-Object IO.MemoryStream
    $enc.Save($ms)
    return , $ms.ToArray()
}

# ICO container with PNG-compressed entries (supported since Windows Vista)
function Write-FolderIco([string]$Path, [string]$Accent, [string]$Glyph) {
    $sizes = 16, 20, 24, 32, 40, 48, 64, 96, 128, 256
    $images = foreach ($s in $sizes) { , (New-FolderPng $s $Accent $Glyph) }
    $ms = New-Object IO.MemoryStream
    $w = New-Object IO.BinaryWriter $ms
    $w.Write([uint16]0); $w.Write([uint16]1); $w.Write([uint16]$sizes.Count)
    $offset = 6 + 16 * $sizes.Count
    for ($i = 0; $i -lt $sizes.Count; $i++) {
        $dim = if ($sizes[$i] -ge 256) { 0 } else { $sizes[$i] }
        $w.Write([byte]$dim); $w.Write([byte]$dim); $w.Write([byte]0); $w.Write([byte]0)
        $w.Write([uint16]1); $w.Write([uint16]32)
        $w.Write([uint32]$images[$i].Length); $w.Write([uint32]$offset)
        $offset += $images[$i].Length
    }
    foreach ($img in $images) { $w.Write($img) }
    $w.Flush()
    New-Item -ItemType Directory -Force (Split-Path $Path) | Out-Null
    [IO.File]::WriteAllBytes($Path, $ms.ToArray())
}

# Reads Windows' icon groups and writes resource-only DLLs that Windhawk's Resource Redirect mod
# loads in place of imageres.dll / shell32.dll / zipfldr.dll
$IconResCode = @"
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;

namespace Omadows {
    public class IconRes {
        [DllImport("kernel32", CharSet = CharSet.Unicode, SetLastError = true)] static extern IntPtr LoadLibraryEx(string f, IntPtr h, uint fl);
        [DllImport("kernel32")] static extern bool FreeLibrary(IntPtr h);
        [DllImport("kernel32")] static extern IntPtr FindResource(IntPtr h, IntPtr n, IntPtr t);
        [DllImport("kernel32")] static extern IntPtr LoadResource(IntPtr h, IntPtr r);
        [DllImport("kernel32")] static extern IntPtr LockResource(IntPtr r);
        [DllImport("kernel32")] static extern uint SizeofResource(IntPtr h, IntPtr r);
        [DllImport("kernel32", CharSet = CharSet.Unicode, SetLastError = true)] static extern IntPtr BeginUpdateResource(string f, bool del);
        [DllImport("kernel32", SetLastError = true)] static extern bool UpdateResource(IntPtr h, IntPtr type, IntPtr name, ushort lang, byte[] data, uint size);
        [DllImport("kernel32", SetLastError = true)] static extern bool EndUpdateResource(IntPtr h, bool discard);

        // same language as Windows' own icons (en-US)
        const ushort Lang = 1033;

        static byte[] Res(IntPtr m, int type, int id) {
            IntPtr r = FindResource(m, (IntPtr)id, (IntPtr)type);
            if (r == IntPtr.Zero) return null;
            uint size = SizeofResource(m, r);
            byte[] b = new byte[size];
            Marshal.Copy(LockResource(LoadResource(m, r)), b, 0, (int)size);
            return b;
        }

        // The 32-bit frames of an icon group: size -> straight BGRA pixels, top-down
        public static Dictionary<int, byte[]> Frames(string module, int group) {
            var frames = new Dictionary<int, byte[]>();
            IntPtr m = LoadLibraryEx(module, IntPtr.Zero, 0x2 | 0x20);
            if (m == IntPtr.Zero) throw new Exception("cannot load " + module);
            try {
                byte[] dir = Res(m, 14, group);
                if (dir == null) return frames;
                int count = BitConverter.ToUInt16(dir, 4);
                for (int i = 0; i < count; i++) {
                    int o = 6 + i * 14;
                    int size = dir[o] == 0 ? 256 : dir[o];
                    if (BitConverter.ToUInt16(dir, o + 6) != 32 || frames.ContainsKey(size)) continue;
                    byte[] px = Decode(Res(m, 3, BitConverter.ToUInt16(dir, o + 12)), size);
                    if (px != null) frames[size] = px;
                }
            } finally { FreeLibrary(m); }
            return frames;
        }

        static byte[] Decode(byte[] data, int size) {
            if (data == null) return null;
            if (data.Length > 8 && data[0] == 0x89 && data[1] == 0x50) {
                using (var bmp = new Bitmap(new MemoryStream(data))) {
                    if (bmp.Width != size || bmp.Height != size) return null;
                    return Pixels(bmp);
                }
            }
            int hdr = BitConverter.ToInt32(data, 0), w = BitConverter.ToInt32(data, 4), h = BitConverter.ToInt32(data, 8) / 2;
            if (w != size || h != size || BitConverter.ToInt16(data, 14) != 32) return null;
            byte[] px = new byte[w * h * 4];
            for (int y = 0; y < h; y++) Buffer.BlockCopy(data, hdr + (h - 1 - y) * w * 4, px, y * w * 4, w * 4);
            bool anyAlpha = false;
            for (int i = 3; i < px.Length; i += 4) if (px[i] != 0) { anyAlpha = true; break; }
            if (!anyAlpha) {
                // old-style icon: transparency comes from the AND mask
                int maskStride = ((w + 31) / 32) * 4, maskOff = hdr + w * h * 4;
                for (int y = 0; y < h; y++)
                    for (int x = 0; x < w; x++) {
                        bool clear = (data[maskOff + (h - 1 - y) * maskStride + x / 8] & (0x80 >> (x % 8))) != 0;
                        px[(y * w + x) * 4 + 3] = clear ? (byte)0 : (byte)255;
                    }
            }
            return px;
        }

        static byte[] Pixels(Bitmap bmp) {
            var bd = bmp.LockBits(new Rectangle(0, 0, bmp.Width, bmp.Height), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            byte[] px = new byte[bmp.Width * bmp.Height * 4];
            for (int y = 0; y < bmp.Height; y++) Marshal.Copy(IntPtr.Add(bd.Scan0, y * bd.Stride), px, y * bmp.Width * 4, bmp.Width * 4);
            bmp.UnlockBits(bd);
            return px;
        }

        public static byte[] FromPng(byte[] png) {
            using (var bmp = new Bitmap(new MemoryStream(png))) return Pixels(bmp);
        }

        // Our folder plus whatever the original icon draws that Windows' plain folder doesn't
        // (badges, symbols, zippers). Pixels close to the plain folder are dropped, with a soft edge.
        public static byte[] Badge(byte[] art, byte[] orig, byte[] plain) {
            byte[] o = (byte[])art.Clone();
            for (int i = 0; i < o.Length; i += 4) {
                int oa = orig[i + 3];
                if (oa == 0) continue;
                double keep = 1.0;
                if (plain[i + 3] > 0) {
                    int d = Math.Max(Math.Max(Math.Abs(orig[i] - plain[i]), Math.Abs(orig[i + 1] - plain[i + 1])),
                                     Math.Max(Math.Abs(orig[i + 2] - plain[i + 2]), Math.Abs(oa - plain[i + 3])));
                    keep = Math.Min(1.0, Math.Max(0.0, (d - 20) / 40.0));
                }
                if (keep <= 0) continue;
                double a = oa / 255.0 * keep, ba = o[i + 3] / 255.0;
                double outA = a + ba * (1 - a);
                for (int c = 0; c < 3; c++) o[i + c] = (byte)Math.Round((orig[i + c] * a + o[i + c] * ba * (1 - a)) / outA);
                o[i + 3] = (byte)Math.Round(outA * 255);
            }
            return o;
        }

        // Only the part of an icon inside a box (on the 256 grid), for badges on art that differs
        public static byte[] Clip(byte[] px, int size, int x0, int y0, int x1, int y1) {
            byte[] o = (byte[])px.Clone();
            for (int y = 0; y < size; y++)
                for (int x = 0; x < size; x++) {
                    int gx = x * 256 / size, gy = y * 256 / size;
                    if (gx < x0 || gx >= x1 || gy < y0 || gy >= y1) o[(y * size + x) * 4 + 3] = 0;
                }
            return o;
        }

        static byte[] Png(byte[] px, int size) {
            using (var bmp = new Bitmap(size, size, PixelFormat.Format32bppArgb)) {
                var bd = bmp.LockBits(new Rectangle(0, 0, size, size), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
                for (int y = 0; y < size; y++) Marshal.Copy(px, y * size * 4, IntPtr.Add(bd.Scan0, y * bd.Stride), size * 4);
                bmp.UnlockBits(bd);
                var ms = new MemoryStream();
                bmp.Save(ms, ImageFormat.Png);
                return ms.ToArray();
            }
        }

        // 32-bit DIB frame like Windows' own small icons: header, bottom-up BGRA, then the AND mask
        static byte[] Dib(byte[] px, int size) {
            int maskStride = ((size + 31) / 32) * 4, maskOff = 40 + size * size * 4;
            byte[] b = new byte[maskOff + maskStride * size];
            BitConverter.GetBytes(40).CopyTo(b, 0);
            BitConverter.GetBytes(size).CopyTo(b, 4);
            BitConverter.GetBytes(size * 2).CopyTo(b, 8);
            BitConverter.GetBytes((short)1).CopyTo(b, 12);
            BitConverter.GetBytes((short)32).CopyTo(b, 14);
            BitConverter.GetBytes(b.Length - 40).CopyTo(b, 20);
            for (int y = 0; y < size; y++) {
                Buffer.BlockCopy(px, y * size * 4, b, 40 + (size - 1 - y) * size * 4, size * 4);
                for (int x = 0; x < size; x++)
                    if (px[(y * size + x) * 4 + 3] == 0) b[maskOff + (size - 1 - y) * maskStride + x / 8] |= (byte)(0x80 >> (x % 8));
            }
            return b;
        }

        readonly SortedDictionary<int, SortedDictionary<int, byte[]>> groups = new SortedDictionary<int, SortedDictionary<int, byte[]>>();

        public void Add(int group, int size, byte[] px) {
            if (!groups.ContainsKey(group)) groups[group] = new SortedDictionary<int, byte[]>();
            groups[group][size] = px;
        }

        // Any PE file works as the base: its own resources are dropped and only ours are written
        public void Save(string basePath, string outPath) {
            File.Copy(basePath, outPath, true);
            File.SetAttributes(outPath, FileAttributes.Normal);
            IntPtr h = BeginUpdateResource(outPath, true);
            if (h == IntPtr.Zero) throw new Exception("BeginUpdateResource failed: " + Marshal.GetLastWin32Error());
            int nextId = 1;
            bool ok = false;
            try {
                foreach (var g in groups) {
                    var frames = new List<KeyValuePair<int, byte[]>>(g.Value);
                    frames.Reverse(); // largest first, like Windows' own groups
                    byte[] dir = new byte[6 + 14 * frames.Count];
                    BitConverter.GetBytes((short)1).CopyTo(dir, 2);
                    BitConverter.GetBytes((short)frames.Count).CopyTo(dir, 4);
                    for (int i = 0; i < frames.Count; i++) {
                        int size = frames[i].Key;
                        byte[] data = size >= 256 ? Png(frames[i].Value, size) : Dib(frames[i].Value, size);
                        if (!UpdateResource(h, (IntPtr)3, (IntPtr)nextId, Lang, data, (uint)data.Length))
                            throw new Exception("UpdateResource failed: " + Marshal.GetLastWin32Error());
                        int o = 6 + i * 14;
                        dir[o] = (byte)(size >= 256 ? 0 : size);
                        dir[o + 1] = dir[o];
                        BitConverter.GetBytes((short)1).CopyTo(dir, o + 4);
                        BitConverter.GetBytes((short)32).CopyTo(dir, o + 6);
                        BitConverter.GetBytes(data.Length).CopyTo(dir, o + 8);
                        BitConverter.GetBytes((short)nextId).CopyTo(dir, o + 12);
                        nextId++;
                    }
                    if (!UpdateResource(h, (IntPtr)14, (IntPtr)g.Key, Lang, dir, (uint)dir.Length))
                        throw new Exception("UpdateResource failed: " + Marshal.GetLastWin32Error());
                }
                ok = true;
            } finally {
                if (!EndUpdateResource(h, !ok) && ok) throw new Exception("EndUpdateResource failed: " + Marshal.GetLastWin32Error());
            }
        }
    }
}
"@

# Which of Windows' icons get replaced, by group: Art is what New-FolderPng draws; with Ref, the
# group keeps Windows' badge (whatever differs from the plain icon Ref) on our art. Folders 5 / 6
# are the back and front Explorer draws a folder's previews between; the colored known folders,
# Home and Gallery get our symbol.
$SystemResources = "$env:SystemRoot\SystemResources"
$RedirectLibraries = @(
    @{ File = 'imageres.dll'; Module = "$SystemResources\imageres.dll.mun"; Icons = @(
        @{ Art = 'folder'; Ids = @(3, 4, 9, 10, 18, 115, 123, 162, 181, 185, 186, 190) }
        @{ Art = 'back'; Ids = @(5) }
        @{ Art = 'front'; Ids = @(6) }
        @{ Art = 'folder'; Ref = 3; Ids = @(73, 74, 77, 129, 143, 166, 174, 175, 178, 1025) }
        @{ Art = 'folder'; Glyph = 'music'; Ids = @(108) }
        @{ Art = 'folder'; Glyph = 'documents'; Ids = @(112) }
        @{ Art = 'folder'; Glyph = 'pictures'; Ids = @(113) }
        @{ Art = 'folder'; Glyph = 'desktop'; Ids = @(183) }
        @{ Art = 'folder'; Glyph = 'downloads'; Ids = @(184) }
        @{ Art = 'folder'; Glyph = 'videos'; Ids = @(189) }
        @{ Art = 'drive'; Ids = @(32, 35) }
        @{ Art = 'drive'; Ref = 32; Ids = @(28, 29, 30, 33, 36, 37, 42, 43, 44, 58) }
        @{ Art = 'computer'; Ids = @(109) }
        @{ Art = 'computer'; Ref = 109; Ids = @(149, 152) }
        # Network: Windows draws a different monitor there, so only its globe is kept (Clip: x0 y0 x1 y1)
        @{ Art = 'computer'; Ref = 109; Clip = @(0, 0, 112, 112); Ids = @(25) }) }
    @{ File = 'shell32.dll'; Module = "$SystemResources\shell32.dll.mun"; Icons = @(
        @{ Art = 'folder'; Ids = @(4, 5, 173, 264, 319, 16772) }
        @{ Art = 'folder'; Ref = 4; Ids = @(20, 37, 39, 46, 146, 172, 210, 256, 267, 16715, 16781, 37219) }
        @{ Art = 'folder'; Glyph = 'home'; Ids = @(51380) }
        @{ Art = 'folder'; Glyph = 'gallery'; Ids = @(51586) }
        @{ Art = 'drive'; Ids = @(8, 9) }
        @{ Art = 'drive'; Ref = 8; Ids = @(10, 12, 54) }
        @{ Art = 'computer'; Ids = @(16) }
        @{ Art = 'computer'; Ref = 16; Clip = @(0, 0, 112, 112); Ids = @(15, 18) }) }
    # zip folders are drawn on imageres' folder
    @{ File = 'zipfldr.dll'; Module = "$SystemResources\zipfldr.dll.mun"; Icons = @(
        @{ Art = 'folder'; Ref = 3; RefModule = "$SystemResources\imageres.dll.mun"; Ids = @(101, 123, 124) }) }
)

function Build-RedirectTheme([string]$Dir, [string]$Accent) {
    Add-Type -AssemblyName PresentationCore, WindowsBase, System.Drawing
    if (-not ('Omadows.IconRes' -as [type])) { Add-Type -TypeDefinition $IconResCode -ReferencedAssemblies System.Drawing }
    $tmp = "$Dir.tmp"
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force $tmp | Out-Null
    $art = @{}
    $ini = @('[redirections]')
    foreach ($lib in $RedirectLibraries) {
        $dll = New-Object Omadows.IconRes
        foreach ($group in $lib.Icons) {
            # the plain Windows icon the badged ones are compared against
            $ref = if ($group.Ref) { [Omadows.IconRes]::Frames($(if ($group.RefModule) { $group.RefModule } else { $lib.Module }), $group.Ref) }
            foreach ($id in $group.Ids) {
                $orig = [Omadows.IconRes]::Frames($lib.Module, $id)
                # same sizes as the icon it replaces
                foreach ($size in @($orig.Keys)) {
                    $key = "$size/$($group.Art)/$($group.Glyph)"
                    if (-not $art.ContainsKey($key)) { $art[$key] = [Omadows.IconRes]::FromPng((New-FolderPng $size $Accent $group.Glyph $group.Art)) }
                    if (-not $ref) { $dll.Add($id, $size, $art[$key]) }
                    elseif ($ref.ContainsKey($size)) {
                        $badge = $orig[$size]
                        if ($group.Clip) { $c = $group.Clip; $badge = [Omadows.IconRes]::Clip($badge, $size, $c[0], $c[1], $c[2], $c[3]) }
                        $dll.Add($id, $size, [Omadows.IconRes]::Badge($art[$key], $badge, $ref[$size]))
                    }
                }
            }
        }
        $dll.Save("$env:SystemRoot\System32\imageres.dll", (Join-Path $tmp $lib.File))
        # 32-bit programs load the SysWOW64 copies
        $ini += "%SystemRoot%\System32\$($lib.File)=$($lib.File)"
        $ini += "%SystemRoot%\SysWOW64\$($lib.File)=$($lib.File)"
    }
    [IO.File]::WriteAllLines((Join-Path $tmp 'theme.ini'), [string[]]$ini)
    Remove-Item $Dir -Recurse -Force -ErrorAction SilentlyContinue
    Rename-Item $tmp (Split-Path $Dir -Leaf)
}

# Windhawk's Resource Redirect mod, when installed, loads our DLLs instead of Windows' icon libraries
# in every program. Our theme path goes first so it wins; paths added in Windhawk itself are kept.
function Set-RedirectTheme([string]$Color) {
    $modKey = 'SOFTWARE\Windhawk\Engine\Mods\icon-resource-redirect'
    $hklm = [Microsoft.Win32.Registry]::LocalMachine
    $mod = $hklm.OpenSubKey($modKey, $true)
    if (-not $mod) { return }
    $dir = $null
    if ($Color -ne 'default') {
        # the version makes a changed icon list rebuild the DLLs of a color built before
        $dir = Join-Path $iconRoot ('redirect-2-' + $Color.Substring(1))
        if (-not (Test-Path (Join-Path $dir 'theme.ini'))) { Build-RedirectTheme $dir $Color }
    }
    $settings = $mod.CreateSubKey('Settings')
    $paths = @()
    for ($i = 0; ; $i++) {
        $p = [string]$settings.GetValue("themePaths[$i]")
        if (-not $p) { break }
        if (-not $p.StartsWith((Join-Path $iconRoot 'redirect-'), [StringComparison]::OrdinalIgnoreCase)) { $paths += $p }
    }
    if ($dir) { $paths = @($dir) + $paths }
    foreach ($n in $settings.GetValueNames()) { if ($n.StartsWith('themePaths[')) { $settings.DeleteValue($n) } }
    for ($i = 0; $i -lt $paths.Count; $i++) { $settings.SetValue("themePaths[$i]", $paths[$i], [Microsoft.Win32.RegistryValueKind]::String) }
    # folders with previews are only themed when every resource load is redirected
    if ($dir) { $settings.SetValue('allResourceRedirect', 1, [Microsoft.Win32.RegistryValueKind]::DWord) }
    $settings.Close()
    # Windhawk hands a mod its new settings when this value changes
    $mod.SetValue('SettingsChangeTime', [int](([DateTime]::UtcNow - [DateTime]'1970-01-01').TotalSeconds), [Microsoft.Win32.RegistryValueKind]::DWord)
    $mod.Close()
    # DLLs of earlier colors stay loaded until every program has switched; whatever is still in use
    # is removed on a later run
    Start-Sleep -Seconds 2
    Get-ChildItem $iconRoot -Directory -Filter 'redirect-*' -ErrorAction SilentlyContinue | Where-Object { -not $dir -or $_.FullName -ne $dir } | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}

# Explorer's background: Windhawk's Translucent Windows mod blurs it and tints it with the theme's
# background (its custom rendering also paints selections and drive fill bars in the accent), and
# Windows 11 File Explorer Styler's "Translucent Explorer11" theme lets the top bar show it.
# Explorer Visual Tweaks Dark, if installed, paints only the drive fill bars (track included) in
# the theme's colors; its other parts would fight Translucent Windows. Each mod is set up once when
# first seen (later changes made in Windhawk are kept); after that only the colors follow the theme.
function Set-ExplorerBackground([string]$Color, [string]$Alpha, [hashtable]$Bars) {
    $hklm = [Microsoft.Win32.Registry]::LocalMachine
    $done = $hklm.CreateSubKey('SOFTWARE\Omadows\WindhawkSetup')
    $mods = @(
        @{ Id = 'translucent-windows'
           Setup = @{ 'BackgroundEffects.type' = 'acrylicblur'; 'RenderingMod.ThemeBackground' = 1; 'RenderingMod.AccentColorControls' = 1 }
           # "default" is the mod's own blend
           Values = @{ 'BackgroundEffects.AccentBlurBehind' = $(if ($Color -eq 'default') { '3A232323' } else { $Alpha + $Color.Substring(1).ToUpper() }) } }
        @{ Id = 'windows-11-file-explorer-styler'; Setup = @{ 'theme' = 'Translucent Explorer11' }; Values = @{} }
    )
    if ($Bars) {
        $hex = { param($c) $c.TrimStart('#').ToUpper() }
        $mods += @{ Id = 'explorer-visual-tweaks-dark'
            Setup = @{ 'itemsView.customizeItemsView' = 0; 'navigationPane.customizeNavigationPane' = 0; 'previewPane.matchDetailsPaneBg' = 0
                       'progress.customizeProgress' = 1; 'progress.showProgressBorder' = 1 }
            Values = @{ 'progress.fillLeft' = & $hex $Bars.accent; 'progress.fillRight' = & $hex (Get-Mix $Bars.accent '#ffffff' 0.2)
                        'progress.fullLeft' = & $hex $Bars.red; 'progress.fullRight' = & $hex (Get-Mix $Bars.red '#ffffff' 0.2)
                        'progress.background' = & $hex (Get-Mix $Bars.background $Bars.foreground 0.16)
                        'progress.backgroundBorder' = & $hex (Get-Mix $Bars.background $Bars.foreground 0.26) } }
    }
    foreach ($m in $mods) {
        $mod = $hklm.OpenSubKey("SOFTWARE\Windhawk\Engine\Mods\$($m.Id)", $true)
        if (-not $mod) { continue }
        $settings = $mod.CreateSubKey('Settings')
        $values = $m.Values.Clone()
        if (-not $done.GetValue($m.Id)) {
            foreach ($k in $m.Setup.Keys) { $values[$k] = $m.Setup[$k] }
            # it hooks every program by default; only Explorer needs it
            if ($m.Id -eq 'translucent-windows' -and -not $mod.GetValue('IncludeCustom')) {
                $mod.SetValue('IncludeCustom', 'explorer.exe', [Microsoft.Win32.RegistryValueKind]::String)
                $mod.SetValue('IncludeExcludeCustomOnly', 1, [Microsoft.Win32.RegistryValueKind]::DWord)
            }
            $done.SetValue($m.Id, 1, [Microsoft.Win32.RegistryValueKind]::DWord)
        }
        $changed = $false
        foreach ($k in $values.Keys) {
            $kind = if ($values[$k] -is [int]) { [Microsoft.Win32.RegistryValueKind]::DWord } else { [Microsoft.Win32.RegistryValueKind]::String }
            if ([string]$settings.GetValue($k) -ne [string]$values[$k]) { $settings.SetValue($k, $values[$k], $kind); $changed = $true }
        }
        $settings.Close()
        if ($changed) { $mod.SetValue('SettingsChangeTime', [int](([DateTime]::UtcNow - [DateTime]'1970-01-01').TotalSeconds), [Microsoft.Win32.RegistryValueKind]::DWord) }
        $mod.Close()
    }
    $done.Close()
}

if ($colors['brave']) {
    $key = 'HKLM:\SOFTWARE\Policies\BraveSoftware\Brave'
    if ($colors['brave'] -eq 'default') {
        Remove-ItemProperty $key -Name BrowserThemeColor, BrowserColorScheme -ErrorAction SilentlyContinue
    } else {
        if (-not (Test-Path $key)) { New-Item $key -Force | Out-Null }
        Set-ItemProperty $key -Name BrowserThemeColor -Value $colors['brave'] -Type String
        Set-ItemProperty $key -Name BrowserColorScheme -Value 'device' -Type String
    }
}

if ($colors['folder']) {
    # before the Shell Icons key: the switcher waits for that key, then refreshes Explorer's icons
    try { Set-RedirectTheme $colors['folder'] } catch { [IO.File]::WriteAllText((Join-Path $PSScriptRoot 'last-error.txt'), "Windhawk icons: $($_.Exception.Message)") }
    $k = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Icons'
    if ($colors['folder'] -eq 'default') {
        Remove-ItemProperty $k -Name '3', '4' -ErrorAction SilentlyContinue
        Get-ChildItem $iconRoot -Filter 'folder-*.ico' -ErrorAction SilentlyContinue | Remove-Item -ErrorAction SilentlyContinue
    } else {
        Add-Type -AssemblyName PresentationCore, WindowsBase
        $ico = Join-Path $iconRoot ('folder-' + $colors['folder'].Substring(1) + '.ico')
        if (-not (Test-Path $ico)) { Write-FolderIco $ico $colors['folder'] $null }
        # a new file name per color makes Explorer drop its cached folder icon
        if (-not (Test-Path $k)) { New-Item $k -Force | Out-Null }
        Set-ItemProperty $k -Name '3' -Value "$ico,0" -Type String
        Set-ItemProperty $k -Name '4' -Value "$ico,0" -Type String
        Get-ChildItem $iconRoot -Filter 'folder-*.ico' | Where-Object { $_.FullName -ne $ico } | Remove-Item -ErrorAction SilentlyContinue
    }
}

if ($colors['explorer']) {
    try { Set-ExplorerBackground $colors['explorer'] $ExplorerAlpha $BarColors } catch { [IO.File]::WriteAllText((Join-Path $PSScriptRoot 'last-error.txt'), "Explorer background: $($_.Exception.Message)") }
}

if ($colors['special']) {
    $hklm = [Microsoft.Win32.Registry]::LocalMachine
    # the Windows originals (with their value type) are saved once so "special default" can restore them
    $saved = $hklm.CreateSubKey('SOFTWARE\Omadows\KnownFolderIcons')
    foreach ($name in $KnownFolders.Keys) {
        $fd = $hklm.OpenSubKey("SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\$($KnownFolders[$name])", $true)
        if (-not $fd) { continue }
        if ($null -eq $saved.GetValue($name)) {
            $orig = $fd.GetValue('Icon', $null, 'DoNotExpandEnvironmentNames')
            if ($null -ne $orig) { $saved.SetValue($name, $orig, $fd.GetValueKind('Icon')) }
        }
        if ($colors['special'] -eq 'default') {
            $orig = $saved.GetValue($name, $null, 'DoNotExpandEnvironmentNames')
            if ($null -ne $orig) { $fd.SetValue('Icon', $orig, $saved.GetValueKind($name)) }
        } else {
            Add-Type -AssemblyName PresentationCore, WindowsBase
            $ico = Join-Path $iconRoot ($colors['special'].Substring(1) + "\$name.ico")
            if (-not (Test-Path $ico)) { Write-FolderIco $ico $colors['special'] $name }
            $fd.SetValue('Icon', "$ico,0", [Microsoft.Win32.RegistryValueKind]::String)
        }
        $fd.Close()
    }
    $saved.Close()
    # symbol icons of earlier colors are no longer referenced
    $keep = if ($colors['special'] -eq 'default') { '' } else { $colors['special'].Substring(1) }
    Get-ChildItem $iconRoot -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne $keep -and $_.Name -notlike 'redirect-*' } | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}
'@
    [IO.File]::WriteAllText($helper, $code.Replace('__COLOR_FILE__', $ColorFile.Replace("'", "''")), (New-Object System.Text.UTF8Encoding $false))

    $svc = New-Object -ComObject Schedule.Service
    $svc.Connect()
    $root = $svc.GetFolder('\')
    try { $folder = $root.GetFolder('Omadows') } catch { $folder = $root.CreateFolder('Omadows') }
    $def = $svc.NewTask(0)
    $def.RegistrationInfo.Description = 'Applies the current Omadows theme to Brave (BrowserThemeColor policy), the Explorer folder and known-folder icons, the Windhawk Resource Redirect icons and the Windhawk Explorer background mods.'
    $def.Settings.ExecutionTimeLimit = 'PT2M'
    $def.Settings.DisallowStartIfOnBatteries = $false
    $def.Settings.StopIfGoingOnBatteries = $false
    $def.Principal.RunLevel = 1
    $action = $def.Actions.Create(0)
    $action.Path = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    $action.Arguments = "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$helper`""
    # SYSTEM and admins own it; the user may only read and start it
    $sddl = "D:(A;;FA;;;BA)(A;;FA;;;SY)(A;;GRGX;;;$UserSid)"
    [void]$folder.RegisterTaskDefinition('Theme colors', $def, 6, 'SYSTEM', $null, 5, $sddl)
}

# Windhawk mods, pinned to the versions tested with the theme switcher: Resource Redirect (folder,
# drive and This PC icons), Translucent Windows + Windows 11 File Explorer Styler (Explorer's
# tinted background; Translucent Windows only in Explorer) and Explorer Visual Tweaks Dark (only
# the drive fill bars). Settings are the mods' defaults with these changes; the theme-dependent
# ones (icon theme path, tint, bar colors) are written by the theme switcher's helper task.
$WindhawkMods = @(
    @{ Id = 'icon-resource-redirect'; Version = '1.3'; Include = '*'; Architecture = ''
       Settings = [ordered]@{ 'iconTheme' = ''; 'disableThumbnails' = 0; 'allResourceRedirect' = 1; 'themePaths[0]' = ''
                              'redirectionResourcePaths[0].original' = ''; 'redirectionResourcePaths[0].redirect' = ''; 'themeFolder' = '' } }
    @{ Id = 'translucent-windows'; Version = '1.8.2'; Include = '*'; Architecture = ''; IncludeCustom = 'explorer.exe'
       Settings = [ordered]@{ 'RenderingMod.ThemeBackground' = 1; 'RenderingMod.SysColors' = 0; 'RenderingMod.AccentColorControls' = 1
                              'BackgroundEffects.type' = 'acrylicblur'; 'BackgroundEffects.AccentBlurBehind' = '3A232323'; 'FlyoutsEffects' = 1
                              'RuledPrograms[0].target' = 'Notepad.exe'; 'RuledPrograms[0].RenderingMod.ThemeBackground' = 0
                              'RuledPrograms[0].RenderingMod.AccentColorControls' = 0; 'RuledPrograms[0].BackgroundEffects.type' = 'none'
                              'RuledPrograms[0].BackgroundEffects.AccentBlurBehind' = '3A232323' } }
    @{ Id = 'windows-11-file-explorer-styler'; Version = '1.7'; Include = 'explorer.exe'; Architecture = 'x86-64'
       Settings = [ordered]@{ 'theme' = 'Translucent Explorer11'; 'backgroundTranslucentEffect' = ''; 'backgroundTranslucentEffectRegion' = ''
                              'styleConstants[0]' = ''; 'controlStyles[0].target' = ''; 'controlStyles[0].styles[0]' = ''
                              'themeResourceVariables[0]' = ''; 'explorerFrameContainerHeight' = 0; 'xamlDiagnosticsHandling' = 'alert' } }
    @{ Id = 'explorer-visual-tweaks-dark'; Version = '1.0.1'; Include = 'explorer.exe|prevhost.exe'; Architecture = 'x86-64'
       Settings = [ordered]@{ 'itemsView.customizeItemsView' = 0; 'navigationPane.customizeNavigationPane' = 0; 'navigationPane.showFocusPill' = 1
                              'navigationPane.focusPillColor' = '4CC2FF'; 'selectionAppearance.cornerRadius' = 2; 'selectionAppearance.showBorder' = 1
                              'selectionAppearance.activeFillColor' = '4D4D4D'; 'selectionAppearance.activeBorderColor' = '555555'
                              'selectionAppearance.multiFillColor' = '454545'; 'selectionAppearance.multiBorderColor' = '505050'
                              'progress.customizeProgress' = 1; 'progress.radius' = 4; 'progress.fillLeft' = '0078D7'; 'progress.fillRight' = '0094FE'
                              'progress.fullLeft' = 'E43060'; 'progress.fullRight' = 'ED6050'; 'progress.background' = '454545'
                              'progress.showProgressBorder' = 1; 'progress.backgroundBorder' = '323232'
                              'previewPane.matchDetailsPaneBg' = 0; 'previewPane.previewPaneBgColor' = '191919' } }
)

# Installs a mod the way Windhawk's own window does: its precompiled DLLs and source from
# mods.windhawk.net, the registry entry and the settings. Windhawk's service sees the new entry and
# loads the mod right away. A mod that is already installed (any version) is left alone.
function Install-WindhawkMods {
    if (-not (Test-Path "$env:ProgramFiles\Windhawk\windhawk.exe")) { throw 'Windhawk is not installed' }
    $data = Join-Path $env:ProgramData 'Windhawk'
    $hklm = [Microsoft.Win32.Registry]::LocalMachine
    $arm = $env:PROCESSOR_ARCHITECTURE -eq 'ARM64' -or $env:PROCESSOR_ARCHITEW6432 -eq 'ARM64'
    $installed = @()
    foreach ($m in $WindhawkMods) {
        $keyPath = "SOFTWARE\Windhawk\Engine\Mods\$($m.Id)"
        $existing = $hklm.OpenSubKey($keyPath)
        if ($existing) { $existing.Close(); Write-Info "$($m.Id) already installed"; continue }
        $url = "https://mods.windhawk.net/mods/$($m.Id)/$($m.Version)"
        $file = '{0}_{1}_{2}.dll' -f $m.Id, $m.Version, (Get-Random -Minimum 100000 -Maximum 1000000)
        # 64-bit always; 32-bit (and arm64 on ARM PCs) unless the mod is x86-64 only
        $targets = @('64')
        if ($m.Architecture -ne 'x86-64') { $targets += '32'; if ($arm) { $targets += 'arm64' } }
        foreach ($t in $targets) {
            $dir = Join-Path $data "Engine\Mods\$t"
            New-Item -ItemType Directory -Force $dir | Out-Null
            try { Invoke-WebRequest "$($url)_$t.dll" -OutFile (Join-Path $dir $file) -UseBasicParsing }
            catch { if ($t -eq '64') { throw "$($m.Id): download failed ($($_.Exception.Message))" } }
        }
        New-Item -ItemType Directory -Force (Join-Path $data 'ModsSource') | Out-Null
        Invoke-WebRequest "$url.wh.cpp" -OutFile (Join-Path $data "ModsSource\$($m.Id).wh.cpp") -UseBasicParsing
        # disabled until the settings are in place, so the mod never starts without them
        $key = $hklm.CreateSubKey($keyPath)
        $key.SetValue('Disabled', 1, [Microsoft.Win32.RegistryValueKind]::DWord)
        $settings = $key.CreateSubKey('Settings')
        foreach ($n in $m.Settings.Keys) {
            $v = $m.Settings[$n]
            if ($v -is [int]) { $settings.SetValue($n, $v, [Microsoft.Win32.RegistryValueKind]::DWord) } else { $settings.SetValue($n, [string]$v, [Microsoft.Win32.RegistryValueKind]::String) }
        }
        $settings.Close()
        foreach ($n in 'Include', 'Architecture', 'Version') { $key.SetValue($n, [string]$m[$n], [Microsoft.Win32.RegistryValueKind]::String) }
        $key.SetValue('Exclude', '', [Microsoft.Win32.RegistryValueKind]::String)
        if ($m.IncludeCustom) {
            $key.SetValue('IncludeCustom', $m.IncludeCustom, [Microsoft.Win32.RegistryValueKind]::String)
            $key.SetValue('IncludeExcludeCustomOnly', 1, [Microsoft.Win32.RegistryValueKind]::DWord)
        }
        $key.SetValue('LibraryFileName', $file, [Microsoft.Win32.RegistryValueKind]::String)
        $key.SetValue('SettingsChangeTime', [int](([DateTime]::UtcNow - [DateTime]'1970-01-01').TotalSeconds), [Microsoft.Win32.RegistryValueKind]::DWord)
        $key.SetValue('Disabled', 0, [Microsoft.Win32.RegistryValueKind]::DWord)
        $key.Close()
        $installed += $m
        Write-Info "$($m.Id) $($m.Version) installed"
    }
    # Windhawk's window lists installed versions here (for its update checks)
    $profilePath = Join-Path $data 'userprofile.json'
    if ($installed -and (Test-Path $profilePath)) {
        $p = Get-Content $profilePath -Raw | ConvertFrom-Json
        if (-not $p.mods) { Set-Prop $p 'mods' ([pscustomobject]@{}) }
        foreach ($m in $installed) { Set-Prop $p.mods $m.Id ([pscustomobject]@{ version = $m.Version }) }
        [IO.File]::WriteAllText($profilePath, ($p | ConvertTo-Json -Depth 10), $Utf8NoBom)
    }
    if ((Get-Service windhawk -ErrorAction SilentlyContinue).Status -ne 'Running') { Start-Service windhawk -ErrorAction SilentlyContinue }
}

$MachinePackages = @('LGUG2Z.komorebi', 'LGUG2Z.whkd', 'AmN.yasb', 'RamenSoftware.Windhawk')
$TerminalExtras = @('Microsoft.PowerShell', 'Starship.Starship', 'Fastfetch-cli.Fastfetch')

function Install-MachinePackages {
    Ensure-Winget
    $ids = $MachinePackages
    if (-not $SkipTerminalExtras) { $ids += $TerminalExtras }
    $failed = @()
    foreach ($id in $ids) { if (-not (Install-Package $id)) { $failed += $id } }
    if ($failed -notcontains 'RamenSoftware.Windhawk') {
        try { Install-WindhawkMods } catch { $failed += "Windhawk mods ($($_.Exception.Message))" }
    }
    # komorebi recommends long path support
    Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name LongPathsEnabled -Value 1 -Type DWord
    # lets theme switches recolor Brave and Explorer's folder icon later without admin
    try { Install-ThemeColorsTask (Join-Path $UserProfile '.config\omadows\theme-colors') $UserSid }
    catch { $failed += "theme colors task ($($_.Exception.Message))" }
    return $failed
}

# Deletes files, retrying while programs let go of them; what is still in use Windows deletes at
# the next restart. Returns how many are left for the restart.
function Remove-Files([string[]]$Paths, [int]$Seconds) {
    for ($i = 0; $i -lt $Seconds * 2 -and @($Paths | Where-Object { Test-Path $_ }).Count; $i++) {
        $Paths | Where-Object { Test-Path $_ } | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 500
    }
    $left = @($Paths | Where-Object { Test-Path $_ })
    foreach ($p in $left) {
        # files first, then their folders from the deepest up (a folder goes once it's empty)
        $items = @(Get-ChildItem $p -Recurse -Force -ErrorAction SilentlyContinue | Sort-Object { $_.FullName.Length } -Descending) + @(Get-Item $p -Force)
        foreach ($item in $items) { [void][Win32.Native]::MoveFileEx($item.FullName, [NullString]::Value, 4) }   # MOVEFILE_DELAY_UNTIL_REBOOT
    }
    return $left.Count
}

# Removes the four mods the way Windhawk's window does: its service unloads a mod as soon as the
# registry entry is gone, then the files can go
function Uninstall-WindhawkMods {
    $data = Join-Path $env:ProgramData 'Windhawk'
    $hklm = [Microsoft.Win32.Registry]::LocalMachine
    $files = @()
    $removed = @()
    foreach ($m in $WindhawkMods) {
        $keyPath = "SOFTWARE\Windhawk\Engine\Mods\$($m.Id)"
        $key = $hklm.OpenSubKey($keyPath)
        if ($key) {
            $key.Close()
            $hklm.DeleteSubKeyTree($keyPath)
            $removed += $m.Id
            Write-Info "$($m.Id) removed"
        }
        # every compiled version of the mod, also ones an earlier run couldn't delete
        foreach ($t in '32', '64', 'arm64') { $files += @(Get-ChildItem (Join-Path $data "Engine\Mods\$t") -Filter "$($m.Id)_*.dll" -ErrorAction SilentlyContinue | ForEach-Object FullName) }
        $files += Join-Path $data "ModsSource\$($m.Id).wh.cpp"
    }
    # the DLLs stay locked until every program has unloaded the mod
    $left = Remove-Files $files 10
    if ($left) { Write-Info "$left mod file(s) still in use; Windows deletes them at the next restart" }
    $profilePath = Join-Path $data 'userprofile.json'
    if ($removed -and (Test-Path $profilePath)) {
        $p = Get-Content $profilePath -Raw | ConvertFrom-Json
        if ($p.mods) { foreach ($id in $removed) { $p.mods.PSObject.Properties.Remove($id) } }
        [IO.File]::WriteAllText($profilePath, ($p | ConvertTo-Json -Depth 10), $Utf8NoBom)
    }
}

# Known folders by FOLDERID, whose Icon the theme colors helper can change (it saved the originals)
$KnownFolderIds = [ordered]@{
    desktop = '{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}'; documents = '{FDD39AD0-238F-46AF-ADB4-6C85480369C7}'
    downloads = '{374DE290-123F-4565-9164-39C4925E467B}'; pictures = '{33E28130-4E1E-4676-835A-98395C3BC3BB}'
    music = '{4BD8D571-6D19-48D3-BE97-422220080E43}'; videos = '{18989B1D-99B5-455B-841C-AB7C74E4DDFC}'
}

# The elevated half of -Uninstall: everything the install put in machine-wide places
function Uninstall-Machine {
    $failed = @()
    try { Uninstall-WindhawkMods } catch { $failed += "Windhawk mods ($($_.Exception.Message))" }
    try {
        $svc = New-Object -ComObject Schedule.Service
        $svc.Connect()
        try {
            $folder = $svc.GetFolder('\Omadows')
            foreach ($t in @($folder.GetTasks(0))) { $folder.DeleteTask($t.Name, 0) }
            $svc.GetFolder('\').DeleteFolder('Omadows', 0)
            Write-Info 'theme colors task removed'
        } catch { }
        $hklm = [Microsoft.Win32.Registry]::LocalMachine
        $saved = $hklm.OpenSubKey('SOFTWARE\Omadows\KnownFolderIcons')
        if ($saved) {
            foreach ($name in $saved.GetValueNames()) {
                if (-not $KnownFolderIds.Contains($name)) { continue }
                $fd = $hklm.OpenSubKey("SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\$($KnownFolderIds[$name])", $true)
                if ($fd) { $fd.SetValue('Icon', $saved.GetValue($name, $null, 'DoNotExpandEnvironmentNames'), $saved.GetValueKind($name)); $fd.Close() }
            }
            $saved.Close()
        }
        Remove-Item 'HKLM:\SOFTWARE\Omadows' -Recurse -Force -ErrorAction SilentlyContinue
        # Explorer's folder icon, if it is still ours
        $icons = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Icons'
        foreach ($n in '3', '4') {
            if ([string](Get-ItemProperty $icons -ErrorAction SilentlyContinue).$n -like "*\Omadows\icons\*") { Remove-ItemProperty $icons -Name $n }
        }
        Remove-ItemProperty 'HKLM:\SOFTWARE\Policies\BraveSoftware\Brave' -Name 'BrowserThemeColor', 'BrowserColorScheme' -ErrorAction SilentlyContinue
        # its icon DLLs stay loaded until every program has noticed the icon mod is gone
        if (Remove-Files @(Join-Path $env:ProgramFiles 'Omadows') 20) { Write-Info 'C:\Program Files\Omadows is still in use; Windows deletes it at the next restart' }
        Write-Info 'Explorer icon, Brave policy and Program Files\Omadows removed'
    } catch { $failed += "theme colors parts ($($_.Exception.Message))" }
    if ($RemoveApps) {
        Ensure-Winget
        foreach ($id in $MachinePackages + $TerminalExtras) {
            Write-Info "removing $id ..."
            $r = Uninstall-Package $id
            if ($r -eq 'user') { Write-Info "$id is installed for your user only; the main window removes it" }
            elseif ($r -notin 'removed', 'absent') { $failed += "$id ($r)" }
            # Windhawk's uninstaller leaves its engine and mod files behind while programs still have
            # them loaded
            if ($id -eq 'RamenSoftware.Windhawk' -and $r -in 'removed', 'absent' -and -not (Test-Path (Join-Path $env:ProgramFiles 'Windhawk\windhawk.exe')) -and -not (Get-Service windhawk -ErrorAction SilentlyContinue)) {
                if (Remove-Files @((Join-Path $env:ProgramFiles 'Windhawk'), (Join-Path $env:ProgramData 'Windhawk')) 5) { Write-Info "Windhawk's leftover files are in use; Windows deletes them at the next restart" }
            }
        }
        Remove-StalePathEntries 'Machine'
        # the installer options PowerShell 7's setup remembers, once no PowerShell 7 is left
        if (-not (Get-ChildItem (Join-Path $env:ProgramFiles 'PowerShell') -Filter pwsh.exe -Recurse -Depth 1 -ErrorAction SilentlyContinue)) {
            Remove-Item 'HKLM:\SOFTWARE\Microsoft\PowerShellCore\InstallerProperties' -Recurse -Force -ErrorAction SilentlyContinue
            $pc = Get-Item 'HKLM:\SOFTWARE\Microsoft\PowerShellCore' -ErrorAction SilentlyContinue
            if ($pc -and $pc.SubKeyCount -eq 0 -and $pc.ValueCount -eq 0) { Remove-Item $pc.PSPath -Force }
        }
    }
    return $failed
}

if ($UninstallPhase) {
    Write-Step 'Removing the machine-wide parts'
    $failed = @(Uninstall-Machine)
    if ($failed.Count) {
        Write-Warn ('Not removed: ' + ($failed -join '; '))
        Read-Host 'Press Enter to close this window'
        exit 1
    }
    exit 0
}

if ($InstallPhase) {
    Write-Step 'Installing machine-wide packages'
    $failed = @(Install-MachinePackages)
    if ($failed.Count) {
        Write-Warn ('These packages failed: ' + ($failed -join ', '))
        Read-Host 'Press Enter to close this window'
        exit 1
    }
    exit 0
}

# ---------------------------------------------------------------------------------------------
# User half
# ---------------------------------------------------------------------------------------------

function Install-NerdFont {
    $fontDir = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
    $reg = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
    if (Test-Path "$fontDir\JetBrainsMonoNerdFontPropo-Regular.ttf") { Write-Info 'already installed'; return }
    $tmp = Join-Path $env:TEMP "nerdfont-$Stamp"
    New-Item -ItemType Directory -Force $tmp | Out-Null
    try {
        $rel = Invoke-RestMethod 'https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest' -Headers @{ 'User-Agent' = 'omadows-setup' } -UseBasicParsing
        $asset = $rel.assets | Where-Object { $_.name -eq 'JetBrainsMono.zip' }
        Write-Info "downloading JetBrainsMono Nerd Font $($rel.tag_name) ..."
        Invoke-WebRequest $asset.browser_download_url -OutFile "$tmp\JetBrainsMono.zip" -UseBasicParsing
        Expand-Archive "$tmp\JetBrainsMono.zip" -DestinationPath "$tmp\x" -Force
        New-Item -ItemType Directory -Force $fontDir | Out-Null
        if (-not (Test-Path $reg)) { New-Item $reg -Force | Out-Null }
        # NerdFont, NerdFontMono and NerdFontPropo families (the NL variants are skipped)
        $files = Get-ChildItem "$tmp\x" -Filter 'JetBrainsMonoNerdFont*.ttf'
        foreach ($f in $files) {
            $target = Join-Path $fontDir $f.Name
            Copy-Item $f.FullName $target -Force
            Set-ItemProperty $reg -Name ($f.BaseName + ' (TrueType)') -Value $target
            [void][Win32.Native]::AddFontResource($target)
        }
        $r = [UIntPtr]::Zero
        [void][Win32.Native]::SendMessageTimeout([IntPtr]0xffff, 0x1D, [UIntPtr]::Zero, [IntPtr]::Zero, 2, 1000, [ref]$r)   # WM_FONTCHANGE
        Write-Info "installed $($files.Count) font files"
    } finally {
        Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Install-ThemeSwitcher {
    $tool = "$env:USERPROFILE\.config\omadows\omadows.ps1"
    Write-TextFile $tool $ThemeTool
    # Start-menu shortcuts (also searchable from Win+Space); whkd's theme keys open these.
    # conhost --headless keeps PowerShell from flashing a console or Windows Terminal window.
    $programs = [Environment]::GetFolderPath('Programs')
    $shell = New-Object -ComObject WScript.Shell
    foreach ($s in @(@('Omadows Theme', 'pick', 'Pick an Omarchy theme'), @('Omadows Next Wallpaper', 'next-bg', 'Next wallpaper of the current Omarchy theme'), @('Omadows Settings', 'settings', 'Gap size and the folders whose programs are not tiled'))) {
        $lnk = $shell.CreateShortcut((Join-Path $programs "$($s[0]).lnk"))
        $lnk.TargetPath = "$env:SystemRoot\System32\conhost.exe"
        $lnk.Arguments = "--headless powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$tool`" $($s[1])"
        $lnk.Description = $s[2]
        $lnk.IconLocation = "$env:SystemRoot\System32\themecpl.dll,0"
        $lnk.WindowStyle = 7
        $lnk.Save()
    }
    # 4 px gaps and the untiled game folders found on this PC (settings.json, editable in Omadows Settings)
    if ((Invoke-Native 'powershell.exe' @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $tool, 'apply-settings')) -ne 0) { Write-Warn 'gap and game-folder settings were not applied; open Omadows Settings later' }
    Write-Info 'downloading the Tokyo Night wallpapers and theming every app ...'
    $code = Invoke-Native 'powershell.exe' @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $tool, 'set', 'tokyo-night')
    if ($code -ne 0) { throw "the theme switcher reported problems; see $env:USERPROFILE\.config\omadows\omadows.log" }
}

function Set-DarkMode {
    $k = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
    if (-not (Test-Path $k)) { New-Item $k -Force | Out-Null }
    Set-ItemProperty $k -Name AppsUseLightTheme -Value 0 -Type DWord
    Set-ItemProperty $k -Name SystemUsesLightTheme -Value 0 -Type DWord
    Set-ItemProperty $k -Name EnableTransparency -Value 1 -Type DWord
    $r = [UIntPtr]::Zero
    [void][Win32.Native]::SendMessageTimeoutText([IntPtr]0xffff, 0x1A, [UIntPtr]::Zero, 'ImmersiveColorSet', 2, 5000, [ref]$r)   # WM_SETTINGCHANGE
}

function Set-WindowsTerminal {
    $dir = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"
    $path = Join-Path $dir 'settings.json'
    $s = $null
    if (Test-Path $path) {
        $raw = Get-Content $path -Raw
        try { $s = $raw | ConvertFrom-Json } catch {
            # older generated templates contain // comments that Windows PowerShell 5.1 cannot parse
            try { $s = (($raw -split "`r?`n") | Where-Object { $_ -notmatch '^\s*//' }) -join "`n" | ConvertFrom-Json } catch { }
        }
        if (-not $s) { throw 'could not parse settings.json; theme it by hand' }
    } else {
        # Terminal has never been opened; it fills in everything else on first launch
        New-Item -ItemType Directory -Force $dir | Out-Null
        $s = [pscustomobject]@{ '$schema' = 'https://aka.ms/terminal-profiles-schema' }
    }
    if (-not $s.profiles) { Set-Prop $s 'profiles' ([pscustomobject]@{ defaults = [pscustomobject]@{}; list = @() }) }
    if ($s.profiles -is [array]) { throw 'settings.json uses the old profiles format; theme it by hand' }
    if (-not $s.profiles.defaults) { Set-Prop $s.profiles 'defaults' ([pscustomobject]@{}) }
    # colors come from the theme switcher's "Omadows" scheme
    $d = $s.profiles.defaults
    Set-Prop $d 'font' ([pscustomobject]@{ face = 'JetBrainsMono Nerd Font Propo'; size = 11; cellHeight = '1.5' })
    Set-Prop $d 'opacity' 92
    Set-Prop $d 'useAcrylic' $true
    Set-Prop $d 'padding' '14'
    # PowerShell 7, if its install worked (Terminal warns about a default profile that doesn't exist)
    if (-not $SkipTerminalExtras -and ((Test-Path "$env:ProgramFiles\PowerShell\7\pwsh.exe") -or (Get-Command pwsh.exe -ErrorAction SilentlyContinue))) {
        Set-Prop $s 'defaultProfile' '{574e775e-4f2a-5b96-ac1e-a2962a402336}'
    }
    Write-JsonFile $path $s
}

function Set-Komorebi {
    $komorebic = Join-Path $env:ProgramFiles 'komorebi\bin\komorebic.exe'
    if (-not (Test-Path $komorebic)) { throw 'komorebi is not installed' }
    Backup-File "$env:USERPROFILE\komorebi.json"
    Backup-File "$env:USERPROFILE\.config\whkdrc"
    # quickstart fetches applications.json (community per-app rules) and writes example configs we replace
    [void](Invoke-Native $komorebic @('quickstart'))
    if (-not (Test-Path "$env:USERPROFILE\applications.json")) { Write-Warn 'applications.json was not downloaded; some apps may tile oddly' }
    Write-TextFile "$env:USERPROFILE\komorebi.json" $KomorebiJson -NoBackup
    Write-TextFile "$env:USERPROFILE\.config\whkdrc" $Whkdrc -NoBackup
}

function Set-Yasb {
    if (-not (Test-Path "$env:ProgramFiles\YASB\yasbc.exe")) { throw 'YASB is not installed' }
    # written before YASB's first start, so its welcome wizard is skipped; the theme switcher writes styles.css
    Write-TextFile "$env:USERPROFILE\.config\yasb\config.yaml" $YasbConfig
}

function Set-PowerToys {
    $ptExe = "$env:LOCALAPPDATA\PowerToys\PowerToys.exe"
    if (-not (Test-Path $ptExe)) { throw 'PowerToys is not installed' }
    $ptSettings = "$env:LOCALAPPDATA\Microsoft\PowerToys\settings.json"
    $cpDir = "$env:LOCALAPPDATA\Packages\Microsoft.CommandPalette_8wekyb3d8bbwe\LocalState"
    $cpSettings = Join-Path $cpDir 'settings.json'
    if (-not (Get-Process PowerToys -ErrorAction SilentlyContinue)) { Start-Process $ptExe }
    # PowerToys and Command Palette create their settings files on first run
    $deadline = (Get-Date).AddSeconds(90)
    while (((-not (Test-Path $ptSettings)) -or (-not (Test-Path $cpSettings))) -and (Get-Date) -lt $deadline) { Start-Sleep -Seconds 3 }
    Get-Process PowerToys*, Microsoft.CmdPal* -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 2

    if (Test-Path $ptSettings) {
        $j = Get-Content $ptSettings -Raw | ConvertFrom-Json
        Set-Prop $j 'startup' $true
        if ($j.enabled) { Set-Prop $j.enabled 'FancyZones' $false }   # FancyZones fights the tiling WM
        Write-JsonFile $ptSettings $j
    } else {
        Write-Warn 'PowerToys settings were not created in time; turn off FancyZones in PowerToys yourself'
    }

    if (Test-Path $cpSettings) { $c = Get-Content $cpSettings -Raw | ConvertFrom-Json }
    else { New-Item -ItemType Directory -Force $cpDir | Out-Null; $c = [pscustomobject]@{} }
    Set-Prop $c 'Hotkey' ([pscustomobject]@{ win = $true; ctrl = $false; alt = $false; shift = $false; code = 32; key = '' })   # Win+Space
    Set-Prop $c 'UseLowLevelGlobalHotkey' $true   # needed to take Win+Space from the language switcher
    Write-JsonFile $cpSettings $c

    Start-Process $ptExe
}

function Set-Starship {
    Update-SessionPath
    if (-not (Get-Command starship -ErrorAction SilentlyContinue)) { throw 'starship is not installed' }
    # Omarchy's prompt uses ANSI color names, so it follows whichever theme the terminal has
    $cfg = "$env:USERPROFILE\.config\starship.toml"
    if (-not (Test-Path $cfg)) {
        Invoke-WebRequest 'https://raw.githubusercontent.com/basecamp/omarchy/HEAD/config/starship.toml' -OutFile $cfg -UseBasicParsing
    }
    $docs = [Environment]::GetFolderPath('MyDocuments')
    foreach ($p in "$docs\PowerShell\Microsoft.PowerShell_profile.ps1", "$docs\WindowsPowerShell\Microsoft.PowerShell_profile.ps1") {
        if ((Test-Path $p) -and (Select-String -Path $p -SimpleMatch 'starship init' -Quiet)) { continue }
        New-Item -ItemType Directory -Force (Split-Path $p) | Out-Null
        Add-Content -Path $p -Value 'Invoke-Expression (&starship init powershell)'
    }
    # Windows PowerShell only loads profile scripts when scripts are allowed
    if ((Get-ExecutionPolicy -Scope CurrentUser) -eq 'Undefined' -and (Get-ExecutionPolicy -Scope LocalMachine) -in 'Undefined', 'Restricted') {
        Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force
        Write-Info 'execution policy for your user set to RemoteSigned (so profiles load)'
    }
}

# Desktop icons: the desktop's "Show desktop icons" command toggles them live; without a desktop
# window the setting takes effect at next sign-in
function Set-DesktopIcons([bool]$Visible) {
    $adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    if (((Get-ItemProperty $adv -ErrorAction SilentlyContinue).HideIcons -eq 1) -ne $Visible) { return }
    $n = [NullString]::Value
    $view = [Win32.Native]::FindWindowEx([Win32.Native]::FindWindow('Progman', $n), [IntPtr]::Zero, 'SHELLDLL_DefView', $n)
    $w = [IntPtr]::Zero
    while ($view -eq [IntPtr]::Zero) {
        $w = [Win32.Native]::FindWindowEx([IntPtr]::Zero, $w, 'WorkerW', $n)
        if ($w -eq [IntPtr]::Zero) { break }
        $view = [Win32.Native]::FindWindowEx($w, [IntPtr]::Zero, 'SHELLDLL_DefView', $n)
    }
    if ($view -ne [IntPtr]::Zero) {
        [void][Win32.Native]::SendMessage($view, 0x111, [IntPtr]0x7402, [IntPtr]::Zero)   # View > Show desktop icons
    } else {
        Set-ItemProperty $adv -Name HideIcons -Value $(if ($Visible) { 0 } else { 1 }) -Type DWord
    }
}

function Hide-DesktopIcons { Set-DesktopIcons $false }

function Set-TaskbarAutoHide([bool]$AutoHide) {
    # the saved setting Explorer starts with (bit 0 of byte 8), so it survives Explorer restarting...
    $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3'
    $saved = (Get-ItemProperty $key -ErrorAction SilentlyContinue).Settings
    if ($saved -and $saved.Length -gt 8) {
        $saved[8] = if ($AutoHide) { $saved[8] -bor 1 } else { $saved[8] -band 0xFE }
        Set-ItemProperty $key -Name Settings -Value $saved -Type Binary
    }
    # ...and the running taskbar
    $abd = New-Object Win32.Native+APPBARDATA
    $abd.cbSize = [Runtime.InteropServices.Marshal]::SizeOf($abd)
    $abd.hWnd = [Win32.Native]::FindWindow('Shell_TrayWnd', [NullString]::Value)
    $abd.lParam = [IntPtr]$(if ($AutoHide) { 1 } else { 2 })   # ABS_AUTOHIDE / ABS_ALWAYSONTOP
    [void][Win32.Native]::SHAppBarMessage(0x0A, [ref]$abd)   # ABM_SETSTATE
}

function Enable-TaskbarAutoHide { Set-TaskbarAutoHide $true }

# komorebi (with whkd) and YASB start from sign-in tasks: Windows holds back Startup-folder and
# Run-key apps until the desktop has gone idle, which can take minutes; sign-in tasks start at once
function Register-SignInTask([string]$Name, [string]$Exe, [string]$Arguments, [string]$Description) {
    $user = "$env:USERDOMAIN\$env:USERNAME"
    $svc = New-Object -ComObject Schedule.Service
    $svc.Connect()
    $def = $svc.NewTask(0)
    $def.RegistrationInfo.Description = $Description
    $def.Settings.ExecutionTimeLimit = 'PT0S'      # YASB keeps running; the default limit would end it after 3 days
    $def.Settings.DisallowStartIfOnBatteries = $false
    $def.Settings.StopIfGoingOnBatteries = $false
    $def.Settings.MultipleInstances = 2            # don't start a second copy
    $def.Settings.Priority = 4                     # normal; tasks default to below normal, which children inherit
    $trigger = $def.Triggers.Create(9)             # at sign-in
    $trigger.UserId = $user
    $def.Principal.UserId = $user
    $def.Principal.LogonType = 3                   # in the signed-in session, no stored password
    $def.Principal.RunLevel = 0
    $action = $def.Actions.Create(0)
    $action.Path = $Exe
    $action.Arguments = $Arguments
    [void]$svc.GetFolder('\').RegisterTaskDefinition($Name, $def, 6, $null, $null, 3)
}

function Start-Desktop {
    Update-SessionPath
    $komorebic = Join-Path $env:ProgramFiles 'komorebi\bin\komorebic.exe'
    $yasb = Join-Path $env:ProgramFiles 'YASB\yasb.exe'
    # the slower autostart entries komorebi and YASB create for themselves
    Remove-Item (Join-Path ([Environment]::GetFolderPath('Startup')) 'komorebi.lnk') -ErrorAction SilentlyContinue
    Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'YASB' -ErrorAction SilentlyContinue
    if (Test-Path $komorebic) {
        if (Get-Process komorebi -ErrorAction SilentlyContinue) { [void](Invoke-Native $komorebic @('stop', '--whkd')); Start-Sleep -Seconds 2 }
        Register-SignInTask 'Omadows komorebi' (Join-Path $env:ProgramFiles 'komorebi\bin\komorebic-no-console.exe') 'start --whkd' 'Starts komorebi and whkd when you sign in (Omadows)'
        Start-ScheduledTask -TaskName 'Omadows komorebi'
        Write-Info 'komorebi + whkd running, start at sign-in'
    }
    if (Test-Path $yasb) {
        Get-Process yasb -ErrorAction SilentlyContinue | Stop-Process -Force
        Register-SignInTask 'Omadows YASB' $yasb '' 'Starts the YASB top bar when you sign in (Omadows)'
        Start-ScheduledTask -TaskName 'Omadows YASB'
        Write-Info 'YASB running, starts at sign-in'
    }
}

# Configs the setup replaces, saved once before the first install so -Uninstall can put them back
# (komorebi's quickstart also writes komorebi.bar.json, which the setup leaves as it is)
$Originals = @('komorebi.json', 'komorebi.bar.json', 'applications.json', '.config\whkdrc', '.config\yasb\config.yaml', '.config\yasb\styles.css', '.config\starship.toml')
$OriginalsDir = Join-Path $env:USERPROFILE '.config\omadows\originals'

function Save-Originals {
    if (Test-Path $OriginalsDir) { return }
    New-Item -ItemType Directory -Force $OriginalsDir | Out-Null
    # installed before originals were kept: these files are Omadows' own
    if (Test-Path (Join-Path $env:USERPROFILE '.config\omadows\omadows.ps1')) { return }
    foreach ($rel in $Originals) {
        $p = Join-Path $env:USERPROFILE $rel
        if (-not (Test-Path $p)) { continue }
        $dst = Join-Path $OriginalsDir $rel
        New-Item -ItemType Directory -Force (Split-Path $dst) | Out-Null
        Copy-Item $p $dst
    }
}

# ---------------------------------------------------------------------------------------------
# Uninstall (-Uninstall)
# ---------------------------------------------------------------------------------------------

function Stop-Desktop {
    $komorebic = Join-Path $env:ProgramFiles 'komorebi\bin\komorebic.exe'
    # stopping komorebi shows the windows it had hidden on other workspaces again
    if ((Test-Path $komorebic) -and (Get-Process komorebi -ErrorAction SilentlyContinue)) { [void](Invoke-Native $komorebic @('stop', '--whkd')) }
    Get-Process yasb, whkd -ErrorAction SilentlyContinue | Stop-Process -Force
    foreach ($t in 'Omadows komorebi', 'Omadows YASB') { Unregister-ScheduledTask -TaskName $t -Confirm:$false -ErrorAction SilentlyContinue }
    $programs = [Environment]::GetFolderPath('Programs')
    foreach ($s in 'Omadows Theme', 'Omadows Next Wallpaper', 'Omadows Settings') { Remove-Item (Join-Path $programs "$s.lnk") -ErrorAction SilentlyContinue }
}

function Reset-WindowsTerminal([bool]$Apps) {
    $path = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    if (-not (Test-Path $path)) { return }
    $raw = Get-Content $path -Raw
    try { $s = $raw | ConvertFrom-Json } catch { $s = (($raw -split "`r?`n") | Where-Object { $_ -notmatch '^\s*//' }) -join "`n" | ConvertFrom-Json }
    if ($s.schemes) { $s.schemes = @($s.schemes | Where-Object { $_.name -ne 'Omadows' }) }
    if ($s.themes) { $s.themes = @($s.themes | Where-Object { $_.name -ne 'Omadows' }) }
    if ($s.theme -eq 'Omadows') { $s.PSObject.Properties.Remove('theme') }
    $d = $s.profiles.defaults
    if ($d) {
        # only the values the setup and the theme switcher set
        if ($d.colorScheme -eq 'Omadows') { $d.PSObject.Properties.Remove('colorScheme') }
        if ($d.font -and $d.font.face -eq 'JetBrainsMono Nerd Font Propo') { $d.PSObject.Properties.Remove('font') }
        if ($d.opacity -eq 92) { $d.PSObject.Properties.Remove('opacity') }
        if ($d.useAcrylic -eq $true) { $d.PSObject.Properties.Remove('useAcrylic') }
        if ($d.padding -eq '14') { $d.PSObject.Properties.Remove('padding') }
    }
    # without PowerShell 7, open Windows PowerShell
    if ($Apps -and $s.defaultProfile -eq '{574e775e-4f2a-5b96-ac1e-a2962a402336}') { $s.defaultProfile = '{61c54bbd-c2c6-5271-96e7-009a87ff44bf}' }
    Write-JsonFile $path $s
}

function Reset-VsCode {
    $ext = Join-Path $env:USERPROFILE '.vscode\extensions'
    Remove-Item (Join-Path $ext 'omadows-theme') -Recurse -Force -ErrorAction SilentlyContinue
    $registry = Join-Path $ext 'extensions.json'
    if (Test-Path $registry) {
        $parsed = [IO.File]::ReadAllText($registry) | ConvertFrom-Json
        $entries = @(@(foreach ($e in $parsed) { $e }) | Where-Object { $_.identifier.id -ne 'local.omadows-theme' })
        [IO.File]::WriteAllText($registry, (ConvertTo-Json -InputObject ([object[]]$entries) -Depth 16 -Compress), $Utf8NoBom)
    }
    # the color theme goes back to VS Code's default if a theme switch set it
    $settings = Join-Path $env:APPDATA 'Code\User\settings.json'
    if (-not (Test-Path $settings)) { return }
    $ours = @('Omadows') + @(Get-ChildItem (Join-Path $env:USERPROFILE '.config\omadows\themes') -Recurse -Filter vscode.json -ErrorAction SilentlyContinue |
        ForEach-Object { try { (Get-Content $_.FullName -Raw | ConvertFrom-Json).name } catch { } })
    $text = [IO.File]::ReadAllText($settings)
    $m = [regex]::Match($text, '\s*"workbench\.colorTheme"\s*:\s*"([^"]*)"\s*,?')
    if ($m.Success -and $ours -contains $m.Groups[1].Value) { [IO.File]::WriteAllText($settings, $text.Remove($m.Index, $m.Length), $Utf8NoBom) }
}

function Reset-Obsidian {
    $registry = Join-Path $env:APPDATA 'obsidian\obsidian.json'
    if (-not (Test-Path $registry)) { return }
    foreach ($v in (Get-Content $registry -Raw | ConvertFrom-Json).vaults.PSObject.Properties.Value) {
        Remove-Item (Join-Path $v.path '.obsidian\themes\Omadows') -Recurse -Force -ErrorAction SilentlyContinue
        $a = Join-Path $v.path '.obsidian\appearance.json'
        if (Test-Path $a) {
            $j = Get-Content $a -Raw | ConvertFrom-Json
            if ($j.cssTheme -eq 'Omadows') { $j.cssTheme = ''; [IO.File]::WriteAllText($a, ($j | ConvertTo-Json -Depth 8), $Utf8NoBom) }
        }
    }
}

function Reset-Profiles {
    $docs = [Environment]::GetFolderPath('MyDocuments')
    foreach ($p in "$docs\PowerShell\Microsoft.PowerShell_profile.ps1", "$docs\WindowsPowerShell\Microsoft.PowerShell_profile.ps1") {
        if (-not (Test-Path $p)) { continue }
        $lines = @([IO.File]::ReadAllLines($p) | Where-Object { $_.Trim() -ne 'Invoke-Expression (&starship init powershell)' })
        # a profile that only held the starship line was created by the setup
        if (-not ($lines | Where-Object { $_.Trim() })) { Remove-Item $p -Force } else { [IO.File]::WriteAllLines($p, [string[]]$lines) }
    }
}

function Restore-Originals {
    foreach ($rel in $Originals) {
        $p = Join-Path $env:USERPROFILE $rel
        $saved = Join-Path $OriginalsDir $rel
        if (Test-Path $saved) { Copy-Item $saved $p -Force; Write-Info "restored $rel" }
        elseif (Test-Path $p) { Remove-Item $p -Force; Write-Info "removed $rel" }
    }
    $yasb = Join-Path $env:USERPROFILE '.config\yasb'
    if ((Test-Path $yasb) -and -not (Get-ChildItem $yasb -Force)) { Remove-Item $yasb }
}

function Reset-Desktop {
    Set-TaskbarAutoHide $false
    Set-DesktopIcons $true
    # the wallpaper slideshow points into ~/.config/omadows, which goes away
    $default = Join-Path $env:SystemRoot 'Web\Wallpaper\Windows\img0.jpg'
    if (Test-Path $default) { [void][Win32.Native]::SystemParametersInfo(0x14, 0, $default, 3) }   # SPI_SETDESKWALLPAPER
    # Settings would still show "Slideshow" (2) instead of "Picture" (0)
    $wp = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers'
    if ((Get-ItemProperty $wp -ErrorAction SilentlyContinue).BackgroundType -eq 2) { Set-ItemProperty $wp -Name BackgroundType -Value 0 -Type DWord }
    # the theme switcher's slideshow options (shuffle, 5 minutes) back to Windows' defaults
    $ss = 'HKCU:\Control Panel\Personalization\Desktop Slideshow'
    $o = Get-ItemProperty $ss -ErrorAction SilentlyContinue
    if ($o.Interval -eq 300000 -and $o.Shuffle -eq 1) { Remove-ItemProperty $ss -Name Interval, Shuffle -ErrorAction SilentlyContinue }
}

# Explorer keeps some of the removed mods' styling (a black top bar) until it restarts
function Restart-Explorer {
    $old = @(Get-Process explorer -ErrorAction SilentlyContinue | ForEach-Object Id)
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    # Windows restarts the shell by itself; start it if it didn't
    $deadline = (Get-Date).AddSeconds(15)
    do { Start-Sleep -Milliseconds 500; $new = Get-Process explorer -ErrorAction SilentlyContinue | Where-Object { $old -notcontains $_.Id } } while (-not $new -and (Get-Date) -lt $deadline)
    if (-not $new) { Start-Process explorer.exe }
}

function Remove-UserApps {
    [void](Uninstall-Package 'Microsoft.PowerToys')
    # what winget installed for this user only, which the admin window can't remove
    foreach ($id in $MachinePackages + $TerminalExtras) { [void](Uninstall-Package $id 'user') }
    Remove-StalePathEntries 'User'
    # settings, logs and caches the uninstallers leave in your profile, once the app is gone
    $leftovers = @(
        @{ App = @("$env:ProgramFiles\komorebi\bin\komorebi.exe"); Paths = @("$env:LOCALAPPDATA\komorebi") }
        @{ App = @("$env:ProgramFiles\YASB\yasb.exe"); Paths = @("$env:LOCALAPPDATA\YASB", "$env:USERPROFILE\.config\yasb\yasb.log") }
        @{ App = @("$env:LOCALAPPDATA\PowerToys\PowerToys.exe", "$env:ProgramFiles\PowerToys\PowerToys.exe"); Paths = @("$env:LOCALAPPDATA\Microsoft\PowerToys", 'HKCU:\Software\Microsoft\PowerToys') }
        @{ App = @("$env:ProgramFiles\PowerShell\7\pwsh.exe"); Paths = @("$env:LOCALAPPDATA\Microsoft\PowerShell") }
    )
    foreach ($l in $leftovers) {
        if (@($l.App | Where-Object { Test-Path $_ }).Count) { continue }
        $l.Paths | Where-Object { Test-Path $_ } | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
    $yasb = Join-Path $env:USERPROFILE '.config\yasb'
    if ((Test-Path $yasb) -and -not (Get-ChildItem $yasb -Force)) { Remove-Item $yasb }
    $fontDir = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
    $reg = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
    $left = 0
    foreach ($f in Get-ChildItem $fontDir -Filter 'JetBrainsMonoNerdFont*.ttf' -ErrorAction SilentlyContinue) {
        [void][Win32.Native]::RemoveFontResource($f.FullName)
        Remove-ItemProperty $reg -Name ($f.BaseName + ' (TrueType)') -ErrorAction SilentlyContinue
        Remove-Item $f.FullName -Force -ErrorAction SilentlyContinue
        if (Test-Path $f.FullName) { $left++ }
    }
    $r = [UIntPtr]::Zero
    [void][Win32.Native]::SendMessageTimeout([IntPtr]0xffff, 0x1D, [UIntPtr]::Zero, [IntPtr]::Zero, 2, 1000, [ref]$r)   # WM_FONTCHANGE
    if ($left) { Write-Warn "$left font files are in use; they go away after a restart" }
}

function Invoke-Uninstall {
    Write-Host 'Omadows: uninstall' -ForegroundColor Magenta
    $apps = if ($RemoveApps) { $true } elseif ($KeepApps) { $false } else {
        (Read-Host 'Also remove the apps it installed (komorebi, whkd, YASB, Windhawk, PowerToys, PowerShell 7, starship, fastfetch, JetBrainsMono Nerd Font)? [y/N]') -match '^(y|yes)$'
    }
    $tool = Join-Path $env:USERPROFILE '.config\omadows\omadows.ps1'
    $runTool = { param($cmd) if (Test-Path $tool) { if ((Invoke-Native 'powershell.exe' @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $tool, $cmd)) -ne 0) { throw "omadows.ps1 $cmd failed" } } }

    Invoke-Step 'Stop komorebi, whkd and YASB; remove their sign-in tasks and the Start menu shortcuts' { Stop-Desktop }
    Invoke-Step 'Desktop/Documents/Downloads/Pictures/Music/Videos icons' { & $runTool 'restore-folders' }
    Invoke-Step 'Machine-wide parts (one UAC prompt)' {
        if (Test-Admin) {
            $script:RemoveApps = [switch]$apps
            $failed = @(Uninstall-Machine)
            if ($failed.Count) { throw ('not removed: ' + ($failed -join '; ')) }
        } else {
            if (-not $PSCommandPath) { throw 'save this script to a file and run it with -File' }
            $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -UninstallPhase -UserProfile `"$UserProfile`" -UserSid $UserSid"
            if ($apps) { $argList += ' -RemoveApps' }
            try { $p = Start-Process powershell.exe -Verb RunAs -ArgumentList $argList -Wait -PassThru }
            catch { throw 'the UAC prompt was declined; run the uninstall again and click Yes' }
            if ($p.ExitCode -ne 0) { throw 'some machine-wide parts were not removed (see the admin window)' }
        }
        Update-SessionPath
    }
    Invoke-Step 'Explorer icons and folder previews' { & $runTool 'refresh-explorer' }
    Invoke-Step 'Windows Terminal, VS Code, Obsidian and PowerShell profiles' { Reset-WindowsTerminal $apps; Reset-VsCode; Reset-Obsidian; Reset-Profiles }
    Invoke-Step 'komorebi, whkd, YASB and starship configs' { Restore-Originals }
    Invoke-Step 'Taskbar, desktop icons and wallpaper' { Reset-Desktop }
    Invoke-Step 'Restart Explorer (open folder windows close)' { Restart-Explorer }
    if ($apps) { Invoke-Step 'PowerToys and the JetBrainsMono Nerd Font' { Remove-UserApps } }
    Invoke-Step 'Omadows files (~/.config/omadows)' {
        $dir = Join-Path $env:USERPROFILE '.config\omadows'
        if (Test-Path $dir) { Remove-Item $dir -Recurse -Force }
    }

    Write-Host ''
    if ($Failures.Count) {
        Write-Host ('Finished with problems in: ' + ($Failures -join '; ')) -ForegroundColor Yellow
        Write-Host 'Run the uninstall again after fixing the cause; finished steps are skipped safely.' -ForegroundColor Yellow
    } else {
        Write-Host 'Omadows removed.' -ForegroundColor Green
    }
    $pending = [string[]](Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -ErrorAction SilentlyContinue).PendingFileRenameOperations
    if ($pending -match '\\(Windhawk|Omadows)(\\|$)') { Write-Host 'Restart Windows once to delete the files programs still had open.' }
    $kept = @('dark mode and the accent color', 'long path support', 'your script execution policy', 'backups named *.bak-<timestamp>', 'VS Code theme extensions a theme installed')
    if (-not $apps) { $kept = @('the apps (komorebi, whkd, YASB, Windhawk, PowerToys, PowerShell 7, starship, fastfetch, the Nerd Font) and PowerToys'' settings; they no longer start with Windows') + $kept }
    Write-Host ("`nKept: " + ($kept -join '; ') + '.')
    exit $(if ($Failures.Count) { 1 } else { 0 })
}

# ---------------------------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------------------------

if ($Uninstall) { Invoke-Uninstall }

Write-Host 'Omadows: Omarchy-style Windows setup' -ForegroundColor Magenta

Invoke-Step 'Machine-wide installs (one UAC prompt)' {
    Ensure-Winget
    if (Test-Admin) {
        Write-Warn 'Running as administrator: works, but apps started at the end run elevated until you sign out and back in.'
        $failed = @(Install-MachinePackages)
        if ($failed.Count) { throw ('failed: ' + ($failed -join ', ')) }
    } else {
        if (-not $PSCommandPath) { throw 'save this script to a file and run it with -File' }
        $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -InstallPhase -UserProfile `"$UserProfile`" -UserSid $UserSid"
        if ($SkipTerminalExtras) { $argList += ' -SkipTerminalExtras' }
        try { $p = Start-Process powershell.exe -Verb RunAs -ArgumentList $argList -Wait -PassThru }
        catch { throw 'the UAC prompt was declined; run the script again and click Yes' }
        if ($p.ExitCode -ne 0) { throw 'some machine-wide installs failed (see the admin window)' }
    }
    Update-SessionPath
}

Invoke-Step 'Keep your current configs (for -Uninstall)' { Save-Originals }
Invoke-Step 'PowerToys (per-user, no admin)' { if (-not (Install-Package 'Microsoft.PowerToys' 'user')) { throw 'install failed' } }
Invoke-Step 'JetBrainsMono Nerd Font (per-user)' { Install-NerdFont }
Invoke-Step 'Dark mode' { Set-DarkMode }
Invoke-Step 'Windows Terminal font and transparency' { Set-WindowsTerminal }
if (-not $SkipTerminalExtras) { Invoke-Step 'starship prompt (Omarchy)' { Set-Starship } }
Invoke-Step 'komorebi + whkd config' { Set-Komorebi }
Invoke-Step 'YASB config' { Set-Yasb }
Invoke-Step 'Theme switcher, Tokyo Night theme and wallpaper slideshow' { Install-ThemeSwitcher }
Invoke-Step 'PowerToys: Win+Space launcher, FancyZones off, start with Windows' { Set-PowerToys }
Invoke-Step 'Hide desktop icons, auto-hide taskbar' { Hide-DesktopIcons; Enable-TaskbarAutoHide }
Invoke-Step 'Start komorebi, whkd and YASB' { Start-Desktop }

Write-Host ''
if ($Failures.Count) {
    Write-Host ('Finished with problems in: ' + ($Failures -join '; ')) -ForegroundColor Yellow
    Write-Host 'Fix the cause shown above and run the script again; finished steps are skipped or redone safely.' -ForegroundColor Yellow
} else {
    Write-Host 'Done.' -ForegroundColor Green
}
Write-Host @'

Keys (Win = Super):
  Win+Space launcher        Win+Enter terminal       Win+Shift+B/F/N/O/T  Brave/Files/VS Code/Obsidian/Task Manager
  Win+W close               Win+F fullscreen         Win+T float/tile     Win+J flip layout
  Win+arrows focus          Win+Shift+arrows move    Win+1..9 workspace   Win+Shift+1..9 send to workspace
  Win+Tab next workspace    Win+-/= resize           Win+Shift+P pause    Win+K all shortcuts
  Win+Ctrl+Shift+Space theme picker                  Win+Ctrl+Space next wallpaper

Still to do by hand:
  - Sign out and back in once so everything starts from autostart.

komorebi is free for personal use; commercial use needs a license (see C:\Program Files\komorebi\License.rtf).
'@
