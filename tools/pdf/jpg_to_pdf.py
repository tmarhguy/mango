#!/usr/bin/env python3
"""Convert images to a single PDF."""

import argparse
import glob
import os
import sys

import fitz  # pymupdf

IMAGE_EXTS = (".jpg", ".jpeg", ".png", ".webp")


def _is_image(path: str) -> bool:
    return os.path.splitext(path)[1].lower() in IMAGE_EXTS


def collect_inputs(paths: list[str]) -> list[str]:
    files: list[str] = []
    seen: set[str] = set()

    def add(path: str) -> None:
        real = os.path.abspath(path)
        if real not in seen:
            seen.add(real)
            files.append(real)

    for path in paths:
        if os.path.isdir(path):
            found: list[str] = []
            for ext in IMAGE_EXTS:
                found.extend(glob.glob(os.path.join(path, f"*{ext}")))
                found.extend(glob.glob(os.path.join(path, f"*{ext.upper()}")))
            for item in sorted(found, key=lambda p: os.path.basename(p).lower()):
                if os.path.isfile(item) and _is_image(item):
                    add(item)
        elif "*" in path or "?" in path:
            for item in sorted(glob.glob(path)):
                if os.path.isfile(item) and _is_image(item):
                    add(item)
        elif os.path.isfile(path):
            add(path)
    return files


def main() -> int:
    parser = argparse.ArgumentParser(description="Convert images to PDF.")
    parser.add_argument("inputs", nargs="+", help="Image files, a folder, or globs")
    parser.add_argument("-o", "--output", required=True, help="Output PDF path")
    args = parser.parse_args()

    files = collect_inputs(args.inputs)
    if not files:
        print("Error: no images found.", file=sys.stderr)
        return 1

    os.makedirs(os.path.dirname(os.path.abspath(args.output)) or ".", exist_ok=True)
    doc = fitz.open()
    for path in files:
        img = fitz.open(path)
        rect = img[0].rect
        page = doc.new_page(width=rect.width, height=rect.height)
        page.insert_image(rect, filename=path)
        img.close()
    doc.save(args.output)
    doc.close()

    print(f"Saved {len(files)} page(s) → {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
