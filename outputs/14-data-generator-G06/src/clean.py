from __future__ import annotations

import shutil
from pathlib import Path


def clean_generated(input_dir: Path, confirmed: bool) -> None:
    target = input_dir.resolve()
    if not target.name.startswith("generated"):
        raise ValueError(f"refusing to clean {target}; choose a directory named generated")
    if not target.exists():
        print(f"Nothing to clean: {target}")
        return
    if any(target.iterdir()) and not confirmed:
        raise ValueError(f"{target} is not empty; rerun with --yes")
    shutil.rmtree(target)
    print(f"Removed generated data: {target}")