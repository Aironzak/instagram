#!/usr/bin/env python3
"""Покадровое мерцание и расстояние между первым и последним кадром.

    python3 measure_flicker.py ./frames

Скачки яркости между соседними кадрами не видны на 24–30 fps, но именно они
читаются как мерцание при медленной промотке скроллом. Последняя строка — стык
лупа: насколько последний кадр далёк от первого, если проход зациклен.
"""

import sys

import numpy as np

from _frames import frame_files, gray_thumb, rms


def main(argv):
    if not argv:
        sys.exit("использование: measure_flicker.py <папка с кадрами>")

    files = frame_files(argv[0])
    thumbs = [gray_thumb(f) for f in files]
    means = [float(t.mean()) for t in thumbs]

    deltas = [abs(means[i] - means[i - 1]) for i in range(1, len(means))]
    if not deltas:
        sys.exit("нужно хотя бы два кадра")

    mean_delta = float(np.mean(deltas))
    max_delta = float(np.max(deltas))
    sd_delta = float(np.std(deltas))
    loop_gap = rms(thumbs[0], thumbs[-1])

    print(f"кадров: {len(files)}")
    print(f"яркость: мин {min(means):.2f}, макс {max(means):.2f}, "
          f"средняя {np.mean(means):.2f}")
    print("")
    print("МЕРЦАНИЕ (скачок яркости между соседними кадрами, 0..255)")
    print(f"  средний    {mean_delta:.3f}")
    print(f"  максимум   {max_delta:.3f}")
    print(f"  разброс    {sd_delta:.3f}")
    print("")
    print("СТЫК ЛУПА (RMS-разница картинок, 0..255)")
    print(f"  первый|последний  {loop_gap:.2f}")
    typical = float(np.median(deltas)) if deltas else 0.0
    if typical > 0:
        print(f"  относительно обычной смены кадра: {loop_gap / max(typical, 1e-6):.1f}×")
    print("")
    if mean_delta < 0.5:
        print("Мерцания нет.")
    elif mean_delta < 1.5:
        print("Лёгкое мерцание — на промотке может быть заметно.")
    else:
        print("Заметное мерцание — стоит прогнать video_deflicker до нарезки.")


if __name__ == "__main__":
    main(sys.argv[1:])
