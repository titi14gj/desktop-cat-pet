import math
import os
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets"
SOURCE_1 = Path("/Users/titi14gj/Desktop/1.jpg")
SOURCE_2 = Path("/Users/titi14gj/Desktop/2.jpg")
KEY = (255, 0, 255)


def make_subject(source_path: Path) -> Image.Image:
    image = Image.open(source_path).convert("RGBA")
    # This crop keeps the cat, paws, and tail while removing most room clutter.
    crop_box = (235, 55, 1085, 1675)
    cropped = image.crop(crop_box)

    width, height = cropped.size
    mask = Image.new("L", (width, height), 0)
    draw = ImageDraw.Draw(mask)

    # Soft hand-built silhouette for this specific sitting pose.
    draw.ellipse((95, 360, 730, 1535), fill=255)
    draw.ellipse((120, 115, 640, 650), fill=255)
    draw.polygon([(150, 210), (210, 0), (335, 270)], fill=255)
    draw.polygon([(465, 250), (600, 0), (655, 300)], fill=255)
    draw.ellipse((190, 1290, 430, 1615), fill=255)
    draw.ellipse((390, 1280, 610, 1615), fill=255)
    draw.ellipse((540, 1290, 900, 1510), fill=255)
    draw.rounded_rectangle((300, 610, 560, 1485), radius=120, fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(9))

    # Suppress very bright wall/table pixels near the silhouette edge.
    gray = cropped.convert("L")
    dark_mask = gray.point(lambda p: 255 if p < 224 else 45)
    mask = ImageChops.multiply(mask, dark_mask.filter(ImageFilter.GaussianBlur(2)))
    mask = mask.point(lambda p: 255 if p > 70 else 0).filter(ImageFilter.GaussianBlur(1.2))

    cropped.putalpha(mask)
    bbox = cropped.getbbox()
    subject = cropped.crop(bbox)
    subject.thumbnail((520, 720), Image.Resampling.LANCZOS)
    return subject


def paste_center(base: Image.Image, subject: Image.Image, x: int, y: int) -> None:
    base.alpha_composite(subject, (x - subject.width // 2, y - subject.height))


def pixels(image: Image.Image):
    getter = getattr(image, "get_flattened_data", image.getdata)
    return list(getter())


def keyed_frame(subject: Image.Image, canvas_size: int = 640) -> Image.Image:
    return Image.new("RGBA", (canvas_size, canvas_size), (*KEY, 255))


def affine(subject: Image.Image, angle: float = 0, scale_x: float = 1, scale_y: float = 1) -> Image.Image:
    new_w = max(1, int(subject.width * scale_x))
    new_h = max(1, int(subject.height * scale_y))
    resized = subject.resize((new_w, new_h), Image.Resampling.BICUBIC)
    return resized.rotate(angle, resample=Image.Resampling.BICUBIC, expand=True)


def save_gif(frames, path: Path, duration: int = 70) -> None:
    rgb_frames = []
    for frame in frames:
        rgba = Image.new("RGBA", frame.size, (*KEY, 255))
        rgba.alpha_composite(frame)
        key_pixels = [
            pixel[:3] == KEY
            for pixel in pixels(rgba)
        ]
        paletted = rgba.convert("P", palette=Image.Palette.ADAPTIVE, colors=255)
        palette = paletted.getpalette()
        paletted.putpalette([255, 0, 255] + palette[3:])
        data = pixels(paletted)
        data = [0 if is_key else value for value, is_key in zip(data, key_pixels)]
        paletted.putdata(data)
        rgb_frames.append(paletted)

    rgb_frames[0].save(
        path,
        save_all=True,
        append_images=rgb_frames[1:],
        duration=duration,
        loop=0,
        disposal=2,
        transparency=0,
    )


def make_sway(subject: Image.Image):
    frames = []
    for i in range(32):
        t = math.sin(i / 32 * math.tau)
        frame = keyed_frame(subject)
        dancer = affine(subject, angle=t * 4.5, scale_x=1 - abs(t) * 0.015, scale_y=1 + abs(t) * 0.015)
        paste_center(frame, dancer, 320 + int(t * 18), 600)
        frames.append(frame)
    return frames


def make_bounce(subject: Image.Image):
    frames = []
    for i in range(28):
        t = math.sin(i / 28 * math.tau)
        lift = max(0, t) * 42
        squash = 1 - max(0, -t) * 0.035
        stretch = 1 + max(0, t) * 0.035
        frame = keyed_frame(subject)
        dancer = affine(subject, angle=math.sin(i / 28 * math.tau * 2) * 2, scale_x=squash, scale_y=stretch)
        paste_center(frame, dancer, 320, 600 - int(lift))
        frames.append(frame)
    return frames


def make_head_bop(subject: Image.Image):
    frames = []
    for i in range(36):
        t = math.sin(i / 36 * math.tau)
        frame = keyed_frame(subject)
        body = affine(subject, angle=t * 2.5, scale_x=1, scale_y=1)
        paste_center(frame, body, 320 + int(t * 12), 600)
        # Extra small face highlight bounce makes the still photo read as a dance loop at small sizes.
        sparkle = ImageDraw.Draw(frame)
        sparkle.ellipse((342 + int(t * 10), 132 + int(abs(t) * 8), 356 + int(t * 10), 146 + int(abs(t) * 8)), fill=(255, 255, 255, 100))
        frames.append(frame)
    return frames


def make_combined(subject: Image.Image):
    frames = []
    for i in range(48):
        t = math.sin(i / 48 * math.tau)
        t2 = math.sin(i / 48 * math.tau * 2)
        frame = keyed_frame(subject)
        dancer = affine(
            subject,
            angle=t * 5.5,
            scale_x=1 - max(0, -t2) * 0.025,
            scale_y=1 + max(0, t2) * 0.025,
        )
        paste_center(frame, dancer, 320 + int(t * 20), 600 - int(max(0, t2) * 28))
        frames.append(frame)
    return frames


def main():
    ASSETS.mkdir(parents=True, exist_ok=True)
    source = SOURCE_2 if SOURCE_2.exists() else SOURCE_1
    subject = make_subject(source)
    subject.save(ASSETS / "cat_cutout.png")

    animations = {
        "cat_sway.gif": make_sway(subject),
        "cat_bounce.gif": make_bounce(subject),
        "cat_head_bop.gif": make_head_bop(subject),
        "cat_dance_combo.gif": make_combined(subject),
    }
    for name, frames in animations.items():
        save_gif(frames, ASSETS / name)

    # The app uses assets/cat.gif as its default animation.
    save_gif(animations["cat_dance_combo.gif"], ASSETS / "cat.gif")


if __name__ == "__main__":
    main()
