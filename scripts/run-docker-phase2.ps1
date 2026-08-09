param([int]$Bookings = 100000, [switch]$KeepContainer)
$ErrorActionPreference = 'Stop'
if (-not $env:MSSQL_SA_PASSWORD) { $env:MSSQL_SA_PASSWORD = 'Local-only-Password-48606!' }
docker compose up -d sqlserver
try {
  & "$PSScriptRoot\wait-for-sqlserver.ps1"
  $env:DB_SERVER = 'localhost,1433'; $env:DB_DATABASE = 'tempdb'; $env:DB_USERNAME = 'sa'; $env:DB_PASSWORD = $env:MSSQL_SA_PASSWORD; $env:SQLCMD_TRUST_CERTIFICATE = 'true'
  Push-Location "$PSScriptRoot\..\outputs\13-concurrency-tests-G06"; npm install; npm test; Pop-Location
  Push-Location "$PSScriptRoot\..\outputs\14-data-generator-G06"; python -m unittest discover -s test; python -m src.cli generate --bookings $Bookings --seed 48606; python -m src.cli validate; Pop-Location
} finally { if (-not $KeepContainer) { docker compose down -v } }