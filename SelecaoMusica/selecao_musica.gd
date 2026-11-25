class_name SelecaoMusica
extends Control
## TELA DE ESCOLHA DE MÚSICA (layout independente, não depende do resto do Versus).
## Lista rolável à esquerda, painel de detalhes (capa, artista, BPM, duração) à direita e PRÉVIA tocando a música destacada.
##
## COMO USAR
##  1. Instancie/abra  SelecaoMusica/selecao_musica.tscn  e clique no nó raiz.
##  2. No Inspetor, grupo "Músicas": adicione itens em "Musicas" (ItemMusica) ou arraste arquivos de áudio em "Audios Rapidos".
##  3. No grupo "Cenas": escolha a "Cena Ao Confirmar" (para onde ir ao apertar ENTER). Cada música também pode ter a sua
##     própria "Cena Destino" (tem prioridade).
##  4. Na cena de destino, leia a música escolhida com:   SelecaoMusica.escolhida   (um ItemMusica: .audio, .bpm, .nome_exibido, .extras...)
##     Se preferir, conecte o sinal  musica_confirmada(item)  no lugar de usar a variável.
##
## CONTROLES: setas cima/baixo (ou W S) escolhem, ENTER/ESPAÇO/F confirmam, R sorteia, ESC volta (se houver "Cena Ao Voltar"),
##            mouse: clique escolhe, clique de novo na escolhida confirma.

## Emitido quando o jogador confirma uma música (antes de trocar de cena).
signal musica_confirmada(item: ItemMusica)

## Última música confirmada. Fica guardada de uma cena para outra (variável estática, não precisa de Autoload).
static var escolhida: ItemMusica = null

# ───────────────────────── EXPORTS ─────────────────────────
@export_group("Músicas")
## Músicas completas da lista (aparecem primeiro).
@export var musicas: Array[ItemMusica] = []
## Atalho: arraste só arquivos de áudio aqui. O nome vem do nome do arquivo.
@export var audios_rapidos: Array[AudioStream] = []
## BPM dos itens criados por "Audios Rapidos".
@export_range(40.0, 240.0, 1.0, "suffix:bpm") var bpm_padrao: float = 120.0

@export_group("Cenas")
## Cena carregada quando o jogador confirma uma música (se a música não tiver "Cena Destino" própria).
@export_file("*.tscn") var cena_ao_confirmar: String = ""
## Cena carregada ao apertar ESC (vazio = ESC não faz nada).
@export_file("*.tscn") var cena_ao_voltar: String = ""

@export_group("Aparência")
## Título no topo da tela.
@export var titulo: String = "ESCOLHA A MÚSICA"
## Imagem de fundo (opcional; fica escurecida).
@export var fundo: Texture2D
## Cor de destaque (título, linha selecionada, moldura dos detalhes).
@export var cor_destaque: Color = Color("ffd45a")
## Fonte dos textos. Vazio = tenta usar a fonte MonsterFriendFore do projeto, senão a fonte padrão.
@export var fonte: Font

@export_group("Prévia")
## Toca um trecho da música destacada na lista.
@export var tocar_previa: bool = true
## Volume da prévia.
@export_range(-40.0, 6.0, 0.5, "suffix:dB") var volume_previa_db: float = -8.0
## Quanto tempo (s) depois de destacar a prévia começa.
@export_range(0.0, 2.0, 0.05) var atraso_previa: float = 0.35

const LARGURA := 1366.0
const ALTURA := 768.0
const ALTURA_LINHA := 66.0
const COR_AZUL := Color("22306b")
const COR_CREME := Color("f4f1e6")

var _itens: Array[ItemMusica] = []
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
var _aviso: Label
var _previa: AudioStreamPlayer
var _sfx_mover: AudioStreamPlayer
var _sfx_ok: AudioStreamPlayer
var _timer_previa := -1.0
var _tempo := 0.0


# ───────────────────────── MONTAGEM ─────────────────────────

## Junta as músicas (completas + rápidas), monta a interface e seleciona a primeira (ou a última escolhida).
func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if fonte == null and ResourceLoader.exists("res://Assets/fonte/MonsterFriendFore.otf"):
		fonte = load("res://Assets/fonte/MonsterFriendFore.otf")
	_itens = _montar_itens()
	_montar_interface()
	_montar_audio()
	if _itens.is_empty():
		_nome.text = "NENHUMA MÚSICA NA LISTA"
		_info.text = "Adicione músicas no Inspetor (Musicas / Audios Rapidos)"
		return
	if escolhida != null and _itens.has(escolhida):
		_indice = _itens.find(escolhida)
	_atualizar(false)


## Lista final: itens de "musicas" + itens criados a partir de "audios_rapidos".
func _montar_itens() -> Array[ItemMusica]:
	var r: Array[ItemMusica] = []
	for m in musicas:
		if m != null and m.audio != null:
			r.append(m)
	for a in audios_rapidos:
		if a == null:
			continue
		var m := ItemMusica.new()
		m.audio = a
		m.bpm = bpm_padrao
		var arq := a.resource_path.get_file().get_basename()
		m.nome_exibido = arq if arq != "" else "MÚSICA"
		r.append(m)
	return r


## Cria fundo, título, lista rolável, painel de detalhes, dicas e o aviso de "sem cena de destino".
func _montar_interface() -> void:
	var bg := TextureRect.new()
	bg.texture = fundo
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.modulate = Color(0.35, 0.35, 0.5)
	add_child(bg)
	var veu := ColorRect.new()
	veu.color = Color(0.04, 0.03, 0.18, 0.7 if fundo != null else 1.0)
	veu.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(veu)

	# "palco" fixo 1366x768 centralizado (tudo é posicionado dentro dele)
	_palco = Control.new()
	_palco.set_anchors_preset(Control.PRESET_CENTER)
	_palco.offset_left = -LARGURA / 2.0
	_palco.offset_right = LARGURA / 2.0
	_palco.offset_top = -ALTURA / 2.0
	_palco.offset_bottom = ALTURA / 2.0
	_palco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_palco)

	var t := _rotulo(_palco, titulo, 52, cor_destaque, 10)
	t.position = Vector2(0, 20)
	t.size = Vector2(LARGURA, 70)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# lista rolável à esquerda
	var painel_lista := Panel.new()
	painel_lista.position = Vector2(50, 110)
	painel_lista.size = Vector2(700, 580)
	painel_lista.add_theme_stylebox_override("panel", _caixa(Color(0.05, 0.05, 0.18, 0.88), Color("8aa0ff"), 4, 10))
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
	for i in _itens.size():
		_lista.add_child(_criar_linha(i))

	# detalhes à direita
	var det := Panel.new()
	det.position = Vector2(790, 110)
	det.size = Vector2(526, 580)
	det.add_theme_stylebox_override("panel", _caixa(Color(0.05, 0.05, 0.18, 0.88), cor_destaque, 4, 10))
	_palco.add_child(det)
	_capa = TextureRect.new()
	_capa.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # antes da textura (senão a capa cresce até o tamanho da imagem)
	_capa.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_capa.clip_contents = true
	_capa.position = Vector2(133, 24)
	_capa.size = Vector2(260, 260)
	det.add_child(_capa)
	_disco = Control.new()   # disco de vinil desenhado quando a música não tem capa
	_disco.position = _capa.position
	_disco.size = _capa.size
	_disco.draw.connect(_desenhar_disco)
	det.add_child(_disco)
	_nome = _rotulo(det, "", 34, Color.WHITE, 8)
	_nome.position = Vector2(10, 300)
	_nome.size = Vector2(506, 100)
	_nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_artista = _rotulo(det, "", 24, cor_destaque, 6)
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

	_aviso = _rotulo(_palco, "", 24, Color("ff6b6b"), 6)
	_aviso.position = Vector2(0, 84)
	_aviso.size = Vector2(LARGURA, 30)
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


## Botão (linha) da música i: nome em cima, artista (ou BPM) embaixo.
func _criar_linha(i: int) -> Button:
	var m := _itens[i]
	var b := Button.new()
	b.custom_minimum_size = Vector2(660, ALTURA_LINHA)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(_ao_clicar_linha.bind(i))
	var l1 := _rotulo(b, m.nome_exibido, 26, COR_AZUL, 0)
	l1.position = Vector2(16, 6)
	l1.size = Vector2(628, 32)
	l1.clip_text = true
	var l2 := _rotulo(b, m.artista if m.artista != "" else "BPM %d" % int(m.bpm), 18, Color("4a5a99"), 0)
	l2.position = Vector2(16, 36)
	l2.size = Vector2(628, 24)
	l2.clip_text = true
	_linhas.append(b)
	return b


## Cria um Label com a fonte, tamanho, cor e contorno desejados.
func _rotulo(pai: Node, texto: String, tam: int, cor: Color, contorno: int) -> Label:
	var l := Label.new()
	l.text = texto
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if fonte != null:
		l.add_theme_font_override("font", fonte)
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.15))
	l.add_theme_constant_override("outline_size", contorno)
	pai.add_child(l)
	return l


## Caixa com fundo, borda e cantos arredondados.
func _caixa(fundo_cor: Color, borda: Color, espessura: int, raio: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fundo_cor
	sb.border_color = borda
	sb.set_border_width_all(espessura)
	sb.set_corner_radius_all(raio)
	return sb


## Players de áudio: prévia + efeitos (bips gerados por código, sem arquivos).
func _montar_audio() -> void:
	_previa = AudioStreamPlayer.new()
	_previa.volume_db = volume_previa_db
	add_child(_previa)
	_previa.finished.connect(_ao_acabar_previa)
	_sfx_mover = AudioStreamPlayer.new()
	_sfx_mover.stream = _bip(660.0, 0.05, 0.25)
	add_child(_sfx_mover)
	_sfx_ok = AudioStreamPlayer.new()
	_sfx_ok.stream = _bip(990.0, 0.18, 0.3)
	add_child(_sfx_ok)


## Gera um bip (onda quadrada) simples.
func _bip(freq: float, segundos: float, volume: float) -> AudioStreamWAV:
	var taxa := 22050
	var n := int(taxa * segundos)
	var dados := PackedByteArray()
	dados.resize(n * 2)
	for i in n:
		var env := 1.0 - float(i) / float(n)
		var onda := 1.0 if fmod(float(i) * freq / taxa, 1.0) < 0.5 else -1.0
		dados.encode_s16(i * 2, int(onda * env * volume * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = taxa
	w.data = dados
	return w


## Disco de vinil desenhado (gira devagar) para músicas sem capa.
func _desenhar_disco() -> void:
	var c := _disco.size / 2.0
	_disco.draw_circle(c, 126.0, Color(0.05, 0.05, 0.08))
	for r in [110.0, 90.0, 70.0]:
		_disco.draw_arc(c, r, 0.0, TAU, 48, Color(1, 1, 1, 0.08), 2.0)
	_disco.draw_circle(c, 46.0, cor_destaque)
	_disco.draw_circle(c, 7.0, Color(0.05, 0.05, 0.08))
	var a := _tempo * 1.2
	_disco.draw_line(c + Vector2.from_angle(a) * 52.0, c + Vector2.from_angle(a) * 118.0, Color(1, 1, 1, 0.25), 3.0)


# ───────────────────────── ATUALIZAÇÃO ─────────────────────────

## Destaca a linha escolhida, rola até ela, atualiza os detalhes e agenda a prévia.
func _atualizar(com_som: bool) -> void:
	for i in _linhas.size():
		var sel := i == _indice
		var estilo := _caixa(cor_destaque if sel else COR_CREME, Color("c0392b") if sel else COR_AZUL, 5 if sel else 3, 8)
		for nome in ["normal", "hover", "pressed", "focus"]:
			_linhas[i].add_theme_stylebox_override(nome, estilo)
	_rolagem.ensure_control_visible(_linhas[_indice])
	var m := _itens[_indice]
	_capa.texture = m.capa
	_capa.visible = m.capa != null
	_disco.visible = m.capa == null
	_nome.text = m.nome_exibido
	_artista.text = m.artista
	var dur := m.audio.get_length()
	_info.text = "BPM: %d          DURAÇÃO: %d:%02d" % [int(m.bpm), int(dur) / 60, int(dur) % 60]
	if com_som:
		_sfx_mover.play()
	_previa.stop()
	_timer_previa = atraso_previa if tocar_previa else -1.0


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
	if _itens.is_empty() or _saindo:
		return
	var m := _itens[_indice]
	_previa.stream = m.audio
	_previa.play(clampf(m.inicio_previa, 0.0, maxf(m.audio.get_length() - 1.0, 0.0)))


## A prévia acabou: repete.
func _ao_acabar_previa() -> void:
	if not _saindo and not _itens.is_empty() and tocar_previa:
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
		KEY_ESCAPE: _voltar()
		KEY_UP, KEY_W: _mover(-1)
		KEY_DOWN, KEY_S: _mover(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_F: _confirmar()
		KEY_R: _sortear()


func _mover(passo: int) -> void:
	if _itens.size() < 2:
		return
	_indice = wrapi(_indice + passo, 0, _itens.size())
	_atualizar(true)


## R: destaca uma música aleatória (ainda precisa confirmar).
func _sortear() -> void:
	if _itens.size() < 2:
		return
	var novo := _indice
	while novo == _indice:
		novo = randi() % _itens.size()
	_indice = novo
	_atualizar(true)


## Clique: destaca; clicar na já destacada confirma.
func _ao_clicar_linha(i: int) -> void:
	if i == _indice:
		_confirmar()
	else:
		_indice = i
		_atualizar(true)


## Confirma: guarda em SelecaoMusica.escolhida, emite o sinal e vai para a cena de destino.
func _confirmar() -> void:
	if _saindo or _itens.is_empty():
		return
	var item := _itens[_indice]
	var destino := item.cena_destino if item.cena_destino != "" else cena_ao_confirmar
	escolhida = item
	musica_confirmada.emit(item)
	if destino == "":
		_aviso.text = "Defina a 'Cena Ao Confirmar' no Inspetor da SelecaoMusica"
		return
	_sfx_ok.play()
	_sair(destino)


## ESC: vai para a "Cena Ao Voltar" (se existir).
func _voltar() -> void:
	if cena_ao_voltar != "":
		_sair(cena_ao_voltar)


## Para a prévia e troca de cena.
func _sair(cena: String) -> void:
	_saindo = true
	_previa.stop()
	get_tree().create_timer(0.2).timeout.connect(func() -> void:
		get_tree().change_scene_to_file(cena))
