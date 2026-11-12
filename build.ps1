# Builds out\screensaver.zip and (optionally) sideloads it to your Roku.
#   .\build.ps1                                  -> just build the zip
#   .\build.ps1 -RokuIP 192.168.1.50 -Password x -> build + install on the Roku
#   .\build.ps1 -Store                           -> out\reefscape-store.zip for the Roku Streaming Store:
#        screensaver only (no title= in the manifest, no source\dev.brs with Main()), as Roku requires
param(
    [string]$RokuIP,
    [string]$Password,
    [switch]$Store
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

New-Item -ItemType Directory -Force out | Out-Null
$zip = "out\screensaver.zip"
if ($Store) { $zip = "out\reefscape-store.zip" }
if (Test-Path $zip) { Remove-Item $zip }

# Windows' built-in tar makes zips with forward-slash paths, which Roku requires
# (PowerShell 5.1's Compress-Archive uses backslashes and can break the install).
if ($Store) {
    $stage = "out\store"
    if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
    New-Item -ItemType Directory -Force $stage | Out-Null
    Copy-Item -Recurse source, components, images $stage
    Remove-Item "$stage\source\dev.brs"
    Remove-Item "$stage\components\OceanKeys.brs"
    $sx = "$stage\components\OceanScene.xml"
    (Get-Content $sx) | Where-Object { $_ -notmatch 'OceanKeys\.brs' } | Set-Content -Encoding ascii $sx
    (Get-Content manifest) | Where-Object { $_ -notmatch '^title=' } | Set-Content -Encoding ascii "$stage\manifest"
    Push-Location $stage
    tar.exe -a -c -f "..\reefscape-store.zip" manifest source components images
    $ok = $LASTEXITCODE
    Pop-Location
    if ($ok -ne 0) { throw "zip failed" }
} else {
    tar.exe -a -c -f $zip manifest source components images
    if ($LASTEXITCODE -ne 0) { throw "zip failed" }
}
Write-Host "Built $zip"

if ($RokuIP) {
    if (-not $Password) { throw "Pass -Password (the dev password you set when enabling developer mode)" }
    Write-Host "Installing to $RokuIP ..."
    # listen to the debug console during install so compile errors can be shown
    $tcp = New-Object System.Net.Sockets.TcpClient($RokuIP, 8085)
    $stream = $tcp.GetStream(); $stream.ReadTimeout = 300
    $buf = New-Object byte[] 32768
    try { while ($stream.Read($buf, 0, $buf.Length) -gt 0) {} } catch {}

    $result = curl.exe --silent --show-error --user "rokudev:$Password" --digest `
        -F "mysubmit=Install" -F "archive=@$zip" "http://$RokuIP/plugin_install"
    $msg = ($result | Select-String -Pattern '"text":"([^"]*(Success|Identical|Failure)[^"]*)"' -AllMatches |
        ForEach-Object { $_.Matches } | ForEach-Object { $_.Groups[1].Value }) -join " "
    Write-Host $msg

    if ($msg -match "Failure") {
        $log = ""; $end = (Get-Date).AddSeconds(3)
        while ((Get-Date) -lt $end) { try { $n = $stream.Read($buf, 0, $buf.Length); if ($n -gt 0) { $log += [Text.Encoding]::UTF8.GetString($buf, 0, $n) } } catch {} }
        $log -split "`n" | Where-Object { $_ -match "error|ERROR" } | ForEach-Object { Write-Host $_.Trim() -ForegroundColor Red }
    }
    $tcp.Close()
}
