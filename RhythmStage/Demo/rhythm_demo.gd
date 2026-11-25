extends CanvasLayer
## CENA DE RITMO REUTILIZÁVEL (rhythm_demo.tscn).
##
## A raiz é um CanvasLayer: a tela de ritmo (inclusive o resultado no meio da tela) se posiciona pela
## JANELA, não pelo nó onde ela for instanciada. Funciona igual dentro de Node2D, Control, mundo com
## câmera etc. A propriedade "Layer" do Inspector define quem fica por cima (deixe o seu menu/HUD
## com um Layer maior para ele aparecer sobre o ritmo).
##
## Para usar em outra cena: arraste rhythm_demo.tscn para ela (ou Instanciar Cena Filha) e ajuste as
## propriedades DESTE nó raiz no Inspector: música, duração, quantidade de jogadores e notas aleatórias.
## Não precisa abrir os filhos. Por código:
##     var ritmo = preload("res://RhythmStage/Demo/rhythm_demo.tscn").instantiate()
##     ritmo.players = 2
##     ritmo.duration_seconds = 90.0
##     ritmo.rhythm_finished.connect(_on_ritmo_fim)
##     add_child(ritmo)
##
## Esta cena NÃO trata o ESC: o seu HUD/menu continua dono dessa tecla.
## O resultado (pontos, erros e parabéns) só aparece no FINAL da música, no meio da tela.

## A música terminou (com ou sem o painel de resultado na tela).
signal rhythm_finished(score: int, accuracy: float, rank: String, max_combo: int)
## O jogador apertou ENTER para continuar no resultado (emitido antes da ação escolhida em "Continue Action").
signal continue_requested

@export var player: RhythmPlayer

@export_group("Música")
## Chart (.json) da música. Define a música que toca e o BPM em que as notas caem.
@export_file("*.json") var chart_path := "res://RhythmStage/charts/seiza_ni_naretara.json"
## Duração da faixa em segundos, contada do início da música. 0 = música inteira.
## Se for maior que a música, ela toca de novo até completar o tempo.
@export_range(0.0, 600.0, 1.0, "or_greater", "suffix:s") var duration_seconds := 60.0
## Se a duração for maior que o chart, repete as notas dele até completar o tempo.
@export var fill_duration := true

@export_group("Jogadores")
## Quantos jogadores tocam ao mesmo tempo. Só aparecem a pista e o nome de quem está jogando.
## "Do chart" = as lanes que o .json da música define.
@export_enum("Do chart", "1 jogador", "2 jogadores", "3 jogadores") var players := 3
## Ordem em que os personagens entram: 0 = ANA, 1 = MARCOS, 2 = JUNPEI. O primeiro da lista é o jogador 1.
@export var lane_order: PackedInt32Array = PackedInt32Array([1, 0, 2])
## Com mais de 1 jogador: reparte as notas do chart entre eles.
@export var distribute_notes := true

@export_group("Notas aleatórias")
## As notas aparecem de forma aleatória, sem parar, até o fim da duração escolhida.
@export var random_notes := true
## Média de notas por segundo, por jogador.
@export_range(0.5, 8.0, 0.1) var random_notes_per_second := 1.8
## 0 = sorteio diferente a cada partida. Outro número repete sempre a mesma sequência.
@export var random_seed := 0

@export_group("Cena")
## Começa sozinha ao entrar na cena. Desligue para chamar start_music() quando quiser.
@export var auto_start := true
## Mostra o fundo (cenário escurecido e chão). Desligue para jogar o ritmo por cima da sua própria cena.
@export var show_background := true
## Mostra o painel de resultado no meio da tela quando a música acaba.
@export var show_results := true
## O que acontece quando o jogador aperta ENTER para continuar, no resultado final:
## reinicia a cena atual do jogo (padrão), reinicia só a música, ou nada (use o sinal continue_requested).
@export_enum("Reiniciar a cena atual", "Reiniciar só a música", "Nada (só avisar pelo sinal)") var continue_action := 0
## R ao final permite trocar de cena ou reiniciar. Desligue se outra cena controla isso.
@export var allow_restart := true
## Cena para qual o jogo vai ao apertar R no final (Deixe vazio para reiniciar a música atual).
@export_file("*.tscn") var next_scene_path := ""

## Variável interna para controlar se o jogador já pode apertar R
var _can_restart := false

@onready var _score_label: Label = %ScoreLabel
@onready var _combo_label: Label = %ComboLabel
@onready var _info_label: Label = %InfoLabel
@onready var _help_label: Label = %AjudaLabel
@onready var _countdown_label: Label = %CountdownLabel
@onready var _results_panel: Control = %ResultsPanel
@onready var _title_label: Label = %TitleLabel
@onready var _message_label: Label = %MessageLabel
@onready var _results_label: Label = %ResultsLabel
@onready var _hint_label: Label = %HintLabel


func _ready() -> void:
	_results_panel.visible = false
	_can_restart = false
	for bg in ["Background", "Escurecer", "Chao"]:
		var node := get_node_or_null(bg) as CanvasItem
		if node != null:
			node.visible = show_background
	if player == null:
		push_error("RhythmDemo: aponte a propriedade 'player' para o RhythmPlayer.")
		return

	player.started.connect(_on_started)
	player.finished.connect(_on_finished)
	if auto_start:
		start_music()


## (Re)começa a música com as propriedades atuais desta cena.
func start_music() -> void:
	_can_restart = false
	_results_panel.visible = false
	player.chart_path = chart_path
	player.duration_seconds = duration_seconds
	player.fill_duration = fill_duration
	player.players = players
	player.lane_order = lane_order
	player.distribute_notes = distribute_notes
	player.random_notes = random_notes
	player.random_notes_per_second = random_notes_per_second
	player.random_seed = random_seed
	player.start()


func stop_music() -> void:
	player.stop()
	_results_panel.visible = false
	_can_restart = false


func _process(_delta: float) -> void:
	if player == null or player.play == null:
		return
	var sc := player.score
	_score_label.text = "PONTOS %06d" % sc.score
	_combo_label.text = ("COMBO x%d" % sc.combo) if sc.combo > 1 else ""
	_countdown_label.text = str(ceili(-player.song_time)) if player.song_time < 0.0 else ""


func _on_started() -> void:
	_results_panel.visible = false
	_can_restart = false
	var chart := player.chart
	var count := player.active_player_count()
	var artist := (" — " + chart.artist) if chart.artist != "" else ""
	var jogadores := "%d jogador%s" % [count, "" if count == 1 else "es"]
	var duracao := ("  •  %ds" % int(chart.duration_limit)) if chart.duration_limit > 0.0 else ""
	if player.random_notes:
		duracao += "  •  aleatório"
	var linhas: PackedStringArray = []
	if chart.title.strip_edges() != "":
		linhas.append(chart.title + artist)
	linhas.append("%d BPM  •  %d notas" % [int(chart.bpm), chart.notes.size()])
	linhas.append(jogadores + duracao)
	_info_label.text = "\n".join(linhas)

	# ajuda apenas com as teclas de quem está jogando (sem a tecla R durante a música)
	var parts: PackedStringArray = []
	for lane in RhythmConfig.lanes.size():
		if player.is_lane_active(lane):
			var labels := PackedStringArray(RhythmConfig.lanes[lane]["labels"])
			parts.append("%s: %s" % [player.styles[lane]["name"], " ".join(labels)])
	_help_label.text = "   •   ".join(parts)


func _on_finished(final_score: int, accuracy: float, rank: String, max_combo: int) -> void:
	rhythm_finished.emit(final_score, accuracy, rank, max_combo)
	_can_restart = true # Libera a tecla R apenas agora que terminou
	
	if not show_results:
		return

	var counts: Array = player.score.counts
	_title_label.text = "PARABÉNS!"
	_message_label.text = _congrats(rank)
	
	var acao_texto := "próxima cena" if next_scene_path != "" else "reiniciar música"
	
	_results_label.text = "PONTUAÇÃO: %d\nPRECISÃO: %.1f%%    RANK: %s\nCOMBO MÁXIMO: %d\n\n%s %d    %s %d    %s %d\nERROS: %d" % [
		final_score, accuracy * 100.0, rank, max_combo,
		RhythmConfig.JUDGMENT_NAMES[0], counts[0], RhythmConfig.JUDGMENT_NAMES[1], counts[1],
		RhythmConfig.JUDGMENT_NAMES[2], counts[2], counts[3],
	]
	
	# Exibe no painel de resultados a instrução para apertar R e ENTER
	if allow_restart:
		_hint_label.text = "ENTER: continuar   |   R: " + acao_texto
	else:
		_hint_label.text = "ENTER: continuar" if continue_action != 2 else ""
		
	_results_panel.visible = true


func _congrats(rank: String) -> String:
	match rank:
		"S":
			return "Você terminou a música com uma performance perfeita!"
		"A":
			return "Você terminou a música e mandou muito bem!"
		"B":
			return "Você terminou a música. Falta pouco para a nota máxima!"
	return "Você terminou a música. Treine mais um pouco e tente de novo!"


func _unhandled_input(event: InputEvent) -> void:
	if player == null:
		return
	var ke := event as InputEventKey
	if ke == null or not ke.pressed or ke.echo:
		return
		
	match ke.physical_keycode:
		KEY_R:
			# Só executa se allow_restart estiver ligado E a música/notas tiverem acabado (_can_restart)
			if allow_restart and _can_restart:
				get_viewport().set_input_as_handled()
				if next_scene_path != "":
					get_tree().change_scene_to_file(next_scene_path)
				else:
					start_music()
		KEY_ENTER, KEY_KP_ENTER:
			if _results_panel.visible:
				get_viewport().set_input_as_handled()
				_continue()


## O jogador quer continuar depois do resultado.
func _continue() -> void:
	_results_panel.visible = false   # evita apertar ENTER duas vezes
	continue_requested.emit()
	match continue_action:
		0:
			if get_tree().current_scene != null:
				get_tree().reload_current_scene()
			else:
				start_music()
		1:
			start_music()
		_:
			pass
