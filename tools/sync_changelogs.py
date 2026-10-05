#!/usr/bin/env python3
"""Generate F-Droid's per-ABI changelog files from a release-notes file named after the version.

F-Droid names a changelog by the versionCode of the build it belongs to, and Megrim's recipe
splits each release into three per-ABI builds (`VercodeOperation: %c * 10 + 1/2/3`). So release
1.0.6, versionCode 11, needs identical files called 111.txt, 112.txt and 113.txt — numbers nobody
wants to type or keep in sync by hand.

So: write the notes once in `docs/release-notes/<version>.txt`, run this, and the three copies are
generated. CI re-runs it with --check so a hand-edit that drifts fails the build instead of
shipping a wrong changelog.

  tools/sync_changelogs.py            # write the per-ABI files for the current pubspec version
  tools/sync_changelogs.py --check    # verify they match; non-zero exit if not

Note: the un-suffixed `<versionCode>.txt` files from earlier releases (6.txt .. 11.txt) match no
F-Droid build and are read by nothing — the GitHub release workflow does not use changelogs. They
are left in place as history; this script does not write new ones.
"""

import argparse
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
PUBSPEC = ROOT / "app" / "pubspec.yaml"
NOTES_DIR = ROOT / "docs" / "release-notes"
CHANGELOG_DIR = ROOT / "fastlane" / "metadata" / "android" / "en-US" / "changelogs"

# Must match `VercodeOperation` in the merged fdroiddata recipe for org.maegley.megrim.
ABI_SUFFIXES = (1, 2, 3)

# fastlane's (and Play's) per-release limit, which F-Droid inherits by convention. Worth enforcing
# here: it has been checked by hand every release so far, which is exactly the kind of thing that
# gets forgotten.
MAX_CHARS = 500


def read_version():
    """(versionName, versionCode) from `version: 1.0.6+11` in the app pubspec."""
    text = PUBSPEC.read_text(encoding="utf-8")
    m = re.search(r"^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)\s*$", text, re.M)
    if not m:
        sys.exit(f"Could not find a `version: X.Y.Z+N` line in {PUBSPEC}")
    return m.group(1), int(m.group(2))


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--check", action="store_true",
                    help="verify the generated files match the notes; don't write")
    args = ap.parse_args()

    name, code = read_version()
    notes_path = NOTES_DIR / f"{name}.txt"
    if not notes_path.exists():
        sys.exit(
            f"Missing release notes for {name}.\n"
            f"Create {notes_path.relative_to(ROOT)} (<= {MAX_CHARS} characters), then re-run."
        )

    notes = notes_path.read_text(encoding="utf-8")
    if len(notes) > MAX_CHARS:
        sys.exit(
            f"{notes_path.relative_to(ROOT)} is {len(notes)} characters; "
            f"the limit is {MAX_CHARS}."
        )

    targets = [CHANGELOG_DIR / f"{code * 10 + s}.txt" for s in ABI_SUFFIXES]
    problems = []
    for t in targets:
        if args.check:
            current = t.read_text(encoding="utf-8") if t.exists() else None
            if current != notes:
                problems.append(t.relative_to(ROOT))
        else:
            t.write_text(notes, encoding="utf-8")

    rel = [str(t.relative_to(ROOT)) for t in targets]
    if args.check:
        if problems:
            print(f"Changelogs for {name} (versionCode {code}) are out of date or missing:")
            for p in problems:
                print(f"  {p}")
            print(f"\nRun: tools/sync_changelogs.py")
            return 1
        print(f"Changelogs for {name} (versionCode {code}) match "
              f"{notes_path.relative_to(ROOT)} ({len(notes)}/{MAX_CHARS} chars).")
        return 0

    print(f"Wrote {name} (versionCode {code}, {len(notes)}/{MAX_CHARS} chars) to:")
    for r in rel:
        print(f"  {r}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
