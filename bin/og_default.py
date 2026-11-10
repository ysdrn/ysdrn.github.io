#!/usr/bin/env python3
"""サイト共通の SNS 用画像（assets/img/og-default.png）を作る。

800×800 の正方形（X の小さいカード summary は画像を正方形に切るため）、青 #2563eb の地に白で「yoshidaren」だけ。
2026-11-10: 文字が幅いっぱいに見えると本人が言ったので 104px → 56px にして中央に置いた。
作り直したら _config.yml の og_image の ?v= を上げる（X などは同じ URL の画像を覚えている）。

    python3 bin/og_default.py
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "img" / "og-default.png"
SIZE = 800
BG = (0x25, 0x63, 0xEB)
TEXT = "yoshidaren"
FONT = "/System/Library/Fonts/Helvetica.ttc"
FONT_SIZE = 56

img = Image.new("RGB", (SIZE, SIZE), BG)
draw = ImageDraw.Draw(img)
font = ImageFont.truetype(FONT, FONT_SIZE)
# 字面（ascender から descender まで）の中心を画像の中心に置く
draw.text((SIZE / 2, SIZE / 2), TEXT, font=font, fill=(255, 255, 255), anchor="mm")
img.save(OUT, optimize=True)
print(f"og_default: {OUT.relative_to(ROOT)}")
