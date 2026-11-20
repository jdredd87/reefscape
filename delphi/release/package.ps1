# Builds both Delphi flavours and packs the downloads for a GitHub release into release\out:
#   Reefscape-VCL-<version>-win64.zip   Reefscape.scr + README.txt
#   Reefscape-FMX-<version>-win64.zip   ReefscapeFMX.scr, ReefscapeFMX.exe, sk4d.dll + README.txt
#   SHA256SUMS.txt
#   .\package.ps1 -Version 1.0.0
param([string]$Version = '1.0.0')
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

# (each build script moves to its own folder, so they are called by full path)
& (Join-Path $PSScriptRoot '..\build.ps1')
& (Join-Path $PSScriptRoot '..\fmx\build.ps1')
Set-Location $PSScriptRoot

if (Test-Path out) { Get-ChildItem out | Remove-Item -Recurse -Force }
New-Item -ItemType Directory -Force out\vcl, out\fmx | Out-Null

Copy-Item ..\bin\Reefscape.scr out\vcl\
Copy-Item README-VCL.txt out\vcl\README.txt
Copy-Item ..\fmx\bin\Win64\ReefscapeFMX.scr, ..\fmx\bin\Win64\ReefscapeFMX.exe, ..\fmx\bin\Win64\sk4d.dll out\fmx\
Copy-Item README-FMX.txt out\fmx\README.txt

$vcl = "out\Reefscape-VCL-$Version-win64.zip"
$fmx = "out\Reefscape-FMX-$Version-win64.zip"
Compress-Archive -Path out\vcl\* -DestinationPath $vcl
Compress-Archive -Path out\fmx\* -DestinationPath $fmx
Remove-Item out\vcl, out\fmx -Recurse -Force

$sums = Get-ChildItem out\*.zip | ForEach-Object { "{0}  {1}" -f (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLower(), $_.Name }
Set-Content out\SHA256SUMS.txt $sums -Encoding ascii
Get-ChildItem out | ForEach-Object { "{0,12:N0}  {1}" -f $_.Length, $_.Name }
