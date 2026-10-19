# Omadows one-line install. In a normal (not admin) PowerShell window:
#
#   irm https://raw.githubusercontent.com/codedusting/omadows/main/install.ps1 | iex
#
# Options, set first in the same window:
#   $env:OMADOWS_SKIP_EXTRAS = 1    leave out PowerShell 7, starship and fastfetch
#   $env:OMADOWS_UNINSTALL = 1      undo everything instead
#   $env:OMADOWS_REMOVE_APPS = 1    with uninstall: remove the apps too (0 keeps them; unset asks)
#
# Downloads omadows-setup.ps1 to a temporary folder and runs it from there with Windows PowerShell:
# the setup relaunches itself as administrator once, which needs a file to run from.
& {
    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $yes = '1', 'true', 'yes'
    $setupArgs = @()
    if ($env:OMADOWS_SKIP_EXTRAS -in $yes) { $setupArgs += '-SkipTerminalExtras' }
    if ($env:OMADOWS_UNINSTALL -in $yes) {
        $setupArgs += '-Uninstall'
        if ($env:OMADOWS_REMOVE_APPS -in $yes) { $setupArgs += '-RemoveApps' }
        elseif ($env:OMADOWS_REMOVE_APPS -in '0', 'false', 'no') { $setupArgs += '-KeepApps' }
    }
    # one-time options: a later install in the same window shouldn't repeat them
    Remove-Item Env:OMADOWS_SKIP_EXTRAS, Env:OMADOWS_UNINSTALL, Env:OMADOWS_REMOVE_APPS -ErrorAction SilentlyContinue
    $dir = Join-Path $env:TEMP ('omadows-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    New-Item -ItemType Directory -Force $dir | Out-Null
    $setup = Join-Path $dir 'omadows-setup.ps1'
    Write-Host 'Downloading Omadows...' -ForegroundColor Magenta
    Invoke-WebRequest 'https://raw.githubusercontent.com/codedusting/omadows/main/omadows-setup.ps1' -OutFile $setup -UseBasicParsing
    & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File $setup @setupArgs
}
