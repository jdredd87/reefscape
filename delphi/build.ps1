# Builds bin\Reefscape.scr from the command line (the same result as building Reefscape.dproj in the IDE).
#   .\build.ps1            64-bit release build
#   .\build.ps1 -Win32     32-bit build
#   .\build.ps1 -Run       build, then run it in a test window
param(
    [switch]$Win32,
    [switch]$Run,
    [string]$Studio = 'C:\Program Files (x86)\Embarcadero\Studio\37.0'
)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

if (-not (Test-Path ReefRes.rc)) { & .\make-rc.ps1 }

$platform = if ($Win32) { 'Win32' } else { 'Win64' }
$dcc = if ($Win32) { 'dcc32.exe' } else { 'dcc64.exe' }
$dcu = "dcu\$platform"
New-Item -ItemType Directory -Force bin, $dcu | Out-Null

& "$Studio\bin\brcc32.exe" '-foReefRes.res' ReefRes.rc | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Resource compile failed' }

& "$Studio\bin\$dcc" -B -Q '-$O+' '-$D-' '-$L-' '-$Y-' '-$C-' `
    '-NSSystem;Winapi;System.Win;Vcl;Vcl.Imaging' "-NU$dcu" '-Ebin' Reefscape.dpr
if ($LASTEXITCODE -ne 0) { throw 'Compile failed' }

$scr = Get-Item bin\Reefscape.scr
Write-Host ("Built {0} ({1:N0} bytes, {2})" -f $scr.FullName, $scr.Length, $platform)
# Windows always starts a .scr with /s, so the test window runs from a copy named .exe
if ($Run) { Copy-Item $scr.FullName bin/ReefTest.exe -Force; & ./bin/ReefTest.exe /w }
