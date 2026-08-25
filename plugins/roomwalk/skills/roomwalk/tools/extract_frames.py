#!/usr/bin/env python3
"""Видео → пронумерованные кадры + манифест. Работает на macOS, Windows и Linux.

    python3 extract_frames.py in.mp4 ./frames --count 120 --width 864 --quality 0.66

Кадры читаются подряд одним проходом, а не выборочной перемоткой. Так задумано:
перемотка отдаёт ближайший опорный кадр, и в последовательности появляются дубли —
на медленной промотке это видно как залипание. Ролики здесь короткие, 8–15 секунд,
так что сплошное чтение ничего не стоит.

ffmpeg отдельно ставить не нужно: пакет imageio-ffmpeg приносит свой бинарник.
"""

import json
import os
import sys

from _frames import fail

try:
    import imageio_ffmpeg
    import numpy as np
    from PIL import Image
except ImportError as e:
    sys.exit(
        f"не хватает библиотеки: {e.name}\n"
        "поставьте зависимости:  python3 -m pip install --user pillow numpy imageio-ffmpeg"
    )


def parse_args(argv):
    if len(argv) < 2:
        sys.exit(
            "использование: extract_frames.py <видео> <папка> "
            "[--count N] [--width PX] [--quality 0..1]\n"
            "  --count    сколько кадров вынуть (по умолчанию 120)\n"
            "  --width    ширина кадра в пикселях, высота по пропорции (по умолчанию 1280)\n"
            "  --quality  качество JPEG 0..1 (по умолчанию 0.72)"
        )
    src, out = argv[0], argv[1]
    opts = {"count": 120, "width": 1280, "quality": 0.72}
    rest = argv[2:]
    for i in range(0, len(rest) - 1, 2):
        key, value = rest[i], rest[i + 1]
        if key == "--count":
            opts["count"] = int(value)
        elif key == "--width":
            opts["width"] = int(value)
        elif key == "--quality":
            opts["quality"] = float(value)
    if opts["count"] < 2:
        fail("--count должен быть больше 1")
    if opts["width"] < 1:
        fail("--width должен быть положительным")
    return src, out, opts


def main(argv):
    src, out_dir, opts = parse_args(argv)
    if not os.path.isfile(src):
        fail(f"не найден файл {src}")
    os.makedirs(out_dir, exist_ok=True)

    reader = imageio_ffmpeg.read_frames(src)
    meta = next(reader)
    w, h = meta["size"]
    fps = meta.get("fps") or 0
    duration = meta.get("duration") or 0

    print(f"вход:   {os.path.basename(src)}")
    print(f"исходник: {w}x{h}, {duration:.2f} с, {fps:.2f} fps")

    # Сколько кадров в ролике на самом деле — узнаём по ходу чтения, а не из метаданных:
    # они врут чаще, чем хотелось бы.
    frames = list(reader)
    total = len(frames)
    if total == 0:
        fail("в видео не нашлось кадров")

    want = min(opts["count"], total)
    # Равномерно по всей длине, обязательно включая первый и последний.
    picks = [round(i * (total - 1) / (want - 1)) for i in range(want)]

    out_w = opts["width"]
    out_h = max(1, round(h * out_w / w))
    quality = max(1, min(100, round(opts["quality"] * 100)))

    written = 0
    for n, idx in enumerate(picks):
        arr = np.frombuffer(frames[idx], dtype=np.uint8).reshape(h, w, 3)
        im = Image.fromarray(arr)
        if (out_w, out_h) != (w, h):
            im = im.resize((out_w, out_h), Image.LANCZOS)
        im.save(os.path.join(out_dir, f"frame_{n:04d}.jpg"), "JPEG",
                quality=quality, optimize=True)
        written += 1

    manifest = {
        "frames": written,
        "pattern": "frame_%04d.jpg",
        "width": out_w,
        "height": out_h,
        "source": os.path.basename(src),
        "source_fps": fps,
        "source_duration": duration,
    }
    with open(os.path.join(out_dir, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=1, ensure_ascii=False)

    weight = sum(
        os.path.getsize(os.path.join(out_dir, n))
        for n in os.listdir(out_dir) if n.endswith(".jpg")
    ) / 1048576
    print(f"выход:  {written} кадров {out_w}x{out_h} -> {os.path.abspath(out_dir)}")
    print(f"записано {written}, общий вес {weight:.1f} МБ")


if __name__ == "__main__":
    main(sys.argv[1:])
