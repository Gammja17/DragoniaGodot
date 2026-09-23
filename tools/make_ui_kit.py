"""UI 조각 그림(9-slice)을 픽셀 단위로 찍는다 → assets/ui/kit/*.png

2D판의 가는 금테(assets/ui/frame.png: 두 줄 금선 + 모서리 네모)를 1배 크기에서 또렷하게 다시 그린 것.
theme.tres 와 판 씬들이 이 그림을 StyleBoxTexture 로 쓴다. 색을 바꾸려면 여기 값을 고치고 다시 돌린다.

    python tools/make_ui_kit.py
"""
from pathlib import Path
from PIL import Image

OUT = Path(__file__).resolve().parent.parent / "assets" / "ui" / "kit"

GOLD = (216, 178, 90, 255)
GOLD_LIT = (246, 218, 140, 255)
GOLD_DARK = (150, 112, 46, 255)
GOLD_DIM = (106, 90, 56, 255)   # 어두운 바탕 위의 흐린 금 (반투명으로 두면 뒤의 땅색이 비친다)
EDGE = (8, 7, 13, 235)          # 금테 바깥의 검은 선 (밝은 땅 위에서도 테두리가 서게)
INK = (15, 14, 23, 255)         # 판 바탕 (불투명: 뒤의 HUD·땅이 비치면 글이 안 읽힌다)
INK_DEEP = (9, 8, 15, 255)      # 두 금선 사이
CLEAR = (0, 0, 0, 0)


def canvas(w, h, fill=CLEAR):
    return Image.new("RGBA", (w, h), fill)


def rect(im, x0, y0, x1, y1, c):
    """x0..x1, y0..y1 (끝 포함) 을 채운다"""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            im.putpixel((x, y), c)


def ring(im, i, c, lit=None, dark=None):
    """바깥에서 i 번째 줄에 한 칸 두께 테를 두른다. lit/dark 를 주면 위·왼쪽은 밝게, 아래·오른쪽은 어둡게"""
    w, h = im.size
    for x in range(i, w - i):
        im.putpixel((x, i), lit or c)
        im.putpixel((x, h - 1 - i), dark or c)
    for y in range(i, h - i):
        im.putpixel((i, y), lit or c)
        im.putpixel((w - 1 - i, y), dark or c)


def panel():
    """큰 판: 검은 선 · 금선(빛 받는 쪽이 밝다) · 어두운 띠 · 가는 금선 · 바탕, 네 모서리에 금 네모"""
    S = 40
    im = canvas(S, S)
    rect(im, 1, 1, S - 2, S - 2, INK)
    ring(im, 1, EDGE)
    ring(im, 2, GOLD, GOLD_LIT, GOLD_DARK)
    ring(im, 3, INK_DEEP)
    ring(im, 4, INK_DEEP)
    ring(im, 5, GOLD_DIM)
    # 모서리 장식: 7×7 금 네모, 가운데 어둡게, 한가운데 금 점
    for (cx, cy) in [(0, 0), (S - 7, 0), (0, S - 7), (S - 7, S - 7)]:
        rect(im, cx, cy, cx + 6, cy + 6, EDGE)
        rect(im, cx + 1, cy + 1, cx + 5, cy + 5, GOLD)
        rect(im, cx + 2, cy + 2, cx + 4, cy + 4, INK_DEEP)
        im.putpixel((cx + 3, cy + 3), GOLD_LIT)
        im.putpixel((cx + 1, cy + 1), GOLD_LIT)
    im.save(OUT / "panel.png")


def box(name, fill, border, top=None, edge=EDGE):
    """단추·칸: 검은 선 + 한 칸 테 + 바탕 (+ 위쪽 한 줄 빛)"""
    S = 12
    im = canvas(S, S)
    ring(im, 0, edge)
    ring(im, 1, border)
    rect(im, 2, 2, S - 3, S - 3, fill)
    if top:   # 바탕 위에 섞은 색으로 (반투명 그대로 찍으면 뒤가 비친다)
        a = top[3] / 255
        c = tuple(round(fill[i] + (top[i] - fill[i]) * a) for i in range(3)) + (fill[3],)
        for x in range(2, S - 2):
            im.putpixel((x, 2), c)
    im.save(OUT / f"{name}.png")


def primary(name, top_c, bottom_c):
    """금빛 큰 단추: 위에서 아래로 짙어지는 금, 위 한 줄 밝게, 아래 한 줄 그늘"""
    S = 16
    im = canvas(S, S)
    ring(im, 0, EDGE)
    for y in range(1, S - 1):
        k = (y - 1) / (S - 3)
        c = tuple(round(top_c[i] + (bottom_c[i] - top_c[i]) * k) for i in range(3)) + (255,)
        for x in range(1, S - 1):
            im.putpixel((x, y), c)
    for x in range(1, S - 1):
        im.putpixel((x, 1), (255, 244, 200, 255))
        im.putpixel((x, S - 2), (120, 84, 28, 255))
    im.save(OUT / f"{name}.png")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    panel()
    box("btn", (30, 28, 42, 240), GOLD_DIM, (255, 255, 255, 22))
    box("btn_hover", (46, 41, 58, 245), GOLD, (255, 255, 255, 34))
    box("btn_pressed", (22, 20, 31, 245), GOLD_LIT)
    box("btn_disabled", (20, 19, 27, 200), (58, 51, 40, 220), None, (8, 7, 13, 150))
    box("tab_on", (216, 178, 90, 255), GOLD_LIT, (255, 236, 170, 255))
    box("inset", (26, 25, 37, 230), (64, 56, 42, 255), None, CLEAR)
    primary("primary", (248, 218, 136), (184, 136, 50))
    primary("primary_hover", (255, 232, 160), (206, 158, 66))


if __name__ == "__main__":
    main()
