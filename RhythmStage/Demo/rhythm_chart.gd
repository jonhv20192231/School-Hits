class_name RhythmChart
extends RefCounted
## Um chart = as notas + qual música ele usa. Lê os MESMOS .json de res://RhythmStage/charts/
## (formato descrito em charts/README.md). Porte de Chart.cs + Note.cs.

const MUSIC_DIR := "res://RhythmStage/music/"
const MUSIC_EXTENSIONS := ["", ".ogg", ".mp3", ".wav"]


class Note:
	var time := 0.0        # quando deve ser acertada (s)
	var duration := 0.0    # 0 = nota normal; > 0 = nota longa
	var lane := 0
	var col := 0           # coluna dentro da lane
	var state: int = RhythmConfig.NoteState.IDLE

	func is_hold() -> bool:
		return duration > 0.0


var title := "Sem título"
var artist := ""
var music_file := ""
var path := ""             # de onde foi carregado ("" = chart embutido)
var bpm := 120.0
var offset := 0.0
var end_time := 0.0
## Duração máxima tocada (s, contada desde o início da música). 0 = sem limite.
var duration_limit := 0.0
var stage := ""
## id da lane ("susie"/"kris"/"ralsei") -> { sprite, name, color (Color ou null), enabled }
var styles: Dictionary = {}
var notes: Array = []      # de RhythmChart.Note, ordenado por tempo


# ───────────── música ─────────────

## Caminho res:// da música se existir, senão "".
func resolve_music_path() -> String:
	return resolve_music(music_file)


static func resolve_music(file: String) -> String:
	if file.strip_edges() == "":
		return ""
	var base := file
	if not (file.begins_with("res://") or file.begins_with("user://")):
		base = MUSIC_DIR + file
	for ext in MUSIC_EXTENSIONS:
		if ResourceLoader.exists(base + ext):
			return base + ext
	return ""


func load_music() -> AudioStream:
	var p := resolve_music_path()
	if p == "":
		if music_file.strip_edges() != "":
			push_warning("Música '%s' não encontrada em %s (chart: %s)." % [music_file, MUSIC_DIR, title])
		return null
	return load(p) as AudioStream


# ───────────── notas ─────────────

func add_note(beat: float, lane: int, col: int, len_beats: float = 0.0) -> void:
	if lane < 0 or lane >= RhythmConfig.lanes.size():
		return
	if col < 0 or col >= RhythmConfig.lane_columns(lane):
		return
	var spb := 60.0 / bpm
	var n := Note.new()
	n.time = offset + beat * spb
	n.duration = len_beats * spb
	n.lane = lane
	n.col = col
	notes.append(n)


func finish() -> void:
	notes.sort_custom(func(a: Note, b: Note) -> bool: return a.time < b.time)
	end_time = 0.0
	for n: Note in notes:
		end_time = maxf(end_time, n.time + n.duration)


func is_enabled(lane_id: String) -> bool:
	if not styles.has(lane_id):
		return true
	return styles[lane_id]["enabled"]


func _copy_header() -> RhythmChart:
	var c := RhythmChart.new()
	c.title = title
	c.artist = artist
	c.music_file = music_file
	c.path = path
	c.bpm = bpm
	c.offset = offset
	c.stage = stage
	c.styles = styles
	c.duration_limit = duration_limit
	return c


static func _copy_note(n: Note) -> Note:
	var copy := Note.new()
	copy.time = n.time
	copy.duration = n.duration
	copy.lane = n.lane
	copy.col = n.col
	return copy


## Cópia para jogar: notas novas (estado limpo) só das lanes que passam em lane_active(lane) -> bool.
## O chart original não é alterado.
func clone_for(lane_active: Callable) -> RhythmChart:
	var c := _copy_header()
	for n: Note in notes:
		if lane_active.call(n.lane):
			c.notes.append(_copy_note(n))
	c.finish()
	return c


## Modo "N jogadores": cópia com as notas nas lanes escolhidas (target_lanes = índices de lane).
##  distribute = true : reparte TODAS as notas entre os jogadores, em revezamento (1 nota para cada).
##  distribute = false: mantém só as notas que já eram dessas lanes (se não sobrar nenhuma, reparte).
## Notas que cairiam em cima de outra na mesma coluna são empurradas para a coluna ao lado.
func retarget(target_lanes: Array, distribute: bool = true) -> RhythmChart:
	var c := _copy_header()
	var pool: Array = []
	if not distribute:
		for n: Note in notes:
			if target_lanes.has(n.lane):
				pool.append(n)
	var spread := distribute or pool.is_empty()
	if spread:
		pool = notes

	var busy_until := {}   # "lane*10+col" -> quando a última nota dessa coluna termina
	var i := 0
	for n: Note in pool:
		var lane: int = target_lanes[i % target_lanes.size()] if spread else n.lane
		i += 1
		var cols := RhythmConfig.lane_columns(lane)
		var col := -1
		for k in cols:
			var try_col := (n.col + k) % cols
			var key := lane * 10 + try_col
			if not busy_until.has(key) or n.time - busy_until[key] > 0.06:
				col = try_col
				break
		if col < 0:
			continue   # sem coluna livre nesse instante: descarta
		var copy := _copy_note(n)
		copy.lane = lane
		copy.col = col
		busy_until[lane * 10 + col] = copy.time + copy.duration
		c.notes.append(copy)
	c.finish()
	return c


## Modo aleatório: ignora as notas do chart e sorteia notas novas para as lanes dadas, até "duration"
## segundos. As notas caem na grade de batidas do chart (colcheias do BPM dele), então combinam com
## a música. per_second = média de notas por segundo POR JOGADOR. seed_value 0 = sorteio novo a cada partida.
static func generate_random(source: RhythmChart, target_lanes: Array, duration: float,
		per_second: float, seed_value: int = 0) -> RhythmChart:
	var c := source._copy_header()
	var rng := RandomNumberGenerator.new()
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()

	var step := 60.0 / source.bpm / 2.0                   # colcheia
	var chance := clampf(per_second * step, 0.0, 1.0)     # chance de nota por lane a cada passo
	var first := 2.0                                      # deixa um respiro no começo
	var t := source.offset + ceilf((first - source.offset) / step) * step
	var busy_until := {}                                  # "lane*10+col" -> quando a coluna fica livre
	while t < duration - 0.5:
		for lane: int in target_lanes:
			if rng.randf() > chance:
				continue
			var cols := RhythmConfig.lane_columns(lane)
			var start_col := rng.randi_range(0, cols - 1)
			for k in cols:
				var col := (start_col + k) % cols
				var key := lane * 10 + col
				if busy_until.has(key) and t - busy_until[key] <= 0.2:
					continue
				var n := Note.new()
				n.time = t
				n.lane = lane
				n.col = col
				if rng.randf() < 0.08:                   # de vez em quando, nota longa
					n.duration = step * rng.randi_range(2, 4)
				busy_until[key] = n.time + n.duration
				c.notes.append(n)
				break
		t += step
	c.finish()
	return c


## Se o chart é mais curto que "duration", repete o padrão de notas até preencher o tempo todo.
func loop_to(duration: float) -> void:
	if notes.is_empty() or duration <= 0.0:
		return
	var first: float = (notes[0] as Note).time
	var period := maxf((end_time - first) + 60.0 / bpm * 4.0, 4.0)   # padrão + 1 compasso de respiro
	var original: Array = notes.duplicate()
	var k := 1
	while first + period * k <= duration - 0.5:
		for n: Note in original:
			var copy := _copy_note(n)
			copy.time += period * k
			if copy.time <= duration - 0.5:
				notes.append(copy)
		k += 1
	finish()


## Limita a faixa a "limit" segundos desde o início da música (0 = não limita).
## Remove as notas depois do limite e encurta notas longas que passariam dele.
func trim_to(limit: float) -> void:
	if limit <= 0.0:
		return
	duration_limit = limit
	notes = notes.filter(func(n: Note) -> bool: return n.time <= limit)
	for n: Note in notes:
		if n.time + n.duration > limit:
			n.duration = maxf(0.0, limit - n.time)
	finish()


# ───────────── carregar ─────────────

static func load_file(file_path: String) -> RhythmChart:
	if not FileAccess.file_exists(file_path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(file_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Erro ao ler chart '%s': JSON inválido." % file_path)
		return null
	var root: Dictionary = parsed

	var chart := RhythmChart.new()
	chart.path = file_path
	chart.title = str(root.get("title", file_path.get_file().get_basename()))
	chart.artist = str(root.get("artist", ""))
	chart.music_file = str(root.get("music", ""))
	chart.bpm = float(root.get("bpm", 120.0))
	chart.offset = float(root.get("offset", 0.0))
	chart.stage = str(root.get("stage", ""))

	var chars: Variant = root.get("characters", {})
	if typeof(chars) == TYPE_DICTIONARY:
		for id: String in chars:
			var v: Variant = chars[id]
			if typeof(v) != TYPE_DICTIONARY:
				continue
			var style := {
				"sprite": str(v.get("sprite", "")),
				"name": str(v.get("name", "")),
				"color": null,
				"enabled": not (v.has("enabled") and v["enabled"] == false),
			}
			var color_text := str(v.get("color", ""))
			if color_text != "":
				if Color.html_is_valid(color_text):
					style["color"] = Color.html(color_text)
				else:
					push_warning("Cor inválida '%s' em %s" % [color_text, file_path])
			chart.styles[id.to_lower()] = style

	var arr: Variant = root.get("notes", [])
	if typeof(arr) == TYPE_ARRAY:
		for n: Variant in arr:
			if typeof(n) != TYPE_DICTIONARY:
				continue
			var col: Variant = n.get("col", n.get("sub", 0))
			chart.add_note(float(n.get("beat", 0)), int(n.get("lane", 0)), int(col), float(n.get("len", 0)))
	chart.finish()
	return chart


## Chart mínimo, só para o jogo nunca ficar sem nada para tocar.
static func fallback() -> RhythmChart:
	var c := RhythmChart.new()
	c.title = ""   # chart de emergência: sem título para não aparecer mensagem na tela
	c.bpm = 120.0
	for i in 32:
		var lane := i % 3
		c.add_note(4 + i, lane, i % RhythmConfig.lane_columns(lane))
	c.finish()
	return c
