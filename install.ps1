# Omadows one-line install. In a normal (not admin) PowerShell window:
#
#   irm https://raw.githubusercontent.com/codedusting/omadows/main/install.ps1 | iex
#
# To leave out PowerShell 7, starship and fastfetch, first run:  $env:OMADOWS_SKIP_EXTRAS = 1
#
# Downloads omadows-setup.ps1 to a temporary folder and runs it from there with Windows PowerShell:
# the setup relaunches itself as administrator once, which needs a file to run from.
& {
    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $dir = Join-Path $env:TEMP ('omadows-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    New-Item -ItemType Directory -Force $dir | Out-Null
    $setup = Join-Path $dir 'omadows-setup.ps1'
    Write-Host 'Downloading Omadows...' -ForegroundColor Magenta
    Invoke-WebRequest 'https://raw.githubusercontent.com/codedusting/omadows/main/omadows-setup.ps1' -OutFile $setup -UseBasicParsing
    $setupArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $setup)
    if ($env:OMADOWS_SKIP_EXTRAS -in '1', 'true', 'yes') { $setupArgs += '-SkipTerminalExtras' }
    & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" @setupArgs
}
