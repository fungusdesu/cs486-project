#!/usr/bin/env bash
set -euo pipefail
bookings="${1:-100000}"
export MSSQL_SA_PASSWORD="${MSSQL_SA_PASSWORD:?Set MSSQL_SA_PASSWORD before running Docker}"
docker compose up -d sqlserver
cleanup() { if [ "${KEEP_CONTAINER:-false}" != "true" ]; then docker compose down -v; fi; }
trap cleanup EXIT
scripts/wait-for-sqlserver.sh
export DB_SERVER='localhost,1433' DB_DATABASE='tempdb' DB_USERNAME='sa' DB_PASSWORD="$MSSQL_SA_PASSWORD" SQLCMD_TRUST_CERTIFICATE='true'
(cd outputs/13-concurrency-tests-G06 && npm install && npm test)
(cd outputs/14-data-generator-G06 && python3 -m unittest discover -s test && python3 -m src.cli generate --bookings "$bookings" --seed 48606 && python3 -m src.cli validate)