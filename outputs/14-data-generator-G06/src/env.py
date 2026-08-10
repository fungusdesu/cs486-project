from __future__ import annotations

import os
import re
from pathlib import Path


ENV_NAME = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


def load_dotenv(path: Path | None = None) -> Path | None:
    """Load a simple local .env without overriding the parent shell."""
    env_path = path or (Path(__file__).parents[1] / ".env")
    if not env_path.is_file():
        return None

    for line_number, original in enumerate(
        env_path.read_text(encoding="utf-8").splitlines(), start=1
    ):
        line = original.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("export "):
            line = line[7:].lstrip()
        if "=" not in line:
            raise RuntimeError(f"{env_path}:{line_number}: expected NAME=value")
        name, value = line.split("=", 1)
        name = name.strip()
        value = value.strip()
        if not ENV_NAME.fullmatch(name):
            raise RuntimeError(f"{env_path}:{line_number}: invalid environment name")
        if len(value) >= 2 and value[0] == value[-1] and value[0] in {"'", '"'}:
            value = value[1:-1]
        os.environ.setdefault(name, value)
    return env_path
