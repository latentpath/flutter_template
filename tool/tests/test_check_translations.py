import json
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "check_translations.py"


class TranslationChecks(unittest.TestCase):
    def run_check(self, source, target, report):
        with tempfile.TemporaryDirectory() as directory:
            paths = [Path(directory) / name for name in ("en.arb", "zh.arb", "report.json")]
            for path, value in zip(paths, (source, target, report)):
                path.write_text(json.dumps(value), encoding="utf-8")
            return subprocess.run(
                ["python3", str(SCRIPT), "--template", str(paths[0]),
                 "--translation", str(paths[1]), "--report", str(paths[2])],
                capture_output=True, text=True, check=False,
            )

    def test_valid_translations(self):
        self.assertEqual(self.run_check({"hello": "Hi"}, {"hello": "你好"}, {}).returncode, 0)

    def test_rejects_missing_and_extra_keys(self):
        for target in ({}, {"hello": "你好", "extra": "额外"}):
            with self.subTest(target=target):
                self.assertNotEqual(self.run_check({"hello": "Hi"}, target, {}).returncode, 0)

    def test_rejects_orphan_metadata(self):
        self.assertNotEqual(self.run_check({"hello": "Hi"}, {"hello": "你好", "@extra": {}}, {}).returncode, 0)

    def test_rejects_placeholder_mismatch(self):
        source = {"hello": "Hi {name}", "@hello": {"placeholders": {"name": {"type": "String"}}}}
        target = {"hello": "你好 {name}", "@hello": {"placeholders": {"name": {"type": "int"}}}}
        self.assertNotEqual(self.run_check(source, target, {}).returncode, 0)

    def test_rejects_untranslated_report(self):
        self.assertNotEqual(self.run_check({"hello": "Hi"}, {"hello": "你好"}, {"zh": ["hello"]}).returncode, 0)

    def test_rejects_missing_report(self):
        result = subprocess.run(["python3", str(SCRIPT), "--report", "/nonexistent/report.json"], capture_output=True, check=False)
        self.assertNotEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()
