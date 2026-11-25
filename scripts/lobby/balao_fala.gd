extends CanvasLayer
## Caixa de fala do lobby (fica fixa na tela, embaixo). Mostra uma lista de falas em
## sequência, com efeito de digitação. Enter/Espaço (ui_accept) avança mais rápido.
## Cada fala: { "nome": String, "texto": String, "cor": Color, "retrato": Texture2D }

signal linha_exibida(indice: int)

const FONTE_NOME := "res://Assets/fonte/MonsterFriendFore.otf"

var segundos_por_linha := 2.2

var _linhas: Array = []
var _i := -1
var _ativo := false
var _digitando := false
var _espera := 0.0
var _tween: Tween
var _painel: PanelContainer
var _retrato: TextureRect
var _nome: Label
var _texto: Label


func _init() -> void:
	layer = 20
	visible = false
	var raiz := Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(raiz)

	_painel = PanelContainer.new()
	_painel.anchor_left = 0.07
	_painel.anchor_right = 0.93
	_painel.anchor_top = 1.0
	_painel.anchor_bottom = 1.0
	_painel.offset_top = -150
	_painel.offset_bottom = -18
	_painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var caixa := StyleBoxFlat.new()
	caixa.bg_color = Color(0.07, 0.05, 0.14, 0.95)
	caixa.border_color = Color(1.0, 0.86, 0.4)
	caixa.set_border_width_all(3)
	caixa.set_corner_radius_all(8)
	caixa.content_margin_left = 16
	caixa.content_margin_right = 16
	caixa.content_margin_top = 12
	caixa.content_margin_bottom = 12
	_painel.add_theme_stylebox_override("panel", caixa)
	raiz.add_child(_painel)

	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 16)
	_painel.add_child(linha)

	_retrato = TextureRect.new()
	_retrato.custom_minimum_size = Vector2(84, 84)
	_retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_retrato.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_retrato.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_retrato.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	linha.add_child(_retrato)

	var coluna := VBoxContainer.new()
	coluna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coluna.add_theme_constant_override("separation", 6)
	linha.add_child(coluna)

	_nome = Label.new()
	_nome.add_theme_font_size_override("font_size", 24)
	if ResourceLoader.exists(FONTE_NOME):
		_nome.add_theme_font_override("font", load(FONTE_NOME))
	coluna.add_child(_nome)

	_texto = Label.new()
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_texto.add_theme_font_size_override("font_size", 22)
	coluna.add_child(_texto)

	var dica := Label.new()
	dica.text = "Enter: pular"
	dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dica.add_theme_font_size_override("font_size", 13)
	dica.modulate = Color(1, 1, 1, 0.45)
	coluna.add_child(dica)


func abrir(linhas: Array) -> void:
	if _ativo or linhas.is_empty():
		return
	_linhas = linhas
	_i = -1
	_ativo = true
	visible = true
	_painel.modulate.a = 0.0
	create_tween().tween_property(_painel, "modulate:a", 1.0, 0.18)
	_proxima()


func fechar() -> void:
	if not _ativo:
		return
	_ativo = false
	if _tween != null:
		_tween.kill()
	var t := create_tween()
	t.tween_property(_painel, "modulate:a", 0.0, 0.18)
	t.tween_callback(func(): if not _ativo: visible = false)


func esta_aberto() -> bool:
	return _ativo


func _proxima() -> void:
	_i = (_i + 1) % _linhas.size()
	var fala: Dictionary = _linhas[_i]
	_nome.text = fala.nome
	_nome.add_theme_color_override("font_color", fala.get("cor", Color(1, 0.9, 0.5)))
	_retrato.texture = fala.get("retrato", null)
	_texto.text = fala.texto
	_texto.visible_ratio = 0.0
	_digitando = true
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_texto, "visible_ratio", 1.0, maxf(0.3, fala.texto.length() * 0.03))
	_tween.finished.connect(_terminou_de_digitar)
	linha_exibida.emit(_i)


func _terminou_de_digitar() -> void:
	_digitando = false
	_espera = segundos_por_linha


func _process(delta: float) -> void:
	if not _ativo or _digitando:
		return
	_espera -= delta
	if _espera <= 0.0:
		_proxima()


func _unhandled_input(event: InputEvent) -> void:
	if not _ativo or not event.is_action_pressed("ui_accept"):
		return
	if _digitando:
		_tween.kill()
		_texto.visible_ratio = 1.0
		_terminou_de_digitar()
	else:
		_proxima()
