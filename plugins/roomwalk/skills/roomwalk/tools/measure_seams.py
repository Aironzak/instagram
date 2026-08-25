#!/usr/bin/env python3
"""Насколько заметен каждый стык — в числах, а не на глаз.

    python3 measure_seams.py ./frames 120
    python3 measure_seams.py ./frames --seams 240,360

Разрыв на стыке сравнивается с обычной сменой кадра ВНУТРИ дублей. Читать так:
меньше 2× — незаметен, 2–5× — слегка виден, больше 5× — рвётся.

Вариант с --seams нужен, когда дубли разной длины: 15-секундный и два по 8
не делятся на равные куски, а именно так и получается на живой сборке.
"""

import sys

from _frames import fail, frame_files, gray_thumb, median, rms


def main(argv):
    if not argv:
        sys.exit(
            "использование: measure_seams.py <папка> <кадров в сегменте>\n"
            "               measure_seams.py <папка> --seams 240,360"
        )
    directory = argv[0]
    seg = 0
    seams = []
    if len(argv) > 2 and argv[1] == "--seams":
        seams = [int(x) for x in argv[2].split(",") if x.strip()]
    elif len(argv) > 1 and argv[1] == "--seams":
        fail("--seams нужен список, например --seams 240,360")
    elif len(argv) > 1:
        seg = int(argv[1])

    files = frame_files(directory)
    if not seams:
        if seg <= 0 or seg >= len(files):
            fail("кадров меньше, чем длина сегмента")
        seams = list(range(seg, len(files), seg))

    seams = [s for s in seams if 0 < s < len(files)]
    if not seams:
        fail("стыки не попадают внутрь последовательности")

    print(f"кадров {len(files)}, дублей {len(seams) + 1}\n")

    thumbs = [gray_thumb(f) for f in files]

    # Норма — соседние кадры внутри дублей; сами стыки в неё не входят.
    seam_set = set(seams)
    inside = [rms(thumbs[i - 1], thumbs[i])
              for i in range(1, len(thumbs)) if i not in seam_set]
    if not inside:
        fail("не из чего считать норму")
    med = median(inside)

    print(f"типичная смена кадра внутри дубля: {med:.2f}\n")
    print(f"{'стык':<12}{'разрыв':<10}отношение")

    worst = 0.0
    for k in seams:
        gap = rms(thumbs[k - 1], thumbs[k])
        ratio = gap / med if med > 0 else float("nan")
        worst = max(worst, ratio)
        mark = "незаметен" if ratio < 2 else ("слегка виден" if ratio < 5 else "рвётся")
        print(f"{f'{k - 1}|{k}':<12}{f'{gap:.2f}':<10}{ratio:.2f}×  {mark}")

    print(f"\nхудший стык: {worst:.2f}×")
    if worst < 2:
        print("Все стыки в пределах обычной смены кадра.")
    elif worst < 5:
        print("Есть заметные стыки — стоит перегенерить именно их.")
    else:
        print("Стыки рвутся: дубли не сходятся по композиции.")


if __name__ == "__main__":
    main(sys.argv[1:])
