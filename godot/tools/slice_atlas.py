#!/usr/bin/env python3
"""Slice the basic spell VFX atlas into assets/vfx/{spell}/{state}_0.png.

Layout (3 rows × 4 cols) — image.png only:
  row 0 fire      — hold, charge, projectile, impact
  row 1 frost     — hold, charge, projectile, impact
  row 2 lightning — hold, charge, projectile, impact (kept for future; unused in play)

Ultimates (blizzard / fire rain) reuse basic projectile art in code —
no dedicated ultimate atlas.

Usage:
  python3 godot/tools/slice_atlas.py
  python3 godot/tools/slice_atlas.py --pad 512 --inset 6
"""

from __future__ import annotations

import argparse
import shutil
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]  # godot/
ASSETS = ROOT / "assets"
VFX = ASSETS / "vfx"

BASIC_ATLAS = ASSETS / "image.png"

BASIC_ROWS = [
    ("fire", ["hold", "charge", "projectile", "impact"]),
    ("frost", ["hold", "charge", "projectile", "impact"]),
    ("lightning", ["hold", "charge", "projectile", "impact"]),
]


def slice_grid(
    img: Image.Image,
    rows: int = 3,
    cols: int = 4,
    inset: int = 0,
) -> list[list[Image.Image]]:
    """Even 3×4 grid; remainder pixels go to the last row/col."""
    w, h = img.size
    cells: list[list[Image.Image]] = []
    y0 = 0
    for r in range(rows):
        y1 = h if r == rows - 1 else (r + 1) * (h // rows)
        row_cells: list[Image.Image] = []
        x0 = 0
        for c in range(cols):
            x1 = w if c == cols - 1 else (c + 1) * (w // cols)
            l = x0 + inset
            t = y0 + inset
            ri = x1 - inset
            b = y1 - inset
            if ri <= l or b <= t:
                l, t, ri, b = x0, y0, x1, y1
            row_cells.append(img.crop((l, t, ri, b)))
            x0 = x1
        cells.append(row_cells)
        y0 = y1
    return cells


def pad_to_square(cell: Image.Image, size: int | None) -> Image.Image:
    if size is None or size <= 0:
        return cell
    cell = cell.convert("RGBA")
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    cw, ch = cell.size
    scale = min(size / cw, size / ch)
    nw, nh = max(1, int(cw * scale)), max(1, int(ch * scale))
    resized = cell.resize((nw, nh), Image.Resampling.LANCZOS)
    out.paste(resized, ((size - nw) // 2, (size - nh) // 2), resized)
    return out


def write_row(
    row_cells: list[Image.Image],
    spell: str,
    states: list[str],
    pad: int | None,
) -> None:
    out_dir = VFX / spell
    out_dir.mkdir(parents=True, exist_ok=True)
    for cell, state in zip(row_cells, states):
        frame = pad_to_square(cell.convert("RGBA"), pad)
        dest = out_dir / f"{state}_0.png"
        frame.save(dest, "PNG")
        print(f"  {dest.relative_to(ROOT)}  {frame.size[0]}×{frame.size[1]}")


def slice_atlas(
    atlas_path: Path,
    layout: list[tuple[str, list[str]]],
    pad: int | None,
    inset: int = 0,
) -> None:
    if not atlas_path.is_file():
        raise FileNotFoundError(atlas_path)
    img = Image.open(atlas_path).convert("RGBA")
    print(f"\n{atlas_path.name}  {img.size[0]}×{img.size[1]}  inset={inset}")
    grid = slice_grid(img, inset=inset)
    for r, (spell, states) in enumerate(layout):
        write_row(grid[r], spell, states, pad)


def sync_reference_copies() -> None:
    pairs = [
        (BASIC_ATLAS, ASSETS / "atlas_basic_3x4.png"),
        (BASIC_ATLAS, VFX / "spell_atlas_basic.png"),
        (BASIC_ATLAS, VFX / "spell_atlas.png"),
    ]
    for src, dst in pairs:
        if src.is_file():
            shutil.copy2(src, dst)
            print(f"  copy {src.name} → {dst.relative_to(ROOT)}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--pad",
        type=int,
        default=512,
        help="Pad/scale each cell into a square PNG (0 = raw cell size). Default 512.",
    )
    parser.add_argument(
        "--inset",
        type=int,
        default=4,
        help="Shrink each cell by N px on all sides to reduce neighbor bleed. Default 4.",
    )
    parser.add_argument(
        "--no-sync-atlases",
        action="store_true",
        help="Do not refresh atlas_basic / spell_atlas_* copies.",
    )
    args = parser.parse_args()
    pad = None if args.pad <= 0 else args.pad

    slice_atlas(BASIC_ATLAS, BASIC_ROWS, pad, inset=args.inset)

    if not args.no_sync_atlases:
        print("\nSync atlas reference copies:")
        sync_reference_copies()

    print("\nDone. Restart the Godot scene to pick up new PNG frames.")


if __name__ == "__main__":
    main()
