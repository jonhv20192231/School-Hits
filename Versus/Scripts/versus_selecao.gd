extends Control
## SELEÇÃO DE PERSONAGEM ao estilo Street Fighter II.
## • Grade de retratos no centro (com cursor vermelho do P1 e azul do P2/CPU) e os dois lutadores
##   escolhidos em painéis grandes dos lados, com plaquinha de nome.
## • Modo 1 jogador: você escolhe o seu lutador e DEPOIS escolhe também o adversário (ou aperta R para sortear os dois).
##   Modo 2 jogadores: os dois escolhem ao mesmo tempo.
## • Ao confirmar, o lutador solta a "voz" (áudio do Lutador.voz_selecao, cortado em voz_duracao segundos).
## • Depois vai para a escolha de mapa, escolha de música, cutscene de apresentação e a batalha.
## A grade é gerada sozinha a partir do ELENCO: para colocar personagem novo basta adicioná-lo em
## res://Versus/Dados/elenco.tres (veja Versus/COMO_ADICIONAR_PERSONAGEM.md).
##
## CONTROLES: 1 jogador -> setas ou W A S D movem, ENTER/ESPAÇO/F confirmam, R sorteia os personagens.
##            2 jogadores -> P1: W A S D + F   |   P2: setas + ENTER.   R sorteia.   ESC volta.

# ───────────────────────── EXPORTS ─────────────────────────
## Lista de lutadores. Vazio = usa res://Versus/Dados/elenco.tres
@export var elenco: ElencoLutadores
## Quantas colunas tem a grade de retratos.
@export_range(2, 8) var colunas: int = 4
## Quantas linhas (no mínimo; cresce sozinha se houver lutadores demais). Espaços vazios aparecem com "?".
@export_range(1, 4) var linhas: int = 2
## Tamanho de cada quadradinho da grade.
@export var tamanho_celula: Vector2 = Vector2(118, 118)
## Espaço entre os quadradinhos.
@export var espaco_celulas: float = 10.0
## Cor do cursor do jogador 1 e do jogador 2/CPU.
@export var cor_cursor_p1: Color = Color("ff3b3b")
@export var cor_cursor_p2: Color = Color("3b8bff")
## No modo 1 jogador: true = você escolhe o personagem do adversário; false = a CPU sorteia sozinha.
@export var permitir_escolher_adversario: bool = true
## Fundo da tela.
@export var fundo: Texture2D = preload("res://Assets/Cenários/e3b7af9d-8ca8-44fd-9591-c39a4e4f1910.jpg")

# ───────────────────────── ESTADO ─────────────────────────
## ESCOLHENDO = jogador(es) escolhendo; ADVERSARIO = (1 jogador) agora escolhe o adversário;
## SORTEANDO = animação do sorteio/CPU; SAINDO = indo para a escolha de mapa.
enum Fase { ESCOLHENDO, ADVERSARIO, SORTEANDO, SAINDO }

const LARGURA := 1366.0
const ALTURA := 768.0

var _fase := Fase.ESCOLHENDO
var _lutadores: Array[Lutador] = []
var _cursor: Array[int] = [0, 0]                 # índice do lutador sob o cursor de cada lado
var _confirmado: Array[bool] = [false, false]
var _modo_cpu := true

var _palco: Control                               # área fixa 1366x768 centralizada onde tudo é posicionado
var _grade_pos := Vector2.ZERO                    # canto superior esquerdo da grade (dentro do palco)
var _cursores: Control                            # camada onde os cursores são desenhados
var _celulas: Array[Control] = []
var _paineis: Array[Panel] = []
var _previews: Array[AnimatedSprite2D] = []       # lutador grande de cada lado
var _placas: Array[Label] = []                    # nome do lutador de cada lado
var _status: Array[Label] = []                    # "PRONTO!"
var _titulo: Label                                # título do topo (muda quando é a vez de escolher o adversário)
var _dica: Label                                  # texto de ajuda dos controles (muda conforme a fase)
var _anim_tempo := [0.0, 0.0]
var _anim_indice := [0, 0]
var _voz: Array[AudioStreamPlayer] = []
var _voz_token := [0, 0]                          # evita que um corte de áudio antigo pare uma voz nova
var _sfx_mover: AudioStreamPlayer
var _sfx_ok: AudioStreamPlayer
var _tempo := 0.0


# ───────────────────────── MONTAGEM ─────────────────────────

## Carrega o elenco, monta toda a interface e mostra os primeiros lutadores.
func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_modo_cpu = VersusEstado.p2_eh_cpu()
	if elenco == null:
		elenco = VersusEstado.carregar_elenco()
	if elenco != null:
		for l in elenco.lutadores:
			if l != null and l.sprite_frames != null:
				_lutadores.append(l)
	_montar_fundo()
	_montar_palco()
	_montar_audio()
	if _lutadores.is_empty():
		_aviso_sem_lutadores()
		return
	_cursor[1] = mini(1, _lutadores.size() - 1)
	_atualizar_preview(0)
	_atualizar_preview(1)
	_cursores.queue_redraw()


## Fundo: imagem do palco bem escurecida + véu azul.
func _montar_fundo() -> void:
	var bg := TextureRect.new()
	bg.texture = fundo
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.modulate = Color(0.45, 0.45, 0.6)
	add_child(bg)
	var veu := ColorRect.new()
	veu.color = Color(0.03, 0.02, 0.15, 0.55)
	veu.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(veu)


## Cria o "palco" (1366x768 centralizado) e põe título, painéis, grade e dicas dentro dele.
func _montar_palco() -> void:
	_palco = Control.new()
	_palco.set_anchors_preset(Control.PRESET_CENTER)
	_palco.offset_left = -LARGURA / 2.0
	_palco.offset_right = LARGURA / 2.0
	_palco.offset_top = -ALTURA / 2.0
	_palco.offset_bottom = ALTURA / 2.0
	_palco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_palco)

	# título
	_titulo = _rotulo(_palco, "ESCOLHA SEU LUTADOR", 52, VersusEstilo.COR_AMARELO, 10)
	var titulo := _titulo
	titulo.position = Vector2(0, 24)
	titulo.size = Vector2(LARGURA, 70)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# "VS" no centro, acima da grade
	var vs := _rotulo(_palco, "VS", 120, Color("ff3b3b"), 14)
	vs.position = Vector2(0, 130)
	vs.size = Vector2(LARGURA, 150)
	vs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# painéis dos dois lutadores (esquerda: P1, direita: P2/CPU)
	var tags := ["1P", "CPU" if _modo_cpu else "2P"]
	var cores := [cor_cursor_p1, cor_cursor_p2]
	for i in 2:
		_montar_painel(i, Vector2(36 if i == 0 else LARGURA - 36 - 380, 120), tags[i], cores[i])

	# grade de retratos
	_montar_grade()

	# dicas de controle (o texto muda conforme a fase, veja _atualizar_dica)
	_dica = _rotulo(_palco, "", 21, Color.WHITE, 5)
	_dica.position = Vector2(0, 662)
	_dica.size = Vector2(LARGURA, 80)
	_dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_atualizar_dica()


## Escreve na parte de baixo da tela quais teclas usar na fase atual.
func _atualizar_dica() -> void:
	if _dica == null:
		return
	_titulo.text = "ESCOLHA O ADVERSÁRIO" if (_modo_cpu and _fase == Fase.ADVERSARIO) else "ESCOLHA SEU LUTADOR"
	if not _modo_cpu:
		_dica.text = "1P: A D W S mover, F confirmar          2P: SETAS mover, ENTER confirmar\nR: sortear os dois          ESC: voltar"
	elif _fase == Fase.ADVERSARIO:
		_dica.text = "AGORA ESCOLHA O ADVERSÁRIO: SETAS ou A D W S mover, ENTER confirmar\nR: sortear o adversário          ESC: voltar"
	else:
		_dica.text = "SETAS ou A D W S: mover          ENTER, ESPAÇO ou F: confirmar\nR: sortear você e o adversário          ESC: voltar"


## Painel grande de um lado: moldura colorida, lutador animado, plaquinha de nome e "PRONTO!".
func _montar_painel(i: int, pos: Vector2, tag: String, cor: Color) -> void:
	var p := Panel.new()
	p.position = pos
	p.size = Vector2(380, 480)
	p.add_theme_stylebox_override("panel", VersusEstilo.caixa(Color(0.06, 0.06, 0.2, 0.85), cor, 6, 10))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_palco.add_child(p)
	_paineis.append(p)

	var t := _rotulo(p, tag, 34, cor, 6)
	t.position = Vector2(14, 8)

	var st := _rotulo(p, "", 30, Color("5dff7a"), 6)
	st.position = Vector2(0, 8)
	st.size = Vector2(366, 40)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status.append(st)

	var sp := AnimatedSprite2D.new()
	sp.centered = false
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.position = Vector2(190, 395)
	p.add_child(sp)
	_previews.append(sp)

	# plaquinha de nome (como no Street Fighter: faixa colorida embaixo)
	var faixa := ColorRect.new()
	faixa.color = Color(cor.r * 0.55, cor.g * 0.55, cor.b * 0.55, 0.95)
	faixa.position = Vector2(0, 416)
	faixa.size = Vector2(380, 64)
	faixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(faixa)
	var nome := _rotulo(p, "", 40, Color.WHITE, 8)
	nome.position = Vector2(0, 420)
	nome.size = Vector2(380, 56)
	nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nome.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_placas.append(nome)


## Gera a grade (colunas x linhas) a partir do elenco; espaços sem lutador mostram "?".
func _montar_grade() -> void:
	var total_linhas := maxi(linhas, int(ceil(float(_lutadores.size()) / colunas)))
	var larg := colunas * tamanho_celula.x + (colunas - 1) * espaco_celulas
	var alt := total_linhas * tamanho_celula.y + (total_linhas - 1) * espaco_celulas
	_grade_pos = Vector2((LARGURA - larg) / 2.0, 300.0)
	var grade := Control.new()
	grade.position = _grade_pos
	grade.size = Vector2(larg, alt)
	grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_palco.add_child(grade)
	for idx in colunas * total_linhas:
		var c := Panel.new()
		c.position = _pos_celula(idx)
		c.size = tamanho_celula
		c.add_theme_stylebox_override("panel", VersusEstilo.caixa(Color(0.08, 0.08, 0.22, 0.9), Color("8aa0ff"), 3, 4))
		grade.add_child(c)
		if idx < _lutadores.size():
			var tr := TextureRect.new()
			tr.texture = _lutadores[idx].obter_retrato()
			tr.set_anchors_preset(Control.PRESET_FULL_RECT)
			tr.offset_left = 6; tr.offset_top = 6; tr.offset_right = -6; tr.offset_bottom = -6
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			c.add_child(tr)
			c.gui_input.connect(_ao_mouse_na_celula.bind(idx))
			c.mouse_entered.connect(_ao_mouse_entrar.bind(idx))
		else:
			var q := _rotulo(c, "?", 64, Color(1, 1, 1, 0.35), 0)
			q.set_anchors_preset(Control.PRESET_FULL_RECT)
			q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_celulas.append(c)
	# camada dos cursores por cima das células
	_cursores = Control.new()
	_cursores.position = _grade_pos
	_cursores.size = grade.size
	_cursores.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursores.draw.connect(_desenhar_cursores)
	_palco.add_child(_cursores)


## Cria um Label já estilizado como filho de "pai".
func _rotulo(pai: Node, texto: String, tam: int, cor: Color, contorno: int) -> Label:
	var l := Label.new()
	l.text = texto
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	VersusEstilo.estilizar_rotulo(l, tam, cor, contorno)
	pai.add_child(l)
	return l


## Players de áudio: uma voz por lado + efeitos de mover e confirmar.
func _montar_audio() -> void:
	for i in 2:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_voz.append(p)
	_sfx_mover = AudioStreamPlayer.new()
	_sfx_mover.stream = VersusEstilo.bip(660.0, 0.05, 0.25)
	add_child(_sfx_mover)
	_sfx_ok = AudioStreamPlayer.new()
	_sfx_ok.stream = VersusEstilo.bip(990.0, 0.18, 0.3)
	add_child(_sfx_ok)


## Elenco vazio: mostra um aviso e deixa voltar com ESC.
func _aviso_sem_lutadores() -> void:
	var l := _rotulo(_palco, "NENHUM LUTADOR NO ELENCO\nAdicione em Versus/Dados/elenco.tres\n(ESC para voltar)", 36, Color.WHITE, 6)
	l.position = Vector2(0, 300)
	l.size = Vector2(LARGURA, 200)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


# ───────────────────────── POSIÇÕES ─────────────────────────

## Posição (dentro da grade) da célula de número idx.
func _pos_celula(idx: int) -> Vector2:
	var c := idx % colunas
	var r := idx / colunas
	return Vector2(c * (tamanho_celula.x + espaco_celulas), r * (tamanho_celula.y + espaco_celulas))


## Desenha os cursores: vermelho (P1) e azul (P2/CPU) que piscam em volta da célula escolhida.
func _desenhar_cursores() -> void:
	if _lutadores.is_empty():
		return
	var pisca := 0.65 + 0.35 * sin(_tempo * 10.0)
	var cores := [cor_cursor_p1, cor_cursor_p2]
	for i in 2:
		var r := Rect2(_pos_celula(_cursor[i]), tamanho_celula).grow(4.0 - i * 5.0)
		var cor: Color = cores[i]
		cor.a = 1.0 if _confirmado[i] else pisca
		_cursores.draw_rect(r, cor, false, 5.0)


# ───────────────────────── LOOP ─────────────────────────

## Anima os cursores e faz os lutadores grandes alternarem de pose (parado / acertando).
func _process(delta: float) -> void:
	_tempo += delta
	if _cursores != null:
		_cursores.queue_redraw()
	if _lutadores.is_empty():
		return
	for i in 2:
		_anim_tempo[i] += delta
		if _anim_tempo[i] >= 0.42:
			_anim_tempo[i] = 0.0
			_proxima_pose(i)


## Troca a pose do lutador grande do lado i, percorrendo idle e as poses hit_*.
func _proxima_pose(i: int) -> void:
	var l := _lutadores[_cursor[i]]
	var poses: Array[StringName] = []
	if l.sprite_frames.has_animation(&"idle"):
		poses.append(&"idle")
	var n := 0
	while l.sprite_frames.has_animation(StringName("hit_%d" % n)):
		poses.append(StringName("hit_%d" % n))
		n += 1
	if poses.is_empty():
		return
	_anim_indice[i] = (_anim_indice[i] + 1) % poses.size()
	var nome: StringName = poses[_anim_indice[i]]
	var sp := _previews[i]
	sp.flip_h = (i == 1) and not l.animacoes_sem_espelhar.has(String(nome))
	sp.play(nome)


## Mostra o lutador que está sob o cursor do lado i no painel grande, com nome na plaquinha.
func _atualizar_preview(i: int) -> void:
	var l := _lutadores[_cursor[i]]
	var sp := _previews[i]
	sp.sprite_frames = l.sprite_frames
	sp.scale = Vector2.ONE * l.escala_sprite * 1.05
	var tam := l.tamanho_quadro()
	sp.offset = Vector2(-tam.x * 0.5, -(tam.y - l.deslocamento_pes))
	sp.flip_h = (i == 1)
	_anim_indice[i] = 0
	_anim_tempo[i] = 0.0
	if l.sprite_frames.has_animation(&"idle"):
		sp.play(&"idle")
	_placas[i].text = l.nome_exibido
	_placas[i].add_theme_color_override("font_color", l.cor)


# ───────────────────────── ENTRADA ─────────────────────────

## Lado (0 = P1, 1 = P2/adversário) que as setas e o WASD controlam agora no modo 1 jogador.
func _lado_ativo() -> int:
	return 1 if _fase == Fase.ADVERSARIO else 0


## Lado controlado pelo mouse (no modo 2 jogadores o mouse é do P1).
func _lado_mouse() -> int:
	return _lado_ativo() if _modo_cpu else 0


## Teclado: mover cursores, confirmar, sortear (R) e voltar (ESC).
func _unhandled_input(event: InputEvent) -> void:
	var ke := event as InputEventKey
	if ke == null or not ke.pressed or ke.echo:
		return
	var k := ke.physical_keycode
	if k == KEY_ESCAPE and _fase != Fase.SAINDO:
		get_tree().change_scene_to_file(VersusEstado.CENA_MODO_VERSUS)
		return
	if _lutadores.is_empty() or (_fase != Fase.ESCOLHENDO and _fase != Fase.ADVERSARIO):
		return
	var ativo := _lado_ativo()
	var lado_wasd := ativo                       # W A S D e F controlam este lado
	var lado_setas := ativo if _modo_cpu else 1  # setas e ENTER (no 2P as setas são do P2)
	match k:
		KEY_A: _mover(lado_wasd, -1, 0)
		KEY_D: _mover(lado_wasd, 1, 0)
		KEY_W: _mover(lado_wasd, 0, -1)
		KEY_S: _mover(lado_wasd, 0, 1)
		KEY_F: _confirmar(lado_wasd)
		KEY_LEFT: _mover(lado_setas, -1, 0)
		KEY_RIGHT: _mover(lado_setas, 1, 0)
		KEY_UP: _mover(lado_setas, 0, -1)
		KEY_DOWN: _mover(lado_setas, 0, 1)
		KEY_ENTER, KEY_KP_ENTER: _confirmar(lado_setas)
		KEY_SPACE: _confirmar(lado_wasd)
		KEY_R: _sortear()


## Mouse passou por cima de um retrato: move o cursor do lado ativo até ele.
func _ao_mouse_entrar(idx: int) -> void:
	var lado := _lado_mouse()
	if (_fase == Fase.ESCOLHENDO or _fase == Fase.ADVERSARIO) and not _confirmado[lado] and _cursor[lado] != idx:
		_cursor[lado] = idx
		_atualizar_preview(lado)
		_sfx_mover.play()


## Clique do mouse em um retrato: confirma o lado ativo.
func _ao_mouse_na_celula(evento: InputEvent, idx: int) -> void:
	var lado := _lado_mouse()
	var mb := evento as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT \
			and (_fase == Fase.ESCOLHENDO or _fase == Fase.ADVERSARIO) and not _confirmado[lado]:
		_cursor[lado] = idx
		_atualizar_preview(lado)
		_confirmar(lado)


## Move o cursor do lado i na grade (dx/dy = -1, 0 ou 1), pulando espaços vazios e dando a volta nas bordas.
func _mover(i: int, dx: int, dy: int) -> void:
	if _confirmado[i]:
		return
	var total_linhas := maxi(linhas, int(ceil(float(_lutadores.size()) / colunas)))
	var c: int = _cursor[i] % colunas
	var r: int = _cursor[i] / colunas
	for _passo in colunas * total_linhas:
		c = wrapi(c + dx, 0, colunas)
		r = wrapi(r + dy, 0, total_linhas)
		var idx := r * colunas + c
		if idx < _lutadores.size():
			if idx != _cursor[i]:
				_cursor[i] = idx
				_atualizar_preview(i)
				_sfx_mover.play()
			return


## "Trava" a escolha do lado i: marca PRONTO, toca o som, a voz e faz o painel piscar (sem mudar de fase).
func _travar(i: int) -> void:
	_confirmado[i] = true
	_status[i].text = "PRONTO!"
	_sfx_ok.play()
	_tocar_voz(i)
	_paineis[i].modulate = Color(2.0, 2.0, 2.0)
	create_tween().tween_property(_paineis[i], "modulate", Color.WHITE, 0.4)


## Confirma o lutador do lado i e decide o próximo passo:
## 1 jogador: depois do P1, escolhe o adversário (ou a CPU sorteia); 2 jogadores: espera os dois.
func _confirmar(i: int) -> void:
	if _confirmado[i]:
		return
	_travar(i)
	if _modo_cpu and i == 0:
		if permitir_escolher_adversario:
			_fase = Fase.ADVERSARIO
			_status[1].text = "ESCOLHA!"
			_atualizar_dica()
		else:
			_fase = Fase.SORTEANDO
			_cpu_escolhe()
	elif _confirmado[0] and _confirmado[1]:
		_agendar_proximo(0.9)


## TECLA R: sorteia o lutador de quem ainda não confirmou (você e o adversário) com os cursores girando,
## confirma os dois e segue para a escolha de mapa.
func _sortear() -> void:
	var lados: Array[int] = []
	for i in 2:
		if not _confirmado[i]:
			lados.append(i)
	if lados.is_empty():
		return
	_fase = Fase.SORTEANDO
	# sorteia os resultados finais (o adversário tenta ser diferente do P1 quando há mais de um lutador)
	var final: Array[int] = [_cursor[0], _cursor[1]]
	for i in lados:
		final[i] = randi() % _lutadores.size()
	if lados.has(1) and _lutadores.size() > 1 and final[1] == final[0] and randf() < 0.75:
		final[1] = (final[0] + 1 + randi() % (_lutadores.size() - 1)) % _lutadores.size()
	var t := create_tween()
	for _k in 12:
		t.tween_callback(func() -> void:
			for i in lados:
				_cursor[i] = randi() % _lutadores.size()
				_atualizar_preview(i)
			_sfx_mover.play())
		t.tween_interval(0.07)
	t.tween_callback(func() -> void:
		for i in lados:
			_cursor[i] = final[i]
			_atualizar_preview(i)
			_travar(i)
		_agendar_proximo(1.0))


## Toca a "voz" do lutador confirmado e a corta depois de voz_duracao segundos (0 = toca inteira).
func _tocar_voz(i: int) -> void:
	var l := _lutadores[_cursor[i]]
	if l.voz_selecao == null:
		return
	var p := _voz[i]
	_voz_token[i] += 1
	var token: int = _voz_token[i]
	p.stop()
	p.stream = l.voz_selecao
	p.volume_db = l.voz_volume_db
	p.play()
	if l.voz_duracao > 0.0:
		get_tree().create_timer(l.voz_duracao).timeout.connect(_cortar_voz.bind(i, token))


## Corta a voz do lado i com um fade-out curtinho (só se ainda for a mesma voz).
func _cortar_voz(i: int, token: int) -> void:
	if token != _voz_token[i] or not is_instance_valid(_voz[i]):
		return
	var t := create_tween()
	t.tween_property(_voz[i], "volume_db", -40.0, 0.15)
	t.tween_callback(_voz[i].stop)


## (Só se permitir_escolher_adversario = false) A CPU escolhe: o cursor azul gira e para em um lutador sorteado.
func _cpu_escolhe() -> void:
	var opcoes: Array[int] = []
	for idx in _lutadores.size():
		if idx != _cursor[0] or _lutadores.size() == 1:
			opcoes.append(idx)
	var escolhido: int = opcoes.pick_random()
	var t := create_tween()
	t.tween_interval(0.5)
	for _k in 12:
		t.tween_callback(func() -> void:
			_cursor[1] = randi() % _lutadores.size()
			_atualizar_preview(1)
			_sfx_mover.play())
		t.tween_interval(0.09)
	t.tween_callback(func() -> void:
		_cursor[1] = escolhido
		_atualizar_preview(1)
		_travar(1)
		_agendar_proximo(0.9))


## Guarda os lutadores escolhidos e, depois de uma pausa, vai para a escolha de mapa.
func _agendar_proximo(espera: float) -> void:
	_fase = Fase.SAINDO
	VersusEstado.lutador_p1 = _lutadores[_cursor[0]]
	VersusEstado.lutador_p2 = _lutadores[_cursor[1]]
	get_tree().create_timer(espera).timeout.connect(_ir_para_mapa)


## Vai para a escolha de mapa.
func _ir_para_mapa() -> void:
	get_tree().change_scene_to_file(VersusEstado.CENA_MAPA)
