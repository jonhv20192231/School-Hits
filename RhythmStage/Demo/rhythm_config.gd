class_name RhythmConfig
extends RefCounted
## Constantes e ajustes do ritmo. Porte de Config.cs + Judgment.cs (100% GDScript, sem .NET).
##
## Os ids das lanes continuam "susie", "kris" e "ralsei" porque é assim que os charts (.json)
## se referem a elas em "characters". O NOME mostrado na tela é o de baixo (ANA, MARCOS, JUNPEI).

enum Judgment { PERFECT, GREAT, GOOD, MISS }
enum NoteState { IDLE, HOLDING, DONE, MISSED }

## Nomes mostrados na tela (português do Brasil), na ordem PERFECT, GREAT, GOOD, MISS.
const JUDGMENT_NAMES := ["PERFEITO", "ÓTIMO", "BOM", "ERROU"]
const JUDGMENT_POINTS := [300, 200, 100, 0]
const JUDGMENT_ACCURACY := [1.0, 0.8, 0.5, 0.0]
static var judgment_colors: Array = [
	Color("ffe866"), Color("66ff99"), Color("66b3ff"), Color("ff5566"),
]

# ───────────── layout da pista (mesmas medidas do Config.cs) ─────────────
const LANE_TOP := 80.0
const LANE_BOTTOM := 560.0
const HIT_Y := 490.0
const LANE_W := 200.0
const LANE_GAP := 60.0

# ───────────── jogabilidade ─────────────
const SCROLL_SPEED := 480.0   # pixels por segundo
const LEAD_IN := 3.0          # contagem antes da música (s)

# janelas de acerto (segundos)
const WIN_PERFECT := 0.045
const WIN_GREAT := 0.090
const WIN_GOOD := 0.140
const WIN_MISS := 0.160       # atrasou mais que isso = MISS
const HOLD_TAIL_FORGIVE := 0.15

# anti-spam (apertar tudo ao mesmo tempo vale menos pontos)
const BURST_WINDOW := 0.05
const CHORD_TOLERANCE := 0.04
const GHOST_PENALTY_SCORE := 5
const GHOST_ACCURACY_PENALTY := 0.05
static var anti_spam_enabled := true
static var spam_score_factor := 0.5

## Ajuste fino de sincronia (s). Positivo = notas chegam mais tarde.
static var audio_offset := 0.0

## Lanes: ordem = esquerda → direita. Para mudar teclas, mexa em "keys" e "labels".
## As teclas são FÍSICAS (a posição na teclado), igual ao C#.
static var lanes: Array = [
	{
		"name": "ANA", "id": "susie", "color": Color("e0508f"),
		"keys": [KEY_A, KEY_S, KEY_D, KEY_F],
		"labels": ["A", "S", "D", "F"],
	},
	{
		"name": "MARCOS", "id": "kris", "color": Color("3fe0d0"),
		"keys": [KEY_G, KEY_H, KEY_J],
		"labels": ["G", "H", "J"],
	},
	{
		"name": "JUNPEI", "id": "ralsei", "color": Color("8fd04a"),
		"keys": [KEY_K, KEY_L, KEY_SEMICOLON],
		"labels": ["K", "L", "Ç"],
	},
]


static func lane_columns(lane: int) -> int:
	return lanes[lane]["keys"].size()


## Converte o erro de tempo (s) em julgamento. Só use dentro da janela GOOD.
static func judgment_from_offset(dt: float) -> int:
	var a := absf(dt)
	if a <= WIN_PERFECT:
		return Judgment.PERFECT
	if a <= WIN_GREAT:
		return Judgment.GREAT
	return Judgment.GOOD
