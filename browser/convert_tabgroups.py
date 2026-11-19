#!/usr/bin/env python3
"""Convert Chrome 'Tab Groups Extension' rules (browser/tabgroups_rules.json)
into Firefox/Chrome 'Auto Tab Groups' (nitzanpap/auto-tab-groups) import JSON.
"""

from __future__ import annotations

import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

VALID_COLORS = ("blue", "green", "yellow", "purple", "cyan", "orange", "pink", "red", "grey")
DEFAULT_COLOR_BY_NAME = {
    "jira": "blue",
    "dic": "green",
    "google": "yellow",
    "dev": "cyan",
    "notion": "grey",
    "fig": "pink",
    "ai": "purple",
    "git": "orange",
    "blog": "cyan",
    "cloud": "orange",
    "youtube": "red",
    "stg": "yellow",
    "sns": "pink",
    "prtimes": "blue",
}


def convert_match(match: dict) -> list[str]:
    method = match.get("method", "includes")
    val = (match.get("value") or "").strip()
    if not val:
        return []

    if method == "regex":
        # Auto Tab Groups expects regex wrapped in /.../
        if not (val.startswith("/") and val.endswith("/")):
            val = f"/{val}/"
        return [val]

    # Strip scheme and trailing slash for URL/href matches
    cleaned = re.sub(r"^https?://", "", val, flags=re.IGNORECASE).strip("/")
    if not cleaned:
        return []

    if cleaned == "localhost":
        return ["localhost", "localhost:*"]
    return [cleaned]


def convert_rules(src: dict) -> dict:
    now = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    out_rules: dict[str, dict] = {}
    color_idx = 0

    for rule_id, rule in src.items():
        if rule_id == "meta" or not isinstance(rule, dict):
            continue

        matches = rule.get("urlMatches") or []
        domains: list[str] = []
        has_regex = False
        for m in matches:
            if m.get("method") == "regex":
                has_regex = True
            for pat in convert_match(m):
                pat_norm = pat.strip()
                if pat_norm and pat_norm not in domains:
                    domains.append(pat_norm)

        if not domains:
            continue

        name = (rule.get("groupName") or rule.get("ruleName") or rule_id).strip()
        color = rule.get("groupColor")
        if color not in VALID_COLORS:
            color = DEFAULT_COLOR_BY_NAME.get(name.lower()) or VALID_COLORS[color_idx % len(VALID_COLORS)]
            color_idx += 1

        # Specific domain rules get higher priority (2) than catch-all regex rules (1)
        # so e.g. aistudio.google.com -> AI and console.cloud.google.com -> Cloud win over Google regex.
        priority = 1 if has_regex else 2

        out_rules[rule_id] = {
            "id": rule_id,
            "name": name,
            "domains": domains,
            "color": color,
            "enabled": rule.get("enabled", True) is not False,
            "priority": priority,
            "isBlacklist": False,
            "createdAt": now,
        }

    return {
        "version": "1.0",
        "exportDate": now,
        "rules": out_rules,
        "totalRules": len(out_rules),
    }


def main() -> int:
    repo_browser_dir = Path(__file__).resolve().parent
    src_path = Path(sys.argv[1]) if len(sys.argv) > 1 else repo_browser_dir / "tabgroups_rules.json"
    dest_path = Path(sys.argv[2]) if len(sys.argv) > 2 else repo_browser_dir / "auto_tab_groups_rules.json"

    with src_path.open("r", encoding="utf-8") as f:
        src_data = json.load(f)

    converted = convert_rules(src_data)
    with dest_path.open("w", encoding="utf-8") as f:
        json.dump(converted, f, indent=2, ensure_ascii=False)
        f.write("\n")

    print(f"Converted {converted['totalRules']} rules -> {dest_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
