#!/usr/bin/env python3
"""Fail when localized ARB keys or placeholder declarations diverge."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EN = json.loads((ROOT / "lib/l10n/app_en.arb").read_text(encoding="utf-8"))
ZH = json.loads((ROOT / "lib/l10n/app_zh.arb").read_text(encoding="utf-8"))

def messages(arb):
    return {key for key in arb if not key.startswith("@@") and not key.startswith("@")} 

en_keys = messages(EN)
zh_keys = messages(ZH)
if en_keys != zh_keys:
    raise SystemExit(f"ARB message keys differ: missing in zh={sorted(en_keys - zh_keys)}, extra in zh={sorted(zh_keys - en_keys)}")

for key in en_keys:
    en_meta = EN.get(f"@{key}", {}).get("placeholders", {})
    zh_meta = ZH.get(f"@{key}", {}).get("placeholders", {})
    if en_meta.keys() != zh_meta.keys():
        raise SystemExit(f"ARB placeholder declarations differ for {key}")

print(f"Checked {len(en_keys)} localized messages in en and zh.")
