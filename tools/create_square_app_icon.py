#!/usr/bin/env python3
"""
Create a square launcher-icon source from the wide 3elty image.

Input:
  assets/icon/3elty.jpeg

Output:
  assets/icon/app_icon.png

Why this exists:
  The provided image is 1247×672, so it is not square. Android launcher icons
  need a square source. This script preserves the image aspect ratio, centers it
  on a soft background, and adds safe padding instead of stretching it.
"""

from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageOps

PROJECT_ROOT = Path(__file__).resolve().parents[1]
SOURCE = PROJECT_ROOT / "assets" / "icon" / "3elty.jpeg"
OUTPUT = PROJECT_ROOT / "assets" / "icon" / "app_icon.png"

CANVAS_SIZE = 1024
SAFE_AREA = 760
BACKGROUND = (224, 242, 241, 255)  # #E0F2F1, matching the app soft teal background


def main() -> None:
    if not SOURCE.exists():
        raise FileNotFoundError(
            f"Missing source image: {SOURCE}\n"
            "Place your image at assets/icon/3elty.jpeg, then run this script again."
        )

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)

    image = Image.open(SOURCE).convert("RGBA")
    image = ImageOps.contain(image, (SAFE_AREA, SAFE_AREA), method=Image.Resampling.LANCZOS)

    canvas = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), BACKGROUND)
    x = (CANVAS_SIZE - image.width) // 2
    y = (CANVAS_SIZE - image.height) // 2
    canvas.alpha_composite(image, (x, y))

    canvas.save(OUTPUT)
    print(f"Created {OUTPUT.relative_to(PROJECT_ROOT)} from {SOURCE.relative_to(PROJECT_ROOT)}")


if __name__ == "__main__":
    main()
