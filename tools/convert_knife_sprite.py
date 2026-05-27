from pathlib import Path
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SRC_PATH = ROOT / "Assets" / "fruit" / "knife.png"
OUT_PATH = ROOT / "knife_48x48_rgba332.mem"
SPRITE_SIZE = 48


def quantize_rgba332(rgba):
    r, g, b, a = rgba
    if a < 96:
        return 0

    r3 = r >> 5
    g3 = g >> 5
    b2 = b >> 6
    return 0x100 | (r3 << 5) | (g3 << 2) | b2


def main():
    image = Image.open(SRC_PATH).convert("RGBA")
    image = image.resize((SPRITE_SIZE, SPRITE_SIZE), Image.Resampling.NEAREST)

    pixels = image.load()
    lines = []
    for y in range(SPRITE_SIZE):
        for x in range(SPRITE_SIZE):
            lines.append(f"{quantize_rgba332(pixels[x, y]):03x}")

    OUT_PATH.write_text("\n".join(lines) + "\n", encoding="ascii")
    print(f"Wrote {OUT_PATH} ({len(lines)} words)")


if __name__ == "__main__":
    main()
