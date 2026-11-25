extends Control
## ESCOLHA DE MAPA (cenário) — vem depois da seleção de personagem.
## Mostra a FOTO grande do mapa selecionado, o nome e uma fileira de miniaturas. A lista vem de
## res://Versus/Dados/elenco_cenarios.tres (cada mapa é um "CenarioVersus" com "Foto" e "Fundo").
## CONTROLES: setas esquerda/direita (ou A D) trocam de mapa, ENTER/ESPAÇO/F confirmam, R sorteia, ESC volta.

# ───────────────────────── EXPORTS ─────────────────────────
## Lista de mapas. Vazio = usa res://Versus/Dados/elenco_cenarios.tres
@export var elenco: ElencoCenarios
## Quantas miniaturas aparecem de uma vez embaixo (a fileira rola se houver mais mapas).
@export_range(3, 9) var miniaturas_visiveis: int = 5

const LARGURA := 1366.0
const ALTURA := 768.0
const PREVIA := Vector2(700, 394)      # tamanho da foto grande
const MINI := Vector2(160, 90)         # tamanho de cada miniatura

var _mapas: Array[CenarioVersus] = []
var _indice := 0
var _saindo := false

var _palco: Control
var _fundo_desfocado: TextureRect
var _previa: TextureRect
var _moldura: Panel
var _nome: Label
var _contador: Label
var _faixa_mini: Control
var _sfx_mover: AudioStreamPlayer
var _sfx_ok: AudioStreamPlayer
var _tween_previa: Tween


## Carrega a lista e monta a tela.
func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if elenco == null:
		elenco = VersusEstado.carregar_cenarios()
	if elenco != null:
		for c in elenco.cenarios:
			if c != null and c.obter_foto() != null:
				_mapas.append(c)
	_montar_interface()
	_montar_audio()
	if _mapas.is_empty():
		_nome.text = "NENHUM MAPA NO ELENCO"
		_contador.text = "Adicione em Versus/Dados/elenco_cenarios.tres   (ENTER: continuar sem mapa)"
		return
	# se o jogador já tinha escolhido um mapa (voltou da escolha de música), começa nele
	if VersusEstado.cenario != null and _mapas.has(VersusEstado.cenario):
		_indice = _mapas.find(VersusEstado.cenario)
	_mostrar(false)


## Fundo, título, foto grande com moldura, nome, setas, miniaturas e dicas.
func _montar_interface() -> void:
	_fundo_desfocado = TextureRect.new()
	_fundo_desfocado.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fundo_desfocado.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fundo_desfocado.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_fundo_desfocado.modulate = Color(0.35, 0.35, 0.5)
	add_child(_fundo_desfocado)
	var veu := ColorRect.new()
	veu.color = Color(0.03, 0.02, 0.15, 0.55)
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

	var titulo := _rotulo(_palco, "ESCOLHA O CENÁRIO", 52, VersusEstilo.COR_AMARELO, 10)
	titulo.position = Vector2(0, 20)
	titulo.size = Vector2(LARGURA, 70)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# moldura + foto grande
	var px := (LARGURA - PREVIA.x) / 2.0
	_moldura = Panel.new()
	_moldura.position = Vector2(px - 8, 92)
	_moldura.size = PREVIA + Vector2(16, 16)
	_moldura.add_theme_stylebox_override("panel", VersusEstilo.caixa(Color(0.03, 0.03, 0.12), VersusEstilo.COR_AMARELO, 6, 8))
	_moldura.gui_input.connect(_ao_clicar_previa)
	_palco.add_child(_moldura)
	_previa = TextureRect.new()
	_previa.position = Vector2(8, 8)
	_previa.size = PREVIA
	_previa.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_previa.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_previa.clip_contents = true
	_previa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_moldura.add_child(_previa)

	# setas (triângulos) nas laterais da foto
	_palco.add_child(_triangulo(Vector2(px - 70, 92 + PREVIA.y / 2.0), -1))
	_palco.add_child(_triangulo(Vector2(px + PREVIA.x + 70, 92 + PREVIA.y / 2.0), 1))

	# nome do mapa sobre a foto (faixa embaixo)
	_nome = _rotulo(_palco, "", 44, Color.WHITE, 9)
	_nome.position = Vector2(0, 500)
	_nome.size = Vector2(LARGURA, 56)
	_nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_contador = _rotulo(_palco, "", 22, Color(1, 1, 1, 0.8), 4)
	_contador.position = Vector2(0, 552)
	_contador.size = Vector2(LARGURA, 30)
	_contador.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_faixa_mini = Control.new()
	_faixa_mini.position = Vector2(0, 590)
	_faixa_mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_palco.add_child(_faixa_mini)

	var dica := _rotulo(_palco, "SETAS ou A D: trocar          ENTER, ESPAÇO ou F: confirmar          R: sortear          ESC: voltar", 19, Color.WHITE, 4)
	dica.position = Vector2(0, 722)
	dica.size = Vector2(LARGURA, 26)
	dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


## Triângulo amarelo apontando para a esquerda (-1) ou direita (1), centrado em "pos".
func _triangulo(pos: Vector2, sentido: int) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array([Vector2(22 * sentido, 0), Vector2(-18 * sentido, -34), Vector2(-18 * sentido, 34)])
	p.color = VersusEstilo.COR_AMARELO
	p.position = pos
	return p


func _rotulo(pai: Node, texto: String, tam: int, cor: Color, contorno: int) -> Label:
	var l := Label.new()
	l.text = texto
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	VersusEstilo.estilizar_rotulo(l, tam, cor, contorno)
	pai.add_child(l)
	return l


func _montar_audio() -> void:
	_sfx_mover = AudioStreamPlayer.new()
	_sfx_mover.stream = VersusEstilo.bip(660.0, 0.05, 0.25)
	add_child(_sfx_mover)
	_sfx_ok = AudioStreamPlayer.new()
	_sfx_ok.stream = VersusEstilo.bip(990.0, 0.18, 0.3)
	add_child(_sfx_ok)


# ───────────────────────── EXIBIÇÃO ─────────────────────────

## Atualiza foto, nome, contador e miniaturas para o mapa selecionado (animado = faz a foto "entrar").
func _mostrar(animado: bool) -> void:
	var m := _mapas[_indice]
	_previa.texture = m.obter_foto()
	_fundo_desfocado.texture = m.obter_foto()
	_nome.text = m.nome_exibido
	_contador.text = "%d de %d" % [_indice + 1, _mapas.size()]
	_montar_miniaturas()
	if animado:
		if _tween_previa:
			_tween_previa.kill()
		_previa.modulate = Color(2, 2, 2, 0.4)
		_tween_previa = create_tween()
		_tween_previa.tween_property(_previa, "modulate", Color.WHITE, 0.2)


## Reconstrói a fileira de miniaturas (janela de "miniaturas_visiveis" mapas em volta do selecionado).
func _montar_miniaturas() -> void:
	for c in _faixa_mini.get_children():
		c.queue_free()
	var total := _mapas.size()
	var qtd := mini(miniaturas_visiveis, total)
	var inicio := clampi(_indice - qtd / 2, 0, total - qtd)
	var largura := qtd * MINI.x + (qtd - 1) * 14.0
	var x0 := (LARGURA - largura) / 2.0
	for k in qtd:
		var idx := inicio + k
		var sel := idx == _indice
		var p := Panel.new()
		p.position = Vector2(x0 + k * (MINI.x + 14.0), 0) + (Vector2.ZERO if sel else Vector2(0, 8))
		p.size = MINI * (1.0 if sel else 0.92)
		var borda := VersusEstilo.COR_AMARELO if sel else Color(1, 1, 1, 0.4)
		p.add_theme_stylebox_override("panel", VersusEstilo.caixa(Color(0, 0, 0, 0.6), borda, 5 if sel else 2, 4))
		p.gui_input.connect(_ao_clicar_miniatura.bind(idx))
		_faixa_mini.add_child(p)
		var tr := TextureRect.new()
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # antes da textura, senão a miniatura cresce até o tamanho da imagem
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.clip_contents = true
		tr.texture = _mapas[idx].obter_foto()
		tr.position = Vector2(4, 4)
		tr.size = p.size - Vector2(8, 8)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(tr)


# ───────────────────────── ENTRADA ─────────────────────────

## Teclado: trocar, confirmar, sortear e voltar.
func _unhandled_input(event: InputEvent) -> void:
	var ke := event as InputEventKey
	if ke == null or not ke.pressed or ke.echo or _saindo:
		return
	match ke.physical_keycode:
		KEY_ESCAPE:
			_saindo = true
			get_tree().change_scene_to_file(VersusEstado.CENA_SELECAO)
		KEY_LEFT, KEY_A: _trocar(-1)
		KEY_RIGHT, KEY_D: _trocar(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_F: _confirmar()
		KEY_R: _sortear()


## Troca para o mapa anterior (-1) ou próximo (+1), dando a volta nas pontas.
func _trocar(passo: int) -> void:
	if _mapas.size() < 2:
		return
	_indice = wrapi(_indice + passo, 0, _mapas.size())
	_sfx_mover.play()
	_mostrar(true)


## TECLA R: escolhe um mapa aleatório (diferente do atual, se possível). Ainda precisa confirmar.
func _sortear() -> void:
	if _mapas.size() < 2:
		return
	var novo := _indice
	while novo == _indice:
		novo = randi() % _mapas.size()
	_indice = novo
	_sfx_mover.play()
	_mostrar(true)


## Clique em uma miniatura: seleciona; clicar na já selecionada confirma.
func _ao_clicar_miniatura(evento: InputEvent, idx: int) -> void:
	var mb := evento as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT or _saindo:
		return
	if idx == _indice:
		_confirmar()
	else:
		_indice = idx
		_sfx_mover.play()
		_mostrar(true)


## Clique na foto grande confirma.
func _ao_clicar_previa(evento: InputEvent) -> void:
	var mb := evento as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_confirmar()


## Confirma o mapa, guarda no VersusEstado e vai para a escolha de música.
func _confirmar() -> void:
	if _saindo:
		return
	_saindo = true
	VersusEstado.cenario = _mapas[_indice] if not _mapas.is_empty() else null
	_sfx_ok.play()
	if _mapas.is_empty():
		get_tree().change_scene_to_file(VersusEstado.CENA_MUSICA)
		return
	_moldura.modulate = Color(2, 2, 2)
	create_tween().tween_property(_moldura, "modulate", Color.WHITE, 0.35)
	get_tree().create_timer(0.55).timeout.connect(func() -> void:
		get_tree().change_scene_to_file(VersusEstado.CENA_MUSICA))
