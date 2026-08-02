from __future__ import annotations

import csv
import json
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
    request_rows = list(read_rows(input_dir / "booking_requests.csv"))
    request_ids = {row["booking_request_id"] for row in request_rows}
    if len(request_ids) != len(request_rows):
        errors.append("booking_requests.csv contains duplicate booking_request_id values")

    years = {
        datetime.fromisoformat(row["requested_start_time"]).year for row in request_rows
    }
    if len(years) < 3:
        errors.append(f"only {len(years)} calendar years represented: {sorted(years)}")

    bookings: dict[str, dict[str, str]] = {}
    for row in read_rows(input_dir / "bookings.csv"):
        if row["booking_request_id"] not in request_ids:
            errors.append(f"booking references missing request {row['booking_request_id']}")
        if row["user_id"] not in user_ids:
            errors.append(f"booking references missing user {row['user_id']}")
        if row["space_id"] not in space_ids:
            errors.append(f"booking references missing space {row['space_id']}")
        bookings[row["booking_request_id"]] = row

    approved = {
        row["booking_request_id"]
        for row in read_rows(input_dir / "reviews.csv")
        if row["request_decision_code"] == "APPROVED"
    }
    requests_by_id = {row["booking_request_id"]: row for row in request_rows}
    approved_slots: set[tuple[str, str, str]] = set()
    for request_id in approved:
        booking = bookings.get(request_id)
        request = requests_by_id.get(request_id)
        if not booking or not request:
            errors.append(f"approved request {request_id} has incomplete relationships")
            continue
        key = (
            booking["space_id"],
            request["requested_start_time"],
            request["requested_end_time"],
        )
        if key in approved_slots:
            errors.append(f"duplicate approved slot detected for request {request_id}: {key}")
        approved_slots.add(key)

    for row in read_rows(input_dir / "advisory_acknowledgements.csv"):
        if row["booking_request_id"] not in request_ids:
            errors.append(f"acknowledgement references missing request {row['booking_request_id']}")
        if row["maintenance_id"] not in maintenance_ids:
            errors.append(f"acknowledgement references missing maintenance {row['maintenance_id']}")

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

    result = {
        "valid": not errors,
        "errors": errors[:100],
        "error_count": len(errors),
        "actual_counts": actual_counts,
        "represented_calendar_years": sorted(years),
        "approved_slot_count": len(approved_slots),
        "reservation_status_counts": dict(reservation_counts),
    }
    (input_dir / "validation.json").write_text(
        json.dumps(result, indent=2, sort_keys=True), encoding="utf-8"
    )
    return result
