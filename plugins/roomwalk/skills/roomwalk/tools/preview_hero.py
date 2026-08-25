#!/usr/bin/env python3
"""Собирает то, что зритель видит в герое: кадр + затемняющие градиенты + подпись.

    python3 preview_hero.py frames/frame_0180.jpg out.png "Столы" "на заказ по размеру"

Нужен потому, что скриншоты встроенной панели браузера приходят затемнёнными
и по ним нельзя судить о реальном виде страницы.
"""

import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

from _frames import fail

# Шрифт ищем по системе: на каждой ОС он лежит своим путём, а тащить файл
# в репозиторий ради превью не стоит.
FONT_CANDIDATES = [
    # Сначала те, что покрывают и кириллицу, и знаки валют: подпись на странице
    # почти всегда «от 320 ₽», а Georgia и Times рубль не знают и рисуют квадрат.
    # NewYork здесь нет намеренно: это вариативный шрифт, Pillow берёт из него
    # не тот глиф на ₽ и путает ширины пробелов.
    "/System/Library/Fonts/SFNS.ttf",
    "/System/Library/Fonts/HelveticaNeue.ttc",
    "C:/Windows/Fonts/segoeui.ttf",
    "C:/Windows/Fonts/arial.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    "/usr/share/fonts/truetype/liberation/LiberationSerif-Regular.ttf",
    "/usr/share/fonts/truetype/noto/NotoSerif-Regular.ttf",
    # запасные: красивые, но покрытие уже, берутся только если ничего выше нет
    "/System/Library/Fonts/Supplemental/Georgia.ttf",
    "/System/Library/Fonts/Supplemental/Times New Roman.ttf",
    "/Library/Fonts/Arial.ttf",
]


# Подписи бывают с рублём, лари и кириллицей сразу, а Georgia на маке рубль
# не покрывает и рисует пустой квадрат. AppKit подставлял шрифт сам, Pillow —
# нет, поэтому покрытие проверяем руками: рисуем символ и сравниваем с заведомо
# отсутствующим глифом. Совпало — значит это тот самый квадрат, берём следующий.
PROBE = "\uE000"  # приватная область: глифа нет ни в одном нормальном шрифте


def _covers(font, text):
    try:
        blank = bytes(font.getmask(PROBE))
        for ch in text:
            if ch.isspace():
                continue
            if bytes(font.getmask(ch)) == blank:
                return False
    except Exception:
        return True
    return True


def load_font(size, text=""):
    fallback = None
    for path in FONT_CANDIDATES:
        if not os.path.isfile(path):
            continue
        try:
            font = ImageFont.truetype(path, size)
        except OSError:
            continue
        if fallback is None:
            fallback = font
        if not text or _covers(font, text):
            return font
    return fallback or ImageFont.load_default()


def main(argv):
    if len(argv) < 2:
        sys.exit('использование: preview_hero.py <кадр> <выход.png> ["подпись"] ["пояснение"]')
    src, out = argv[0], argv[1]
    caption = argv[2] if len(argv) > 2 else ""
    note = argv[3] if len(argv) > 3 else ""

    if not os.path.isfile(src):
        fail(f"не найден кадр {src}")

    with Image.open(src) as im:
        base = im.convert("RGB")
    W, H = base.size
    a = np.asarray(base, dtype=np.float64)

    # Те же три градиента, что и на странице: снизу, слева и виньетка.
    ys = np.linspace(0, 1, H)[:, None]
    xs = np.linspace(0, 1, W)[None, :]

    up = np.clip((ys - 0.48) / 0.52, 0, 1) ** 1.2 * 0.86          # снизу вверх
    left = np.clip((0.46 - xs) / 0.46, 0, 1) * 0.62               # слева направо
    dy, dx = (ys - 0.44) / 0.82, (xs - 0.5) / 1.2
    vignette = np.clip(np.sqrt(dy * dy + dx * dx) - 0.42, 0, 1) * 0.5

    shade = np.clip(up + left + vignette, 0, 0.92)
    ground = np.array([13, 10, 9], dtype=np.float64)
    a = a * (1 - shade[..., None]) + ground * shade[..., None]

    canvas = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))
    draw = ImageDraw.Draw(canvas)

    pad = max(20, int(W * 0.043))
    if caption:
        f_title = load_font(max(22, int(W * 0.046)), caption)
        f_note = load_font(max(12, int(W * 0.0115)), note)
        y = H - pad
        if note:
            box = draw.textbbox((0, 0), note, font=f_note)
            y -= box[3] - box[1]
            draw.text((pad, y), note, font=f_note, fill=(201, 191, 178))
            y -= int(W * 0.014)
        box = draw.textbbox((0, 0), caption, font=f_title)
        y -= box[3] - box[1]
        draw.text((pad, y), caption, font=f_title, fill=(242, 236, 228))

    canvas.save(out, "PNG")
    print(f"готово: {os.path.abspath(out)}")


if __name__ == "__main__":
    main(sys.argv[1:])
