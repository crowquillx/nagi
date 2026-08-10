#!/usr/bin/env python3
"""Find repo modules that are unreachable from a real module entrypoint."""

import re
import sys
from collections import deque
from pathlib import Path

MODULE_TREES = ("modules/nixos", "modules/home")
INTENTIONALLY_DORMANT = {
    "modules/nixos/desktop/niri.nix":
        "kept for future Niri re-enablement",
    "modules/home/desktop/niri-user.nix":
        "kept for future Niri re-enablement",
}
PATH_RE = re.compile(
    r"(?<![A-Za-z0-9_./+-])"
    r"(?P<path>(?:\./|\.\./)+(?:[A-Za-z0-9._+-]+/)*[A-Za-z0-9._+-]+)"
    r"(?![A-Za-z0-9_./+-])"
)


def strip_comments_and_strings(text: str) -> str:
    """Blank Nix comments and strings while preserving token boundaries."""
    output: list[str] = []
    index = 0
    block_depth = 0
    state = "normal"

    while index < len(text):
        pair = text[index:index + 2]
        char = text[index]

        if state == "normal":
            if pair == "/*":
                output.extend("  ")
                block_depth = 1
                state = "block"
                index += 2
            elif pair == "''":
                output.extend("  ")
                state = "indented"
                index += 2
            elif char == "#":
                output.append(" ")
                state = "line"
                index += 1
            elif char == '"':
                output.append(" ")
                state = "double"
                index += 1
            else:
                output.append(char)
                index += 1
        elif state == "line":
            output.append("\n" if char == "\n" else " ")
            index += 1
            if char == "\n":
                state = "normal"
        elif state == "block":
            if pair == "/*":
                output.extend("  ")
                block_depth += 1
                index += 2
            elif pair == "*/":
                output.extend("  ")
                block_depth -= 1
                index += 2
                if block_depth == 0:
                    state = "normal"
            else:
                output.append("\n" if char == "\n" else " ")
                index += 1
        elif state == "double":
            if char == "\\":
                output.append(" ")
                index += 1
                if index < len(text):
                    output.append("\n" if text[index] == "\n" else " ")
                    index += 1
            elif char == '"':
                output.append(" ")
                state = "normal"
                index += 1
            else:
                output.append("\n" if char == "\n" else " ")
                index += 1
        elif state == "indented":
            if pair == "''":
                output.extend("  ")
                state = "normal"
                index += 2
            else:
                output.append("\n" if char == "\n" else " ")
                index += 1

    return "".join(output)


def resolve_reference(source: Path, token: str) -> Path | None:
    target = (source.parent / token).resolve()
    if target.is_dir():
        target = target / "default.nix"
    elif target.suffix != ".nix" and (target / "default.nix").is_file():
        target = target / "default.nix"
    return target if target.is_file() and target.suffix == ".nix" else None


def references_from(source: Path) -> set[Path]:
    content = strip_comments_and_strings(source.read_text(encoding="utf-8"))
    references: set[Path] = set()
    for match in PATH_RE.finditer(content):
        target = resolve_reference(source, match.group("path"))
        if target is not None:
            references.add(target)
    return references


def scan(repo: Path) -> tuple[list[Path], list[Path]]:
    repo = repo.resolve()
    candidates = {
        path.resolve()
        for tree in MODULE_TREES
        for path in (repo / tree).rglob("*.nix")
    }
    nix_files = {
        path.resolve()
        for path in repo.rglob("*.nix")
        if ".git" not in path.parts and "result" not in path.parts
    }
    graph = {
        source: references_from(source) & candidates
        for source in nix_files
    }

    roots = {
        target
        for source, targets in graph.items()
        if source not in candidates
        for target in targets
    }
    dormant = [
        (repo / relative).resolve()
        for relative in INTENTIONALLY_DORMANT
        if (repo / relative).is_file()
    ]
    roots.update(dormant)

    reachable: set[Path] = set()
    pending = deque(roots)
    while pending:
        module = pending.popleft()
        if module in reachable:
            continue
        reachable.add(module)
        pending.extend(graph.get(module, set()) - reachable)

    return sorted(candidates - reachable), sorted(dormant)


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: check-orphan-modules.py <repository>", file=sys.stderr)
        return 2

    repo = Path(sys.argv[1]).resolve()
    orphans, dormant = scan(repo)
    for path in dormant:
        relative = path.relative_to(repo).as_posix()
        print(
            f"    DORMANT: {relative} "
            f"({INTENTIONALLY_DORMANT[relative]})"
        )
    for path in orphans:
        print(f"    ORPHAN: {path.relative_to(repo)}")

    if orphans:
        print(
            f"    {len(orphans)} orphan module(s) found - add a real path "
            "reference or an intentional dormant root."
        )
        return 1

    print("    no orphan modules detected")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
