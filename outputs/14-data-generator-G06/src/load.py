from __future__ import annotations

import os
import json
import platform
import shutil
import subprocess
from time import perf_counter
from pathlib import Path


LOAD_ORDER = ('users.csv', 'spaces.csv', 'maintenance.csv', 'booking_requests.csv', 'bookings.csv', 'reviews.csv', 'reservations.csv')

STAGING_TABLES = {
    "users.csv": "staging_phase2.Users",
    "spaces.csv": "staging_phase2.Spaces",
    "maintenance.csv": "staging_phase2.Maintenance",
    "booking_requests.csv": "staging_phase2.BookingRequests",
    "bookings.csv": "staging_phase2.Bookings",
    "reviews.csv": "staging_phase2.Reviews",
    "reservations.csv": "staging_phase2.Reservations",
}


def build_commands(
    input_dir: Path,
    server: str,
    database: str,
    trust_certificate: bool,
) -> list[list[str]]:
    if database.casefold() != "school":
        raise RuntimeError(
            "This G06 adapter targets the School database created by outputs 05 and 10; "
            f"received {database!r}. Set DB_DATABASE=School."
        )
    commands: list[list[str]] = []
    sqlcmd = ["sqlcmd", "-S", server, "-d", database]
    username = os.getenv("DB_USERNAME")
    password = os.getenv("DB_PASSWORD")
    if username:
        if not password:
            raise RuntimeError("DB_PASSWORD is required when DB_USERNAME is set")
        sqlcmd.extend(["-U", username, "-P", password])
    elif os.name != "nt":
        raise RuntimeError(
            "Linux requires SQL authentication. Export DB_USERNAME and DB_PASSWORD; "
            "Windows integrated authentication (-E) is not used on Linux."
        )
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
        if trust_certificate:
            command.append("-u")
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
        visible = command.copy()
        if "-P" in visible:
            visible[visible.index("-P") + 1] = "********"
        print(" ".join(f'"{part}"' if " " in part else part for part in visible))
    if not execute:
        print("Dry run only. Re-run with --execute after reviewing the commands.")
        return
    for executable in ("sqlcmd", "bcp"):
        if not shutil.which(executable):
            raise RuntimeError(f"{executable} was not found on PATH")
    started = perf_counter()
    for position, command in enumerate(commands):
        stage = "create staging tables" if position == 0 else f"bulk load {LOAD_ORDER[position - 1]}"
        try:
            subprocess.run(command, check=True)
        except subprocess.CalledProcessError as error:
            raise RuntimeError(
                f"Failed to {stage} (exit {error.returncode}). Check DB_SERVER, "
                "DB_DATABASE=School, DB_USERNAME/DB_PASSWORD, certificate settings, "
                "and whether outputs 05, 06, and 10 ran successfully."
            ) from None
    staging_seconds = perf_counter() - started

    sqlcmd_base = commands[0][:-2]
    sql_dir = Path(__file__).parents[1] / "sql"
    final_started = perf_counter()
    sql_output: dict[str, str] = {}
    for script in ("validate.sql", "load-final.sql", "validate-final.sql"):
        command = sqlcmd_base + ["-b", "-i", str(sql_dir / script)]
        process = subprocess.Popen(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
        )
        output_lines: list[str] = []
        assert process.stdout is not None
        for line in process.stdout:
            output_lines.append(line)
            print(line, end="", flush=True)
        return_code = process.wait()
        output = "".join(output_lines)
        if return_code != 0:
            raise RuntimeError(
                f"SQL script {script} failed (exit {return_code}); "
                "the production transaction was rolled back when applicable."
            )
        sql_output[script] = output.strip()
    final_seconds = perf_counter() - final_started

    evidence = {
        "server": server,
        "database": database,
        "platform": platform.platform(),
        "python": platform.python_version(),
        "staging_load_seconds": round(staging_seconds, 3),
        "production_load_and_validation_seconds": round(final_seconds, 3),
        "total_load_seconds": round(staging_seconds + final_seconds, 3),
        "sql_output": sql_output,
    }
    (input_dir / "load-evidence.json").write_text(
        json.dumps(evidence, indent=2, sort_keys=True), encoding="utf-8"
    )
    print(f"Staging and production load complete; evidence: {input_dir / 'load-evidence.json'}")
