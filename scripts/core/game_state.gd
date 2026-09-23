extends Node
## 2D판 core/state.js. 게임 전체가 나눠 쓰는 상태. 1단계라 아직 걷기에 필요한 것만 있다.

var game_time := 0.0
var player = null        # Dragon
var map_id := ""
var upgrades := {}       # { spd, dmg, ... } 가게에서 올린 단계
var prologue := false
