from __future__ import annotations

import csv
import json
import math
import random
from time import perf_counter
from collections.abc import Iterable, Iterator
from datetime import date, datetime, time, timedelta
from itertools import product
from pathlib import Path
from typing import Any

from .config import GeneratorConfig


SURNAMES = (
    "Nguyen", "Tran", "Le", "Pham", "Hoang", "Huynh", "Phan", "Vu", "Vo",
    "Dang", "Bui", "Do", "Ho", "Ngo", "Duong", "Ly", "Truong", "Dinh",
    "Mai", "Luu", "Cao", "Ta", "Thai", "Chau", "Ton",
)
MIDDLE_NAMES = (
    "Van", "Thi", "Minh", "Thanh", "Quoc", "Ngoc", "Gia", "Hoai", "Duc", "Bao",
)
GIVEN_NAMES = (
    "An", "Anh", "Bao", "Binh", "Chau", "Chi", "Cuong", "Dai", "Dat", "Duc",
    "Dung", "Giang", "Ha", "Hai", "Hanh", "Hieu", "Hoa", "Hoang", "Hung", "Huy",
    "Khanh", "Khoa", "Lam", "Lan", "Linh", "Loc", "Long", "Mai", "Minh", "My",
    "Nam", "Nga", "Ngan", "Ngoc", "Nhi", "Phong", "Phuc", "Quan", "Quang", "Son",
    "Tam", "Thao", "Thien", "Thu", "Trang", "Trinh", "Trung", "Tuan", "Vy", "Yen",
)
CSV_FIELDS: dict[str, tuple[str, ...]] = {
    "users.csv": (
        "user_id", "surname", "given_name", "email", "phone_number",
        "user_role_code", "department_code", "user_status_code",
    ),
    "spaces.csv": (
        "space_id", "space_name", "space_type_code", "building", "floor",
        "room_number", "capacity", "space_status_code", "space_policy_code",
    ),
    "maintenance.csv": (
        "maintenance_id", "reporter_id", "space_id", "maintenance_description",
        "maintenance_status_code", "impact_level_code", "maintenance_start_time",
        "maintenance_end_time",
    ),
    "booking_requests.csv": (
        "booking_request_id", "request_creation_time", "requested_start_time",
        "requested_end_time", "purpose_code", "expected_participants",
        "request_state_code", "advisory_acknowledged", "instant_approval",
    ),
    "bookings.csv": ("booking_request_id", "user_id", "space_id"),
    "reviews.csv": (
        "review_id", "booking_request_id", "reviewer_id", "request_decision_code",
        "decision_time", "decision_note", "rejection_reason",
    ),
    "reservations.csv": (
        "reservation_id", "booking_request_id", "reservation_status_code", "usage_note",
    ),
    "advisory_acknowledgements.csv": (
        "booking_request_id", "maintenance_id", "acknowledged_at",
    ),
}

USER_ID_BASE = 80_000_000
BOOKING_ID_BASE = 10_000_000
POLICY_CODES = ("POLAA", "POLBB", "POLCC", "POLDD")


def iso(value: datetime) -> str:
    return value.isoformat(timespec="seconds")


def write_csv(path: Path, rows: Iterable[dict[str, Any]]) -> int:
    fields = CSV_FIELDS[path.name]
    count = 0
    with path.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields, extrasaction="raise")
        writer.writeheader()
        for row in rows:
            writer.writerow(row)
            count += 1
    return count


def iter_users(count: int) -> Iterator[dict[str, Any]]:
    produced = 0
    round_number = 0
    while produced < count:
        for surname, middle, given in product(SURNAMES, MIDDLE_NAMES, GIVEN_NAMES):
            if produced >= count:
                return
            produced += 1
            suffix = "" if round_number == 0 else str(round_number + 1)
            role = "FACILITY_STAFF" if produced <= 50 else "STUDENT"
            department = "" if role == "FACILITY_STAFF" else f"D{((produced - 1) % 8) + 1:02d}"
            yield {
                "user_id": f"{USER_ID_BASE + produced:08d}",
                "surname": surname,
                "given_name": f"{middle} {given}{suffix}",
                "email": f"user{produced:08d}@student.local",
                "phone_number": f"{900_000_000 + produced:010d}",
                "user_role_code": role,
                "department_code": department,
                "user_status_code": "ACTIVE",
            }
        round_number += 1


def build_spaces(count: int) -> list[dict[str, Any]]:
    types = ("CLASSROOM", "LECTURE_HALL", "MEETING_ROOM", "STUDY", "LAB")
    spaces: list[dict[str, Any]] = []
    for index in range(count):
        building_number = index // 50
        spaces.append({
            "space_id": f"S{index + 1:04d}",
            "space_name": f"Synthetic Space {index + 1}",
            "space_type_code": types[index % len(types)],
            # Start at J to avoid the A/B/C/I buildings in the Phase 1 seed.
            "building": chr(ord("J") + building_number),
            "floor": (index // 10) % 5 + 1,
            "room_number": index % 50 + 1,
            "capacity": 20 + (index % 9) * 10,
            "space_status_code": "AVAILABLE",
            "space_policy_code": POLICY_CODES[index % len(POLICY_CODES)],
        })
    return spaces


def academic_days(start_years: tuple[int, ...]) -> list[date]:
    days: list[date] = []
    for year in start_years:
        periods = (
            (date(year, 8, 15), date(year, 12, 15)),
            (date(year + 1, 1, 15), date(year + 1, 5, 31)),
        )
        for start, end in periods:
            current = start
            while current <= end:
                if current.weekday() < 5:
                    days.append(current)
                current += timedelta(days=1)
    return days


def coprime_stride(total_slots: int) -> int:
    stride = 104_729
    while math.gcd(stride, total_slots) != 1:
        stride += 2
    return stride


def decode_slot(
    slot_index: int,
    spaces: list[dict[str, Any]],
    days: list[date],
    hours: tuple[int, ...],
) -> tuple[dict[str, Any], datetime, tuple[str, str, int]]:
    space_index = slot_index % len(spaces)
    quotient = slot_index // len(spaces)
    hour_index = quotient % len(hours)
    day_index = (quotient // len(hours)) % len(days)
    space = spaces[space_index]
    start = datetime.combine(days[day_index], time(hour=hours[hour_index]))
    return space, start, (space["space_id"], start.date().isoformat(), start.hour)


def generate_dataset(config: GeneratorConfig) -> dict[str, Any]:
    started = perf_counter()
    rng = random.Random(config.seed)
    output_dir = Path(config.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    spaces = build_spaces(config.space_count)
    days = academic_days(config.academic_year_start_years)
    hours = tuple(range(8, 18))
    total_slots = len(spaces) * len(days) * len(hours)
    if config.booking_count > total_slots:
        raise ValueError(
            f"booking_count={config.booking_count} exceeds {total_slots} unique approved slots; "
            "increase space_count or the academic-year range"
        )
    stride = coprime_stride(total_slots)

    counts: dict[str, int] = {}
    counts["users.csv"] = write_csv(output_dir / "users.csv", iter_users(config.user_count))
    counts["spaces.csv"] = write_csv(output_dir / "spaces.csv", iter(spaces))

    maintenance_slots = rng.sample(
        range(config.booking_count),
        k=min(config.maintenance_count, config.booking_count),
    )
    maintenance_by_slot: dict[tuple[str, str, int], list[dict[str, Any]]] = {}
    maintenance_rows: list[dict[str, Any]] = []
    for index, booking_position in enumerate(maintenance_slots, start=1):
        slot_index = (booking_position * stride) % total_slots
        space, start, key = decode_slot(slot_index, spaces, days, hours)
        impact = "ADVISORY" if index % 4 else "OUT_OF_SERVICE"
        record = {
            "maintenance_id": f"m{index:05d}",
            "reporter_id": f"{USER_ID_BASE + ((index - 1) % 50) + 1:08d}",
            "space_id": space["space_id"],
            "maintenance_description": f"Synthetic {impact.lower()} maintenance",
            "maintenance_status_code": "OPEN",
            "impact_level_code": impact,
            "maintenance_start_time": iso(start),
            "maintenance_end_time": iso(start + timedelta(hours=1)),
        }
        maintenance_rows.append(record)
        maintenance_by_slot.setdefault(key, []).append(record)
    counts["maintenance.csv"] = write_csv(output_dir / "maintenance.csv", maintenance_rows)

    paths = {
        name: (output_dir / name).open("w", encoding="utf-8", newline="")
        for name in (
            "booking_requests.csv", "bookings.csv", "reviews.csv",
            "reservations.csv", "advisory_acknowledgements.csv",
        )
    }
    writers = {
        name: csv.DictWriter(stream, fieldnames=CSV_FIELDS[name], extrasaction="raise")
        for name, stream in paths.items()
    }
    for writer in writers.values():
        writer.writeheader()

    generated_counts = {name: 0 for name in paths}
    decision_counts = {"APPROVED": 0, "REJECTED": 0, "PENDING": 0, "CANCELLED": 0}
    reservation_counts = {"COMPLETED": 0, "NO_SHOW": 0, "CANCELLED": 0}
    approved_cursor = 0
    purposes = ("TEACHING", "MEETING", "STUDY", "EVENT", "RESEARCH")

    try:
        for index in range(1, config.booking_count + 1):
            roll = rng.random()
            category = (
                "APPROVED" if roll < 0.68 else
                "REJECTED" if roll < 0.82 else
                "PENDING" if roll < 0.92 else
                "CANCELLED"
            )
            if category == "APPROVED":
                while True:
                    slot_index = (approved_cursor * stride) % total_slots
                    approved_cursor += 1
                    space, start, slot_key = decode_slot(slot_index, spaces, days, hours)
                    active_maintenance = maintenance_by_slot.get(slot_key, [])
                    if not any(
                        item["impact_level_code"] == "OUT_OF_SERVICE"
                        for item in active_maintenance
                    ):
                        break
            else:
                slot_index = rng.randrange(total_slots)
                space, start, slot_key = decode_slot(slot_index, spaces, days, hours)
                active_maintenance = maintenance_by_slot.get(slot_key, [])
                while any(
                    item["impact_level_code"] == "OUT_OF_SERVICE"
                    for item in active_maintenance
                ):
                    slot_index = (slot_index + 1) % total_slots
                    space, start, slot_key = decode_slot(slot_index, spaces, days, hours)
                    active_maintenance = maintenance_by_slot.get(slot_key, [])

            request_id = f"{BOOKING_ID_BASE + index:08d}"
            advisories = [
                item for item in active_maintenance if item["impact_level_code"] == "ADVISORY"
            ]
            acknowledged = bool(advisories)
            creation_time = start - timedelta(days=rng.randint(1, 45), hours=rng.randint(0, 12))
            user_id = f"{USER_ID_BASE + rng.randint(51, config.user_count):08d}"
            expected = rng.randint(1, int(space["capacity"]))
            instant = category == "APPROVED" and index % 5 == 0
            request_state = (
                "AUTO_APPROVED" if instant else
                "REVIEWED" if category in {"APPROVED", "REJECTED"} else
                category
            )

            writers["booking_requests.csv"].writerow({
                "booking_request_id": request_id,
                "request_creation_time": iso(creation_time),
                "requested_start_time": iso(start),
                "requested_end_time": iso(start + timedelta(hours=1)),
                "purpose_code": purposes[index % len(purposes)],
                "expected_participants": expected,
                "request_state_code": request_state,
                "advisory_acknowledged": "1" if acknowledged else "0",
                "instant_approval": "1" if instant else "0",
            })
            generated_counts["booking_requests.csv"] += 1
            writers["bookings.csv"].writerow({
                "booking_request_id": request_id,
                "user_id": user_id,
                "space_id": space["space_id"],
            })
            generated_counts["bookings.csv"] += 1
            decision_counts[category] += 1

            if category in {"APPROVED", "REJECTED"} and not instant:
                reviewers = f"{USER_ID_BASE + rng.randint(1, 50):08d}"
                writers["reviews.csv"].writerow({
                    "review_id": f"{request_id[:4]}-{request_id[4:]}",
                    "booking_request_id": request_id,
                    "reviewer_id": reviewers,
                    "request_decision_code": category,
                    "decision_time": iso(creation_time + timedelta(minutes=rng.randint(1, 240))),
                    "decision_note": "Synthetic review",
                    "rejection_reason": "Time conflict or policy restriction" if category == "REJECTED" else "",
                })
                generated_counts["reviews.csv"] += 1

            if category == "APPROVED":
                reservation_roll = rng.random()
                reservation_status = (
                    "COMPLETED" if reservation_roll < 0.84 else
                    "NO_SHOW" if reservation_roll < 0.94 else
                    "CANCELLED"
                )
                reservation_counts[reservation_status] += 1
                writers["reservations.csv"].writerow({
                    "reservation_id": f"V{index:07d}",
                    "booking_request_id": request_id,
                    "reservation_status_code": reservation_status,
                    "usage_note": "Synthetic Phase 2 reservation",
                })
                generated_counts["reservations.csv"] += 1
                for maintenance in advisories:
                    writers["advisory_acknowledgements.csv"].writerow({
                        "booking_request_id": request_id,
                        "maintenance_id": maintenance["maintenance_id"],
                        "acknowledged_at": iso(creation_time),
                    })
                    generated_counts["advisory_acknowledgements.csv"] += 1
    finally:
        for stream in paths.values():
            stream.close()

    counts.update(generated_counts)
    metadata = {
        "generator": "G06 Python scaffold",
        "config": config.to_json_dict(),
        "total_slots": total_slots,
        "slot_stride": stride,
        "files": counts,
        "decisions": decision_counts,
        "reservations": reservation_counts,
        "python": __import__("platform").python_version(),
        "generation_seconds": round(perf_counter() - started, 3),
        "generated_bytes": sum(path.stat().st_size for path in output_dir.glob("*.csv")),
    }
    (output_dir / "metadata.json").write_text(
        json.dumps(metadata, indent=2, sort_keys=True), encoding="utf-8"
    )
    return metadata
