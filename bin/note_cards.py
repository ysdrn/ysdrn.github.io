#!/usr/bin/env python3
"""notes の記事の写真（front matter の cover）に題を重ねたカード画像を作る。

- 入力: _posts/*.md の front matter `cover: <ファイル名>`（写真は assets/img/notes/<ファイル名>）と `title:`
- 出力: assets/img/notes/card/<ファイル名>（1280×670、JPEG）。notes 一覧のサムネと SNS のカード（og:image）に使う
- 記事ページの題の上には題の入っていない元の写真を出す（題が二度続かないように）
- 題か写真が変わった記事だけ作り直す（_data/note_cards.json に題と写真のハッシュを控える）

Mac で実行する（Pillow とヒラギノ角ゴシックが要る。CI では作らない）:
    python3 bin/note_cards.py            # 変わった記事だけ
    python3 bin/note_cards.py --force    # 全部作り直す
pre-commit hook（.githooks/pre-commit）が --quiet で自動実行する。Pillow がなければ何もしない。

2026-11-10 作成。見た目の数値は下の定数。
"""
import hashlib
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
POSTS = ROOT / "_posts"
SRC_DIR = ROOT / "assets" / "img" / "notes"
OUT_DIR = SRC_DIR / "card"
MANIFEST = ROOT / "_data" / "note_cards.json"

W, H = 1280, 670  # note の見出し画像と同じ比率（1.91:1、OGP の推奨）
FONT = "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc"
FONT_SIZE = 64
MIN_FONT_SIZE = 44
LINE_HEIGHT = 1.45
TRACKING = 0.04  # 字間（em）。サイトの記事の題と同じ
MARGIN_X = 72
MARGIN_BOTTOM = 64
MAX_LINES = 3
VERSION = 2  # 見た目を変えたら上げる（全記事を作り直す）

# 行頭に来てはいけない字・行末に来てはいけない字（簡単な禁則）
NO_START = set("、。，．・：；？！」』）〕］｝〉》ー…‥ぁぃぅぇぉっゃゅょゎァィゥェォッャュョヮヵヶ")
NO_END = set("「『（〔［｛〈《")
# 改行しやすい位置（この字の後ろ）。行があふれたら、行末から BACKOFF 字以内のこの位置まで戻して改行する
BREAK_AFTER = set("をはがのにへでともや』」）、。・")
BACKOFF = 8


def front_matter(path):
    text = path.read_text(encoding="utf-8")
    m = re.match(r"---\n(.*?)\n---\n", text, re.S)
    if not m:
        return {}
    fm = {}
    for line in m.group(1).splitlines():
        mm = re.match(r"^(title|cover):\s*(.*)$", line)
        if mm:
            v = mm.group(2).strip()
            if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'":
                v = v[1:-1]
            fm[mm.group(1)] = v
    return fm


def char_advance(font, ch):
    return font.getlength(ch, features=["palt"]) + font.size * TRACKING


def wrap(font, title, max_width):
    lines, line, width = [], "", 0.0
    for ch in title:
        adv = char_advance(font, ch)
        if line and width + adv > max_width:
            # 禁則: 行頭禁止の字は前の行に追い込む／行末禁止の字は次の行に送る
            if ch in NO_START:
                line += ch
                lines.append(line)
                line, width = "", 0.0
                continue
            cut = next((i + 1 for i in range(len(line) - 1, max(len(line) - 1 - BACKOFF, 0), -1)
                        if line[i] in BREAK_AFTER), None)
            if cut and cut < len(line):
                carry = line[cut:]
                lines.append(line[:cut])
                line, width = carry, sum(char_advance(font, c) for c in carry)
            elif line[-1] in NO_END:
                carry = line[-1]
                lines.append(line[:-1])
                line, width = carry, char_advance(font, carry)
            else:
                lines.append(line)
                line, width = "", 0.0
        line += ch
        width += adv
    if line:
        lines.append(line)
    return lines


def cover_crop(img):
    from PIL import Image

    scale = max(W / img.width, H / img.height)
    img = img.resize((round(img.width * scale), round(img.height * scale)), Image.LANCZOS)
    left = (img.width - W) // 2
    top = (img.height - H) // 2
    return img.crop((left, top, left + W, top + H))


def render(src, title, out):
    from PIL import Image, ImageDraw, ImageFilter, ImageFont

    base = cover_crop(Image.open(src).convert("RGB"))

    # 下に向かって暗くするグラデーション（上 30% までは写真のまま、下端で黒 72%）
    shade = Image.new("L", (W, H), 0)
    px = shade.load()
    for y in range(H):
        t = max(0.0, (y / H - 0.30) / 0.70)
        a = int(255 * 0.72 * (t ** 1.4))
        for x in range(W):
            px[x, y] = a
    base = Image.composite(Image.new("RGB", (W, H), (0, 0, 0)), base, shade)

    size = FONT_SIZE
    while True:
        font = ImageFont.truetype(FONT, size)
        lines = wrap(font, title, W - MARGIN_X * 2)
        if len(lines) <= MAX_LINES or size <= MIN_FONT_SIZE:
            break
        size -= 4

    line_h = round(size * LINE_HEIGHT)
    y0 = H - MARGIN_BOTTOM - line_h * len(lines) + round((line_h - size) / 2)

    # 文字の影（ぼかした黒）を先に描いてから白い文字を重ねる
    shadow = Image.new("L", (W, H), 0)
    sd = ImageDraw.Draw(shadow)
    text = Image.new("L", (W, H), 0)
    td = ImageDraw.Draw(text)
    for i, line in enumerate(lines):
        x = MARGIN_X
        y = y0 + i * line_h
        for ch in line:
            sd.text((x, y + 2), ch, font=font, fill=255, features=["palt"])
            td.text((x, y), ch, font=font, fill=255, features=["palt"])
            x += char_advance(font, ch)
    shadow = shadow.filter(ImageFilter.GaussianBlur(6)).point(lambda v: int(v * 0.55))
    base = Image.composite(Image.new("RGB", (W, H), (0, 0, 0)), base, shadow)
    base = Image.composite(Image.new("RGB", (W, H), (255, 255, 255)), base, text)

    out.parent.mkdir(parents=True, exist_ok=True)
    base.save(out, "JPEG", quality=85, optimize=True, progressive=True)


def main():
    force = "--force" in sys.argv
    quiet = "--quiet" in sys.argv
    try:
        import PIL  # noqa: F401
    except ImportError:
        if not quiet:
            print("note_cards: Pillow がないので作らない（pip install pillow）")
        return 0
    if not Path(FONT).exists():
        if not quiet:
            print(f"note_cards: フォントがない: {FONT}")
        return 0

    manifest = json.loads(MANIFEST.read_text(encoding="utf-8")) if MANIFEST.exists() else {}
    seen, made = set(), []
    for post in sorted(POSTS.glob("*.md")):
        fm = front_matter(post)
        cover, title = fm.get("cover"), fm.get("title", "")
        if not cover:
            continue
        src = SRC_DIR / cover
        if not src.exists():
            print(f"note_cards: 写真がない: {src.relative_to(ROOT)}（{post.name}）")
            continue
        seen.add(cover)
        key = hashlib.md5(f"{VERSION}\n{title}\n".encode() + src.read_bytes()).hexdigest()
        out = OUT_DIR / cover
        if not force and manifest.get(cover, {}).get("key") == key and out.exists():
            continue
        render(src, title, out)
        manifest[cover] = {"title": title, "key": key}
        made.append(cover)

    for gone in sorted(set(manifest) - seen):
        manifest.pop(gone)
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if made or not quiet:
        print(f"note_cards: {len(made)} 枚作成" + (f"（{', '.join(made)}）" if made else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
