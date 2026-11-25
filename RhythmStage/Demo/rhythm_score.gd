class_name RhythmScore
extends RefCounted
## Pontuação, combo (total e por lane) e contagem de julgamentos. Porte de ScoreKeeper.cs.

var score := 0
var combo := 0
var max_combo := 0
var total_notes := 0
var spam_count := 0      # acertos "de spam" (rajada): valeram menos pontos
var ghost_taps := 0      # toques sem nota por perto
var lane_combo: Array = []
var counts: Array = [0, 0, 0, 0]   # PERFECT, GREAT, GOOD, MISS


func reset(p_total_notes: int) -> void:
	score = 0
	combo = 0
	max_combo = 0
	total_notes = p_total_notes
	spam_count = 0
	ghost_taps = 0
	lane_combo = []
	for i in RhythmConfig.lanes.size():
		lane_combo.append(0)
	counts = [0, 0, 0, 0]


## score_factor: multiplicador dos pontos deste acerto (1 = normal; menor para acertos de spam).
func register(lane: int, j: int, score_factor: float = 1.0, sloppy: bool = false) -> void:
	counts[j] += 1
	if sloppy:
		spam_count += 1
	if j == RhythmConfig.Judgment.MISS:
		combo = 0
		lane_combo[lane] = 0
		return
	combo += 1
	lane_combo[lane] += 1
	max_combo = maxi(max_combo, combo)
	var points: float = RhythmConfig.JUDGMENT_POINTS[j] + minf(combo, 100) * 2.0
	score += int(roundf(points * score_factor))


func add_hold_bonus() -> void:
	score += 100


## Toque fantasma (aperto sem nota por perto): desconto pequeno de pontos e de precisão.
## O combo NÃO quebra, para perdoar um aperto adiantado.
func register_ghost(_lane: int) -> void:
	ghost_taps += 1
	score = maxi(0, score - RhythmConfig.GHOST_PENALTY_SCORE)


## 0..1
func accuracy() -> float:
	if total_notes <= 0:
		return 0.0
	var total := 0.0
	for j in 4:
		total += counts[j] * RhythmConfig.JUDGMENT_ACCURACY[j]
	return maxf(0.0, (total - ghost_taps * RhythmConfig.GHOST_ACCURACY_PENALTY) / total_notes)


func rank() -> String:
	var a := accuracy()
	if a >= 0.95:
		return "S"
	if a >= 0.85:
		return "A"
	if a >= 0.70:
		return "B"
	return "C"
