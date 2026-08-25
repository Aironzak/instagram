#!/usr/bin/env python3
"""Подтягивает все кадры к общей яркости, перезаписывая их на месте.

    python3 stabilise_exposure.py ./frames [мин 0.75] [макс 1.35]

Коэффициент ограничен сверху и снизу: места, которые темнее по существу —
нутро шкафа, тень под столешницей — остаются тёмными, а не вытягиваются в кашу.
Сколько кадров упёрлось в ограничитель, печатается в конце: это не ошибка,
это те кадры, где свет другой намеренно.
"""

import sys

import numpy as np

from _frames import LUMA, frame_files, load_rgb, median, save_rgb


def main(argv):
    if not argv:
        sys.exit("использование: stabilise_exposure.py <папка> [мин 0.75] [макс 1.35]")
    directory = argv[0]
    gain_min = float(argv[1]) if len(argv) > 1 else 0.75
    gain_max = float(argv[2]) if len(argv) > 2 else 1.35

    files = frame_files(directory)
    print(f"читаю {len(files)} кадров…")

    # Первый проход — средняя яркость каждого кадра по полному размеру.
    means = []
    for path in files:
        a = load_rgb(path).astype(np.float64)
        means.append(float(
            a[..., 0].mean() * LUMA[0]
            + a[..., 1].mean() * LUMA[1]
            + a[..., 2].mean() * LUMA[2]
        ))

    target = median(means)
    print(f"цель: {target:.1f}  (было {min(means):.1f}…{max(means):.1f})")

    # Второй проход — применяем коэффициент через таблицу на 256 значений.
    clamped = 0
    for path, mean in zip(files, means):
        gain = target / max(mean, 1.0)
        if gain < gain_min:
            gain, hit = gain_min, True
        elif gain > gain_max:
            gain, hit = gain_max, True
        else:
            hit = False
        if hit:
            clamped += 1
        if abs(gain - 1) < 0.004:
            continue
        lut = np.clip(np.rint(np.arange(256) * gain), 0, 255).astype(np.uint8)
        save_rgb(path, lut[load_rgb(path)])

    print(f"готово. кадров с упёршимся коэффициентом: {clamped} — там свет намеренно другой")


if __name__ == "__main__":
    main(sys.argv[1:])
