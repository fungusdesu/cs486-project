#!/usr/bin/env bash
set -euo pipefail
timeout_seconds="${1:-300}"
end=$(( $(date +%s) + timeout_seconds ))
while [ "$(date +%s)" -lt "$end" ]; do
  status="$(docker inspect --format '{{.State.Health.Status}}' cs486-sqlserver 2>/dev/null || true)"
  if [ "$status" = "healthy" ]; then echo "SQL Server container is healthy."; exit 0; fi
  sleep 5
done
echo "SQL Server container did not become healthy." >&2
exit 1