from __future__ import annotations

import json
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any


@dataclass(frozen=True)
class GeneratorConfig:
    seed: int = 48606
    user_count: int = 10_000
    space_count: int = 100
    booking_count: int = 100_000
    maintenance_count: int = 2_500
    academic_year_start_years: tuple[int, ...] = (2023, 2024, 2025)
    output_dir: str = "generated"

    def validate(self) -> None:
        if self.user_count < 100:
            raise ValueError("user_count must be at least 100")
        if self.space_count < 2:
            raise ValueError("space_count must be at least 2")
        if self.booking_count < 1:
            raise ValueError("booking_count must be positive")
        if self.maintenance_count < 1:
            raise ValueError("maintenance_count must be positive")
        if len(self.academic_year_start_years) < 3:
            raise ValueError("at least three academic years are required")

    def to_json_dict(self) -> dict[str, Any]:
        value = asdict(self)
        value["academic_year_start_years"] = list(self.academic_year_start_years)
        return value


def load_config(path: Path | None, overrides: dict[str, Any]) -> GeneratorConfig:
    values: dict[str, Any] = {}
    if path:
        values.update(json.loads(path.read_text(encoding="utf-8")))
    values.update({key: value for key, value in overrides.items() if value is not None})
    if "academic_year_start_years" in values:
        values["academic_year_start_years"] = tuple(values["academic_year_start_years"])
    config = GeneratorConfig(**values)
    config.validate()
    return config
