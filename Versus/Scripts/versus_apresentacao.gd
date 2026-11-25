extends Control
## CUTSCENE DE APRESENTAÇÃO — acontece antes da luta.
## Barras de cinema, o cenário escolhido ao fundo, o JOGADOR 1 entra pela esquerda (nome e especial),
## depois o COMPUTADOR (ou JOGADOR 2) entra pela direita, o "VS" bate no meio e a luta começa.
## ENTER, ESPAÇO ou clique PULAM a cutscene. ESC volta para a escolha de música.

# ───────────────────────── EXPORTS ─────────────────────────
## Quanto tempo (s) cada lutador fica em cena sendo apresentado.
@export_range(0.8, 6.0, 0.1) var tempo_por_lutador: float = 2.2
## Toca de novo a "voz" de seleção de cada lutador quando ele é apresentado.
@export var tocar_voz: bool = true
## Altura (px) das barras pretas de cinema em cima e embaixo.
@export var altura_barras: float = 86.0

const LARGURA := 1366.0
const ALTURA := 768.0

var _p1: Lutador
var _p2: Lutador
var _palco: Control
var _cartas: Array[Control] = []         # [lado] -> Control que contém sprite e textos
var _sprites: Array[AnimatedSprite2D] = []
var _anim_tempo := [0.0, 0.0]
var _anim_indice := [0, 0]
var _voz: Array[AudioStreamPlayer] = []
var _preto: ColorRect
var _flash: ColorRect
var _saindo := false
var _sfx_bate: AudioStreamPlayer


## Monta a cena e dispara a linha do tempo da apresentação.
func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	VersusEstado.garantir_lutadores()
	_p1 = VersusEstado.lutador_p1
	_p2 = VersusEstado.lutador_p2
	if _p1 == null or _p2 == null:
		_ir_para_batalha()
		return
	_montar_cenario()
	_montar_audio()
	_montar_carta(0)
	_montar_carta(1)
	_montar_barras()
	_montar_titulo()
	_linha_do_tempo()


# ───────────────────────── MONTAGEM ─────────────────────────

## Fundo (cenário escolhido) escurecido, com palco central para os elementos.
func _montar_cenario() -> void:
	var bg := TextureRect.new()
	var mapa := VersusEstado.cenario
	bg.texture = mapa.obter_fundo() if mapa != null else null
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.modulate = Color(0.55, 0.55, 0.7)
	add_child(bg)
	var veu := ColorRect.new()
	veu.color = Color(0.02, 0.01, 0.12, 0.45)
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


func _montar_audio() -> void:
	for i in 2:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_voz.append(p)
	_sfx_bate = AudioStreamPlayer.new()
	_sfx_bate.stream = VersusEstilo.bip(110.0, 0.35, 0.6)
	add_child(_sfx_bate)


func _rotulo(pai: Node, texto: String, tam: int, cor: Color, contorno: int = 8) -> Label:
	var l := Label.new()
	l.text = texto
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	VersusEstilo.estilizar_rotulo(l, tam, cor, contorno)
	pai.add_child(l)
	return l


## "Carta" de um lado: sprite grande, etiqueta (JOGADOR 1 / COMPUTADOR), nome e especial.
## Começa invisível e fora da tela; a linha do tempo faz ela entrar.
func _montar_carta(i: int) -> void:
	var l := _p1 if i == 0 else _p2
	var carta := Control.new()
	carta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	carta.position = Vector2(0, 0)
	carta.modulate.a = 0.0
	_palco.add_child(carta)
	_cartas.append(carta)

	var cx := 330.0 if i == 0 else LARGURA - 330.0   # centro horizontal da carta
	# faixa de luz atrás do lutador
	var luz := ColorRect.new()
	luz.color = Color(l.cor.r, l.cor.g, l.cor.b, 0.14)
	luz.position = Vector2(cx - 230, 90)
	luz.size = Vector2(460, 560)
	luz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	carta.add_child(luz)

	var sp := AnimatedSprite2D.new()
	sp.sprite_frames = l.sprite_frames
	sp.centered = false
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.scale = Vector2.ONE * l.escala_sprite * 1.45
	var tam := l.tamanho_quadro()
	sp.offset = Vector2(-tam.x * 0.5, -(tam.y - l.deslocamento_pes))
	sp.flip_h = (i == 1)
	sp.position = Vector2(cx, 560)
	if l.sprite_frames.has_animation(&"idle"):
		sp.play(&"idle")
	carta.add_child(sp)
	_sprites.append(sp)

	var papel := "JOGADOR 1"
	if i == 1:
		papel = "COMPUTADOR" if VersusEstado.p2_eh_cpu() else "JOGADOR 2"
	var etiqueta := _rotulo(carta, papel, 40, Color("ff3b3b") if i == 0 else Color("3b8bff"), 9)
	etiqueta.position = Vector2(cx - 230, 96)
	etiqueta.size = Vector2(460, 56)
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var nome := _rotulo(carta, l.nome_exibido, 66, l.cor, 12)
	nome.position = Vector2(cx - 260, 568)
	nome.size = Vector2(520, 84)
	nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var esp := _rotulo(carta, "ESPECIAL: " + l.nome_especial, 24, Color.WHITE, 6)
	esp.position = Vector2(cx - 260, 648)
	esp.size = Vector2(520, 36)
	esp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


## Barras pretas de cinema (entram deslizando) e o "PULAR" no canto.
func _montar_barras() -> void:
	for topo in [true, false]:
		var b := ColorRect.new()
		b.color = Color.BLACK
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.set_anchors_preset(Control.PRESET_TOP_WIDE if topo else Control.PRESET_BOTTOM_WIDE)
		add_child(b)
		# a barra desliza para dentro da tela mexendo nas bordas (offsets)
		var t := create_tween().set_parallel(true)
		if topo:
			b.offset_top = -altura_barras
			b.offset_bottom = 0.0
			t.tween_property(b, "offset_top", 0.0, 0.5).set_trans(Tween.TRANS_QUAD)
			t.tween_property(b, "offset_bottom", altura_barras, 0.5).set_trans(Tween.TRANS_QUAD)
		else:
			b.offset_top = 0.0
			b.offset_bottom = altura_barras
			t.tween_property(b, "offset_top", -altura_barras, 0.5).set_trans(Tween.TRANS_QUAD)
			t.tween_property(b, "offset_bottom", 0.0, 0.5).set_trans(Tween.TRANS_QUAD)
	var pular := _rotulo(self, "ENTER: pular", 20, Color(1, 1, 1, 0.75), 4)
	pular.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	pular.offset_left = -240
	pular.offset_top = -60
	pular.offset_right = -24
	pular.offset_bottom = -20
	pular.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pular.z_index = 5

	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	_preto = ColorRect.new()
	_preto.color = Color.BLACK
	_preto.set_anchors_preset(Control.PRESET_FULL_RECT)
	_preto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_preto)


## Título da partida: mapa e música escolhidos, no alto da tela (dentro da barra de cima).
func _montar_titulo() -> void:
	var mapa := VersusEstado.cenario.nome_exibido if VersusEstado.cenario != null else "-"
	var musica := VersusEstado.musica.nome_exibido if VersusEstado.musica != null else "-"
	var t := _rotulo(self, "CENÁRIO: %s          MÚSICA: %s" % [mapa, musica], 22, Color.WHITE, 5)
	t.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	t.offset_top = 28
	t.offset_bottom = 60
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.z_index = 5


# ───────────────────────── LINHA DO TEMPO ─────────────────────────

## Sequência: fade-in -> JOGADOR 1 -> COMPUTADOR -> VS -> "PREPARAR!" -> fade-out -> batalha.
func _linha_do_tempo() -> void:
	var t := create_tween()
	t.tween_property(_preto, "color:a", 0.0, 0.6)
	t.tween_callback(_apresentar.bind(0))
	t.tween_interval(tempo_por_lutador)
	t.tween_callback(_apresentar.bind(1))
	t.tween_interval(tempo_por_lutador)
	t.tween_callback(_bater_vs)
	t.tween_interval(1.6)
	t.tween_callback(_sair)


## Faz a carta do lado i entrar deslizando, toca a voz do lutador e dá um "soquinho" na etiqueta.
func _apresentar(i: int) -> void:
	if _saindo:
		return
	var carta := _cartas[i]
	carta.position.x = -420.0 if i == 0 else 420.0
	var t := create_tween().set_parallel(true)
	t.tween_property(carta, "position:x", 0.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(carta, "modulate:a", 1.0, 0.25)
	_sfx_bate.play()
	var l := _p1 if i == 0 else _p2
	if tocar_voz and l.voz_selecao != null:
		_voz[i].stream = l.voz_selecao
		_voz[i].volume_db = l.voz_volume_db
		_voz[i].play()
		if l.voz_duracao > 0.0:
			get_tree().create_timer(minf(l.voz_duracao, tempo_por_lutador)).timeout.connect(_voz[i].stop)


## "VS" gigante bate no meio da tela com clarão e tremor, e os dois lutadores ficam em pose de luta.
func _bater_vs() -> void:
	if _saindo:
		return
	_sfx_bate.play()
	var vs := _rotulo(_palco, "VS", 260, Color("ff3b3b"), 20)
	vs.size = Vector2(500, 300)
	vs.position = Vector2(LARGURA / 2.0 - 250, 150)
	vs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vs.pivot_offset = Vector2(250, 150)
	vs.scale = Vector2(4, 4)
	vs.modulate.a = 0.0
	var t := create_tween().set_parallel(true)
	t.tween_property(vs, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(vs, "modulate:a", 1.0, 0.15)
	_flash.color = Color(1, 1, 1, 0.8)
	create_tween().tween_property(_flash, "color:a", 0.0, 0.4)
	_tremer()
	var pronto := _rotulo(_palco, "PREPARAR!", 64, VersusEstilo.COR_AMARELO, 12)
	pronto.size = Vector2(LARGURA, 90)
	pronto.position = Vector2(0, 470)
	pronto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pronto.modulate.a = 0.0
	create_tween().tween_property(pronto, "modulate:a", 1.0, 0.2).set_delay(0.6)


## Tremor rápido do palco inteiro.
func _tremer() -> void:
	var t := create_tween()
	for k in 8:
		t.tween_property(_palco, "position", Vector2(randf_range(-10, 10), randf_range(-8, 8)) * (1.0 - k / 8.0), 0.04)
	t.tween_property(_palco, "position", Vector2.ZERO, 0.04)


## Fade para preto e começa a luta (chamado no fim da cutscene ou ao pular).
func _sair() -> void:
	if _saindo:
		return
	_saindo = true
	var t := create_tween()
	t.tween_property(_preto, "color:a", 1.0, 0.35)
	t.tween_callback(_ir_para_batalha)


func _ir_para_batalha() -> void:
	get_tree().change_scene_to_file(VersusEstado.CENA_BATALHA)


# ───────────────────────── LOOP / ENTRADA ─────────────────────────

## Os lutadores alternam de pose (parado / acertando) enquanto estão em cena.
func _process(delta: float) -> void:
	for i in _sprites.size():
		if _cartas[i].modulate.a <= 0.01:
			continue
		_anim_tempo[i] += delta
		if _anim_tempo[i] >= 0.45:
			_anim_tempo[i] = 0.0
			var l := _p1 if i == 0 else _p2
			var poses: Array[StringName] = []
			if l.sprite_frames.has_animation(&"idle"):
				poses.append(&"idle")
			var n := 0
			while l.sprite_frames.has_animation(StringName("hit_%d" % n)):
				poses.append(StringName("hit_%d" % n))
				n += 1
			if poses.is_empty():
				continue
			_anim_indice[i] = (_anim_indice[i] + 1) % poses.size()
			var nome: StringName = poses[_anim_indice[i]]
			_sprites[i].flip_h = (i == 1) and not l.animacoes_sem_espelhar.has(String(nome))
			_sprites[i].play(nome)


## ENTER/ESPAÇO/clique pulam; ESC volta para a escolha de música.
func _unhandled_input(event: InputEvent) -> void:
	if _saindo:
		return
	var ke := event as InputEventKey
	if ke != null and ke.pressed and not ke.echo:
		match ke.physical_keycode:
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_sair()
			KEY_ESCAPE:
				_saindo = true
				get_tree().change_scene_to_file(VersusEstado.CENA_MUSICA)
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed:
		_sair()
