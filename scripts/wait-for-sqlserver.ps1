param([int]$TimeoutSeconds = 300)
$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
while ((Get-Date) -lt $deadline) {
  $status = docker inspect --format '{{.State.Health.Status}}' cs486-sqlserver 2>$null
  if ($status -eq 'healthy') { Write-Host 'SQL Server container is healthy.'; exit 0 }
  Start-Sleep -Seconds 5
}
Write-Error 'SQL Server container did not become healthy.'
exit 1