from __future__ import annotations

import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from src.generate import CSV_FIELDS
from src.load import build_commands


class LoadCommandTests(unittest.TestCase):
    def make_inputs(self, root: Path) -> None:
        for name, fields in CSV_FIELDS.items():
            (root / name).write_text(",".join(fields) + "\n", encoding="utf-8")

    def test_linux_requires_explicit_sql_credentials(self):
        with tempfile.TemporaryDirectory() as directory, patch.dict(os.environ, {}, clear=True), patch("src.load.os.name", "posix"):
            root = Path(directory)
            self.make_inputs(root)
            with self.assertRaisesRegex(RuntimeError, "DB_USERNAME and DB_PASSWORD"):
                build_commands(root, "localhost,1433", "School", True)

    def test_wrong_database_fails_before_subprocess(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(RuntimeError, "DB_DATABASE=School"):
                build_commands(Path(directory), "localhost,1433", "CS486_G06", True)

    def test_sql_authentication_and_certificate_flags(self):
        with tempfile.TemporaryDirectory() as directory, patch.dict(
            os.environ, {"DB_USERNAME": "g06_member", "DB_PASSWORD": "private"}, clear=True
        ):
            root = Path(directory)
            self.make_inputs(root)
            commands = build_commands(root, "localhost,1433", "School", True)
            self.assertIn("-U", commands[0])
            self.assertNotIn("-E", commands[0])
            self.assertIn("-C", commands[0])
            self.assertTrue(all("-u" in command for command in commands[1:]))

    def test_final_sql_adapter_contract(self):
        sql_dir = Path(__file__).parents[1] / "sql"
        load_sql = (sql_dir / "load-final.sql").read_text(encoding="utf-8")
        validate_sql = (sql_dir / "validate-final.sql").read_text(encoding="utf-8")
        self.assertIn("BEGIN TRANSACTION", load_sql)
        self.assertIn("ROLLBACK TRANSACTION", load_sql)
        self.assertIn("staging_phase2.BookingRequests", load_sql)
        self.assertIn("INSERT INTO dbo.BookingRequest", load_sql)
        self.assertNotIn("Scaffold only", load_sql)
        self.assertIn("Overlapping approved synthetic bookings", validate_sql)
        self.assertIn("allocated_size_mb", validate_sql)


if __name__ == "__main__":
    unittest.main()
