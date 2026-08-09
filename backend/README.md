# G06 localhost backend

A small Express adapter for the protected Phase 2 database operations. It runs on Windows, Linux, and WSL because it uses Node's cross-platform process/runtime APIs and binds to `0.0.0.0`.

## Requirements

- Node.js 18+ and npm
- Optional for SQL Server mode: reachable SQL Server and the `outputs/10` migration plus `outputs/12` procedures

## Run a cross-platform smoke test

```bash
cd backend
npm install
npm test
```

## Run on localhost

```bash
cd backend
cp .env.example .env       # PowerShell: Copy-Item .env.example .env
npm start
```

Open `http://localhost:3000/api/health`. The default `DB_MODE=mock` makes the server runnable without credentials. Mock mode is only for HTTP development and smoke tests.

For SQL Server, edit `.env`, set `DB_MODE=sqlserver`, and provide either `DB_USERNAME`/`DB_PASSWORD` (Windows or Linux SQL authentication) or omit them for Windows integrated authentication. Set `DB_TRUST_SERVER_CERTIFICATE=true` for a local development certificate. Then run `npm start`.

## Example requests

```bash
curl http://localhost:3000/api/health
curl -X POST http://localhost:3000/api/bookings -H 'content-type: application/json' -d '{"booking_request_id":"00000001","user_id":"00000051","space_id":"S0001","requested_start_time":"2026-09-01T09:00:00Z","requested_end_time":"2026-09-01T10:00:00Z"}'
curl -X POST http://localhost:3000/api/bookings/00000001/approve -H 'content-type: application/json' -d '{}'
```

PowerShell equivalent:

```powershell
Invoke-RestMethod http://localhost:3000/api/health
Invoke-RestMethod http://localhost:3000/api/bookings -Method Post -ContentType 'application/json' -Body '{"booking_request_id":"00000001","user_id":"00000051","space_id":"S0001","requested_start_time":"2026-09-01T09:00:00Z","requested_end_time":"2026-09-01T10:00:00Z"}'
```

The backend never exposes the 100,000/500,000-row generator over HTTP. Production booking and approval concurrency must be enforced by the SQL Server procedures, not by a JavaScript mutex.
## Docker SQL Server integration test

From the repository root, set a local-only password and run the full Linux-container workflow:

```powershell
$env:MSSQL_SA_PASSWORD = 'choose-a-local-password'
.\scripts\run-docker-phase2.ps1 -Bookings 100000
```

Fedora/bash equivalent:

```bash
export MSSQL_SA_PASSWORD='choose-a-local-password'
./scripts/run-docker-phase2.sh 100000
```

The script starts SQL Server 2022 Developer, waits for its health check, runs part 13, runs generator unit/reproducibility tests, validates generated data, and removes the container. Set `KEEP_CONTAINER=true` (bash) or pass `-KeepContainer` (PowerShell) when debugging. Never commit the password or generated files.