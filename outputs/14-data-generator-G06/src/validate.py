from __future__ import annotations

import csv
import json
import sqlite3
from collections import Counter
from datetime import datetime
from pathlib import Path
from typing import Any


def read_rows(path: Path):
    with path.open("r", encoding="utf-8", newline="") as stream:
        yield from csv.DictReader(stream)


def validate_dataset(input_dir: Path) -> dict[str, Any]:
    metadata = json.loads((input_dir / "metadata.json").read_text(encoding="utf-8"))
    errors: list[str] = []
    actual_counts: dict[str, int] = {}
    for name, expected in metadata["files"].items():
        actual = sum(1 for _ in read_rows(input_dir / name))
        actual_counts[name] = actual
        if actual != expected:
            errors.append(f"{name}: expected {expected} rows, found {actual}")

    user_ids = {row["user_id"] for row in read_rows(input_dir / "users.csv")}
    space_ids = {row["space_id"] for row in read_rows(input_dir / "spaces.csv")}
    maintenance_ids = {row["maintenance_id"] for row in read_rows(input_dir / "maintenance.csv")}
    years: set[int] = set()

    # An empty-name SQLite connection is a temporary disk-backed database. It
    # avoids materializing 500,000 request dictionaries and relationships in RAM.
    database = sqlite3.connect("")
    try:
        database.executescript("""
            PRAGMA journal_mode = OFF;
            PRAGMA synchronous = OFF;
            CREATE TABLE requests (
                request_id TEXT PRIMARY KEY,
                start_time TEXT NOT NULL,
                end_time TEXT NOT NULL,
                request_state TEXT NOT NULL
            );
            CREATE TABLE bookings (
                request_id TEXT PRIMARY KEY,
                user_id TEXT NOT NULL,
                space_id TEXT NOT NULL
            );
            CREATE TABLE approved (request_id TEXT PRIMARY KEY);
        """)

        request_batch: list[tuple[str, str, str, str]] = []
        for row in read_rows(input_dir / "booking_requests.csv"):
            years.add(datetime.fromisoformat(row["requested_start_time"]).year)
            request_batch.append((
                row["booking_request_id"], row["requested_start_time"],
                row["requested_end_time"], row["request_state_code"],
            ))
            if len(request_batch) == 10_000:
                try:
                    database.executemany("INSERT INTO requests VALUES (?, ?, ?, ?)", request_batch)
                except sqlite3.IntegrityError:
                    errors.append("booking_requests.csv contains duplicate booking_request_id values")
                request_batch.clear()
        if request_batch:
            try:
                database.executemany("INSERT INTO requests VALUES (?, ?, ?, ?)", request_batch)
            except sqlite3.IntegrityError:
                errors.append("booking_requests.csv contains duplicate booking_request_id values")

        booking_batch: list[tuple[str, str, str]] = []
        for row in read_rows(input_dir / "bookings.csv"):
            if row["user_id"] not in user_ids:
                errors.append(f"booking references missing user {row['user_id']}")
            if row["space_id"] not in space_ids:
                errors.append(f"booking references missing space {row['space_id']}")
            booking_batch.append((row["booking_request_id"], row["user_id"], row["space_id"]))
            if len(booking_batch) == 10_000:
                database.executemany("INSERT OR IGNORE INTO bookings VALUES (?, ?, ?)", booking_batch)
                booking_batch.clear()
        if booking_batch:
            database.executemany("INSERT OR IGNORE INTO bookings VALUES (?, ?, ?)", booking_batch)

        missing_relationships = database.execute("""
            SELECT COUNT(*) FROM bookings b
            LEFT JOIN requests r ON r.request_id = b.request_id
            WHERE r.request_id IS NULL
        """).fetchone()[0]
        if missing_relationships:
            errors.append(f"{missing_relationships} bookings reference missing requests")

        database.execute("""
            INSERT INTO approved
            SELECT request_id FROM requests WHERE request_state = 'AUTO_APPROVED'
        """)
        database.executemany(
            "INSERT OR IGNORE INTO approved VALUES (?)",
            ((row["booking_request_id"],) for row in read_rows(input_dir / "reviews.csv")
             if row["request_decision_code"] == "APPROVED"),
        )
        incomplete = database.execute("""
            SELECT COUNT(*) FROM approved a
            LEFT JOIN requests r ON r.request_id = a.request_id
            LEFT JOIN bookings b ON b.request_id = a.request_id
            WHERE r.request_id IS NULL OR b.request_id IS NULL
        """).fetchone()[0]
        if incomplete:
            errors.append(f"{incomplete} approved requests have incomplete relationships")

        duplicate_slots = database.execute("""
            SELECT COUNT(*) FROM (
                SELECT b.space_id, r.start_time, r.end_time
                FROM approved a
                JOIN requests r ON r.request_id = a.request_id
                JOIN bookings b ON b.request_id = a.request_id
                GROUP BY b.space_id, r.start_time, r.end_time
                HAVING COUNT(*) > 1
            )
        """).fetchone()[0]
        if duplicate_slots:
            errors.append(f"{duplicate_slots} duplicate approved slots detected")
        approved_slot_count = database.execute("SELECT COUNT(*) FROM approved").fetchone()[0]

        for row in read_rows(input_dir / "advisory_acknowledgements.csv"):
            if not database.execute(
                "SELECT 1 FROM requests WHERE request_id = ?", (row["booking_request_id"],)
            ).fetchone():
                errors.append(f"acknowledgement references missing request {row['booking_request_id']}")
            if row["maintenance_id"] not in maintenance_ids:
                errors.append(f"acknowledgement references missing maintenance {row['maintenance_id']}")
    finally:
        database.close()

    if len(years) < 3:
        errors.append(f"only {len(years)} calendar years represented: {sorted(years)}")
    reservation_counts = Counter(
        row["reservation_status_code"] for row in read_rows(input_dir / "reservations.csv")
    )
    for required in ("COMPLETED", "NO_SHOW", "CANCELLED"):
        if reservation_counts[required] == 0:
            errors.append(f"no {required} reservations were generated")
    if actual_counts.get("maintenance.csv", 0) == 0:
        errors.append("no maintenance records were generated")
    if actual_counts.get("advisory_acknowledgements.csv", 0) == 0:
        errors.append("no advisory acknowledgements were generated")
    for required in ("APPROVED", "REJECTED", "PENDING", "CANCELLED"):
        if metadata["decisions"].get(required, 0) == 0:
            errors.append(f"no {required} booking outcomes were generated")

    invalid_users = [value for value in user_ids if len(value) != 8 or not value.isdigit()]
    if invalid_users:
        errors.append(f"invalid final-schema user identifiers: {invalid_users[:5]}")
    invalid_maintenance = [
        value for value in maintenance_ids
        if len(value) != 6 or not value.isascii() or not value.islower()
    ]
    if invalid_maintenance:
        errors.append(f"invalid final-schema maintenance identifiers: {invalid_maintenance[:5]}")

    result = {
        "valid": not errors,
        "errors": errors[:100],
        "error_count": len(errors),
        "actual_counts": actual_counts,
        "represented_calendar_years": sorted(years),
        "approved_slot_count": approved_slot_count,
        "reservation_status_counts": dict(reservation_counts),
    }
    (input_dir / "validation.json").write_text(
        json.dumps(result, indent=2, sort_keys=True), encoding="utf-8"
    )
    return result
