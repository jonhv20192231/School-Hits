class_name VersusRitmo
extends RhythmPlayer
## RhythmPlayer ADAPTADO AO VERSUS (herda tudo do RhythmPlayer original, que não foi alterado).
## Diferenças:
##  • só as pistas listadas em "lanes_humanas" leem o teclado (a pista da CPU não reage às teclas);
##  • a CPU aperta/solta colunas por código com apertar_coluna() / soltar_coluna().

## Índices das pistas controladas por teclado (0 = P1/esquerda, 1 = P2/direita). A CPU fica de fora.
var lanes_humanas: Array[int] = [0, 1]


## Lê o teclado só para as pistas humanas (mesma lógica do RhythmPlayer, com o filtro de lanes_humanas).
func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or not is_playing or play == null:
		return
	var ke := event as InputEventKey
	if ke == null or ke.echo:
		return
	var key: Key = ke.physical_keycode
	for lane in lanes_humanas:
		if not is_lane_active(lane):
			continue
		var keys: Array = RhythmConfig.lanes[lane]["keys"]
		for col in keys.size():
			if key != keys[col]:
				continue
			_down[lane][col] = ke.pressed
			if ke.pressed:
				play.press(lane, col, song_time)
			else:
				play.release(lane, col, song_time)
			column_changed.emit(lane, col, ke.pressed)


## Usado pela CPU: aperta a coluna no instante "tempo" (tempo da música, em segundos).
func apertar_coluna(lane: int, col: int, tempo: float) -> void:
	if not is_playing or play == null:
		return
	_down[lane][col] = true
	play.press(lane, col, tempo)
	column_changed.emit(lane, col, true)


## Usado pela CPU: solta a coluna (fim de uma nota longa).
func soltar_coluna(lane: int, col: int, tempo: float) -> void:
	if not is_playing or play == null:
		return
	_down[lane][col] = false
	play.release(lane, col, tempo)
	column_changed.emit(lane, col, false)
