from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path


LOAD_ORDER = ('users.csv', 'spaces.csv', 'maintenance.csv', 'booking_requests.csv', 'bookings.csv', 'reviews.csv', 'reservations.csv', 'advisory_acknowledgements.csv')

STAGING_TABLES = {
    "users.csv": "staging_phase2.Users",
    "spaces.csv": "staging_phase2.Spaces",
    "maintenance.csv": "staging_phase2.Maintenance",
    "booking_requests.csv": "staging_phase2.BookingRequests",
    "bookings.csv": "staging_phase2.Bookings",
    "reviews.csv": "staging_phase2.Reviews",
    "reservations.csv": "staging_phase2.Reservations",
    "advisory_acknowledgements.csv": "staging_phase2.AdvisoryAcknowledgements",
}


def build_commands(
    input_dir: Path,
    server: str,
    database: str,
    trust_certificate: bool,
) -> list[list[str]]:
    commands: list[list[str]] = []
    sqlcmd = ["sqlcmd", "-S", server, "-d", database]
    username = os.getenv("DB_USERNAME")
    password = os.getenv("DB_PASSWORD")
    if username:
        sqlcmd.extend(["-U", username, "-P", password or ""])
    else:
        sqlcmd.append("-E")
    if trust_certificate:
        sqlcmd.append("-C")
    commands.append(sqlcmd + ["-i", str(Path(__file__).parents[1] / "sql" / "create-staging.sql")])

    for filename in LOAD_ORDER:
        table = STAGING_TABLES[filename]
        if not (input_dir / filename).is_file():
            raise FileNotFoundError(f'missing generated input: {input_dir / filename}')
        command = [
            "bcp", table, "in", str((input_dir / filename).resolve()),
            "-S", server, "-d", database, "-c", "-t,", "-F", "2",
        ]
        if username:
            command.extend(["-U", username, "-P", password or ""])
        else:
            command.append("-T")
        commands.append(command)
    return commands


def load_staging(
    input_dir: Path,
    server: str,
    database: str,
    execute: bool,
    trust_certificate: bool,
) -> None:
    commands = build_commands(input_dir, server, database, trust_certificate)
    for command in commands:
        print(" ".join(f'"{part}"' if " " in part else part for part in command))
    if not execute:
        print("Dry run only. Re-run with --execute after reviewing the commands.")
        return
    for executable in ("sqlcmd", "bcp"):
        if not shutil.which(executable):
            raise RuntimeError(f"{executable} was not found on PATH")
    for command in commands:
        subprocess.run(command, check=True)
    print("Staging load complete. Final schema transformation is intentionally blocked until step 10 is approved.")
