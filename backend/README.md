# G06 Localhost Express Backend Scaffold

This API runs locally and delegates database correctness to SQL Server stored procedures. It does not expose the bulk generator over HTTP.

## Setup

```powershell
Copy-Item .env.example .env
npm install
npm start
```

The scaffold's default `mssql` driver uses SQL Server authentication. Put local test credentials in `.env`; never commit that file.

The default URL is `http://localhost:3000`. Test the server and database connection with:

```powershell
Invoke-RestMethod http://localhost:3000/api/health
```

## Procedure adapter contract

Until outputs 10–12 finalize the SQL interface, each endpoint is mapped through an environment variable. A configured procedure must accept one parameter:

```sql
@payload_json NVARCHAR(MAX)
```

The procedure may parse it with `OPENJSON` and return a result set. Unconfigured endpoints return HTTP 501 instead of guessing a procedure or table mapping.

## Routes

- `GET /api/health`
- `POST /api/bookings`
- `POST /api/bookings/:id/approve`
- `POST /api/bookings/:id/reject`
- `GET /api/spaces/available`
- `POST /api/maintenance`
- `PATCH /api/maintenance/:id/impact`
- `GET /api/maintenance/:id/affected-bookings`
- `GET /api/reports/approved-hours`
- `GET /api/reports/bookings-by-time`

## Scaffold limitation

This is an explicitly authorized out-of-order scaffold. Finalize environment mappings and request validation only after outputs 10–12 are approved. Booking and approval routes must call the same protected database operation; an in-process JavaScript mutex is not an acceptable concurrency control.
