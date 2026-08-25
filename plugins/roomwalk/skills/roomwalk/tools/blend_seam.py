#!/usr/bin/env python3
"""Смягчает мягкий стык, не тратя кредитов на пересъёмку.

    python3 blend_seam.py ./frames 240 20

Вес чужого кадра растёт к стыку и спадает от него, максимум 0.5 в самом стыке.
Потолок примерно 2.5×: порванный стык этим не спасти, только слегка заметный.
"""

import os
import sys

import numpy as np

from _frames import fail, load_rgb, save_rgb


def main(argv):
    if len(argv) < 3:
        sys.exit("использование: blend_seam.py <папка> <кадр стыка> <ширина зоны>")
    directory, seam, span = argv[0], int(argv[1]), int(argv[2])
    if span <= 0:
        fail("ширина зоны должна быть больше нуля")

    def path(i):
        return os.path.join(directory, f"frame_{i:04d}.jpg")

    if not (os.path.isfile(path(seam - 1)) and os.path.isfile(path(seam))):
        fail(f"не читаются кадры вокруг стыка {seam}")

    before = load_rgb(path(seam - 1)).astype(np.float64)
    after = load_rgb(path(seam)).astype(np.float64)

    written = 0
    for k in range(-span, span):
        idx = seam + k
        if not os.path.isfile(path(idx)):
            continue
        base = load_rgb(path(idx)).astype(np.float64)
        t = (k + span) / (2 * span)          # 0…1 через зону
        alpha = t * 0.5 if k < 0 else (1 - t) * 0.5
        other = after if k < 0 else before
        if other.shape != base.shape:
            continue
        save_rgb(path(idx), np.clip(base * (1 - alpha) + other * alpha, 0, 255))
        written += 1

    print(f"смешано кадров: {written} вокруг стыка {seam}")


if __name__ == "__main__":
    main(sys.argv[1:])
