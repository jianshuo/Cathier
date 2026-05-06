"""Overlay Chinese serif title onto a base image (Pillow).

Font lookup tries common locations on macOS and Linux. Raises clearly if not found.
"""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ACCENT = (242, 112, 10)  # Cathier orange #F2700A
TEXT_PRIMARY = (26, 22, 19)  # near-black warm

FONT_CANDIDATES = [
    "/System/Library/Fonts/STSong.ttc",  # macOS Chinese serif fallback
    "/System/Library/Fonts/Supplemental/Songti.ttc",  # macOS
    "/usr/share/fonts/opentype/noto/NotoSerifCJK-Regular.ttc",  # Ubuntu
    "/usr/share/fonts/truetype/noto/NotoSerifCJK-Regular.ttc",  # Ubuntu alt
]


def _find_font() -> str:
    for p in FONT_CANDIDATES:
        if Path(p).exists():
            return p
    raise FileNotFoundError(
        "No Chinese serif font found. "
        "Install `fonts-noto-cjk-extra` (Linux) or "
        "Songti (macOS, system default)."
    )


def compose(
    background_path: Path,
    title: str,
    output_path: Path,
) -> Path:
    if not title:
        raise ValueError("title must be non-empty")
    if not Path(background_path).exists():
        raise FileNotFoundError(f"Background not found: {background_path}")

    img = Image.open(background_path).convert("RGB")
    draw = ImageDraw.Draw(img)

    font_path = _find_font()
    # Title size: 12% of image height
    font_size = int(img.height * 0.08)
    font = ImageFont.truetype(font_path, font_size)

    # Center horizontally, vertical band at 50% (visual center of attention).
    bbox = draw.textbbox((0, 0), title, font=font)
    text_w = bbox[2] - bbox[0]
    text_h = bbox[3] - bbox[1]
    x = (img.width - text_w) // 2
    y = (img.height - text_h) // 2

    draw.text((x, y), title, font=font, fill=TEXT_PRIMARY)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    img.save(output_path)
    return output_path
