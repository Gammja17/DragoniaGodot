# Dragonia (Godot)

브라우저판 [Dragonia](https://github.com/Gammja17/Dragonia)를 Godot 4 로 옮기는 저장소.
게임 내용(이야기·수치·지도·그림)은 그대로 두고 엔진만 바꾼다.

- 엔진: Godot 4.7 (Steam판), 렌더러는 웹·모바일에서 다 도는 Compatibility
- 기준 원본: Dragonia `154b06d` (이식이 끝날 때까지 2D판은 동결)
- 내보내기: 웹(GitHub Pages) + 안드로이드 APK + PC

## 폴더

| 폴더 | 내용 |
|---|---|
| `scenes/` | 씬. UI 도 코드로 만들지 않고 씬으로 만든다 |
| `scripts/` | GDScript. 2D판 `src/` 와 같은 갈래(core·world·render·entities…)로 나눈다 |
| `data/` | 2D판 `src/data` 를 JSON 으로 옮긴 것 (손으로 고치지 않는다). 데이터 속 함수는 `scripts/data/conditions.gd` 에 GDScript 로 옮기고 경로("모듈:경로")로 이어 붙인다 |
| `assets/` | 2D판 에셋 복사본 (출처는 `CREDITS.md`) |
| `tools/` | 변환·검증 도구 |
| `_ref2d/` | 2D판 원본 사본. git 에 넣지 않는다 (아래 참고) |

## 2D판 원본 사본 만들기

`tools/export_data.mjs` 와 대조 검사가 읽는다.

```bash
mkdir _ref2d && git -C ../Dragonia archive 154b06d | tar -x -C _ref2d
echo '{"type":"module"}' > _ref2d/package.json
node tools/export_data.mjs
```

## 검증 도구

- `tools/dump_maps.tscn` — 지도를 구워 행별 해시를 뽑는다. 브라우저에서 2D판으로 같은 해시를 뽑아 대조한다
  (1단계에서 VILLAGE·LAKE·FALLS·SKY_RUINS·SNOW_ROAD·DOJO 모두 픽셀 단위로 같았다)
- `tools/test_move.tscn` — 걷기·대시·물가 충돌
- `tools/dump_world.tscn` — 지도를 채운 결과(소품 종류별 수, 마을 용 자리). 2D판 `__dragonia.state.entities` 와 대조
- `tools/test_travel.tscn` — 포탈로 지도 오가기, 이야기가 안 열어 준 길 막기
- `tools/shot.tscn` — 원하는 지도에서 화면 찍기 (`--write-movie`)

```bash
godot --headless --path . tools/test_move.tscn
```

## 진행

1. **뼈대** — 데이터 변환, 입력, 카메라, 지형 생성, 충돌, 용 걷기 ✅
2. **월드** — 소품·나무, 포탈과 지도 이동, 장(章)이 여는 길, 마을 용 배치(일과)·어슬렁거림·혼잣말, 이름표, 지역 배너·알림 ✅
3. 전투 — 브레스, 스킬, 적 AI, 보스
4. 시스템 — 퀘스트, 스토리, 컷씬, 세이브, 둥지, 가족
5. UI — HUD, 일지, 대화창, 설정, 터치 조작
6. 연출 — 조명, 낮밤, 날씨, 포스트프로세싱, 소리
