from __future__ import annotations

import hashlib
import tempfile
import unittest
from pathlib import Path

from src.config import GeneratorConfig
from src.generate import generate_dataset
from src.validate import validate_dataset


class GeneratorTests(unittest.TestCase):
    def test_same_seed_is_byte_reproducible_and_valid(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            first = root / "generated-a"
            second = root / "generated-b"
            config = GeneratorConfig(user_count=200, space_count=20, booking_count=1000, maintenance_count=50, output_dir=str(first))
            generate_dataset(config)
            generate_dataset(GeneratorConfig(**{**config.to_json_dict(), "output_dir": str(second)}))
            self.assertTrue(validate_dataset(first)["valid"])
            self.assertTrue(validate_dataset(second)["valid"])
            names = sorted(path.name for path in first.glob("*.csv"))
            self.assertEqual(
                [(name, hashlib.sha256((first / name).read_bytes()).hexdigest()) for name in names],
                [(name, hashlib.sha256((second / name).read_bytes()).hexdigest()) for name in names],
            )


if __name__ == "__main__":
    unittest.main()