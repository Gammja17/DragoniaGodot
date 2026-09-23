"""물마루에 없는 글자(이모지 · 기호)만 Noto Emoji 에서 잘라 assets/fonts/NotoEmoji-subset.ttf 로 만든다.

웹판에는 시스템 글꼴이 없어서, 물마루에 없는 🍖 🪙 💞 같은 글자가 네모 상자로 깨진다.
theme.tres 의 물마루가 이 글꼴을 뒤잇는 글꼴(fallback)로 쓴다. 흑백 글꼴이라 아이콘이 글자색을 따라 칠해진다.

    python tools/make_emoji_font.py <NotoEmoji[wght].ttf 경로>

원본: https://github.com/google/fonts/tree/main/ofl/notoemoji (SIL OFL 1.1) — 저장소에는 잘라 낸 것만 둔다.
게임에 새 이모지를 쓰면 이 스크립트를 다시 돌린다.
"""
import glob
import sys
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "fonts" / "NotoEmoji-subset.ttf"
WEIGHT = 600   # 12px 에서 가는 선이 사라지지 않을 만큼 굵게


def used_chars() -> set[int]:
    chars = set()
    for pat in ("scripts/**/*.gd", "scenes/**/*.tscn", "data/**/*.json"):
        for p in glob.glob(str(ROOT / pat), recursive=True):
            chars.update(ord(c) for c in Path(p).read_text(encoding="utf-8"))
    return chars


def main() -> None:
    src = sys.argv[1]
    mulmaru = TTFont(ROOT / "assets" / "fonts" / "Mulmaru.woff2")
    have = set(mulmaru.getBestCmap())
    emoji = TTFont(src)
    offer = set(emoji.getBestCmap())
    need = {c for c in used_chars() if c > 0x7F and c not in have}
    take = sorted(need & offer) + [0x200D, 0xFE0F, 0x20E3]   # 이어 붙이는 글자들
    missing = sorted(need - offer - {0xFE0F, 0x200D})
    font = instancer.instantiateVariableFont(emoji, {"wght": WEIGHT})
    opts = subset.Options()
    opts.layout_features = ["*"]   # 여러 글자를 이어 만드는 이모지(ZWJ)도 살린다
    opts.name_IDs = ["*"]
    sub = subset.Subsetter(opts)
    sub.populate(unicodes=take)
    sub.subset(font)
    font.save(OUT)
    print(f"{len(take)}자 → {OUT.name} ({OUT.stat().st_size // 1024}KB)")
    if missing:
        print("어느 글꼴에도 없는 글자:", " ".join(f"U+{c:04X}" for c in missing))


if __name__ == "__main__":
    main()
