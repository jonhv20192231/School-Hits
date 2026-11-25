extends Control
## ESCOLHA DE MÚSICA — vem depois da escolha de mapa.
## Lista as músicas de res://Versus/Dados/elenco_musicas.tres (músicas completas + "Audios Rapidos"),
## toca uma PRÉVIA da música destacada e mostra os detalhes (capa, artista, BPM, duração) ao lado.
## CONTROLES: setas cima/baixo (ou W S) escolhem, ENTER/ESPAÇO/F confirmam, R sorteia, ESC volta.

# ───────────────────────── EXPORTS ─────────────────────────
## Lista de músicas. Vazio = usa res://Versus/Dados/elenco_musicas.tres
@export var elenco: ElencoMusicas
## Volume da prévia tocada ao destacar uma música.
@export_range(-40.0, 6.0, 0.5, "suffix:dB") var volume_previa_db: float = -8.0
## Quanto tempo (s) depois de destacar uma música a prévia começa a tocar.
@export_range(0.0, 2.0, 0.05) var atraso_previa: float = 0.35

const LARGURA := 1366.0
const ALTURA := 768.0
const ALTURA_LINHA := 66.0

var _musicas: Array[MusicaVersus] = []
var _indice := 0
var _saindo := false

var _palco: Control
var _rolagem: ScrollContainer
var _lista: VBoxContainer
var _linhas: Array[Button] = []
var _capa: TextureRect
var _disco: Control
var _nome: Label
var _artista: Label
var _info: Label
var _previa: AudioStreamPlayer
var _sfx_mover: AudioStreamPlayer
var _sfx_ok: AudioStreamPlayer
var _timer_previa := -1.0
var _tempo := 0.0


## Carrega as músicas e monta a tela.
func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if elenco == null:
		elenco = VersusEstado.carregar_musicas()
	if elenco != null:
		_musicas = elenco.todas()
	_montar_interface()
	_montar_audio()
	if _musicas.is_empty():
		_nome.text = "NENHUMA MÚSICA NO ELENCO"
		_info.text = "Adicione em Versus/Dados/elenco_musicas.tres\n(ENTER: continuar com a música padrão)"
		return
	if VersusEstado.musica != null and _musicas.has(VersusEstado.musica):
		_indice = _musicas.find(VersusEstado.musica)
	_atualizar(false)


## Fundo, título, lista rolável à esquerda e painel de detalhes à direita.
func _montar_interface() -> void:
	var bg := TextureRect.new()
	bg.texture = VersusEstado.cenario.obter_fundo() if VersusEstado.cenario != null else null
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.modulate = Color(0.35, 0.35, 0.5)
	add_child(bg)
	var veu := ColorRect.new()
	veu.color = Color(0.04, 0.03, 0.18, 0.7)
	veu.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(veu)

	_palco = Control.new()
	_palco.set_anchors_preset(Control.PRESET_CENTER)
	_palco.offset_left = -LARGURA / 2.0
	_palco.offset_right = LARGURA / 2.0
	_palco.offset_top = -ALTURA / 2.0
	_palco.offset_bottom = ALTURA / 2.0
	_palco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_palco)

	var titulo := _rotulo(_palco, "ESCOLHA A MÚSICA", 52, VersusEstilo.COR_AMARELO, 10)
	titulo.position = Vector2(0, 20)
	titulo.size = Vector2(LARGURA, 70)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# lista rolável
	var painel_lista := Panel.new()
	painel_lista.position = Vector2(50, 110)
	painel_lista.size = Vector2(700, 580)
	painel_lista.add_theme_stylebox_override("panel", VersusEstilo.caixa(Color(0.05, 0.05, 0.18, 0.88), Color("8aa0ff"), 4, 10))
	_palco.add_child(painel_lista)
	_rolagem = ScrollContainer.new()
	_rolagem.position = Vector2(10, 10)
	_rolagem.size = Vector2(680, 560)
	_rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	painel_lista.add_child(_rolagem)
	_lista = VBoxContainer.new()
	_lista.custom_minimum_size = Vector2(660, 0)
	_lista.add_theme_constant_override("separation", 6)
	_rolagem.add_child(_lista)
	for i in _musicas.size():
		_lista.add_child(_criar_linha(i))

	# painel de detalhes
	var det := Panel.new()
	det.position = Vector2(790, 110)
	det.size = Vector2(526, 580)
	det.add_theme_stylebox_override("panel", VersusEstilo.caixa(Color(0.05, 0.05, 0.18, 0.88), VersusEstilo.COR_AMARELO, 4, 10))
	_palco.add_child(det)
	_capa = TextureRect.new()
	_capa.position = Vector2(133, 24)
	_capa.size = Vector2(260, 260)
	_capa.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_capa.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_capa.clip_contents = true
	det.add_child(_capa)
	_disco = Control.new()   # "disco de vinil" desenhado quando a música não tem capa
	_disco.position = _capa.position
	_disco.size = _capa.size
	_disco.draw.connect(_desenhar_disco)
	det.add_child(_disco)
	_nome = _rotulo(det, "", 34, Color.WHITE, 8)
	_nome.position = Vector2(10, 300)
	_nome.size = Vector2(506, 100)
	_nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_artista = _rotulo(det, "", 24, VersusEstilo.COR_AMARELO, 6)
	_artista.position = Vector2(10, 410)
	_artista.size = Vector2(506, 40)
	_artista.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info = _rotulo(det, "", 24, Color.WHITE, 5)
	_info.position = Vector2(10, 470)
	_info.size = Vector2(506, 100)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var dica := _rotulo(_palco, "SETAS ou W S: escolher          ENTER, ESPAÇO ou F: confirmar          R: sortear          ESC: voltar", 19, Color.WHITE, 4)
	dica.position = Vector2(0, 716)
	dica.size = Vector2(LARGURA, 26)
	dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


## Cria o botão (linha) da música i: nome à esquerda, artista e BPM à direita.
func _criar_linha(i: int) -> Button:
	var m := _musicas[i]
	var b := Button.new()
	b.custom_minimum_size = Vector2(660, ALTURA_LINHA)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(_ao_clicar_linha.bind(i))
	var l1 := _rotulo(b, m.nome_exibido, 26, Color("22306b"), 0)
	l1.position = Vector2(16, 6)
	l1.size = Vector2(628, 32)
	l1.clip_text = true
	var sub := m.artista if m.artista != "" else "BPM %d" % int(m.bpm)
	var l2 := _rotulo(b, sub, 18, Color("4a5a99"), 0)
	l2.position = Vector2(16, 36)
	l2.size = Vector2(628, 24)
	l2.clip_text = true
	_linhas.append(b)
	return b


func _rotulo(pai: Node, texto: String, tam: int, cor: Color, contorno: int) -> Label:
	var l := Label.new()
	l.text = texto
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	VersusEstilo.estilizar_rotulo(l, tam, cor, contorno)
	pai.add_child(l)
	return l


func _montar_audio() -> void:
	_previa = AudioStreamPlayer.new()
	_previa.volume_db = volume_previa_db
	add_child(_previa)
	_previa.finished.connect(_ao_acabar_previa)
	_sfx_mover = AudioStreamPlayer.new()
	_sfx_mover.stream = VersusEstilo.bip(660.0, 0.05, 0.25)
	add_child(_sfx_mover)
	_sfx_ok = AudioStreamPlayer.new()
	_sfx_ok.stream = VersusEstilo.bip(990.0, 0.18, 0.3)
	add_child(_sfx_ok)


## Vinil simples (círculos) para músicas sem capa; gira devagar enquanto a prévia toca.
func _desenhar_disco() -> void:
	var c := _disco.size / 2.0
	_disco.draw_circle(c, 126.0, Color(0.05, 0.05, 0.08))
	for r in [110.0, 90.0, 70.0]:
		_disco.draw_arc(c, r, 0.0, TAU, 48, Color(1, 1, 1, 0.08), 2.0)
	_disco.draw_circle(c, 46.0, VersusEstilo.COR_AMARELO)
	_disco.draw_circle(c, 7.0, Color(0.05, 0.05, 0.08))
	var a := _tempo * 1.2
	_disco.draw_line(c + Vector2.from_angle(a) * 52.0, c + Vector2.from_angle(a) * 118.0, Color(1, 1, 1, 0.25), 3.0)


# ───────────────────────── ATUALIZAÇÃO ─────────────────────────

## Destaca a linha escolhida, rola a lista até ela, atualiza os detalhes e agenda a prévia.
func _atualizar(tocar_som: bool) -> void:
	for i in _linhas.size():
		var sel := i == _indice
		var b := _linhas[i]
		var normal := VersusEstilo.caixa(VersusEstilo.COR_AMARELO if sel else VersusEstilo.COR_PAINEL, Color("c0392b") if sel else VersusEstilo.COR_BORDA, 5 if sel else 3, 8)
		for estilo in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(estilo, normal)
	_rolagem.ensure_control_visible(_linhas[_indice])
	var m := _musicas[_indice]
	_capa.texture = m.capa
	_capa.visible = m.capa != null
	_disco.visible = m.capa == null
	_nome.text = m.nome_exibido
	_artista.text = m.artista
	var dur := m.audio.get_length() if m.audio != null else 0.0
	_info.text = "BPM: %d          DURAÇÃO: %d:%02d" % [int(m.bpm), int(dur) / 60, int(dur) % 60]
	if tocar_som:
		_sfx_mover.play()
	_previa.stop()
	_timer_previa = atraso_previa


func _process(delta: float) -> void:
	_tempo += delta
	if _disco != null and _disco.visible:
		_disco.queue_redraw()
	if _timer_previa >= 0.0:
		_timer_previa -= delta
		if _timer_previa < 0.0:
			_tocar_previa()


## Toca a prévia da música destacada a partir de "inicio_previa".
func _tocar_previa() -> void:
	if _musicas.is_empty() or _saindo:
		return
	var m := _musicas[_indice]
	_previa.stream = m.audio
	_previa.play(clampf(m.inicio_previa, 0.0, maxf(m.audio.get_length() - 1.0, 0.0)))


## Prévia terminou: toca de novo desde o começo da prévia.
func _ao_acabar_previa() -> void:
	if not _saindo and not _musicas.is_empty():
		_tocar_previa()


# ───────────────────────── ENTRADA ─────────────────────────

## Teclado: escolher, confirmar, sortear e voltar.
func _unhandled_input(event: InputEvent) -> void:
	var ke := event as InputEventKey
	if ke == null or not ke.pressed or _saindo:
		return
	var k := ke.physical_keycode
	if ke.echo and k != KEY_UP and k != KEY_DOWN and k != KEY_W and k != KEY_S:
		return   # segurar as setas continua rolando a lista
	match k:
		KEY_ESCAPE:
			_sair(VersusEstado.CENA_MAPA)
		KEY_UP, KEY_W: _mover(-1)
		KEY_DOWN, KEY_S: _mover(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_F: _confirmar()
		KEY_R: _sortear()


## Sobe (-1) ou desce (+1) na lista, dando a volta nas pontas.
func _mover(passo: int) -> void:
	if _musicas.size() < 2:
		return
	_indice = wrapi(_indice + passo, 0, _musicas.size())
	_atualizar(true)


## TECLA R: destaca uma música aleatória (ainda precisa confirmar).
func _sortear() -> void:
	if _musicas.size() < 2:
		return
	var novo := _indice
	while novo == _indice:
		novo = randi() % _musicas.size()
	_indice = novo
	_atualizar(true)


## Clique em uma linha: destaca; clicar na já destacada confirma.
func _ao_clicar_linha(i: int) -> void:
	if i == _indice:
		_confirmar()
	else:
		_indice = i
		_atualizar(true)


## Confirma a música e vai para a cutscene de apresentação.
func _confirmar() -> void:
	if _saindo:
		return
	VersusEstado.musica = _musicas[_indice] if not _musicas.is_empty() else null
	_sfx_ok.play()
	_sair(VersusEstado.CENA_APRESENTACAO)


## Para a prévia e troca de cena.
func _sair(cena: String) -> void:
	_saindo = true
	_previa.stop()
	get_tree().create_timer(0.2).timeout.connect(func() -> void:
		get_tree().change_scene_to_file(cena))
