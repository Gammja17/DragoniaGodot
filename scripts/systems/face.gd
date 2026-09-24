class_name Face
## 2D판 systems/face.js. 대사 한 줄을 읽어 초상화 표정을 고른다.
## 대사 노드에 face 를 적어 두면 그쪽이 우선이고, 이건 안 적힌 대사용. 표정은 assets/portraits 의 여섯 가지.
## 말투 단서(낱말·문장부호)를 세어 제일 많이 걸린 표정을 고르고, 아무것도 안 걸리면 neutral.
## 평범한 물음표(용건이 있느냐?)나 "조심해라" 같은 흔한 말은 단서로 안 친다 — 너무 자주 걸려서 표정이 덜컥거린다.

# 같은 수면 앞쪽이 이긴다 — "뭐?!" 같은 놀람은 화·기쁨보다 먼저 잡는다
const CUES := [
	["surprised", "\\?!|!\\?|헉|앗[,!.]|엥|설마|세상에|말도 안|뭐라고|깜짝|놀랐|놀라운|어머[,!]|이럴 수가"],
	["angry",     "꺼져|닥쳐|감히|건방|괘씸|젠장|망할|용납|그만해!|하지 마!|이놈|이 녀석!|덤벼|썩 |화가 나|화났|짜증|열받|노발|분하"],
	["sad",       "슬프|슬픔|눈물|울었|울고 |흐느|미안|그립|그리워|외로|쓸쓸|후회|죽었|무덤|한숨|서글|서러|흑흑|안타깝|가엾|불쌍|보고 싶"],
	["worried",   "걱정|불안|위험|무서|두려|어쩌지|어쩌나|큰일|서둘러|위태|불길|수상|괜찮을까|괜찮겠|초조|긴장|조마조마|어떡하"],
	["happy",     "ㅋㅋ|하하|허허|헤헤|후후|히히|고마워|고맙|좋[아다네군]!|신난|신나|기뻐|기쁘|재밌|재미있|웃음|웃었|웃으|축하|반가|반갑|최고|멋지|멋져|잘했|훌륭|대단|맛있|즐거|행복|♪"],
]
static var _res: Array = []   # [[face, RegEx], ...] 한 번만 만든다


static func face_for(text: String) -> String:
	if text == "": return "neutral"
	if _res.is_empty():
		for c in CUES:
			var re := RegEx.new()
			re.compile(c[1])
			_res.append([c[0], re])
	var best := "neutral"
	var best_n := 0
	for r in _res:
		var n: int = r[1].search_all(text).size()
		if n > best_n:
			best = r[0]; best_n = n
	return best
