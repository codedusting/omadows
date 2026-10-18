# Runs inside Windows Sandbox as its logon command (see run.ps1): installs winget, which the
# Sandbox lacks, installs Omadows unattended, then writes checks, logs and screenshots to
# C:\omadows-results. done.txt marks the end.
#
# Installs with the published one-line command, typed into a script the way a user types it into
# PowerShell; if run.ps1 -Local put omadows-setup.ps1 into C:\omadows-test, runs that file instead.
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
$in = 'C:\omadows-test'
$out = 'C:\omadows-results'
New-Item -ItemType Directory -Force $out | Out-Null
Start-Transcript -Path "$out\bootstrap-transcript.txt" | Out-Null
function Step([string]$m) { $line = '{0:HH:mm:ss} {1}' -f (Get-Date), $m; Add-Content "$out\progress.txt" $line; Write-Host $line }

Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing @'
using System; using System.Drawing; using System.Runtime.InteropServices;
public static class Shot {
    [DllImport("user32")] public static extern bool SetProcessDPIAware();
    [DllImport("user32")] static extern int GetSystemMetrics(int i);
    [DllImport("dwmapi")] static extern int DwmGetWindowAttribute(IntPtr h, int a, out RECT r, int s);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
    public static void Screen(string path) {
        var b = new Bitmap(GetSystemMetrics(0), GetSystemMetrics(1));
        using (var g = Graphics.FromImage(b)) g.CopyFromScreen(0, 0, 0, 0, b.Size);
        b.Save(path);
    }
    public static RECT Frame(IntPtr h) { RECT r; DwmGetWindowAttribute(h, 9, out r, Marshal.SizeOf(typeof(RECT))); return r; }
}
'@
[void][Shot]::SetProcessDPIAware()

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Step "sandbox user $env:USERNAME, admin: $admin, Windows $([Environment]::OSVersion.Version)"

# 1. winget: App Installer and its dependencies from the winget-cli release
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Step 'installing winget'
    try {
        $tmp = Join-Path $env:TEMP 'winget'
        New-Item -ItemType Directory -Force $tmp | Out-Null
        $rel = Invoke-RestMethod 'https://api.github.com/repos/microsoft/winget-cli/releases/latest' -Headers @{ 'User-Agent' = 'omadows-sandbox-test' } -UseBasicParsing
        $deps = $rel.assets | Where-Object { $_.name -eq 'DesktopAppInstaller_Dependencies.zip' }
        $bundle = $rel.assets | Where-Object { $_.name -like '*.msixbundle' } | Select-Object -First 1
        Invoke-WebRequest $deps.browser_download_url -OutFile "$tmp\deps.zip" -UseBasicParsing
        Invoke-WebRequest $bundle.browser_download_url -OutFile "$tmp\winget.msixbundle" -UseBasicParsing
        Expand-Archive "$tmp\deps.zip" "$tmp\deps" -Force
        Get-ChildItem "$tmp\deps" -Recurse -Filter *.appx | Where-Object { $_.FullName -match '\\x64\\' } | ForEach-Object { Add-AppxPackage $_.FullName -ErrorAction Continue }
        Add-AppxPackage "$tmp\winget.msixbundle"
        $env:Path += ";$env:LOCALAPPDATA\Microsoft\WindowsApps"
        Step "winget $(winget --version)"
    } catch { Step "winget install failed: $($_.Exception.Message)" }
}

# 2. install Omadows; its output goes to setup-output.txt
$run = Join-Path $env:TEMP 'omadows-install.ps1'
if (Test-Path "$in\omadows-setup.ps1") {
    $dir = Join-Path $env:USERPROFILE 'Desktop\omadows'
    New-Item -ItemType Directory -Force $dir | Out-Null
    Copy-Item "$in\omadows-setup.ps1" $dir
    Set-Content $run "& `"$dir\omadows-setup.ps1`""
    Step 'installing from the local omadows-setup.ps1'
} else {
    Set-Content $run 'irm https://raw.githubusercontent.com/codedusting/omadows/main/install.ps1 | iex'
    Step 'installing with the one-line command'
}
$sw = [Diagnostics.Stopwatch]::StartNew()
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $run *> "$out\setup-output.txt"
Step "install finished in $([int]$sw.Elapsed.TotalMinutes) min, exit code $LASTEXITCODE"
Start-Sleep -Seconds 20

# 3. checks
$c = New-Object System.Collections.Generic.List[string]
function Check([string]$name, $ok, [string]$detail = '') { $c.Add(('{0}  {1}{2}' -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $name, $(if ($detail) { "  ($detail)" }))) }
foreach ($p in 'komorebi', 'whkd', 'yasb', 'windhawk', 'PowerToys') { Check "process $p running" ([bool](Get-Process $p -ErrorAction SilentlyContinue)) }
Check 'Windhawk service running' ((Get-Service windhawk -ErrorAction SilentlyContinue).Status -eq 'Running')
foreach ($id in 'icon-resource-redirect', 'translucent-windows', 'windows-11-file-explorer-styler', 'explorer-visual-tweaks-dark') {
    $lib = (Get-ItemProperty "HKLM:\SOFTWARE\Windhawk\Engine\Mods\$id" -ErrorAction SilentlyContinue).LibraryFileName
    Check "Windhawk mod $id installed" ($lib -and (Test-Path "C:\ProgramData\Windhawk\Engine\Mods\64\$lib")) $lib
}
$tw = Get-Process explorer -ErrorAction SilentlyContinue | Where-Object { try { $_.Modules.ModuleName -like 'translucent-windows*' } catch { $false } }
Check 'Translucent Windows loaded in Explorer' ([bool]$tw)
$mods = 'HKLM:\SOFTWARE\Windhawk\Engine\Mods'
$rr = (Get-Item "$mods\icon-resource-redirect\Settings" -ErrorAction SilentlyContinue).GetValue('themePaths[0]')
Check 'Resource Redirect points at a built icon theme' ($rr -and (Test-Path (Join-Path $rr 'imageres.dll'))) $rr
$tint = (Get-Item "$mods\translucent-windows\Settings" -ErrorAction SilentlyContinue).GetValue('BackgroundEffects.AccentBlurBehind')
Check 'Explorer tint set by the theme' ($tint -and $tint -ne '3A232323') $tint
Check 'fill bar colors set by the theme' (((Get-Item "$mods\explorer-visual-tweaks-dark\Settings" -ErrorAction SilentlyContinue).GetValue('progress.fillLeft')) -notin $null, '0078D7')
try { $svc = New-Object -ComObject Schedule.Service; $svc.Connect(); $t = $svc.GetFolder('\Omadows').GetTask('Theme colors'); Check 'Omadows theme colors task' ($t.LastTaskResult -eq 0) ('last result 0x{0:X}' -f $t.LastTaskResult) } catch { Check 'Omadows theme colors task' $false $_.Exception.Message }
$err = 'C:\Program Files\Omadows\last-error.txt'
Check 'helper reported no error' (-not (Test-Path $err)) $(if (Test-Path $err) { Get-Content $err -Raw })
Check 'Explorer folder icon themed' ([string](Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Icons' -ErrorAction SilentlyContinue).'3' -like 'C:\Program Files\Omadows\icons\*')
$cfg = Join-Path $env:USERPROFILE '.config\omadows'
Check 'current theme is tokyo-night' ((Get-Content "$cfg\current-theme" -ErrorAction SilentlyContinue) -eq 'tokyo-night')
Check 'settings.json written' (Test-Path "$cfg\settings.json")
$kj = Get-Content "$env:USERPROFILE\komorebi.json" -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
Check 'komorebi game-library rules' (@($kj.ignore_rules | Where-Object { $_.kind -eq 'Path' }).Count -ge 8) "paddings $($kj.default_container_padding)/$($kj.default_workspace_padding)"
Check 'YASB styles generated' (Test-Path "$env:USERPROFILE\.config\yasb\styles.css")
foreach ($s in 'Omadows Theme', 'Omadows Next Wallpaper', 'Omadows Settings') { Check "Start menu: $s" (Test-Path (Join-Path ([Environment]::GetFolderPath('Programs')) "$s.lnk")) }
Check 'Nerd Font installed' (Test-Path "$env:LOCALAPPDATA\Microsoft\Windows\Fonts\JetBrainsMonoNerdFontPropo-Regular.ttf")
$threats = @(Get-MpThreatDetection -ErrorAction SilentlyContinue)
Check 'no Defender detections' ($threats.Count -eq 0) (($threats | ForEach-Object { ($_.Resources -join ' ') }) -join ' | ')
$c | Set-Content "$out\checks.txt"
Copy-Item "$cfg\omadows.log", "$cfg\settings.json", "$env:USERPROFILE\komorebi.json" $out -ErrorAction SilentlyContinue
Step 'checks written'

# 4. screenshots, and the gaps komorebi leaves between two Explorer windows
[Shot]::Screen("$out\1-desktop.png")
Start-Process explorer.exe 'shell:MyComputerFolder'; Start-Sleep -Seconds 6
Start-Process explorer.exe 'C:\'; Start-Sleep -Seconds 8
[Shot]::Screen("$out\2-explorer.png")
try {
    $state = (& "$env:ProgramFiles\komorebi\bin\komorebic.exe" state) -join "`n" | ConvertFrom-Json
    $mon = $state.monitors.elements[$state.monitors.focused]; $ws = $mon.workspaces.elements[$mon.workspaces.focused]
    $lines = @("work area: $($mon.work_area_size | ConvertTo-Json -Compress)")
    foreach ($ct in $ws.containers.elements) { $w = $ct.windows.elements[$ct.windows.focused]; $r = [Shot]::Frame([IntPtr][long]$w.hwnd); $lines += "$($w.exe) L$($r.L) T$($r.T) R$($r.R) B$($r.B)" }
    $lines | Set-Content "$out\gaps.txt"
} catch { "gap measurement failed: $($_.Exception.Message)" | Set-Content "$out\gaps.txt" }
Step 'done'
Stop-Transcript | Out-Null
'done' | Set-Content "$out\done.txt"
