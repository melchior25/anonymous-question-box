# Anonymous Question Box - Stop App Ports
# Use this when ports 5000, 5173, 5174, or 5175 are stuck.

$ErrorActionPreference = "Stop"

$Ports = @(5000, 5173, 5174, 5175)

Write-Host ""
Write-Host "Stopping Anonymous Question Box ports..." -ForegroundColor Cyan

foreach ($Port in $Ports) {
    $Connections = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue

    if ($Connections) {
        $ProcessIds = $Connections |
            Select-Object -ExpandProperty OwningProcess -Unique |
            Where-Object { $_ -and $_ -gt 0 }

        if (!$ProcessIds) {
            Write-Host "Port $Port has no stoppable process." -ForegroundColor DarkGray
            continue
        }

        foreach ($ProcessId in $ProcessIds) {
            try {
                Stop-Process -Id $ProcessId -Force
                Write-Host "Stopped process $ProcessId on port $Port" -ForegroundColor Green
            } catch {
                Write-Host "Could not stop process $ProcessId on port $Port" -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "Port $Port is free." -ForegroundColor DarkGray
    }
}

Write-Host ""
Write-Host "Done. You can now run:" -ForegroundColor Cyan
Write-Host "npm run dev" -ForegroundColor White
Write-Host ""