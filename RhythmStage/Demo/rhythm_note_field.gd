class_name RhythmNoteField
extends Control
## Desenha as notas descendo, as linhas de batida, os receptores e os popups de julgamento
## das 3 lanes. Porte do LaneView.cs. Só LÊ o RhythmPlayer: não toca som nem decide acertos.
##
## Para reaproveitar: adicione como filho de um Control, aponte "player" para um RhythmPlayer
## e dê a ele o tamanho da pista (3 lanes = 780 x 480 pixels).
## Os fundos das lanes e a linha de acerto ficam como nós normais na cena (editáveis no editor);
## este nó vem DEPOIS deles na árvore para desenhar por cima.

@export var player: RhythmPlayer

const POPUP_LIFE := 0.7
const FIELD_H := RhythmConfig.LANE_BOTTOM - RhythmConfig.LANE_TOP   # 480
const HIT_Y := RhythmConfig.HIT_Y - RhythmConfig.LANE_TOP           # 410 (linha de acerto)

## Posição x de cada lane (o RhythmHighway atualiza isso para centralizar só as lanes ativas).
var lane_x := PackedFloat32Array([0.0, 260.0, 520.0])

var _pulse: Array = []     # _pulse[lane][col] = brilho do receptor (1 -> 0)
var _popups: Array = []    # { lane, text, color, age }


func _ready() -> void:
	for lane in RhythmConfig.lanes.size():
		var cols: Array = []
		cols.resize(RhythmConfig.lane_columns(lane))
		cols.fill(0.0)
		_pulse.append(cols)

	if player == null:
		push_warning("RhythmNoteField: aponte a propriedade 'player' para um RhythmPlayer.")
		return
	player.column_changed.connect(_on_column_changed)
	player.judged.connect(_on_judged)
	player.started.connect(_on_started)


func _on_started() -> void:
	_popups.clear()


func _on_column_changed(lane: int, col: int, pressed: bool) -> void:
	if pressed:
		_pulse[lane][col] = 1.0


func _on_judged(lane: int, judgment: int, sloppy: bool, _col: int) -> void:
	if sloppy:
		_popups.append({ "lane": lane, "text": "RAJADA", "color": Color("ff9944"), "age": 0.0 })
	else:
		_popups.append({
			"lane": lane,
			"text": RhythmConfig.JUDGMENT_NAMES[judgment],
			"color": RhythmConfig.judgment_colors[judgment],
			"age": 0.0,
		})


func _process(delta: float) -> void:
	for cols: Array in _pulse:
		for c in cols.size():
			cols[c] = maxf(0.0, cols[c] - delta * 6.0)
	for p: Dictionary in _popups:
		p["age"] += delta
	_popups = _popups.filter(func(p: Dictionary) -> bool: return p["age"] < POPUP_LIFE)
	queue_redraw()


func _fill_clipped(r: Rect2, clip: Rect2, color: Color) -> void:
	var inter := r.intersection(clip)
	if inter.has_area():
		draw_rect(inter, color)


func _draw() -> void:
	if player == null or player.play == null:
		return

	var chart := player.chart
	var t := player.song_time
	var font := get_theme_default_font()

	# linhas de batida (as mesmas para todas as lanes)
	var spb := 60.0 / chart.bpm
	var t_lo := t - (FIELD_H - HIT_Y) / RhythmConfig.SCROLL_SPEED
	var t_hi := t + HIT_Y / RhythmConfig.SCROLL_SPEED
	var b_lo := ceili((t_lo - chart.offset) / spb)
	var b_hi := floori((t_hi - chart.offset) / spb)

	for lane in RhythmConfig.lanes.size():
		var def: Dictionary = RhythmConfig.lanes[lane]
		if not player.is_lane_active(lane):
			continue   # sem jogador nesta lane: não desenha nada (o RhythmHighway esconde a pista)
		var x := lane_x[lane]
		var lane_rect := Rect2(x, 0.0, RhythmConfig.LANE_W, FIELD_H)

		var col: Color = player.lane_color(lane)
		var cols: int = RhythmConfig.lane_columns(lane)
		var col_w := RhythmConfig.LANE_W / cols

		# combo grande da lane, ao fundo
		var lane_combo: int = player.score.lane_combo[lane]
		if lane_combo > 0:
			var faded := Color(col.r, col.g, col.b, 0.28)
			draw_string(font, Vector2(x, 230.0), str(lane_combo),
				HORIZONTAL_ALIGNMENT_CENTER, RhythmConfig.LANE_W, 72, faded)
			draw_string(font, Vector2(x, 262.0), "COMBO",
				HORIZONTAL_ALIGNMENT_CENTER, RhythmConfig.LANE_W, 28, faded)

		# linhas de batida
		for b in range(b_lo, b_hi + 1):
			var by := HIT_Y - float((chart.offset + b * spb - t) * RhythmConfig.SCROLL_SPEED)
			var line_alpha := 0.10 if b % 4 != 0 else 0.22
			draw_line(Vector2(x, by), Vector2(x + RhythmConfig.LANE_W, by), Color(1, 1, 1, line_alpha), 1.0)

		# divisórias das colunas
		for c in range(1, cols):
			var dx := x + c * col_w
			draw_line(Vector2(dx, 0.0), Vector2(dx, FIELD_H), Color(col.r, col.g, col.b, 0.35), 1.0)

		# receptores + letra da tecla
		for c in cols:
			var rx := x + c * col_w
			var rec := Rect2(rx + 4.0, HIT_Y - 12.0, col_w - 8.0, 24.0)
			var glow := 0.15 + 0.5 * float(_pulse[lane][c]) + (0.25 if player.is_down(lane, c) else 0.0)
			draw_rect(rec, Color(col.r, col.g, col.b, glow))
			draw_rect(rec, col, false, 2.0)
			draw_string(font, Vector2(rx, FIELD_H + 22.0), def["labels"][c],
				HORIZONTAL_ALIGNMENT_CENTER, col_w, 16, col)

		draw_rect(lane_rect, col, false, 3.0)

	# notas (a lista está ordenada por tempo: dá para parar cedo)
	var look_ahead := HIT_Y / RhythmConfig.SCROLL_SPEED + 0.1
	for n: RhythmChart.Note in chart.notes:
		if n.time > t + look_ahead:
			break
		if n.state == RhythmConfig.NoteState.DONE or not player.is_lane_active(n.lane):
			continue

		var y_head := HIT_Y - float((n.time - t) * RhythmConfig.SCROLL_SPEED)
		var y_tail := y_head - float(n.duration * RhythmConfig.SCROLL_SPEED)
		if y_tail > FIELD_H or y_head < -10.0:
			continue

		var lx := lane_x[n.lane]
		var clip := Rect2(lx + 1.0, 1.0, RhythmConfig.LANE_W - 2.0, FIELD_H - 2.0)
		var cw := RhythmConfig.LANE_W / RhythmConfig.lane_columns(n.lane)
		var nx := lx + n.col * cw + 6.0
		var nw := cw - 12.0

		var missed := n.state == RhythmConfig.NoteState.MISSED
		var c: Color = Color(0.35, 0.35, 0.42) if missed else player.lane_color(n.lane)

		var head_y := y_head
		if n.is_hold():
			var bottom := y_head
			if n.state == RhythmConfig.NoteState.HOLDING:
				bottom = HIT_Y
				head_y = HIT_Y
				c = c.lightened(0.35)
			_fill_clipped(Rect2(nx + nw * 0.2, y_tail, nw * 0.6, bottom - y_tail), clip, c.darkened(0.25))
		_fill_clipped(Rect2(nx, head_y - 8.0, nw, 16.0), clip, c)

	# popups de julgamento
	for p: Dictionary in _popups:
		var jc: Color = p["color"]
		jc.a = 1.0 - float(p["age"]) / POPUP_LIFE
		var px := lane_x[int(p["lane"])]
		draw_string(font, Vector2(px, HIT_Y - 50.0 - float(p["age"]) * 40.0), p["text"],
			HORIZONTAL_ALIGNMENT_CENTER, RhythmConfig.LANE_W, 24, jc)
