#!/usr/bin/env python3
"""Как уезжает свет по ходу прохода — покадрово и по дублям.

    python3 brightness_curve.py ./frames 120
    python3 brightness_curve.py ./frames --seams 240,360

На скорости воспроизведения дрейф незаметен. На медленной промотке скроллом он
читается как «солнце появилось и ушло», и это первое, на что жалуется заказчик.
Сдвиг больше ±6 за дубль виден, меньше ±2 — нет.
"""

import sys

from _frames import bar, fail, frame_files, mean_luma


def main(argv):
    if not argv:
        sys.exit(
            "использование: brightness_curve.py <папка> [кадров в сегменте]\n"
            "               brightness_curve.py <папка> --seams 240,360"
        )
    directory = argv[0]
    seg = 0
    seams = []
    if len(argv) > 2 and argv[1] == "--seams":
        seams = [int(x) for x in argv[2].split(",") if x.strip()]
    elif len(argv) > 1:
        seg = int(argv[1])

    files = frame_files(directory)
    vals = [mean_luma(f) for f in files]
    lo, hi = min(vals), max(vals)

    if seg > 0 and not seams:
        seams = list(range(seg, len(vals), seg))
    seam_set = set(seams)

    print(f"кадров {len(vals)}, яркость {lo:.1f}…{hi:.1f}\n")

    # Каждый пятый — чтобы вывод читался.
    for i, v in enumerate(vals):
        if i % 5:
            continue
        mark = "  ← стык" if i in seam_set else ""
        print(f"{i:4d}  {v:6.1f}  {bar(v, lo, hi)}{mark}")

    if seams:
        print("\nпо дублям:")
        bounds = [0] + seams + [len(vals)]
        for a, b in zip(bounds, bounds[1:]):
            part = vals[a:b]
            if not part:
                continue
            drift = part[-1] - part[0]
            flag = "  ← свет уезжает" if abs(drift) > 6 else ""
            print(f"  {a:3d}–{b - 1:3d}   начало {part[0]:5.1f}  "
                  f"конец {part[-1]:5.1f}  сдвиг {drift:+5.1f}{flag}")


if __name__ == "__main__":
    main(sys.argv[1:])
