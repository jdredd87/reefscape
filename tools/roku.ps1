# Dev helpers for the Roku:
#   .\tools\roku.ps1 log  [-Seconds 10] [-Launch "hour=21"]   launch the dev app and print the debug console
#   .\tools\roku.ps1 shot [-Out file.jpg] save a screenshot of what's on the TV
param(
    [Parameter(Position = 0)][string]$Action = "log",
    [string]$RokuIP = "192.168.50.162",
    [string]$Password = "",   # default: tools\roku-password.txt (not in git)
    [int]$Seconds = 10,
    [string]$Out = "out\screenshot.jpg",
    [string]$Launch = ""     # launch options, e.g. "hour=21" or "demo=1"
)
Set-Location (Split-Path $PSScriptRoot -Parent)
if (-not $Password -and (Test-Path tools\roku-password.txt)) { $Password = (Get-Content tools\roku-password.txt -Raw).Trim() }

if ($Action -eq "log") {
    $c = New-Object System.Net.Sockets.TcpClient($RokuIP, 8085)
    $s = $c.GetStream(); $s.ReadTimeout = 300
    $buf = New-Object byte[] 32768; $text = ""
    try { while ($s.Read($buf, 0, $buf.Length) -gt 0) {} } catch {}
    Invoke-WebRequest -Method Post -Uri "http://${RokuIP}:8060/launch/dev?$Launch" -UseBasicParsing | Out-Null
    $end = (Get-Date).AddSeconds($Seconds)
    while ((Get-Date) -lt $end) {
        try { $n = $s.Read($buf, 0, $buf.Length); if ($n -gt 0) { $text += [Text.Encoding]::UTF8.GetString($buf, 0, $n) } } catch {}
    }
    $c.Close()
    $text
}
elseif ($Action -eq "shot") {
    $page = curl.exe -s --user "rokudev:$Password" --digest -F "mysubmit=Screenshot" "http://$RokuIP/plugin_inspect"
    # most Rokus save dev.jpg, some TVs dev.png
    $ext = "jpg"
    if (($page -join "`n") -match 'pkgs/dev\.(\w+)') { $ext = $Matches[1] }
    $Out = [IO.Path]::ChangeExtension($Out, $ext)
    curl.exe -s --user "rokudev:$Password" --digest -o $Out "http://$RokuIP/pkgs/dev.$ext"
    Get-Item $Out | Select-Object Name, Length
}
elseif ($Action -eq "quit") {
    Invoke-WebRequest -Method Post -Uri "http://${RokuIP}:8060/launch/dev?quit=1" -UseBasicParsing | Out-Null
    "dev app closed"
}
elseif ($Action -eq "mem") {
    $c = New-Object System.Net.Sockets.TcpClient($RokuIP, 8080)
    $ns = $c.GetStream(); $w = New-Object System.IO.StreamWriter($ns); $w.AutoFlush = $true
    Start-Sleep -Milliseconds 500; $w.WriteLine("r2d2_bitmaps"); Start-Sleep 4
    $buf = New-Object byte[] 2000000; $text = ""
    while ($ns.DataAvailable) { $n = $ns.Read($buf, 0, $buf.Length); $text += [Text.Encoding]::UTF8.GetString($buf, 0, $n); Start-Sleep -Milliseconds 400 }
    $c.Close()
    ($text -split "`n" | Select-String "Available texture" | Select-Object -First 1).Line
}
