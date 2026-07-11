#!/usr/bin/env python3
"""
auto_size_text_migrator.py
==========================
Migrates Flutter Text() widgets that use a fontSize in their style
to AutoSizeText() widgets from the auto_size_text package.

Usage:
    python3 auto_size_text_migrator.py <path_to_lib_folder>

Example:
    python3 auto_size_text_migrator.py lib/

What it does:
  1. Scans every .dart file under the given folder.
  2. Skips files that are unlikely to need it (generated, test, model files).
  3. Replaces   Text(  →  AutoSizeText(
     only when the widget's TextStyle contains a fontSize argument.
  4. Adds the auto_size_text import to any file it modifies.
  5. Removes `const` from direct parents of replaced Text() calls
     (AutoSizeText is not a const widget).
  6. Skips Text() inside ElevatedButton / OutlinedButton / TextButton labels
     (they clip naturally and don't benefit).
  7. Writes a summary report: which files changed, how many replacements.

BEFORE RUNNING:
  - Add   auto_size_text: ^3.0.0   to pubspec.yaml dependencies
  - Run   flutter pub get
  - Commit your current work so you can diff / revert easily

After running:
  - Do a hot restart and check for `const` errors — fix manually where needed
  - Search for any remaining `const Text(` that were missed
"""

import os
import re
import sys
from pathlib import Path


# ── Configuration ─────────────────────────────────────────────────────────────

AUTO_SIZE_IMPORT = "import 'package:auto_size_text/auto_size_text.dart';"

# Default AutoSizeText extra params injected after the text string argument.
# Adjust these defaults to your preference.
AUTO_SIZE_EXTRA = ""  # e.g. ", minFontSize: 10, maxLines: 3, overflow: TextOverflow.ellipsis"

# Files / folders to skip entirely
SKIP_PATH_FRAGMENTS = [
    ".dart_tool",
    "generated",
    ".g.dart",
    "freezed",
    "grpc",
    "proto",
    "_test.dart",
    "test/",
]

# Skip replacements when the Text() appears on the same line as these patterns
# (button children that handle overflow themselves)
SKIP_LINE_PATTERNS = [
    r"child\s*:\s*Text\(",          # generic child: Text( — kept for buttons below
    r"ElevatedButton.*Text\(",
    r"OutlinedButton.*Text\(",
    r"TextButton.*Text\(",
    r"FilledButton.*Text\(",
    r"DropdownMenuItem.*Text\(",
    r"Tab\(.*Text\(",
    r"SnackBar.*Text\(",
    r"Tooltip.*Text\(",
]

# Only replace Text() when the SAME widget tree (within ~10 lines) contains fontSize
REQUIRE_FONT_SIZE_NEARBY = True
FONT_SIZE_LOOKAHEAD_LINES = 10   # lines to look ahead for fontSize


# ── Helpers ───────────────────────────────────────────────────────────────────

def should_skip_file(path: str) -> bool:
    for fragment in SKIP_PATH_FRAGMENTS:
        if fragment in path:
            return True
    return False


def has_font_size_nearby(lines: list, start_index: int) -> bool:
    """Check if 'fontSize' appears within FONT_SIZE_LOOKAHEAD_LINES lines after start_index."""
    end = min(start_index + FONT_SIZE_LOOKAHEAD_LINES, len(lines))
    snippet = "".join(lines[start_index:end])
    return "fontSize" in snippet


def line_should_be_skipped(line: str) -> bool:
    for pattern in SKIP_LINE_PATTERNS:
        if re.search(pattern, line):
            return True
    return False


def add_import(content: str) -> str:
    """Add the auto_size_text import after the last existing import line."""
    if AUTO_SIZE_IMPORT in content:
        return content  # already imported

    # Find the position of the last import line
    last_import_match = None
    for m in re.finditer(r"^import\s+['\"].*?['\"];", content, re.MULTILINE):
        last_import_match = m

    if last_import_match:
        insert_pos = last_import_match.end()
        return content[:insert_pos] + "\n" + AUTO_SIZE_IMPORT + content[insert_pos:]

    # No imports found — add at top
    return AUTO_SIZE_IMPORT + "\n" + content


def remove_const_before_text(line: str) -> str:
    """
    Remove `const` that immediately precedes Text( on the same line.
    e.g.  child: const Text(  →  child: Text(
          const Text(          →  Text(
    """
    # const Text(  →  Text(
    line = re.sub(r'\bconst\s+Text\(', 'Text(', line)
    return line


def migrate_file(filepath: str) -> tuple:
    """
    Returns (modified_content, replacement_count) or (None, 0) if no changes.
    """
    with open(filepath, "r", encoding="utf-8") as f:
        original = f.read()

    lines = original.splitlines(keepends=True)
    new_lines = []
    replacement_count = 0
    modified = False

    i = 0
    while i < len(lines):
        line = lines[i]

        # Check if this line contains Text(
        if re.search(r'\bText\(', line) and "AutoSizeText(" not in line:

            # Skip button labels and other excluded contexts
            if line_should_be_skipped(line):
                new_lines.append(line)
                i += 1
                continue

            # Check fontSize is nearby (within the widget tree)
            if REQUIRE_FONT_SIZE_NEARBY and not has_font_size_nearby(lines, i):
                new_lines.append(line)
                i += 1
                continue

            # Remove const before Text( first
            new_line = remove_const_before_text(line)

            # Replace Text( → AutoSizeText(
            replaced = re.sub(r'\bText\(', 'AutoSizeText(', new_line)

            if replaced != line:
                replacement_count += 1
                modified = True
                new_lines.append(replaced)
                i += 1
                continue

        new_lines.append(line)
        i += 1

    if not modified:
        return None, 0

    new_content = "".join(new_lines)
    new_content = add_import(new_content)
    return new_content, replacement_count


def run(lib_path: str):
    lib = Path(lib_path)
    if not lib.exists():
        print(f"ERROR: Path not found: {lib_path}")
        sys.exit(1)

    dart_files = list(lib.rglob("*.dart"))
    total_files_changed = 0
    total_replacements = 0
    report_lines = []

    for dart_file in sorted(dart_files):
        filepath = str(dart_file)

        if should_skip_file(filepath):
            continue

        new_content, count = migrate_file(filepath)
        if new_content is None:
            continue

        with open(filepath, "w", encoding="utf-8") as f:
            f.write(new_content)

        total_files_changed += 1
        total_replacements += count
        report_lines.append(f"  [{count:>3} replacements]  {dart_file.name}")
        print(f"  ✓  {dart_file.name}  ({count} replacements)")

    print()
    print("=" * 60)
    print(f"  Files changed  : {total_files_changed}")
    print(f"  Total replaced : {total_replacements} Text() → AutoSizeText()")
    print("=" * 60)
    print()
    print("NEXT STEPS:")
    print("  1. Run:  flutter pub get")
    print("  2. Hot restart the app")
    print("  3. Fix any `const` errors Flutter flags (remove const from")
    print("     the parent widget, not the AutoSizeText itself)")
    print("  4. Test on a small screen emulator (320px or SE size)")
    print()

    # Write report file
    report_path = lib / "auto_size_migration_report.txt"
    with open(report_path, "w", encoding="utf-8") as f:
        f.write("AutoSizeText Migration Report\n")
        f.write("=" * 60 + "\n")
        f.write(f"Files changed   : {total_files_changed}\n")
        f.write(f"Total replaced  : {total_replacements}\n")
        f.write("=" * 60 + "\n\n")
        f.write("Changed files:\n")
        for line in report_lines:
            f.write(line + "\n")
        f.write("\nManual checks needed:\n")
        f.write("  - Search for remaining `const Text(` in modified files\n")
        f.write("  - Check button labels (ElevatedButton / OutlinedButton)\n")
        f.write("  - Check SnackBar, Tooltip, Tab text widgets\n")
        f.write("  - Check Text() inside AppBar title (usually fine as-is)\n")

    print(f"  Report saved → {report_path}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 auto_size_text_migrator.py <path_to_lib_folder>")
        print("Example: python3 auto_size_text_migrator.py lib/")
        sys.exit(1)

    run(sys.argv[1])
