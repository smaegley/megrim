#!/usr/bin/env bash
# Render the app's screens for a visual review (app/review_test/review_screens_test.dart).
#
#   tools/review_screens.sh                 every configuration
#   tools/review_screens.sh en-US,pseudo    only these (en-US en-GB de-DE pseudo large-text narrow)
#
# Writes app/build/review/<config>/: one PNG per screen, report.pdf, and problems.txt (layout
# overflows and steps that failed). Then app/build/review/sheets/<config>-NN.png: the screens four
# to a sheet, for reviewing. No emulator: it runs as a Flutter test on this machine, with Roboto.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
tools/l10n.py pseudo >/dev/null           # the pseudo configuration needs en-XA
cd app
flutter pub get >/dev/null
if [[ $# -gt 0 ]]; then export REVIEW_CONFIGS="$1"; fi
flutter test review_test/review_screens_test.dart

python3 - <<'PY'
from pathlib import Path
from PIL import Image

review = Path('build/review')
sheets = review / 'sheets'
sheets.mkdir(exist_ok=True)
for old in sheets.glob('*.png'):
    old.unlink()
per = 4
for cfg in sorted(p for p in review.iterdir() if p.is_dir() and p.name != 'sheets'):
    shots = sorted(cfg.glob('*.png'))
    for i in range(0, len(shots), per):
        imgs = [Image.open(p) for p in shots[i:i + per]]
        w, h = imgs[0].size
        sheet = Image.new('RGB', (w * per + 8 * (per - 1), h), 'white')
        for j, img in enumerate(imgs):
            sheet.paste(img, (j * (w + 8), 0))
        sheet.save(sheets / f'{cfg.name}-{i // per + 1:02d}.png')
    problems = (cfg / 'problems.txt').read_text().strip()
    print(f'{cfg.name}: {len(shots)} screens; problems: {problems}')
PY
