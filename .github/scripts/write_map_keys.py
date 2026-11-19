#!/usr/bin/env python3
"""Write local map-key files from CI environment variables.

Reads GOOGLE_MAPS_API_KEY_ANDROID and GOOGLE_MAPS_API_KEY_IOS.
Does not print the values.
"""

import json
import os
import sys
from pathlib import Path


def required(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        print(f"Missing secret {name}", file=sys.stderr)
        sys.exit(1)
    return value


def main() -> None:
    android_key = required("GOOGLE_MAPS_API_KEY_ANDROID")
    ios_key = required("GOOGLE_MAPS_API_KEY_IOS")

    root = Path(__file__).resolve().parents[2]
    local_properties = root / "android" / "local.properties"
    existing = local_properties.read_text() if local_properties.exists() else ""
    kept = [line for line in existing.splitlines() if not line.startswith("MAPS_API_KEY=")]
    kept.append(f"MAPS_API_KEY={android_key}")
    local_properties.write_text("\n".join(kept) + "\n")

    secrets_xcconfig = root / "ios" / "Flutter" / "Secrets.xcconfig"
    secrets_xcconfig.parent.mkdir(parents=True, exist_ok=True)
    secrets_xcconfig.write_text(f"GOOGLE_MAPS_API_KEY={ios_key}\n")

    defines = root / "dart_defines.json"
    defines.write_text(
        json.dumps(
            {
                "GOOGLE_MAPS_API_KEY_ANDROID": android_key,
                "GOOGLE_MAPS_API_KEY_IOS": ios_key,
            },
            indent=2,
        )
        + "\n"
    )


if __name__ == "__main__":
    main()
