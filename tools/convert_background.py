from pathlib import Path
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SRC_PATH = ROOT / "Assets" / "background2.png"
OUT_PATH = ROOT / "background2_64x64_rgb332.mem"
BG_W = 64
BG_H = 64


def quantize_rgb332(rgb):
    r, g, b = rgb
    return ((r >> 5) << 5) | ((g >> 5) << 2) | (b >> 6)


def main():
    image = Image.open(SRC_PATH).convert("RGB")
    if image.size != (BG_W, BG_H):
        image = image.resize((BG_W, BG_H), Image.Resampling.LANCZOS)

    pixels = image.load()
    lines = []
    for y in range(BG_H):
        for x in range(BG_W):
            lines.append(f"{quantize_rgb332(pixels[x, y]):02x}")

    OUT_PATH.write_text("\n".join(lines) + "\n", encoding="ascii")
    print(f"Wrote {OUT_PATH} ({len(lines)} words)")


if __name__ == "__main__":
    main()
