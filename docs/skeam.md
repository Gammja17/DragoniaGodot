# SKEAM 도전 과제

SKEAM(KING 동아리의 게임 상점, https://kh32-7.github.io/skeam/)에 웹판을 올리면, 게임 안에서 이룬 도전 과제가 SKEAM 에 뜬다.

## 어떻게 도나

- `export_presets.cfg` 의 `html/head_include` 가 웹판 index.html 머리에 SKEAM SDK(`skeam-sdk.js`)를 넣는다. Pages 워크플로가 이 설정으로 내보낸다.
- `scripts/systems/achievements.gd` 가 1초마다 지금 판을 보고, 새로 이룬 과제를 하나씩 `SKEAM.unlock(id)` 로 알린다.
  - SKEAM 밖(Pages 주소로 바로 할 때 · 편집기 · PC판)에서는 아무 일도 하지 않는다.
  - 과제는 되도록 세이브에 남는 값에서 읽는다. SKEAM 밖에서 이룬 것도 SKEAM 에서 그 판을 불러오면 그때 알린다.
  - 같은 과제를 또 알려도 SKEAM 은 한 번만 센다. SKEAM 에 등록하지 않은 id 는 SKEAM 이 무시한다.
  - 지금까지 세지 않던 값 넷은 `GameState.stats` 에 센다: `fusions`(융합 브레스) · `downs`(쓰러짐) · `fish`(낚시) · `chores`(잡일).
  - 설정의 테스트 단추를 쓴 판(`story.flags.tested`)은 더 알리지 않는다.
- 과제를 더하려면 `Achievements.earned()` 에 한 줄, 아래 목록에 한 줄을 넣고 SKEAM 에 다시 등록한다. id 는 둘이 같아야 한다.

## SKEAM 에 등록할 목록

SKEAM `games/<게임 id>/game.yml` 의 `achievements:` 에 그대로 넣는다 (아이콘은 없어도 된다. 없으면 🏆 가 뜬다).

```yaml
achievements:
  # 이야기
  - id: morgath
    name: "골짜기의 울음이 멎다"
    desc: "옛 수호룡의 무덤에서 모르가스를 쓰러뜨리세요"
  - id: zalgora
    name: "굶는 계절의 끝"
    desc: "쌍두룡의 둥지에서 잘고라를 쓰러뜨리세요"
  - id: glacia
    name: "한여름의 눈이 그치다"
    desc: "얼어붙은 봉우리에서 글라시아와 싸워 이기세요"
  - id: basil
    name: "사막 길이 열리다"
    desc: "모래 폭군의 둥지에서 바실을 쓰러뜨리세요"
  - id: ignar
    name: "화산 정상의 결판"
    desc: "화산 정상에서 이그나르와 싸워 이기세요"
  - id: ending_guardian
    name: "새 수호룡의 이야기"
    desc: "화산 정상의 싸움 뒤 '끝낸다'를 골라 결말을 보세요"
  - id: ending_redeem
    name: "돌아온 형의 이야기"
    desc: "화산 정상의 싸움 뒤 '같이 가자'를 골라 결말을 보세요. 카이론의 옛이야기('형의 발자취')를 들어야 고를 수 있습니다"
  - id: ending_dark
    name: "잿빛 날개의 이야기"
    desc: "화산 정상에서 이그나르에게 '계속 말해 보라'고 하고 결말을 보세요. 밤손님을 만난 판에서만 고를 수 있습니다"
  # 성장
  - id: stage_teen
    name: "어린 용"
    desc: "승급 시험을 통과해 어린 용이 되세요"
  - id: stage_adult
    name: "성체"
    desc: "성체로 승급하세요. 이제 짝을 맺고 하늘을 날 수 있습니다"
  - id: stage_elder
    name: "고룡"
    desc: "마지막 단계인 고룡으로 깨어나세요"
  - id: fusion
    name: "셋이 하나로"
    desc: "속성 셋을 모아 융합 브레스를 처음 쏘세요"
  # 싸움
  - id: first_kill
    name: "첫 사냥"
    desc: "적을 처음으로 쓰러뜨리세요"
  - id: many_kills
    name: "사냥의 달인"
    desc: "적을 300마리 쓰러뜨리세요"
  - id: first_elite
    name: "금빛 정예"
    desc: "금빛으로 빛나는 정예를 처음 쓰러뜨리세요"
  - id: brink
    name: "구사일생"
    desc: "체력이 바닥나기 직전까지 몰리고도 버텨 내세요"
  - id: first_down
    name: "다시 일어서다"
    desc: "처음으로 쓰러지세요"
  - id: raid_defender
    name: "마을의 방패"
    desc: "사냥꾼 습격을 다섯 번 막아내세요"
  - id: blood_moon
    name: "붉은 달 아래서"
    desc: "붉은 달이 뜬 밤에 적을 스무 마리 쓰러뜨리세요"
  # 생활
  - id: nest
    name: "내 둥지"
    desc: "내 굴 잠자리에 둥지를 지으세요"
  - id: first_kid
    name: "첫 아이"
    desc: "알에서 깨어난 첫 아이를 맞으세요"
  - id: kid_grown
    name: "다 자란 아이"
    desc: "아이를 성체까지 키우세요"
  - id: partner
    name: "짝"
    desc: "마을 용과 짝을 맺으세요"
  - id: vow
    name: "언약의 고리"
    desc: "한눈팔지 않고 닷새를 함께 산 짝과 평생을 약속하세요"
  - id: best_friend
    name: "절친"
    desc: "마을 용 하나와 절친이 되세요"
  - id: cozy_den
    name: "내 집"
    desc: "내 굴의 아늑함을 '내 집'까지 채우세요"
  - id: chore_regular
    name: "게시판 단골"
    desc: "게시판 잡일을 열 번 해내세요"
  - id: requests
    name: "마을의 부탁"
    desc: "마을 용들의 부탁을 여섯 가지 들어주세요"
  - id: kid_flight
    name: "첫 날갯짓"
    desc: "어린 용이 된 아이에게 나는 법을 가르치세요"
  - id: contest_all
    name: "두 마을의 대표"
    desc: "달맞이 모임의 겨루기 셋(폭포 경주, 낚시, 겨루기)을 모두 이기세요"
  - id: hundred_days
    name: "백 일째 아침"
    desc: "백 일째 아침을 맞으세요"
  # 탐험
  - id: waystones
    name: "석비 순례"
    desc: "이동 석비를 모두 깨우세요"
  - id: delve_5
    name: "깊은 곳으로"
    desc: "옛 굴에서 지하 5층까지 내려가세요"
  - id: delve_8
    name: "빛이 닿지 않는 곳"
    desc: "옛 굴에서 지하 8층까지 내려가세요"
  - id: angler
    name: "호숫가의 낚시꾼"
    desc: "물고기를 스무 마리 낚으세요"
  - id: relic_collector
    name: "유물 수집가"
    desc: "유물을 열 개 모으세요"
  - id: sneak_caught
    name: "무궁화 꽃이 피었습니다"
    desc: "몰래 다가가다가 들키세요"
  - id: sky_traces
    name: "하늘에서 본 것"
    desc: "하늘에서만 보이는 옛 흔적 다섯 곳을 모두 찾으세요"
```

## 확인

- 시험: `tools/test_skeam.tscn` (headless). 웹판에서 SKEAM 으로 가는 호출은 이 PC 에서 돌려 볼 수 없다 (웹 내보내기 틀이 없다).
- 배포한 뒤: Pages 주소에서 페이지 소스에 `skeam-sdk.js` 줄이 있는지 본다. SKEAM 에서 게임을 열고 적 하나를 쓰러뜨리면 "도전 과제 달성! 첫 사냥"이 뜬다.
