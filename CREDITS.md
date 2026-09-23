# Credits

게임에 실제로 포함된 외부 에셋 목록. 새 에셋을 쓰기 시작하면 여기에 추가한다.

## 드래곤 스프라이트 (`assets/sprites/dragons/`)

| 파일 | 원작 | 라이선스 | 출처 |
|---|---|---|---|
| `western_*.png` | "Red Dragon" by ZaPaper (credits to buko-studios.com, commissioned by PlayCraft) | CC BY 3.0 | OpenGameArt |
| `wyvern.png`, `hydra.png` | "Flying Dragon Rework" by ZaPaper & Jordan Irwin (AntumDeluge) | CC BY 3.0 | https://opengameart.org/node/83655 |
| `behemoth.png`, `bone.png` | "Stendhal Dragons" © 2017-2018 Kimmo Rundelin | CC BY-SA 3.0 | https://opengameart.org/node/81282 |

| `looks.png` (앉은 용 26종) | **출처·라이선스 확인 필요** — 사용자가 내려받은 `pxl drAHHgon.png`, `image (84).png` 를 64px 칸으로 재배치 | (확인 후 기입) |
| `shadow.png` (최종 보스) | "Shadow Demon Dragon Asset Pack" — 프레임을 잘라 절반 크기로 재배치. **작가·라이선스 확인 필요** | itch.io (확인 후 기입) |

변경 사항: 게임 실행 중에 플레이어/NPC 색상에 맞춰 색조를 바꿔 그린다(`src/render/tint.js`).
CC BY-SA 에셋(`behemoth`, `bone`)을 수정한 결과물은 같은 CC BY-SA 3.0 조건을 따른다.

## 지형 타일 (`assets/tiles/`)

| 파일 | 원작 | 출처 |
|---|---|---|
| `forest*.png`, `forest_trees*.png`, `forest_props*.png` | "Gentle Forest" ($0 palettes: v01 rabite forest, v02 jungle of illusion, v03 moonlight forest) by Seliel the Shaper | https://seliel-the-shaper.itch.io/ |
| `waterfall.png`, `sparkle.png` | 같은 "Gentle Forest" 팩의 `gentle animations` (v01). 폭포 6프레임 × 10행, 물비늘 3프레임 × 3행 | 〃 |
| `village.png` (집, 분수, 상자, 통, 표지판) | "Zelda-like tilesets and sprites" by ArMM1998 (CC0) | OpenGameArt |
| `dungeon.png` (적, 사냥꾼, 화살) | "Tiny Dungeon" by Kenney (CC0) | https://kenney.nl/assets/tiny-dungeon |
| `cave.png` (굴 속 바위 바닥·검은 구멍·돌덩이) | 같은 "Zelda-like tilesets and sprites" by ArMM1998 (CC0) | OpenGameArt |
| `inner.png` (굴에 놓는 살림살이) | 〃 | OpenGameArt |

## 효과 (`assets/vfx/`)

| 파일 | 원작 | 출처 |
|---|---|---|
| `firebolt.png` | "Fire Spell Effect 01" by pimen | https://pimen.itch.io/ |
| `ice.png`, `ice_hit.png` | "Ice Spell Effect 01" by pimen | https://pimen.itch.io/ |
| `thunder.png`, `thunder_hit.png` | "Thunder Spell Effect 01" by pimen | https://pimen.itch.io/ |
| `smoke.png` | "Smoke n Dust 01" by pimen | https://pimen.itch.io/ |
| `campfire.png` | "Animated Fire" by BenHickling (CC0) | OpenGameArt |
| `flames.png` | "Fire Spell Effect 01" by pimen | https://pimen.itch.io/ |
| `ice_spike.png` | "Ice Spell Effect 01" by pimen | https://pimen.itch.io/ |
| `thunder_ball.png` | "Thunder Spell Effect 01" by pimen | https://pimen.itch.io/ |
| `puff.png` | "Smoke n Dust 01" by pimen | https://pimen.itch.io/ |
| `water.png`, `water_hit.png` | "Water Spell Effect 02" by pimen — 물덩이의 되풀이 프레임과 터지는 프레임을 한 줄로 재배치 | https://pimen.itch.io/ |
| `water_splash.png` | "Water Spell Effect 01" by pimen | https://pimen.itch.io/ |
| `earth_hit.png` | "Earth Spell Effect 01" by pimen | https://pimen.itch.io/ |
| `grass.png`, `grass_hit.png` | "Acid Spell Effect" by pimen | https://pimen.itch.io/ |
| `root.png` | "Wood Spell Effect" by pimen | https://pimen.itch.io/ |
| `p_flame.png`, `p_magic.png`, `p_rune.png`, `p_light.png`, `p_streak.png`, `p_twirl.png`, `p_spark.png`, `p_star.png`, `p_arc.png`, `p_halo.png`, `p_sigil.png` (160px 로 줄임) | "Particle Pack" by Kenney (CC0) | https://kenney.nl/assets/particle-pack |
| `star.png`, `ring.png`, `slash.png`, `scorch.png`, `twirl.png`, `spark.png`, `muzzle.png`, `dirt.png`, `flare.png`, `circle_magic.png`, `shockwave.png`, `heart.png`, `aura.png` | "Particle Pack" by Kenney (CC0) | https://kenney.nl/assets/particle-pack |

## UI (`assets/ui/`)

| 파일 | 원작 | 출처 |
|---|---|---|
| `frame.png` (금색으로 재채색) | "Fantasy UI Borders" by Kenney (CC0) | https://kenney.nl/assets/fantasy-ui-borders |

고기·알·동전·장작·머리 장신구 아이콘은 코드로 직접 찍은 픽셀이다(`src/render/pixel.js`).

## 배경음 (`assets/music/`)

모두 **Eric Matyas** 가 만들어 무료로 나눠 주는 곡이다. 조건은 게임 화면 안에 만든 이를 밝히는 것이고,
일지 → [소리] 탭에 `Music by Eric Matyas · www.soundimage.org` 로 적어 두었다. 출처: https://soundimage.org/

| 파일 | 곡 이름 | 쓰이는 곳 |
|---|---|---|
| `title.ogg` | Of Legends and Fables 4 | 타이틀 · 용 만들기 |
| `village.ogg` | Bustling Village | 드래곤 빌리지 |
| `den.ogg` | Dreaming of Faraway Places | 굴 안 (내 굴 · 남의 굴) |
| `lake.ogg` | Magic Ocean | 신비의 호수 |
| `forest.ogg` | Secret Hollow | 깊은 숲 · 아지트 |
| `autumn.ogg` | The Meadow We Call Home | 단풍 골 |
| `jungle.ogg` | Lost Jungle | 환영의 밀림 |
| `hollow.ogg` | Moonlight Flying | 달빛 골짜기 |
| `snow.ogg` | Faraway Winter Wonderland | 서리 봉우리 |
| `desert.ogg` | Desert Mystery | 죽은 사구 |
| `volcano.ogg` | Smoky Sky | 잿빛 화산 |
| `dungeon.ogg` | A Maze of Secret Dungeons | 굴 탐험 |
| `boss.ogg` | Battle of the Ancients | 보스 결투 |
| `raid.ogg` | Tower Defense | 마을 습격 |
| `bloodmoon.ogg` | Darkness Approaches | 붉은 달이 뜬 밤 |

## 효과음 (`assets/sfx/`)

| 파일 | 원작 | 라이선스 | 출처 |
|---|---|---|---|
| `step1~5.ogg` | "Impact Sounds" by Kenney — `footstep_grass_000~004` | CC0 | https://kenney.nl/assets/impact-sounds |
| `hit1~3.ogg`, `crit1~3.ogg` | 같은 팩 — `impactPunch_medium/heavy_000~002` | CC0 | 〃 |
| `guard1~3.ogg` | 같은 팩 — `impactMetal_light_000~002` | CC0 | 〃 |
| `hurt1~3.ogg`, `boom1~3.ogg`, `die1~3.ogg`, `bigdie1~2.ogg`, `warn.ogg`, `thud1~2.ogg`, `glass1~3.ogg` | "Impact Sounds" by Kenney — `impactPunch_heavy`, `impactPlate_heavy`, `impactSoft_heavy`, `impactBell_heavy`, `impactWood_heavy`, `impactGlass` | CC0 | https://kenney.nl/assets/impact-sounds |
| `pickup.ogg`, `chest.ogg`, `quest1~3.ogg`, `whoosh1~3.ogg` | "RPG Audio" by Kenney — `handleSmallLeather`, `metalLatch`, `bookFlip1~3`, `cloth1~3` | CC0 | https://kenney.nl/assets/rpg-audio |
| `slash1~2.ogg`, `coin.ogg`, `ui.ogg` | "RPG Audio" by Kenney — `knifeSlice`, `handleCoins`, `metalClick` | CC0 | https://kenney.nl/assets/rpg-audio |

나머지 효과음 40여 종은 파일 없이 WebAudio 로 그때그때 만든다 (`src/systems/audio.js`).

## 글꼴 (`assets/fonts/`)

| 파일 | 원작 | 라이선스 | 출처 |
|---|---|---|---|
| `Mulmaru.woff2` (assets/fonts) | "물마루 Mulmaru" by Mushsooni — 게임용 한글 픽셀 폰트 | SIL OFL 1.1 | https://github.com/mushsooni/mulmaru |

변경 사항: 원본 ttf/otf 를 게임에 쓰는 글자(라틴, 한글 11,172자, 문장부호·괘선)만 남겨
서브셋한 뒤 woff2 로 압축했다. 글꼴 파일 자체를 따로 배포하거나 팔지 않는다.

## 라이선스 전문
- CC BY 3.0: https://creativecommons.org/licenses/by/3.0/
- CC BY-SA 3.0: https://creativecommons.org/licenses/by-sa/3.0/
- KOGL 제1유형: https://www.kogl.or.kr/info/license.do
