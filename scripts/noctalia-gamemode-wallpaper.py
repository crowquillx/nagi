import fcntl
import os
import re
import sys
import tempfile
import tomllib
from pathlib import Path


SETTINGS = Path.home() / ".config/umbriel/shell-state/noctalia/settings.toml"
STATE_DIR = Path.home() / ".local/state/noctalia-gamemode-wallpaper"
MARKER = STATE_DIR / "paused"
SECTION = re.compile(r"(?m)^\[wallpaper\.automation\][ \t]*$")
VALUE = re.compile(r"(?m)^(enabled[ \t]*=[ \t]*)(true|false)([ \t]*(?:#.*)?)$")


def set_rotation(enabled):
    if not SETTINGS.exists():
        return False

    original = SETTINGS.read_text()
    config = tomllib.loads(original)
    current = config.get("wallpaper", {}).get("automation", {}).get("enabled")
    if current is enabled:
        return False
    if not isinstance(current, bool):
        raise ValueError("Noctalia wallpaper automation setting is missing or invalid")

    section = SECTION.search(original)
    if section is None:
        raise ValueError("Noctalia wallpaper automation section is missing")
    next_section = re.search(r"(?m)^\[", original[section.end():])
    end = section.end() + next_section.start() if next_section else len(original)
    body = original[section.end():end]
    updated, count = VALUE.subn(lambda match: match[1] + str(enabled).lower() + match[3], body, count=1)
    if count != 1:
        raise ValueError("Noctalia wallpaper automation value is missing")

    content = original[:section.end()] + updated + original[end:]
    tomllib.loads(content)
    with tempfile.NamedTemporaryFile(mode="w", dir=SETTINGS.parent, prefix=".settings.toml.", delete=False) as temp:
        temp.write(content)
        temp.flush()
        os.fchmod(temp.fileno(), SETTINGS.stat().st_mode & 0o777)
        os.fsync(temp.fileno())
        temp_path = Path(temp.name)
    try:
        os.replace(temp_path, SETTINGS)
    finally:
        temp_path.unlink(missing_ok=True)
    return True


def main(action):
    STATE_DIR.mkdir(mode=0o700, parents=True, exist_ok=True)
    with (STATE_DIR / "lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if action == "pause":
            if not MARKER.exists():
                if SETTINGS.exists() and tomllib.loads(SETTINGS.read_text()).get("wallpaper", {}).get("automation", {}).get("enabled") is True:
                    MARKER.touch()
                    set_rotation(False)
        elif action in ("resume", "recover"):
            if MARKER.exists():
                if not SETTINGS.exists():
                    return
                set_rotation(True)
                MARKER.unlink()
        else:
            raise ValueError(f"unknown action: {action}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: noctalia-gamemode-wallpaper.py pause|resume|recover")
    main(sys.argv[1])
