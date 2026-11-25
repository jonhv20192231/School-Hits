class_name RhythmGameplay
extends RefCounted
## Lógica pura da partida: recebe apertar/soltar/tempo e decide acertos e erros.
## Não desenha nada e não toca som; quem quiser reagir escuta o sinal "judged". Porte de Gameplay.cs.
##
## ANTI-SPAM (versão suave, igual ao C#): nada é bloqueado, mas apertar tudo junto vale menos.
##  • RAJADA: acerto quase junto de outro numa nota de OUTRO momento = no máximo GOOD e metade dos pontos.
##  • TOQUE FANTASMA: aperto sem nota ao alcance = desconto pequeno.
## Liga/desliga em RhythmConfig.anti_spam_enabled (o RhythmPlayer expõe isso no Inspector).

## judgment: 0 PERFECT, 1 GREAT, 2 GOOD, 3 MISS. col = coluna da nota (para animar por coluna).
signal judged(lane: int, judgment: int, sloppy: bool, col: int)

var chart: RhythmChart
var score := RhythmScore.new()

var _cursor := 0                 # primeiro índice que ainda pode ter nota ativa
var _recent: Array = []          # { press_time, note_time }


func _init(p_chart: RhythmChart) -> void:
	chart = p_chart
	score.reset(chart.notes.size())


func is_finished(song_time: float) -> bool:
	if chart.duration_limit > 0.0:
		return song_time > chart.duration_limit + 0.6   # faixa com duração escolhida
	return song_time > chart.end_time + 2.0


func _register(lane: int, col: int, j: int, sloppy: bool = false) -> void:
	score.register(lane, j, RhythmConfig.spam_score_factor if sloppy else 1.0, sloppy)
	judged.emit(lane, j, sloppy, col)


## Nota que este aperto acertaria: a primeira ainda não tocada nessa coluna dentro da janela.
func _find_target(lane: int, col: int, t: float) -> RhythmChart.Note:
	var notes := chart.notes
	for i in range(_cursor, notes.size()):
		var n: RhythmChart.Note = notes[i]
		if n.state != RhythmConfig.NoteState.IDLE or n.lane != lane or n.col != col:
			continue
		var dt := t - n.time
		if dt < -RhythmConfig.WIN_GOOD:
			break   # notas ordenadas: as próximas estão ainda mais longe
		if dt > RhythmConfig.WIN_GOOD:
			continue
		return n
	return null


## Este acerto é parte de uma rajada? Sim, se outro acerto aconteceu há pouquíssimo tempo
## numa nota de outro momento.
func _is_burst(n: RhythmChart.Note, t: float) -> bool:
	_recent = _recent.filter(func(h: Dictionary) -> bool: return t - h["press_time"] <= RhythmConfig.BURST_WINDOW)
	for h: Dictionary in _recent:
		if absf(n.time - h["note_time"]) > RhythmConfig.CHORD_TOLERANCE:
			return true
	return false


func press(lane: int, col: int, t: float) -> void:
	var target := _find_target(lane, col, t)
	if target == null:
		# nenhuma nota ao alcance: toque fantasma
		if RhythmConfig.anti_spam_enabled:
			score.register_ghost(lane)
		return

	var sloppy := RhythmConfig.anti_spam_enabled and _is_burst(target, t)
	var j := RhythmConfig.judgment_from_offset(t - target.time)
	if sloppy and j < RhythmConfig.Judgment.GOOD:
		j = RhythmConfig.Judgment.GOOD   # rajada nunca é PERFECT/GREAT

	_register(lane, col, j, sloppy)
	target.state = RhythmConfig.NoteState.HOLDING if target.is_hold() else RhythmConfig.NoteState.DONE
	if RhythmConfig.anti_spam_enabled:
		_recent.append({ "press_time": t, "note_time": target.time })


## Coluna da nota longa que o jogador está segurando nesta lane agora, ou -1 se nenhuma.
func holding_col(lane: int, t: float) -> int:
	var notes := chart.notes
	for i in range(_cursor, notes.size()):
		var n: RhythmChart.Note = notes[i]
		if n.time > t + RhythmConfig.WIN_GOOD:
			break
		if n.state == RhythmConfig.NoteState.HOLDING and n.lane == lane:
			return n.col
	return -1


func release(lane: int, col: int, t: float) -> void:
	var notes := chart.notes
	for i in range(_cursor, notes.size()):
		var n: RhythmChart.Note = notes[i]
		if n.time > t + 1.0:
			break
		if n.state != RhythmConfig.NoteState.HOLDING or n.lane != lane or n.col != col:
			continue

		if t >= n.time + n.duration - RhythmConfig.HOLD_TAIL_FORGIVE:
			n.state = RhythmConfig.NoteState.DONE
			score.add_hold_bonus()
		else:
			n.state = RhythmConfig.NoteState.MISSED
			_register(lane, col, RhythmConfig.Judgment.MISS)


## Chame todo frame com o tempo atual da música.
func update(t: float) -> void:
	var notes := chart.notes
	for i in range(_cursor, notes.size()):
		var n: RhythmChart.Note = notes[i]
		if n.time > t + 1.0:
			break

		if n.state == RhythmConfig.NoteState.IDLE and t - n.time > RhythmConfig.WIN_MISS:
			n.state = RhythmConfig.NoteState.MISSED
			_register(n.lane, n.col, RhythmConfig.Judgment.MISS)
		elif n.state == RhythmConfig.NoteState.HOLDING and t >= n.time + n.duration:
			n.state = RhythmConfig.NoteState.DONE
			score.add_hold_bonus()

	while _cursor < notes.size() and \
			(notes[_cursor].state == RhythmConfig.NoteState.DONE or notes[_cursor].state == RhythmConfig.NoteState.MISSED):
		_cursor += 1
