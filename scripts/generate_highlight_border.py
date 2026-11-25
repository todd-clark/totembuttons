"""Generate the shared, tintable rounded highlight border texture."""

import argparse
import math
from pathlib import Path
import struct

OUTPUT = Path(__file__).resolve().parents[1] / "TotemButtons" / "HighlightBorder.tga"
MASK_SIZE = 128
CORNER_RADIUS = 12
CORNER_CENTER = 36
COLOR_INNER = -7
COLOR_OUTER = 0
GLOW_INNER = 13
GLOW_OUTER = MASK_SIZE / 2 - CORNER_CENTER - CORNER_RADIUS


def rounded_box_distance(x, y):
    dx = abs(x + 0.5 - MASK_SIZE / 2) - CORNER_CENTER
    dy = abs(y + 0.5 - MASK_SIZE / 2) - CORNER_CENTER
    return math.hypot(max(dx, 0), max(dy, 0)) + min(max(dx, dy), 0) - CORNER_RADIUS


def render():
    # 32-bit BGRA TGA, with an 8-bit alpha channel and top-left origin.
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0,
                         MASK_SIZE * 2, MASK_SIZE, 32, 0x28)
    pixels = bytearray()
    for y in range(MASK_SIZE):
        # Left mask: falloff on both sides of the stroke. Right mask: solid stroke.
        for glow in (True, False):
            for x in range(MASK_SIZE):
                distance = rounded_box_distance(x, y)
                if glow:
                    falloff = max(0, COLOR_INNER - distance) / GLOW_INNER
                    falloff += max(0, distance - COLOR_OUTER) / GLOW_OUTER
                    alpha = 0.78 * max(0, 1 - falloff) ** 1.65
                else:
                    alpha = max(0, min(1, distance - COLOR_INNER + 0.5, COLOR_OUTER - distance + 0.5))
                pixels.extend((255, 255, 255, round(255 * alpha)))
    return header + pixels


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Verify the saved texture without writing it")
    args = parser.parse_args()
    generated = render()
    if args.check:
        if not OUTPUT.is_file() or OUTPUT.read_bytes() != generated:
            parser.exit(1, "HighlightBorder.tga differs from the generator. Run it again without --check.\n")
        print("HighlightBorder.tga matches the generator.")
    else:
        OUTPUT.write_bytes(generated)


if __name__ == "__main__":
    main()
