#!/usr/bin/env python3
"""Sort store screenshots into place, after `tools/screenshots.sh <target>` has captured them.

    tools/screenshots.py <target>          # validate build/screenshots/raw/<target>/ and copy
    tools/screenshots.py --list            # show the targets, sizes and destinations
    tools/screenshots.py --regen-demo-data # rebuild app/integration_test/demo_data.dart

Each target's raw PNGs (named by the shot list in app/integration_test/shots.dart, e.g.
`03-suspected-factors.png`) are checked against the pixel sizes the store accepts for that device
and then copied:

  * Android targets go to fastlane/metadata/android/en-US/images/<folder>/, which F-Droid reads,
    in filename order. The PNGs already in that folder are REPLACED (they're tracked by git, so
    the old set is still recoverable).
  * iOS targets go to screenshots/ios/<display>/ (gitignored), for uploading in App Store
    Connect. App Store screenshots must not have an alpha channel, so these are flattened to RGB
    (with Pillow if installed, otherwise macOS `sips`, as JPEG).

A size mismatch or a missing shot fails loudly instead of being found at upload time.
"""
import argparse
import json
import re
import shutil
import struct
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / "app"
RAW = APP / "build" / "screenshots" / "raw"
FASTLANE = ROOT / "fastlane" / "metadata" / "android" / "en-US" / "images"

# target → (store, accepted portrait sizes or None for "any", destination)
TARGETS = {
    "android-phone": ("android", None, FASTLANE / "phoneScreenshots"),
    "android-fold": ("android", None, FASTLANE / "sevenInchScreenshots"),
    "iphone-69": ("ios", [(1320, 2868), (1290, 2796), (1260, 2736)], ROOT / "screenshots/ios/iphone-6.9"),
    "iphone-63": ("ios", [(1206, 2622), (1179, 2556)], ROOT / "screenshots/ios/iphone-6.3"),
    "ipad-13": ("ios", [(2064, 2752), (2048, 2732)], ROOT / "screenshots/ios/ipad-13"),
    "duo-inner": ("ios", [(2007, 2853)], ROOT / "screenshots/ios/iphone-duo-inner"),
    "duo-outer": ("ios", [(1398, 2034)], ROOT / "screenshots/ios/iphone-duo-outer"),
}


def shot_names():
    src = (APP / "integration_test" / "shots.dart").read_text()
    block = re.search(r"kShotNames = \[(.*?)\];", src, re.S)
    if not block:
        sys.exit("can't find kShotNames in app/integration_test/shots.dart")
    return re.findall(r"'([^']+)'", block.group(1))


def png_info(path):
    """(width, height, has_alpha) from a PNG header, stdlib only."""
    with open(path, "rb") as f:
        head = f.read(33)
    if head[:8] != b"\x89PNG\r\n\x1a\n":
        sys.exit(f"{path} is not a PNG")
    w, h, _depth, color = struct.unpack(">IIBB", head[16:26])
    return w, h, color in (4, 6)  # gray+alpha, RGBA


def flatten(src, dest_dir):
    """Copy src into dest_dir without an alpha channel. Returns the written path."""
    try:
        from PIL import Image  # type: ignore

        out = dest_dir / src.name
        Image.open(src).convert("RGB").save(out, optimize=True)
        return out
    except ImportError:
        pass
    if shutil.which("sips"):
        out = dest_dir / (src.stem + ".jpg")
        subprocess.run(
            ["sips", "-s", "format", "jpeg", "-s", "formatOptions", "best", str(src), "--out", str(out)],
            check=True,
            capture_output=True,
        )
        return out
    sys.exit("need Pillow (`pip3 install pillow`) or macOS `sips` to strip the alpha channel")


def sort_target(target):
    store, sizes, dest = TARGETS[target]
    src_dir = RAW / target
    names = shot_names()
    shots = [src_dir / f"{n}.png" for n in names]
    missing = [p.name for p in shots if not p.exists()]
    if missing:
        sys.exit(f"{target}: missing {', '.join(missing)} in {src_dir} — run tools/screenshots.sh {target}")

    problems = []
    for p in shots:
        w, h, _ = png_info(p)
        if h < w:
            problems.append(f"{p.name}: {w}×{h} is landscape")
        elif sizes and (w, h) not in sizes:
            ok = ", ".join(f"{a}×{b}" for a, b in sizes)
            problems.append(f"{p.name}: {w}×{h}, but {target} needs {ok}")
    if problems:
        sys.exit(f"{target}: wrong sizes — nothing copied.\n  " + "\n  ".join(problems))

    dest.mkdir(parents=True, exist_ok=True)
    if store == "android":
        # Replace the previous set: F-Droid shows every PNG in the folder, in filename order.
        for old in dest.glob("*.png"):
            old.unlink()
        for p in shots:
            shutil.copy2(p, dest / p.name)
        written = [dest / p.name for p in shots]
    else:
        for old in list(dest.glob("*.png")) + list(dest.glob("*.jpg")):
            old.unlink()
        written = [flatten(p, dest) for p in shots]

    w, h, _ = png_info(shots[0])
    print(f"{target}: {len(written)} shots at {w}×{h} → {dest.relative_to(ROOT)}/")
    for p in written:
        print(f"  {p.name}")


def regen_demo_data():
    src = (APP / "test" / "fixtures" / "sample-data.json").read_text()
    if "'''" in src:
        sys.exit("sample-data.json contains ''' — can't embed it as a raw string")
    out = APP / "integration_test" / "demo_data.dart"
    text = out.read_text()
    header = text[: text.index("const String kDemoExportJson")]
    out.write_text(header + "const String kDemoExportJson = r'''\n" + src + "''';\n")
    json.loads(src)
    print(f"rewrote {out.relative_to(ROOT)}")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("target", nargs="?", choices=sorted(TARGETS))
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--regen-demo-data", action="store_true")
    a = ap.parse_args()
    if a.regen_demo_data:
        regen_demo_data()
    elif a.list or not a.target:
        for t, (store, sizes, dest) in TARGETS.items():
            s = ", ".join(f"{x}×{y}" for x, y in sizes) if sizes else "any portrait size"
            print(f"{t:14} {store:8} {s:38} → {dest.relative_to(ROOT)}/")
    else:
        sort_target(a.target)


if __name__ == "__main__":
    main()
