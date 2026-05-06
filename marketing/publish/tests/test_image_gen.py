import base64
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

from marketing.publish.image_gen import generate_image


@pytest.fixture
def fake_b64_png():
    """A 1x1 transparent PNG, base64-encoded — enough for the API mock."""
    return (
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAA"
        "DUlEQVR42mNkYGD4DwABBAEAfbLI3wAAAABJRU5ErkJggg=="
    )


def test_generate_image_calls_openai_with_correct_args(tmp_path, fake_b64_png):
    output_path = tmp_path / "out.png"

    mock_response = MagicMock()
    mock_response.data = [MagicMock(b64_json=fake_b64_png)]

    with patch("marketing.publish.image_gen.OpenAI") as mock_openai:
        mock_client = MagicMock()
        mock_client.images.generate.return_value = mock_response
        mock_openai.return_value = mock_client

        result = generate_image(
            prompt="warm paper background, single ceramic cup",
            size="1024x1536",
            output_path=output_path,
            api_key="sk-test",
        )

        mock_openai.assert_called_once_with(api_key="sk-test")
        mock_client.images.generate.assert_called_once_with(
            model="gpt-image-1",
            prompt="warm paper background, single ceramic cup",
            size="1024x1536",
            n=1,
        )
        assert result == output_path
        assert output_path.exists()
        assert output_path.read_bytes() == base64.b64decode(fake_b64_png)


def test_generate_image_raises_on_empty_prompt(tmp_path):
    with pytest.raises(ValueError, match="prompt"):
        generate_image(
            prompt="",
            size="1024x1024",
            output_path=tmp_path / "x.png",
            api_key="sk-test",
        )
