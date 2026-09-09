param([int]$Port=8093)
$ErrorActionPreference='Stop'
$serverPath=Join-Path $PSScriptRoot 'tools\serve_phone.py'
if (-not (Test-Path -LiteralPath $serverPath)) { $serverPath=Join-Path $PSScriptRoot 'serve_phone.py' }
$listeners=Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
if ($listeners) {
    $processInfo=Get-CimInstance Win32_Process -Filter ('ProcessId='+$listeners[0].OwningProcess)
    if ($processInfo.CommandLine -notlike '*serve_phone.py*') { throw "Port $Port is already used by another application. Run this script with -Port and another number." }
} else {
    $pythonCommand=Get-Command python -ErrorAction SilentlyContinue
    $pythonPath=if ($pythonCommand) { $pythonCommand.Source } else { Join-Path $env:LOCALAPPDATA 'Programs\Python\Python311\python.exe' }
    if (-not (Test-Path -LiteralPath $pythonPath)) { throw 'Python 3 is needed to serve the browser game. Install Python, then run this launcher again.' }
    $logDirectory=Join-Path $env:LOCALAPPDATA 'The Gods\browser-server'
    New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
    $server=Start-Process -FilePath $pythonPath -ArgumentList @(('"'+$serverPath+'"'),'--port',$Port) -WindowStyle Hidden -RedirectStandardOutput (Join-Path $logDirectory 'server.log') -RedirectStandardError (Join-Path $logDirectory 'errors.log') -PassThru
    Write-Output ('Browser server started (process '+$server.Id+').')
}
Write-Output ('On this computer: http://localhost:'+$Port)
Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -ne '127.0.0.1' -and $_.IPAddress -notlike '169.254.*' -and $_.InterfaceAlias -notlike '*Loopback*' } | ForEach-Object { Write-Output ('On a phone using the same Wi-Fi: http://'+$_.IPAddress+':'+$Port) }
Write-Output 'Keep this computer awake while playing. To stop serving, run Stop Phone Server.ps1.'
