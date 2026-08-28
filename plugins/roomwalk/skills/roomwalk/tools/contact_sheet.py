# Контактный лист: все кадры в одну картинку, чтобы разбор смотреть целиком,
# а не по одному кадру за запрос.
import sys, math
from pathlib import Path
from PIL import Image, ImageDraw

src, out = Path(sys.argv[1]), sys.argv[2]
cols = int(sys.argv[3]) if len(sys.argv) > 3 else 3
files = sorted(src.glob('frame_*.jpg'))
if not files: sys.exit('кадров нет')
tw = 620
# Кадры открываем по одному и сразу закрываем. Держать их списком нельзя:
# Image.open ленив, но resize ниже заставляет PIL загрузить полный растр и
# оставить его в объекте — на 220 кадрах это замеренные 1.6 ГБ.
with Image.open(files[0]) as probe:
    th = round(tw * probe.height / probe.width)
rows = math.ceil(len(files) / cols)
sheet = Image.new('RGB', (cols * tw, rows * th), (0, 0, 0))
d = ImageDraw.Draw(sheet)
for i, f in enumerate(files):
    x, y = (i % cols) * tw, (i // cols) * th
    with Image.open(f) as im:
        sheet.paste(im.resize((tw, th), Image.LANCZOS), (x, y))
    d.text((x + 10, y + 8), f'{i}  {f.stem}', fill=(255, 190, 90))
sheet.save(out, quality=88)
print(f'{out}: {len(files)} кадров, {sheet.width}x{sheet.height}')
