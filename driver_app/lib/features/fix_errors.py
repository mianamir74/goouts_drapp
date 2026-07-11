"""
Flutter Error Auto-Fixer
========================
Paste Flutter error output into a file called `errors.txt` next to this script,
then run:  python fix_errors.py

What it fixes automatically:
  1. "Not a constant expression"          → removes `const` from that line
  2. "The method 'AutoSizeText' isn't defined"  → adds auto_size_text import
  3. "isn't a type" / "Can't find ')'"   → reports location so you can inspect
  4. "Final field 'X' is not initialized" → reports location

Add errors.txt in the same folder as this script (lib/features/).
"""

import re
import os
import sys

# ── Config ────────────────────────────────────────────────────────────────────
FEATURES_DIR = os.path.dirname(os.path.abspath(__file__))
ERRORS_FILE = os.path.join(FEATURES_DIR, 'errors.txt')
AUTO_SIZE_IMPORT = "import 'package:auto_size_text/auto_size_text.dart';\n"

# ── Parse Flutter error lines ─────────────────────────────────────────────────
# Pattern: lib/features/some/file.dart:42:10: Error: Some message
ERROR_RE = re.compile(
    r'lib[/\\]features[/\\](?P<relpath>[^\s:]+\.dart):(?P<line>\d+):\d+:\s+Error:\s+(?P<msg>.+)'
)

def parse_errors(text):
    errors = []
    for match in ERROR_RE.finditer(text):
        errors.append({
            'relpath': match.group('relpath').replace('\\', '/'),
            'line': int(match.group('line')),
            'msg': match.group('msg').strip(),
        })
    return errors

# ── Classify errors ───────────────────────────────────────────────────────────
def classify(msg):
    if 'Not a constant expression' in msg:
        return 'const_expr'
    if "isn't defined for the type" in msg and 'AutoSizeText' in msg:
        return 'missing_import'
    if 'Not found:' in msg and 'auto_size_text' in msg:
        return 'missing_import'
    if "A const constructor can't have a body" in msg:
        return 'const_constructor'
    if "isn't a type" in msg:
        return 'not_a_type'
    if "Can't find" in msg and ("')'" in msg or "']'" in msg or "'}'" in msg):
        return 'unmatched_bracket'
    if 'Final field' in msg and 'not initialized' in msg:
        return 'uninit_field'
    if "Required named parameter" in msg:
        return 'missing_param'
    return 'unknown'

# ── Fix: remove const from a specific line ────────────────────────────────────
def fix_const_on_line(lines, line_no):
    """Remove standalone `const ` keyword from a given 1-based line number."""
    idx = line_no - 1
    if idx < 0 or idx >= len(lines):
        return False
    original = lines[idx]
    # Remove `const ` but not inside strings or comments
    fixed = re.sub(r'\bconst\s+', '', original, count=1)
    if fixed != original:
        lines[idx] = fixed
        return True
    return False

# ── Fix: add auto_size_text import if missing ─────────────────────────────────
def fix_missing_import(lines, filepath):
    """Add auto_size_text import after the last existing import line."""
    for line in lines:
        if AUTO_SIZE_IMPORT.strip() in line:
            return False  # already present
    # Find last import line
    last_import = -1
    for i, line in enumerate(lines):
        if line.strip().startswith('import '):
            last_import = i
    insert_at = last_import + 1 if last_import >= 0 else 0
    lines.insert(insert_at, AUTO_SIZE_IMPORT)
    return True

# ── Main ──────────────────────────────────────────────────────────────────────
def main():
    if not os.path.exists(ERRORS_FILE):
        print(f"ERROR: '{ERRORS_FILE}' not found.")
        print("Create errors.txt in the same folder as this script and paste Flutter errors into it.")
        sys.exit(1)

    with open(ERRORS_FILE, 'r', encoding='utf-8') as f:
        error_text = f.read()

    errors = parse_errors(error_text)
    print(f"Parsed {len(errors)} error entries.\n")

    # Group by file
    by_file = {}
    for e in errors:
        by_file.setdefault(e['relpath'], []).append(e)

    fixed_summary = []
    skipped_summary = []

    for relpath, file_errors in sorted(by_file.items()):
        filepath = os.path.join(FEATURES_DIR, relpath.replace('/', os.sep))
        if not os.path.exists(filepath):
            skipped_summary.append(f"  FILE NOT FOUND: {relpath}")
            continue

        with open(filepath, 'r', encoding='utf-8') as f:
            lines = f.readlines()

        original_lines = list(lines)
        file_fixed = []
        file_skipped = []

        needs_import = False

        for e in file_errors:
            kind = classify(e['msg'])

            if kind == 'const_expr':
                # The error points to the AutoSizeText line — go back up to 5 lines
                # to find the nearest const and remove it
                fixed = False
                for back in range(0, 6):
                    target = e['line'] - back
                    if target < 1:
                        break
                    idx = target - 1
                    if re.search(r'\bconst\b', lines[idx]) and not lines[idx].strip().startswith('//'):
                        if fix_const_on_line(lines, target):
                            file_fixed.append(f"  line {target}: removed const ({e['msg'][:60]})")
                            fixed = True
                            break
                if not fixed:
                    file_skipped.append(f"  line {e['line']}: could not remove const — {e['msg'][:80]}")

            elif kind == 'missing_import':
                needs_import = True

            elif kind == 'const_constructor':
                # Remove const from the constructor line itself
                if fix_const_on_line(lines, e['line']):
                    file_fixed.append(f"  line {e['line']}: removed const from constructor")
                else:
                    file_skipped.append(f"  line {e['line']}: const constructor — manual fix needed")

            else:
                file_skipped.append(
                    f"  line {e['line']} [{kind}]: {e['msg'][:90]}"
                )

        if needs_import:
            if fix_missing_import(lines, filepath):
                file_fixed.append("  added auto_size_text import")

        if lines != original_lines:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.writelines(lines)

        if file_fixed:
            fixed_summary.append(f"\n✅ {relpath}")
            fixed_summary.extend(file_fixed)
        if file_skipped:
            skipped_summary.append(f"\n⚠️  {relpath} — needs manual attention")
            skipped_summary.extend(file_skipped)

    print("=" * 60)
    print("FIXED AUTOMATICALLY:")
    print('\n'.join(fixed_summary) if fixed_summary else "  (none)")
    print()
    print("NEEDS MANUAL ATTENTION:")
    print('\n'.join(skipped_summary) if skipped_summary else "  (none)")
    print("=" * 60)
    print("\nDone. Run `flutter pub get` then hot restart.")

if __name__ == '__main__':
    main()
