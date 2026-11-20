# Builds the FMX app from the command line (the same result as building ReefscapeFMX.dproj in the IDE)
# and puts Skia's library next to it.
#   .\build.ps1            64-bit Windows release build -> bin\Win64\ReefscapeFMX.exe
#   .\build.ps1 -Win32     32-bit build
#   .\build.ps1 -Run       build, then run it
param(
    [switch]$Win32,
    [switch]$Run,
    [string]$Studio = 'C:\Program Files (x86)\Embarcadero\Studio\37.0'
)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

if (-not (Test-Path ReefImages.rc)) { & ..\make-rc.ps1 }
$platform = if ($Win32) { 'Win32' } else { 'Win64' }

cmd /c "call `"$Studio\bin\rsvars.bat`" && msbuild ReefscapeFMX.dproj /t:Build /p:Config=Release /p:Platform=$platform /nologo /v:quiet /clp:ErrorsOnly"
if ($LASTEXITCODE -ne 0) { throw 'Build failed' }

# Skia is a separate library that must sit beside the program
$redist = if ($Win32) { 'win32' } else { 'win64' }
Copy-Item "$Studio\Redist\$redist\sk4d.dll" "bin\$platform\" -Force

$exe = Get-Item "bin\$platform\ReefscapeFMX.exe"
Write-Host ("Built {0} ({1:N0} bytes, {2})" -f $exe.FullName, $exe.Length, $platform)
if ($Run) { & $exe.FullName }
