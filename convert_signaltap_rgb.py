#!/usr/bin/env python3
"""Convert SignalTap OV2640 RGB565 captures to PNG images.

The preferred SignalTap capture contains:
  - ov2640_capture:camera_capture|fifo_wr_valid
  - ov2640_capture:camera_capture|fifo_wr_data[17..0]

If fifo_wr_valid is missing, the script can still create a partial preview by
assuming every exported packed sample is a pixel. That is useful for inspection,
but a complete frame should be captured with fifo_wr_valid as a storage
qualifier or exported signal.
"""

from __future__ import annotations

import argparse
import csv
import math
import struct
import zlib
from pathlib import Path


DEFAULT_WIDTH = 320
DEFAULT_HEIGHT = 240


def _clean_cell(value: str) -> str:
    return value.strip()


def _norm_signal(name: str) -> str:
    return name.strip().lower().replace(" ", "")


def _parse_bit(value: str) -> int | None:
    value = _clean_cell(value)
    if value in {"0", "1"}:
        return int(value)
    return None


def _parse_hex(value: str) -> int | None:
    value = _clean_cell(value)
    if not value or "X" in value.upper() or "Z" in value.upper():
        return None
    try:
        return int(value, 16)
    except ValueError:
        return None


def _find_col(header: list[str], predicates: list) -> int | None:
    for pred in predicates:
        for i, name in enumerate(header):
            if pred(_norm_signal(name)):
                return i
    return None


def _load_signaltap_csv(path: Path) -> tuple[list[str], list[list[str]]]:
    with path.open("r", newline="") as f:
        rows = list(csv.reader(f))

    data_idx = None
    for i, row in enumerate(rows):
        if row and _clean_cell(row[0]).lower() == "data:":
            data_idx = i
            break

    if data_idx is None or data_idx + 1 >= len(rows):
        raise ValueError("Could not find the SignalTap 'Data:' section.")

    header = [_clean_cell(c) for c in rows[data_idx + 1]]
    while header and header[-1] == "":
        header.pop()

    data_rows: list[list[str]] = []
    for row in rows[data_idx + 2 :]:
        row = [_clean_cell(c) for c in row]
        while row and row[-1] == "":
            row.pop()
        if row:
            data_rows.append(row)

    return header, data_rows


def _extract_pixels(
    header: list[str],
    data_rows: list[list[str]],
    assume_all_samples_valid: bool,
) -> tuple[list[int], dict[str, object]]:
    packed_col = _find_col(
        header,
        [
            lambda s: "fifo_wr_data[17..0]" in s,
            lambda s: "wr_data[17..0]" in s,
            lambda s: "fifo_wr_data[15..0]" in s,
            lambda s: "wr_data[15..0]" in s,
        ],
    )
    if packed_col is None:
        raise ValueError("Could not find fifo_wr_data[17..0] or fifo_wr_data[15..0].")

    valid_col = _find_col(
        header,
        [
            lambda s: "fifo_wr_valid" in s,
            lambda s: s.endswith("|fifo_wr_valid"),
            lambda s: s.endswith("|wr_valid"),
            lambda s: s == "fifo_wr_valid",
            lambda s: s == "cam_fifo_wr_valid",
        ],
    )
    href_col = _find_col(header, [lambda s: s == "cam_href" or s.endswith("|cam_href")])
    vsync_col = _find_col(header, [lambda s: s == "cam_vsync" or s.endswith("|cam_vsync")])
    ready_col = _find_col(
        header,
        [
            lambda s: "fifo_wr_ready" in s,
            lambda s: s.endswith("|fifo_wr_ready"),
            lambda s: s.endswith("|wr_ready"),
            lambda s: s == "fifo_wr_ready",
            lambda s: s == "cam_fifo_wr_ready",
        ],
    )
    overflow_col = _find_col(
        header,
        [
            lambda s: "overflow_pulse" in s,
            lambda s: s.endswith("|cam_overflow"),
            lambda s: s.endswith("|overflow"),
            lambda s: s == "overflow",
            lambda s: s == "cam_overflow",
        ],
    )

    pixels: list[int] = []
    sof_positions: list[int] = []
    skipped_x = 0
    valid_rows = 0
    valid_not_ready_rows = 0
    signal_counts: dict[str, int] = {}

    for name, col in {
        "CAM_HREF": href_col,
        "CAM_VSYNC": vsync_col,
        "fifo_wr_ready": ready_col,
        "fifo_wr_valid": valid_col,
        "overflow": overflow_col,
    }.items():
        if col is not None:
            signal_counts[name] = sum(1 for row in data_rows if col < len(row) and _parse_bit(row[col]) == 1)

    for row in data_rows:
        if packed_col >= len(row):
            continue

        packed = _parse_hex(row[packed_col])
        if packed is None:
            skipped_x += 1
            continue

        if valid_col is not None:
            if valid_col >= len(row) or _parse_bit(row[valid_col]) != 1:
                continue
        elif not assume_all_samples_valid:
            continue

        if ready_col is not None and ready_col < len(row) and _parse_bit(row[ready_col]) == 0:
            valid_not_ready_rows += 1

        pixel_index = len(pixels)
        valid_rows += 1
        if packed & (1 << 17):
            sof_positions.append(pixel_index)
        pixels.append(packed & 0xFFFF)

    info: dict[str, object] = {
        "packed_col": header[packed_col],
        "valid_col": header[valid_col] if valid_col is not None else None,
        "href_col": header[href_col] if href_col is not None else None,
        "vsync_col": header[vsync_col] if vsync_col is not None else None,
        "ready_col": header[ready_col] if ready_col is not None else None,
        "overflow_col": header[overflow_col] if overflow_col is not None else None,
        "signal_counts": signal_counts,
        "skipped_x": skipped_x,
        "valid_rows": valid_rows,
        "valid_not_ready_rows": valid_not_ready_rows,
        "sof_positions": sof_positions,
        "used_assume_all_samples_valid": valid_col is None and assume_all_samples_valid,
    }
    return pixels, info


def _choose_frame(pixels: list[int], sof_positions: list[int], frame_pixels: int) -> tuple[list[int], dict[str, object]]:
    if not pixels:
        raise ValueError("No valid RGB565 pixels were extracted.")

    candidates: list[tuple[int, int]] = []
    if sof_positions:
        starts = sof_positions + [len(pixels)]
        for i, start in enumerate(sof_positions):
            end = starts[i + 1]
            candidates.append((start, end))
    else:
        candidates.append((0, len(pixels)))

    complete = [(s, e) for s, e in candidates if e - s >= frame_pixels]
    if complete:
        start, end = complete[0][0], complete[0][0] + frame_pixels
        status = "complete"
    else:
        start, end = max(candidates, key=lambda se: se[1] - se[0])
        status = "partial"

    return pixels[start:end], {
        "status": status,
        "start_pixel": start,
        "end_pixel": end,
        "selected_pixels": end - start,
        "candidate_segments": [(s, e, e - s) for s, e in candidates],
    }


def _rgb565_to_rgb888(pixel: int) -> tuple[int, int, int]:
    r5 = (pixel >> 11) & 0x1F
    g6 = (pixel >> 5) & 0x3F
    b5 = pixel & 0x1F
    return ((r5 << 3) | (r5 >> 2), (g6 << 2) | (g6 >> 4), (b5 << 3) | (b5 >> 2))


def _write_png(path: Path, pixels: list[int], width: int, height: int, byte_swap: bool) -> None:
    expected = width * height
    padded = pixels[:expected] + [0] * max(0, expected - len(pixels))

    raw = bytearray()
    for y in range(height):
        raw.append(0)
        row = padded[y * width : (y + 1) * width]
        for p in row:
            if byte_swap:
                p = ((p & 0xFF) << 8) | ((p >> 8) & 0xFF)
            raw.extend(_rgb565_to_rgb888(p))

    def chunk(kind: bytes, data: bytes) -> bytes:
        return (
            struct.pack(">I", len(data))
            + kind
            + data
            + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)
        )

    png = bytearray(b"\x89PNG\r\n\x1a\n")
    png.extend(chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)))
    png.extend(chunk(b"IDAT", zlib.compress(bytes(raw), level=9)))
    png.extend(chunk(b"IEND", b""))
    path.write_bytes(png)


def main() -> int:
    parser = argparse.ArgumentParser(description="Convert SignalTap RGB565 CSV to PNG.")
    parser.add_argument("csv", nargs="?", default="project/output_files/raw_rgb.csv", help="SignalTap CSV path")
    parser.add_argument("-o", "--output", default=None, help="Output PNG path")
    parser.add_argument("--width", type=int, default=DEFAULT_WIDTH)
    parser.add_argument("--height", type=int, default=DEFAULT_HEIGHT)
    parser.add_argument(
        "--assume-all-samples-valid",
        action="store_true",
        help="Use every packed fifo_wr_data sample when fifo_wr_valid is absent. This is the default.",
    )
    parser.add_argument(
        "--strict-valid",
        action="store_true",
        help="Require a fifo_wr_valid column instead of assuming packed samples are pixels.",
    )
    parser.add_argument(
        "--no-swapped",
        action="store_true",
        help="Do not also emit a byte-swapped comparison PNG.",
    )
    args = parser.parse_args()

    csv_path = Path(args.csv)
    output = Path(args.output) if args.output else csv_path.with_suffix(".png")
    frame_pixels = args.width * args.height

    header, rows = _load_signaltap_csv(csv_path)
    pixels, extract_info = _extract_pixels(
        header,
        rows,
        assume_all_samples_valid=not args.strict_valid or args.assume_all_samples_valid,
    )
    frame, frame_info = _choose_frame(pixels, extract_info["sof_positions"], frame_pixels)

    if frame_info["status"] == "partial":
        out_height = max(1, math.ceil(len(frame) / args.width))
    else:
        out_height = args.height

    _write_png(output, frame, args.width, out_height, byte_swap=False)
    swapped_output = output.with_name(output.stem + "_byteswap" + output.suffix)
    if not args.no_swapped:
        _write_png(swapped_output, frame, args.width, out_height, byte_swap=True)

    print(f"input: {csv_path}")
    print(f"rows in Data section: {len(rows)}")
    print(f"packed column: {extract_info['packed_col']}")
    print(f"valid column: {extract_info['valid_col'] or '(missing)'}")
    if extract_info["signal_counts"]:
        print("signal high counts:")
        for name, count in extract_info["signal_counts"].items():
            print(f"  {name}: {count}")
    print(f"extracted pixels: {len(pixels)}")
    if extract_info["ready_col"] is not None and extract_info["valid_col"] is not None:
        print(f"valid while not ready: {extract_info['valid_not_ready_rows']}")
    print(f"SOF positions: {extract_info['sof_positions'][:8]}")
    print(f"selected frame: {frame_info['status']} ({len(frame)} / {frame_pixels} pixels)")
    if frame_info["status"] == "partial":
        print("warning: capture does not contain a complete 320x240 frame; wrote a partial preview.")
    if extract_info["signal_counts"].get("overflow", 0):
        print("warning: overflow was high during the capture; exported pixels may be missing.")
    if extract_info["used_assume_all_samples_valid"]:
        print("warning: fifo_wr_valid was missing; assumed every packed sample is a pixel.")
    print(f"wrote: {output}")
    if not args.no_swapped:
        print(f"wrote: {swapped_output}")

    return 0
if __name__ == "__main__":
    raise SystemExit(main())
