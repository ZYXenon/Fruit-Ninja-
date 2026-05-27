from pathlib import Path
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = ROOT / "Assets" / "fruit"
OUT_PATH = ROOT / "fruit_sprites_thirdres_rgba332.mem"
DISPLAY_SCALE = 3
ROM_DEPTH = 16384

# Order must match fruit_sprite_rom.sv:
# type 0 apple, 1 strawberry, 2 watermelon, 3 peach, 4 banana, 5 bomb.
# variant 0 whole, 1 left half, 2 right half.
SPRITES = [
    ("apple", "\u82f9\u679c_64x64.png", "\u82f9\u679c\u5de6_64x64.png", "\u82f9\u679c\u53f3_64x64.png"),
    ("strawberry", "\u8349\u8393.png", "\u8349\u8393\u5de6.png", "\u8349\u8393\u53f3.png"),
    ("watermelon", "\u897f\u74dc.png", "\u897f\u74dc\u5de6.png", "\u897f\u74dc\u53f3.png"),
    ("peach", "\u6843\u5b50.png", "\u6843\u5b50\u5de6.png", "\u6843\u5b50\u53f3.png"),
    ("banana", "\u9999\u8549.png", "\u9999\u8549\u5de6.png", "\u9999\u8549\u53f3.png"),
    ("bomb", "\u70b8\u5f39.png", "\u70b8\u5f39.png", "\u70b8\u5f39.png"),
]


def quantize_rgba332(rgba):
    r, g, b, a = rgba
    if a < 96:
        return 0

    return 0x100 | ((r >> 5) << 5) | ((g >> 5) << 2) | (b >> 6)


def apply_corner_color_key(image):
    corners = [
        image.getpixel((0, 0)),
        image.getpixel((image.width - 1, 0)),
        image.getpixel((0, image.height - 1)),
        image.getpixel((image.width - 1, image.height - 1)),
    ]
    opaque_corners = [c for c in corners if c[3] >= 128]

    if not opaque_corners:
        return image

    key_r = sum(c[0] for c in opaque_corners) // len(opaque_corners)
    key_g = sum(c[1] for c in opaque_corners) // len(opaque_corners)
    key_b = sum(c[2] for c in opaque_corners) // len(opaque_corners)
    keyed = []

    for r, g, b, a in image.getdata():
        distance = abs(r - key_r) + abs(g - key_g) + abs(b - key_b)
        keyed.append((r, g, b, 0 if distance < 36 else a))

    image.putdata(keyed)
    return image


def main():
    lines = []
    metadata = []
    base = 0

    for fruit_name, whole, left, right in SPRITES:
        for variant, filename in enumerate((whole, left, right)):
            image = Image.open(ASSET_DIR / filename).convert("RGBA")
            image = apply_corner_color_key(image)
            source_w = max(1, (image.width + DISPLAY_SCALE - 1) // DISPLAY_SCALE)
            source_h = max(1, (image.height + DISPLAY_SCALE - 1) // DISPLAY_SCALE)
            image = image.resize((source_w, source_h), Image.Resampling.LANCZOS)
            pixels = image.load()

            metadata.append((fruit_name, variant, filename, base, image.width, image.height))

            for y in range(image.height):
                for x in range(image.width):
                    lines.append(f"{quantize_rgba332(pixels[x, y]):03x}")

            base += image.width * image.height

    if len(lines) > ROM_DEPTH:
        raise RuntimeError(f"Sprite ROM needs {len(lines)} words, but ROM_DEPTH is {ROM_DEPTH}")

    lines.extend(["000"] * (ROM_DEPTH - len(lines)))
    OUT_PATH.write_text("\n".join(lines) + "\n", encoding="ascii")
    print(f"Wrote {OUT_PATH} ({len(lines)} words)")

    for fruit_name, variant, filename, base, width, height in metadata:
        print(f"{fruit_name:10s} variant={variant} base={base:5d} size={width:3d}x{height:3d} source={filename}")


if __name__ == "__main__":
    main()
