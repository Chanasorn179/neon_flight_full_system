"""Turn the supplied airline logo images into app assets.

Usage:
    python tool/build_airline_logos.py <folder with the extracted logo PNGs>

The source images come from thai_airline_logos_split.zip (one logo per file,
on white, with the airline name printed underneath) plus a separately supplied
Thai AirAsia X logo saved as Thai_AirAsia_X.png in the same folder. This crops each logo mark
(dropping the caption and any fragments of neighbouring logos), centres it on a
white square tile and writes assets/airlines/<CODE>.png (256x256).

The app clips the tiles to rounded squares (lib/widgets/airline_logo.dart).
"""

import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'assets' / 'airlines'
SIZE = 256
PADDING = 0.12  # fraction of the tile left empty on each side
# Wide wordmarks get less padding so they stay legible at 44px.
WIDE_PADDING = 0.05
WIDE = {'PG', 'VZ'}

# code -> (source file, crop box (left, top, right, bottom) of the logo mark)
# Boxes were measured on the supplied 483x543 images; the captions start at y>=370.
SOURCES = {
    'TG': ('Thai_Airways.png', (0, 161, 169, 329)),       # orchid symbol; wordmark is cut off in the source
    'FD': ('Thai_AirAsia.png', (112, 102, 393, 383)),
    'PG': ('Bangkok_Airways.png', (68, 48, 461, 320)),
    'VZ': ('Thai_Vietjet_Air.png', (76, 113, 440, 296)),
    'SL': ('Thai_Lion_Air.png', (162, 35, 343, 236)),     # lion symbol; wordmark is unreadable at icon size
    'DD': ('Nok_Air.png', (101, 100, 391, 390)),          # drops a fragment of the next logo at x>=470
    'XJ': ('Thai_AirAsia_X.png', (145, 75, 1109, 1040)),  # 1254x1254 source; caption below y=1084
}


def tile(mark, padding=PADDING):
    """Centre [mark] on a white square, scaled to fit inside the padding."""
    inner = int(SIZE * (1 - 2 * padding))
    mark = mark.convert('RGBA')
    mark.thumbnail((inner, inner), Image.LANCZOS)
    out = Image.new('RGBA', (SIZE, SIZE), (255, 255, 255, 255))
    out.alpha_composite(mark, ((SIZE - mark.width) // 2, (SIZE - mark.height) // 2))
    return out.convert('RGB')


def main(source_dir):
    source_dir = Path(source_dir)
    OUT.mkdir(parents=True, exist_ok=True)
    for code, (name, box) in SOURCES.items():
        padding = WIDE_PADDING if code in WIDE else PADDING
        tile(Image.open(source_dir / name).crop(box), padding).save(OUT / f'{code}.png', optimize=True)
    print(f'Wrote {len(SOURCES)} logos to {OUT}')


if __name__ == '__main__':
    main(sys.argv[1])
