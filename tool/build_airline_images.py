"""Draw placeholder airline images: a tail fin in the airline color with its code.

Usage:
    python tool/build_airline_images.py

Writes assets/airlines/<CODE>.png (256x256, transparent). These are original
artwork, not the airlines' trademarked logos. To use official logos, overwrite
the files with the same names (square PNG, transparent background works best).
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'assets' / 'airlines'

# Keep in sync with lib/data/thai_airlines.dart.
AIRLINES = {
    'TG': '#5C2D91',
    'FD': '#E4002B',
    'PG': '#00549F',
    'VZ': '#D6001C',
    'SL': '#B5121B',
    'DD': '#F2A900',
    'XJ': '#C8102E',
}

SIZE = 256
SCALE = 4  # draw large, then downsample for smooth edges
FONT = Path('C:/Windows/Fonts/arialbd.ttf')


def hex_rgb(value):
    value = value.lstrip('#')
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def luminance(rgb):
    def channel(c):
        c /= 255
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (channel(c) for c in rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def mix(rgb, other, t):
    return tuple(round(a + (b - a) * t) for a, b in zip(rgb, other))


def draw(code, color):
    s = SIZE * SCALE
    base = hex_rgb(color)
    light = mix(base, (255, 255, 255), 0.35)
    dark = mix(base, (0, 0, 0), 0.25)
    text_color = (20, 20, 20) if luminance(base) > 0.45 else (255, 255, 255)

    img = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    def p(x, y):
        return (x * s, y * s)

    # Swept tail fin with a lighter leading-edge stripe and a stabilizer.
    fin = [p(0.14, 0.90), p(0.46, 0.10), p(0.80, 0.10), p(0.70, 0.90)]
    d.polygon(fin, fill=base)
    d.polygon([p(0.46, 0.10), p(0.58, 0.10), p(0.30, 0.90), p(0.14, 0.90)], fill=light)
    d.polygon([p(0.10, 0.90), p(0.90, 0.90), p(0.86, 0.96), p(0.06, 0.96)], fill=dark)

    font = ImageFont.truetype(str(FONT), int(s * 0.25))
    box = d.textbbox((0, 0), code, font=font)
    w, h = box[2] - box[0], box[3] - box[1]
    cx, cy = s * 0.55, s * 0.55
    d.text((cx - w / 2 - box[0], cy - h / 2 - box[1]), code, font=font, fill=text_color)

    return img.resize((SIZE, SIZE), Image.LANCZOS)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for code, color in AIRLINES.items():
        draw(code, color).save(OUT / f'{code}.png', optimize=True)
    print(f'Wrote {len(AIRLINES)} images to {OUT}')


if __name__ == '__main__':
    main()
