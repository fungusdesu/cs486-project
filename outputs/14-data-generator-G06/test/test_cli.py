from __future__ import annotations

import argparse
import unittest
from pathlib import Path
from unittest.mock import patch

from src.cli import main


class CliEnvironmentTests(unittest.TestCase):
    def test_non_load_command_does_not_read_dotenv(self):
        arguments = argparse.Namespace(
            command="clean", input=Path("generated"), yes=True
        )
        with (
            patch("src.cli.parser") as parser_factory,
            patch("src.cli.load_dotenv") as load_dotenv,
            patch("src.cli.clean_generated") as clean_generated,
        ):
            parser_factory.return_value.parse_args.return_value = arguments
            self.assertEqual(main(), 0)
            load_dotenv.assert_not_called()
            clean_generated.assert_called_once_with(Path("generated"), confirmed=True)


if __name__ == "__main__":
    unittest.main()
