"""Общее для кадровых инструментов: чтение, яркость, запись.

Раньше это делали Swift + AVFoundation + CoreGraphics — и работало только на маке.
Здесь то же самое на Pillow и NumPy, поэтому одинаково идёт на macOS, Windows и Linux.
Формулы яркости и размеры уменьшенных копий оставлены прежними, чтобы числа
совпадали с теми, что инструменты печатали раньше.
"""

import os
import sys

try:
    import numpy as np
    from PIL import Image
except ImportError as e:  # pragma: no cover
    sys.exit(
        f"не хватает библиотеки: {e.name}\n"
        "поставьте зависимости:  python3 -m pip install --user pillow numpy imageio-ffmpeg"
    )

JPEG_QUALITY = 72  # 0.72 в старой версии
LUMA = (0.299, 0.587, 0.114)


def fail(msg):
    sys.exit(f"ошибка: {msg}")


def frame_files(directory):
    """Кадры по возрастанию имени — порядок задаётся именем, а не временем файла."""
    if not os.path.isdir(directory):
        fail(f"нет папки {directory}")
    files = sorted(
        os.path.join(directory, n)
        for n in os.listdir(directory)
        if n.lower().endswith(".jpg")
    )
    if not files:
        fail("кадров не найдено")
    return files


def gray_thumb(path, side=48):
    """Уменьшенная копия в оттенках серого — достаточно, чтобы сравнить композицию.

    `side` — максимальная сторона, как у kCGImageSourceThumbnailMaxPixelSize.
    """
    with Image.open(path) as im:
        im = im.convert("RGB")
        im.thumbnail((side, side), Image.LANCZOS)
        a = np.asarray(im, dtype=np.float64)
    return a[..., 0] * LUMA[0] + a[..., 1] * LUMA[1] + a[..., 2] * LUMA[2]


def mean_luma(path, side=40):
    return float(gray_thumb(path, side).mean())


def load_rgb(path):
    with Image.open(path) as im:
        return np.asarray(im.convert("RGB"), dtype=np.uint8)


def save_rgb(path, arr, quality=JPEG_QUALITY):
    Image.fromarray(np.asarray(arr, dtype=np.uint8)).save(
        path, "JPEG", quality=quality, optimize=True
    )


def rms(a, b):
    if a.shape != b.shape:
        return float("nan")
    d = a - b
    return float(np.sqrt((d * d).mean()))


def median(values):
    """Тот же выбор элемента, что и в старой версии: sorted[n//2], а не среднее двух."""
    return sorted(values)[len(values) // 2]


def bar(value, lo, hi, width=34):
    n = int(((value - lo) / max(hi - lo, 0.001)) * width)
    return "█" * max(n, 1)
