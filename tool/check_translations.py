#!/usr/bin/env python3
"""Check ARB contracts and the Flutter untranslated-message report."""

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def check(template_path, translation_path, report_path):
    template = json.loads(template_path.read_text(encoding="utf-8"))
    translation = json.loads(translation_path.read_text(encoding="utf-8"))
    report = json.loads(report_path.read_text(encoding="utf-8"))

    def messages(arb):
        return {key for key in arb if not key.startswith("@")}

    expected, actual = messages(template), messages(translation)
    for arb, keys in ((template, expected), (translation, actual)):
        orphan = {key[1:] for key in arb if key.startswith("@")
                  and not key.startswith("@@") and key[1:] not in keys}
        if orphan:
            raise ValueError(f"ARB metadata without message: {sorted(orphan)}")
    if expected != actual:
        raise ValueError(
            f"ARB keys differ: missing={sorted(expected - actual)}, "
            f"extra={sorted(actual - expected)}"
        )
    for key in expected:
        source = template.get(f"@{key}", {}).get("placeholders", {})
        target = translation.get(f"@{key}", {}).get("placeholders", {})
        if source != target:
            raise ValueError(f"ARB placeholder declarations differ for {key}")
    if not isinstance(report, dict) or any(report.values()):
        raise ValueError(f"Untranslated messages found: {report}")
    print(f"Checked {len(expected)} localized messages and untranslated report.")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--template", type=Path, default=ROOT / "lib/l10n/app_en.arb")
    parser.add_argument("--translation", type=Path, default=ROOT / "lib/l10n/app_zh.arb")
    parser.add_argument("--report", type=Path, default=ROOT / ".dart_tool/untranslated.json")
    args = parser.parse_args()
    try:
        check(args.template, args.translation, args.report)
    except (ValueError, OSError, json.JSONDecodeError) as error:
        raise SystemExit(str(error)) from error


if __name__ == "__main__":
    main()
