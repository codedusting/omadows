# Tests Omadows on a fresh Windows in Windows Sandbox (Windows 11 Pro or Enterprise, with the
# "Windows Sandbox" feature turned on). Installs with the published one-line command, or with
# -Local the omadows-setup.ps1 of this checkout. Results (checks.txt, logs, screenshots, gaps.txt)
# land in %TEMP%\omadows-sandbox\results; done.txt appears when the run is over. The Sandbox is
# thrown away when its window closes.
param([switch]$Local)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path "$env:SystemRoot\System32\WindowsSandbox.exe")) {
    throw 'Windows Sandbox is not turned on: Enable-WindowsOptionalFeature -Online -FeatureName Containers-DisposableClientVM -All (as admin), then restart'
}
$root = Join-Path $env:TEMP 'omadows-sandbox'
$in = Join-Path $root 'in'
$results = Join-Path $root 'results'
Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $in, $results | Out-Null
Copy-Item (Join-Path $PSScriptRoot 'bootstrap.ps1') $in
if ($Local) { Copy-Item (Join-Path $PSScriptRoot '..\..\omadows-setup.ps1') $in }

# the inputs are read-only inside the Sandbox; only the results folder is writable
$wsb = @"
<Configuration>
  <VGpu>Enable</VGpu>
  <Networking>Enable</Networking>
  <MemoryInMB>8192</MemoryInMB>
  <MappedFolders>
    <MappedFolder>
      <HostFolder>$in</HostFolder>
      <SandboxFolder>C:\omadows-test</SandboxFolder>
      <ReadOnly>true</ReadOnly>
    </MappedFolder>
    <MappedFolder>
      <HostFolder>$results</HostFolder>
      <SandboxFolder>C:\omadows-results</SandboxFolder>
      <ReadOnly>false</ReadOnly>
    </MappedFolder>
  </MappedFolders>
  <LogonCommand>
    <Command>powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\omadows-test\bootstrap.ps1</Command>
  </LogonCommand>
</Configuration>
"@
$wsbPath = Join-Path $root 'omadows.wsb'
[IO.File]::WriteAllText($wsbPath, $wsb)
Start-Process $wsbPath
"Sandbox starting; results in $results (done.txt marks the end)"
