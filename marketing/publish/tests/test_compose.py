from pathlib import Path

import pytest
from PIL import Image

from marketing.publish.compose import compose

FIXTURE = Path(__file__).parent / "fixtures" / "sample_bg.png"


def test_compose_outputs_file_with_correct_size(tmp_path):
    output = tmp_path / "out.png"
    result = compose(
        background_path=FIXTURE,
        title="觉察练习",
        output_path=output,
    )
    assert result == output
    assert output.exists()
    img = Image.open(output)
    assert img.size == (256, 384)


def test_compose_actually_draws_text(tmp_path):
    """Verify the title region pixels differ from the background after compose."""
    output = tmp_path / "out.png"
    compose(
        background_path=FIXTURE,
        title="觉察练习",
        output_path=output,
    )

    bg = Image.open(FIXTURE).convert("RGB")
    out = Image.open(output).convert("RGB")

    # Sample 100 pixels in the title region (roughly center horizontal band).
    title_band_top = int(384 * 0.40)
    title_band_bot = int(384 * 0.60)
    diff_count = 0
    for y in range(title_band_top, title_band_bot, 4):
        for x in range(0, 256, 4):
            if bg.getpixel((x, y)) != out.getpixel((x, y)):
                diff_count += 1
    assert diff_count > 20, "Title text not drawn into title band"


def test_compose_raises_on_missing_background(tmp_path):
    with pytest.raises(FileNotFoundError):
        compose(
            background_path=tmp_path / "does-not-exist.png",
            title="x",
            output_path=tmp_path / "out.png",
        )


def test_compose_raises_on_empty_title(tmp_path):
    with pytest.raises(ValueError, match="title"):
        compose(
            background_path=FIXTURE,
            title="",
            output_path=tmp_path / "out.png",
        )
