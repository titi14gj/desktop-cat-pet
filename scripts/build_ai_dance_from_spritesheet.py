from pathlib import Path

from PIL import Image, ImageChops, ImageFilter, ImageOps


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets"
ANIMATIONS = ASSETS / "animations"
SHEETS = {
    "ai_cat_dance": ASSETS / "ai_cat_dance_spritesheet.png",
    "realistic_slow_dance": ASSETS / "spritesheets" / "realistic_slow_dance.png",
}
KEY = (0, 255, 0)


def remove_green(frame: Image.Image) -> Image.Image:
    rgba = frame.convert("RGBA")
    r, g, b, _a = rgba.split()
    greenish = ImageChops.subtract(g, ImageChops.lighter(r, b)).point(lambda p: 255 if p > 42 else 0)
    bright_green = g.point(lambda p: 255 if p > 135 else 0)
    mask = ImageChops.multiply(greenish, bright_green).filter(ImageFilter.GaussianBlur(1.2))
    alpha = ImageOps.invert(mask).point(lambda p: 0 if p < 36 else 255 if p > 210 else p)
    rgba.putalpha(alpha)
    bbox = rgba.getbbox()
    if bbox:
        rgba = rgba.crop(bbox)
    return rgba


def fit_frame(frame: Image.Image, size: int = 512) -> Image.Image:
    frame.thumbnail((size - 52, size - 52), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    x = (size - frame.width) // 2
    y = size - frame.height - 22
    canvas.alpha_composite(frame, (x, y))
    return canvas


def pixels(image: Image.Image):
    getter = getattr(image, "get_flattened_data", image.getdata)
    return list(getter())


def save_transparent_gif(frames, out_gif: Path):
    # Tkinter's GIF reader handles binary transparency reliably when all empty
    # pixels are mapped to a single palette index.
    gif_frames = []
    for rgba in frames:
        bg = Image.new("RGBA", rgba.size, (255, 0, 255, 255))
        bg.alpha_composite(rgba)
        paletted = bg.convert("P", palette=Image.Palette.ADAPTIVE, colors=255)
        palette = paletted.getpalette()
        paletted.putpalette([255, 0, 255] + palette[3:])
        data = pixels(paletted)
        alpha = pixels(rgba.getchannel("A"))
        data = [0 if a < 20 else value for value, a in zip(data, alpha)]
        paletted.putdata(data)
        gif_frames.append(paletted)
    gif_frames[0].save(
        out_gif,
        save_all=True,
        append_images=gif_frames[1:],
        duration=85,
        loop=0,
        transparency=0,
        disposal=2,
    )


def main():
    ASSETS.mkdir(exist_ok=True)
    ANIMATIONS.mkdir(exist_ok=True)

    for animation_id, sheet_path in SHEETS.items():
        if not sheet_path.exists():
            continue
        out_dir = ANIMATIONS / animation_id
        frames_dir = out_dir / "frames"
        frames_dir.mkdir(parents=True, exist_ok=True)

        sheet = Image.open(sheet_path).convert("RGBA")
        cell_w = sheet.width // 4
        cell_h = sheet.height // 4
        frames = []
        for row in range(4):
            for col in range(4):
                cell = sheet.crop((col * cell_w, row * cell_h, (col + 1) * cell_w, (row + 1) * cell_h))
                frame = fit_frame(remove_green(cell))
                frames.append(frame)
                frame.save(frames_dir / f"frame_{row * 4 + col + 1:02d}.png")

        loop_frames = frames + [frames[0]]
        save_transparent_gif(loop_frames, out_dir / "animation.gif")
        loop_frames[0].save(
            out_dir / "animation.webp",
            save_all=True,
            append_images=loop_frames[1:],
            duration=150 if animation_id == "realistic_slow_dance" else 110,
            loop=0,
            lossless=True,
        )

    # Backward-compatible files used by the older Python prototype.
    realistic = ANIMATIONS / "realistic_slow_dance" / "animation.gif"
    if realistic.exists():
        (ASSETS / "cat.gif").write_bytes(realistic.read_bytes())


if __name__ == "__main__":
    main()
