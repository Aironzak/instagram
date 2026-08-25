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
ims = [Image.open(f) for f in files]
th = round(tw * ims[0].height / ims[0].width)
rows = math.ceil(len(ims) / cols)
sheet = Image.new('RGB', (cols * tw, rows * th), (0, 0, 0))
d = ImageDraw.Draw(sheet)
for i, im in enumerate(ims):
    x, y = (i % cols) * tw, (i // cols) * th
    sheet.paste(im.resize((tw, th), Image.LANCZOS), (x, y))
    d.text((x + 10, y + 8), f'{i}  {files[i].stem}', fill=(255, 190, 90))
sheet.save(out, quality=88)
print(f'{out}: {len(ims)} кадров, {sheet.width}x{sheet.height}')
