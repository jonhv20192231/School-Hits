class_name RhythmPlayer
extends Node
## COMPONENTE REUTILIZÁVEL do ritmo: solte este nó em QUALQUER cena e ele toca um chart.
## Faz o trabalho do Main.cs + Conductor.cs + Session.cs + Sfx.cs (tudo junto, em GDScript puro),
## mas SEM desenhar nada e SEM menus. Quem quiser ver as notas adiciona um RhythmNoteField,
## quem quiser personagens animados usa RhythmCharacter, e quem quiser reagir ao jogo escuta os sinais.
##
## Uso mínimo em outra cena:
##     @onready var ritmo: RhythmPlayer = $RhythmPlayer
##     func _ready():
##         ritmo.judged.connect(_on_julgado)      # (lane, judgment, sloppy, col)
##         ritmo.finished.connect(_on_fim)        # (score, accuracy, rank, max_combo)
##         ritmo.start("res://RhythmStage/charts/never forget.json")

## A música (re)começou: já dá para ler chart e styles.
signal started
## Cada acerto/erro. judgment: 0 PERFECT, 1 GREAT, 2 GOOD, 3 MISS (ver RhythmConfig.JUDGMENT_NAMES).
signal judged(lane: int, judgment: int, sloppy: bool, col: int)
## Uma tecla de coluna foi apertada (pressed = true) ou solta.
signal column_changed(lane: int, col: int, pressed: bool)
## A música acabou. rank = "S", "A", "B" ou "C"; accuracy vai de 0 a 1.
signal finished(score: int, accuracy: float, rank: String, max_combo: int)

@export_group("Chart")
## Chart (.json) que será tocado. Se não existir, toca o chart de teste embutido.
@export_file("*.json") var chart_path := "res://RhythmStage/charts/seiza_ni_naretara.json"
## Começa sozinho ao entrar na cena. Desligue para chamar start() quando quiser.
@export var auto_start := true

@export_group("Jogadores e duração")
## Quantos jogadores tocam AO MESMO TEMPO (cada um com as teclas da própria lane/personagem).
## "Do chart" = usa as lanes que o .json da música define (comportamento original).
@export_enum("Do chart", "1 jogador", "2 jogadores", "3 jogadores") var players := 0
## Ordem em que os personagens entram: 0 = ANA, 1 = MARCOS, 2 = JUNPEI.
## Com 1 jogador toca o primeiro da lista; com 2, os dois primeiros; com 3, todos.
@export var lane_order: PackedInt32Array = PackedInt32Array([1, 0, 2])
## Com mais de 1 jogador: reparte as notas do chart entre eles (cada um toca uma parte).
## Desligado, cada jogador só toca as notas que o chart já tinha na lane dele.
@export var distribute_notes := true
## Quanto tempo a faixa dura, em segundos, contando do início da música. 0 = música inteira.
@export_range(0.0, 600.0, 1.0, "or_greater", "suffix:s") var duration_seconds := 0.0

## Se a duração for maior que o chart, repete as notas dele até completar o tempo (e a música toca de novo).
@export var fill_duration := true

@export_group("Notas aleatórias")
## Ignora as notas do chart e sorteia notas novas, até o fim da duração escolhida acima.
## As notas seguem o BPM do chart, então combinam com a música dele.
@export var random_notes := false
## Média de notas por segundo, POR JOGADOR.
@export_range(0.5, 8.0, 0.1) var random_notes_per_second := 1.8
## 0 = sorteio diferente a cada partida. Qualquer outro número repete sempre as mesmas notas.
@export var random_seed := 0

@export_group("Opções")
## Lê as teclas das lanes (RhythmConfig.lanes). Desligue se a cena controla o input por conta própria.
@export var input_enabled := true
@export var sfx_enabled := true
@export var anti_spam := false
@export_range(0.0, 1.0, 0.05) var spam_score_factor := 0.5
## Ao terminar, grava rhythm_score / rhythm_accuracy / rhythm_rank / rhythm_max_combo no root
## (as mesmas chaves do RhythmLauncher), para outras cenas lerem com get_tree().root.get_meta(...).
@export var save_result_in_root := true

# ───────────── estado (só leitura para as views) ─────────────

var play: RhythmGameplay              # lógica da partida (null antes do primeiro start)
var chart: RhythmChart                # chart em jogo (cópia só com as lanes ativas)
var song_time := -RhythmConfig.LEAD_IN   # tempo da música em segundos; começa negativo (contagem)
var is_playing := false
## Um por lane: { name, color, sprite, active } (o chart pode trocar nome/cor e desligar lanes)
var styles: Array = []
## Nome do fundo pedido pelo chart (sem extensão). "background" se não pedir nenhum.
var stage_name := "background"

var score: RhythmScore:
	get:
		return play.score if play != null else null

var _music: AudioStreamPlayer
var _hit_sfx: AudioStreamPlayer
var _miss_sfx: AudioStreamPlayer
var _has_music := false
var _music_started := false
var _music_base := 0.0                # soma das repetições da música (quando a duração é maior que ela)
var _down: Array = []                 # _down[lane][col] = tecla apertada agora?


func _ready() -> void:
	_music = AudioStreamPlayer.new()
	add_child(_music)
	_hit_sfx = _make_sfx_player("res://RhythmStage/sfx/hit.wav", 880.0, 0.06)
	_miss_sfx = _make_sfx_player("res://RhythmStage/sfx/miss.wav", 140.0, 0.12)

	for lane in RhythmConfig.lanes.size():
		var cols: Array = []
		cols.resize(RhythmConfig.lane_columns(lane))
		cols.fill(false)
		_down.append(cols)
	_apply_chart(null)

	if auto_start:
		start()


# ───────────── controle ─────────────

## Começa (ou recomeça) a música. Passe um chart para trocar; sem argumento usa chart_path.
func start(path: String = "") -> void:
	if _music == null:
		push_error("RhythmPlayer.start() chamado antes de _ready (o nó ainda não está na árvore).")
		return
	if path != "":
		chart_path = path

	RhythmConfig.anti_spam_enabled = anti_spam
	RhythmConfig.spam_score_factor = spam_score_factor

	var source: RhythmChart = RhythmChart.load_file(chart_path)
	if source == null or source.notes.is_empty():
		source = RhythmChart.fallback()   # chart de emergência, em silêncio (sem mensagem na tela)

	_apply_chart(source)
	if players > 0:
		# Modo "N jogadores": as lanes ativas são as N primeiras de lane_order,
		# e as notas do chart são redistribuídas entre elas.
		var chosen := _chosen_lanes()
		for lane in styles.size():
			styles[lane]["active"] = chosen.has(lane)
		if random_notes:
			chart = RhythmChart.generate_random(source, chosen, _random_length(source),
				random_notes_per_second, random_seed)
		else:
			chart = source.retarget(chosen, distribute_notes)
	elif random_notes:
		# Aleatório sem escolher jogadores: usa as lanes que o chart deixa ativas (ou todas).
		if _active_count() == 0:
			for st: Dictionary in styles:
				st["active"] = true
		var lanes: Array = []
		for lane in styles.size():
			if styles[lane]["active"]:
				lanes.append(lane)
		chart = RhythmChart.generate_random(source, lanes, _random_length(source),
			random_notes_per_second, random_seed)
	else:
		# Mesma regra do Main.PrepareChart: o chart decide quem toca ("characters" no .json) e
		# a partida nunca fica sem lanes ou sem notas.
		if _active_count() == 0:
			for st: Dictionary in styles:
				st["active"] = true
		chart = source.clone_for(is_lane_active)
		if chart.notes.is_empty():
			for st: Dictionary in styles:
				st["active"] = true
			chart = source.clone_for(func(_lane: int) -> bool: return true)

	if duration_seconds > 0.0:
		if fill_duration and not random_notes and chart.end_time < duration_seconds - 1.0:
			chart.loop_to(duration_seconds)
		chart.trim_to(duration_seconds)
		if chart.notes.is_empty():
			push_warning("RhythmPlayer: duration_seconds (%.0fs) não deixou nenhuma nota. Aumente a duração." % duration_seconds)

	if play != null and play.judged.is_connected(_on_gameplay_judged):
		play.judged.disconnect(_on_gameplay_judged)
	play = RhythmGameplay.new(chart)
	play.judged.connect(_on_gameplay_judged)

	_clear_down()
	_music.stop()
	_music.stream = chart.load_music()
	_has_music = _music.stream != null
	_music_started = false
	_music_base = 0.0
	song_time = -RhythmConfig.LEAD_IN

	is_playing = true
	started.emit()


func restart() -> void:
	start()


func stop() -> void:
	is_playing = false
	if _music != null:
		_music.stop()
	_clear_down()


## Até quando sortear notas: a duração escolhida, ou o tamanho do chart se ela for 0.
func _random_length(source: RhythmChart) -> float:
	return duration_seconds if duration_seconds > 0.0 else maxf(source.end_time, 30.0)


## Quantos jogadores (lanes ativas) estão tocando nesta partida.
func active_player_count() -> int:
	return _active_count()


## Lanes escolhidas pelo modo "N jogadores", na ordem de lane_order.
func _chosen_lanes() -> Array:
	var order: Array = []
	for l in lane_order:
		if l >= 0 and l < RhythmConfig.lanes.size() and not order.has(l):
			order.append(l)
	for l in RhythmConfig.lanes.size():   # completa o que faltar na lista
		if not order.has(l):
			order.append(l)
	return order.slice(0, clampi(players, 1, 3))


func is_lane_active(lane: int) -> bool:
	return styles[lane]["active"]


func lane_color(lane: int) -> Color:
	return styles[lane]["color"]


## A tecla desta coluna está apertada agora? (para efeitos visuais)
func is_down(lane: int, col: int) -> bool:
	if lane < 0 or lane >= _down.size() or col < 0 or col >= _down[lane].size():
		return false
	return _down[lane][col]


# ───────────── estilos (Session.ApplyChart) ─────────────

func _apply_chart(source: RhythmChart) -> void:
	styles.clear()
	for lane in RhythmConfig.lanes.size():
		var def: Dictionary = RhythmConfig.lanes[lane]
		var st := {
			"name": def["name"], "color": def["color"], "sprite": def["id"], "active": true,
		}
		if source != null and source.styles.has(def["id"]):
			var cs: Dictionary = source.styles[def["id"]]
			if cs["sprite"] != "":
				st["sprite"] = cs["sprite"]
			if cs["name"] != "":
				st["name"] = cs["name"]
			if cs["color"] != null:
				st["color"] = cs["color"]
			st["active"] = cs["enabled"]
		styles.append(st)
	stage_name = source.stage if source != null and source.stage != "" else "background"


func _active_count() -> int:
	var n := 0
	for st: Dictionary in styles:
		if st["active"]:
			n += 1
	return n


# ───────────── loop ─────────────

func _process(delta: float) -> void:
	if not is_playing or play == null:
		return

	_advance_clock(delta)
	play.update(song_time)
	if play.is_finished(song_time):
		_finish()


## Relógio da música (Conductor.Advance): enquanto a música toca, o tempo vem do áudio
## (corrigido pela latência); antes disso é a contagem inicial.
func _advance_clock(delta: float) -> void:
	if _has_music and _music.playing:
		song_time = _music_base + _music.get_playback_position() \
			+ AudioServer.get_time_since_last_mix() \
			- AudioServer.get_output_latency() \
			+ RhythmConfig.audio_offset
		# faixa com duração escolhida: corta a música no limite (o relógio segue pelo delta)
		if chart.duration_limit > 0.0 and song_time >= chart.duration_limit:
			_music.stop()
		return

	song_time += delta
	if _has_music and not _music_started and song_time >= 0.0:
		_music_started = true   # toca só uma vez (se a música acabar antes do chart, não reinicia)
		_music.play()
	elif _has_music and _music_started and chart.duration_limit > 0.0 \
			and song_time < chart.duration_limit - 0.3:
		# a música acabou antes da duração escolhida: toca de novo
		_music_base += maxf(_music.stream.get_length(), 0.1)
		_music.play()


func _finish() -> void:
	is_playing = false
	_music.stop()
	_clear_down()

	var sc := play.score
	if save_result_in_root:
		var root := get_tree().root
		root.set_meta("rhythm_score", sc.score)
		root.set_meta("rhythm_accuracy", sc.accuracy())
		root.set_meta("rhythm_rank", sc.rank())
		root.set_meta("rhythm_max_combo", sc.max_combo)
	finished.emit(sc.score, sc.accuracy(), sc.rank(), sc.max_combo)


func _on_gameplay_judged(lane: int, judgment: int, sloppy: bool, col: int) -> void:
	if sfx_enabled:
		if judgment == RhythmConfig.Judgment.MISS:
			_miss_sfx.play()
		else:
			_hit_sfx.pitch_scale = 1.0 + 0.25 * lane
			_hit_sfx.play()
	judged.emit(lane, judgment, sloppy, col)


# ───────────── input ─────────────

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or not is_playing or play == null:
		return
	var ke := event as InputEventKey
	if ke == null or ke.echo:
		return

	var key: Key = ke.physical_keycode
	for lane in RhythmConfig.lanes.size():
		if not is_lane_active(lane):
			continue   # personagem fora desta música: sem input
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


func _clear_down() -> void:
	for cols: Array in _down:
		cols.fill(false)


# ───────────── efeitos sonoros (Sfx.cs) ─────────────

## Usa o arquivo se existir; senão um beep gerado por código.
func _make_sfx_player(file: String, freq: float, seconds: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	if ResourceLoader.exists(file):
		p.stream = load(file)
	else:
		p.stream = _beep(freq, seconds)
	add_child(p)
	return p


static func _beep(freq: float, seconds: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * seconds)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var env := 1.0 - float(i) / n
		var s := int(sin(TAU * freq * i / rate) * 12000.0 * env)
		data.encode_s16(i * 2, s)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav
