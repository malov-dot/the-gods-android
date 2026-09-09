param([int]$Port=8093)
$listeners=Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
foreach ($listener in $listeners) {
    $processInfo=Get-CimInstance Win32_Process -Filter ('ProcessId='+$listener.OwningProcess)
    if ($processInfo.CommandLine -like '*serve_phone.py*') {
        Stop-Process -Id $listener.OwningProcess
        Write-Output 'The Gods phone server stopped. Saved worlds remain in each browser.'
    }
}
