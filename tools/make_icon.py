"""Draws the 1024×1024 app icon (Pillow)."""
import math, sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter

S = 2048  # supersampled
out = sys.argv[1]

def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))

violet, magenta = (104, 80, 242), (190, 74, 219)
img = Image.new('RGB', (S, S))
px = img.load()
for y in range(S):
    for x in range(S):
        t = (x + y) / (2 * S)
        px[x, y] = lerp(violet, magenta, t)
img = img.convert('RGBA')

# soft light blob top-left
glow = Image.new('RGBA', (S, S), (0, 0, 0, 0))
ImageDraw.Draw(glow).ellipse((-700, -900, 1100, 700), fill=(255, 255, 255, 38))
img = Image.alpha_composite(img, glow.filter(ImageFilter.GaussianBlur(260)))

cx, cy, r, w = S // 2, int(S * 0.58), int(S * 0.34), int(S * 0.055)
box = (cx - r, cy - r, cx + r, cy + r)
start, end = 180 + 20, 360 - 20
track = Image.new('RGBA', (S, S), (0, 0, 0, 0))
td = ImageDraw.Draw(track)
td.arc(box, start, end, fill=(255, 255, 255, 70), width=w)
for ang in (start, end):
    rad = math.radians(ang)
    ex, ey = cx + (r - w / 2) * math.cos(rad), cy + (r - w / 2) * math.sin(rad)
    td.ellipse((ex - w / 2, ey - w / 2, ex + w / 2, ey + w / 2), fill=(255, 255, 255, 70))
for k in range(11):
    ang = math.radians(start + (end - start) * k / 10)
    r0, r1 = r - w * 1.25, r - w * (1.95 if k % 5 == 0 else 1.6)
    td.line((cx + r0 * math.cos(ang), cy + r0 * math.sin(ang), cx + r1 * math.cos(ang), cy + r1 * math.sin(ang)),
            fill=(255, 255, 255, 150), width=int(S * 0.012))
img = Image.alpha_composite(img, track)
d = ImageDraw.Draw(img)
value = 0.72
orange, pink = (255, 170, 60), (255, 92, 120)
steps = 120
stop = start + (end - start) * value
for i in range(steps):
    a0 = start + (stop - start) * i / steps
    a1 = start + (stop - start) * (i + 1.2) / steps
    d.arc(box, a0, a1, fill=lerp(orange, pink, i / steps) + (255,), width=w)
# rounded caps
for ang, col in ((start, orange), (stop, pink)):
    rad = math.radians(ang)
    ex, ey = cx + (r - w / 2) * math.cos(rad), cy + (r - w / 2) * math.sin(rad)
    d.ellipse((ex - w / 2, ey - w / 2, ex + w / 2, ey + w / 2), fill=col + (255,))
# needle
ang = math.radians(stop)
nl = r - w * 2.2
tip = (cx + nl * math.cos(ang), cy + nl * math.sin(ang))
perp = ang + math.pi / 2
bw = S * 0.028
d.polygon([tip, (cx + bw * math.cos(perp), cy + bw * math.sin(perp)), (cx - bw * math.cos(perp), cy - bw * math.sin(perp))],
          fill=(255, 255, 255, 255))
d.ellipse((cx - S * 0.045, cy - S * 0.045, cx + S * 0.045, cy + S * 0.045), fill=(255, 255, 255, 255))
d.ellipse((cx - S * 0.018, cy - S * 0.018, cx + S * 0.018, cy + S * 0.018), fill=magenta + (255,))

# serif "Aa"
font = ImageFont.truetype('/usr/share/fonts/truetype/liberation/LiberationSerif-Bold.ttf', int(S * 0.27))
text = 'Aa'
bbox = d.textbbox((0, 0), text, font=font)
tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
tx, ty = cx - tw / 2 - bbox[0], int(S * 0.665) - bbox[1]
shadow = Image.new('RGBA', (S, S), (0, 0, 0, 0))
ImageDraw.Draw(shadow).text((tx, ty + S * 0.012), text, font=font, fill=(40, 10, 90, 110))
img = Image.alpha_composite(img, shadow.filter(ImageFilter.GaussianBlur(18)))
ImageDraw.Draw(img).text((tx, ty), text, font=font, fill=(255, 255, 255, 255))

img = img.convert('RGB').resize((1024, 1024), Image.LANCZOS)
img.save(out, optimize=True)
print('icon written', out)
