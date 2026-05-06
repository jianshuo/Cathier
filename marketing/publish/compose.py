"""Overlay Chinese serif title onto a base image (Pillow).

Font lookup tries common locations on macOS and Linux, plus a glob fallback
under /usr/share/fonts/ to handle Ubuntu's Noto package layout variations.
"""

from pathlib import Path
from typing import Literal

from PIL import Image, ImageDraw, ImageFont

ACCENT = (242, 112, 10)  # Cathier orange #F2700A
TEXT_PRIMARY = (26, 22, 19)  # near-black warm

TitlePosition = Literal["center", "top", "bottom"]

FONT_CANDIDATES = [
    "/System/Library/Fonts/STSong.ttc",
    "/System/Library/Fonts/Supplemental/Songti.ttc",
    "/usr/share/fonts/opentype/noto/NotoSerifCJK-Regular.ttc",
    "/usr/share/fonts/truetype/noto/NotoSerifCJK-Regular.ttc",
]

FONT_GLOB_DIRS = [
    "/usr/share/fonts/opentype/noto",
    "/usr/share/fonts/truetype/noto",
    "/usr/share/fonts/opentype/noto-cjk",
    "/usr/share/fonts/noto-cjk",
]


def _find_font() -> str:
    for p in FONT_CANDIDATES:
        if Path(p).exists():
            return p
    for dir_path in FONT_GLOB_DIRS:
        d = Path(dir_path)
        if not d.exists():
            continue
        for pattern in ("NotoSerifCJK*Regular*", "NotoSerifCJK*VF*", "NotoSerifCJK*"):
            matches = sorted(d.glob(pattern))
            if matches:
                return str(matches[0])
    raise FileNotFoundError(
        "No Chinese serif font found. "
        "Install `fonts-noto-cjk fonts-noto-cjk-extra` (Linux) or "
        "Songti (macOS, system default)."
    )


def compose(
    background_path: Path,
    title: str,
    output_path: Path,
    title_position: TitlePosition = "center",
) -> Path:
    if not title:
        raise ValueError("title must be non-empty")
    if not Path(background_path).exists():
        raise FileNotFoundError(f"Background not found: {background_path}")

    img = Image.open(background_path).convert("RGB")
    draw = ImageDraw.Draw(img)

    font_path = _find_font()
    font_size = int(img.height * 0.08)  # 8% of image height
    font = ImageFont.truetype(font_path, font_size)

    bbox = draw.textbbox((0, 0), title, font=font)
    text_w = bbox[2] - bbox[0]
    text_h = bbox[3] - bbox[1]
    x = (img.width - text_w) // 2

    if title_position == "top":
        y = int(img.height * 0.12)
    elif title_position == "bottom":
        y = img.height - text_h - int(img.height * 0.12)
    else:
        y = (img.height - text_h) // 2

    draw.text((x, y), title, font=font, fill=TEXT_PRIMARY)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    img.save(output_path)
    return output_path
