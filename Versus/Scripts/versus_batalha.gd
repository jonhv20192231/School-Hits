extends Node2D
## BATALHA VERSUS (ritmo + luta).
## • A pista do P1 fica na ESQUERDA e a do P2/CPU na DIREITA.
## • Em cima de cada pista: nome do lutador (vem do sprite escolhido), barra de vida e barra de especial.
## • Errou a nota  -> perde vida.   Acertou -> recupera vida.
## • Combo -> enche a barra de ESPECIAL. Com a barra cheia, aperte a tecla do especial para dar dano no oponente.
## • Vida zerou = K.O.  Acabou o tempo = vence quem tiver mais vida.
## O mapa e a música escolhidos nas telas anteriores (VersusEstado) têm prioridade sobre os @export de fundo/música/BPM/
## duração abaixo (que só valem se a cena for aberta direto). Tudo que dá para ajustar está nas variáveis @export abaixo,
## visíveis no Inspetor ao clicar no nó raiz da cena.

# ───────────────────────── EXPORTS ─────────────────────────
@export_group("Música e ritmo")
## Músicas possíveis: uma é sorteada a cada luta. Arraste arquivos de áudio aqui.
@export var musicas: Array[AudioStream] = []
## Volume da música.
@export_range(-40.0, 6.0, 0.5, "suffix:dB") var volume_musica_db: float = -4.0
## BPM da grade das notas (ajuste para combinar com a música).
@export_range(40.0, 240.0, 1.0, "suffix:bpm") var bpm_das_notas: float = 120.0
## Duração da luta em segundos (as notas caem até esse tempo).
@export_range(20.0, 600.0, 5.0, "suffix:s") var duracao_segundos: float = 120.0
## Quantas notas por segundo cada lado recebe.
@export_range(0.5, 6.0, 0.1) var notas_por_segundo: float = 1.8
## Semente das notas aleatórias (0 = diferente a cada luta).
@export var semente_aleatoria: int = 0
## Imagem do cenário de fundo.
@export var fundo: Texture2D

@export_group("Combate")
## Vida máxima de cada lutador.
@export var vida_maxima: float = 100.0
## Vida perdida ao errar uma nota.
@export var dano_ao_errar: float = 3.0
## Vida recuperada ao acertar: PERFEITO, ÓTIMO e BOM.
@export var cura_perfeito: float = 1.0
@export var cura_otimo: float = 0.7
@export var cura_bom: float = 0.4
## O especial só enche quando o combo atual é pelo menos este valor.
@export var especial_combo_minimo: int = 3
## Quanto (%) da barra de especial cada acerto com combo enche (valor base).
@export var especial_por_acerto: float = 3.0
## Bônus extra por acerto, multiplicado pelo combo (limitado a 30).
@export var especial_bonus_por_combo: float = 0.15
## Teclas que soltam o especial do P1 e do P2 (a CPU solta sozinha).
@export var tecla_especial_p1: Key = KEY_SPACE
@export var tecla_especial_p2: Key = KEY_ENTER

@export_group("CPU")
## Dificuldade da CPU no modo um jogador.
@export_enum("Fácil", "Normal", "Difícil", "Mestre") var dificuldade_cpu: int = 1
## Chance de a CPU tentar acertar cada nota, por dificuldade.
@export var cpu_precisao: PackedFloat32Array = PackedFloat32Array([0.70, 0.85, 0.94, 0.985])
## Desvio de tempo (s) da CPU por dificuldade (menor = mais PERFEITOs).
@export var cpu_desvio: PackedFloat32Array = PackedFloat32Array([0.075, 0.050, 0.035, 0.022])
## A CPU toca os sons de acerto/erro dela?
@export var sons_da_cpu: bool = false

@export_group("Posições")
## Distância (px) do centro da tela até cada lutador.
@export var distancia_lutadores: float = 230.0
## Distância (px) do chão até a parte de baixo da tela.
@export var altura_do_chao: float = 70.0

# ───────────────────────── LADO (dados de cada jogador) ─────────────────────────
## Guarda tudo de um lado da luta: lutador, vida, especial, combo e estatísticas.
class Lado:
	var indice := 0                  # 0 = esquerda, 1 = direita
	var lutador: Lutador
	var humano := true               # false = CPU
	var vida := 100.0
	var especial := 0.0              # 0 a 100
	var combo := 0
	var combo_max := 0
	var pontos := 0
	var contagem := [0, 0, 0, 0]     # PERFEITO, ÓTIMO, BOM, ERROS
	var view: VersusLutadorView
	var painel: Control
	var rotulo_nome: Label
	var rotulo_tag: Label
	var barra_vida: VersusBarra
	var barra_especial: VersusBarra
	var dica: Label
	var especial_em_voo := false     # true enquanto o golpe especial está acontecendo

# ───────────────────────── NÓS DA CENA ─────────────────────────
@onready var _fundo: TextureRect = %Fundo
@onready var _musica: AudioStreamPlayer = %Musica
@onready var _ritmo: VersusRitmo = %Ritmo
@onready var _pista: VersusPista = %Pista
@onready var _tempo_label: Label = %Tempo
@onready var _contagem: Label = %Contagem
@onready var _mensagem: Label = %Mensagem
@onready var _banner: Label = %BannerEspecial
@onready var _flash: ColorRect = %Flash
@onready var _resultado: PanelContainer = %Resultado
@onready var _titulo_resultado: Label = %TituloResultado
@onready var _coluna_p1: Label = %ColunaP1
@onready var _coluna_p2: Label = %ColunaP2
@onready var _sfx_acerto: AudioStreamPlayer = %SfxAcerto
@onready var _sfx_erro: AudioStreamPlayer = %SfxErro
@onready var _sfx_especial: AudioStreamPlayer = %SfxEspecial

var _lados: Array[Lado] = []
var _cpu: VersusCpu = null
var _fim := false
var _musica_iniciada := false
var _proximo_especial_cpu := -1.0   # tempo (s da música) em que a CPU solta o especial (-1 = ainda não sorteado)
var _rng := RandomNumberGenerator.new()
var _tremor := 0.0
# valores efetivos (a música escolhida pode trocar BPM, duração e notas por segundo)
var _bpm: float = 120.0
var _duracao: float = 120.0
var _nps: float = 1.8


# ───────────────────────── CICLO DE VIDA ─────────────────────────

## Entrou na árvore: troca as pistas do ritmo para o formato versus ANTES de os filhos ficarem prontos.
func _enter_tree() -> void:
	VersusEstado.aplicar_pistas_versus()


## Saiu da árvore: devolve as pistas originais para as outras cenas de ritmo continuarem normais.
func _exit_tree() -> void:
	VersusEstado.restaurar_pistas()


## Monta a luta: lados, interface, ritmo e música.
func _ready() -> void:
	_rng.randomize()
	VersusEstado.garantir_lutadores()
	_montar_lados()
	_aplicar_escolhas()
	_configurar_cenario()
	_configurar_interface()
	_configurar_ritmo()
	get_viewport().size_changed.connect(_organizar_layout)
	_pista.layout_changed.connect(_organizar_layout)
	_organizar_layout()
	_ritmo.start()


## Cria os dois "Lados" ligando cada um aos nós (sprite, nome, barras) da cena.
func _montar_lados() -> void:
	var p2_cpu := VersusEstado.p2_eh_cpu()
	var dados := [VersusEstado.lutador_p1, VersusEstado.lutador_p2]
	var views := [%LutadorP1, %LutadorP2]
	var paineis := [%PainelP1, %PainelP2]
	var tags := [%TagP1, %TagP2]
	var nomes := [%NomeP1, %NomeP2]
	var vidas := [%VidaP1, %VidaP2]
	var especiais := [%EspecialP1, %EspecialP2]
	var dicas := [%DicaP1, %DicaP2]
	for i in 2:
		var l := Lado.new()
		l.indice = i
		l.lutador = dados[i]
		l.humano = (i == 0) or not p2_cpu
		l.vida = vida_maxima
		l.view = views[i]
		l.painel = paineis[i]
		l.rotulo_tag = tags[i]
		l.rotulo_nome = nomes[i]
		l.barra_vida = vidas[i]
		l.barra_especial = especiais[i]
		l.dica = dicas[i]
		_lados.append(l)
		l.view.configurar(l.lutador, i)


## Lê o mapa e a música escolhidos nas telas anteriores (VersusEstado) e ajusta BPM, duração e densidade de notas.
## Se nada foi escolhido (ex.: abriu a cena direto no editor) usa os valores dos @export acima.
func _aplicar_escolhas() -> void:
	_bpm = bpm_das_notas
	_duracao = duracao_segundos
	_nps = notas_por_segundo
	var mapa := VersusEstado.cenario
	if mapa != null:
		fundo = mapa.obter_fundo()
		%CamadaFundo.get_node("Escurecer").color.a = mapa.escurecer
	var m := VersusEstado.musica
	if m != null and m.audio != null:
		musicas = [m.audio] as Array[AudioStream]
		volume_musica_db = m.volume_db
		_bpm = m.bpm
		if m.duracao_luta > 0.0:
			_duracao = m.duracao_luta
		if m.notas_por_segundo > 0.0:
			_nps = m.notas_por_segundo


## Fundo, música, textos iniciais e estilo dos elementos da interface.
func _configurar_cenario() -> void:
	if fundo != null:
		_fundo.texture = fundo
	if not musicas.is_empty():
		_musica.stream = musicas.pick_random()
	_musica.volume_db = volume_musica_db
	_musica.finished.connect(func() -> void:   # música mais curta que a luta: toca de novo
		if not _fim:
			_musica.play())
	_sfx_acerto.stream = VersusEstilo.bip(880.0, 0.06)
	_sfx_erro.stream = VersusEstilo.bip(140.0, 0.12, 0.5)
	_sfx_especial.stream = VersusEstilo.bip(330.0, 0.35, 0.5)


## Preenche nomes, tags (1P/2P/CPU) e cores das barras; esconde a tela de resultado.
func _configurar_interface() -> void:
	var nomes_tag := ["1P", "CPU" if VersusEstado.p2_eh_cpu() else "2P"]
	for l in _lados:
		l.rotulo_tag.text = nomes_tag[l.indice]
		l.rotulo_tag.add_theme_color_override("font_color", l.lutador.cor)
		l.rotulo_nome.text = l.lutador.nome_exibido
		l.rotulo_nome.add_theme_color_override("font_color", l.lutador.cor)
		_ajustar_fonte(l.rotulo_nome, 200.0, 30)
		l.barra_vida.invertido = (l.indice == 1)
		l.barra_especial.invertido = (l.indice == 1)
		l.barra_especial.cor_barra = l.lutador.cor_especial
		l.barra_vida.valor = 1.0
		l.barra_especial.valor = 0.0
		l.dica.text = ""
	_mensagem.text = ""
	_banner.text = ""
	_flash.color.a = 0.0
	_resultado.visible = false
	%BotaoRevanche.pressed.connect(func() -> void: _ir_para(get_tree().current_scene.scene_file_path))
	%BotaoTrocar.pressed.connect(func() -> void: _ir_para(VersusEstado.CENA_SELECAO))
	%BotaoModos.pressed.connect(func() -> void: _ir_para(VersusEstado.CENA_MODOS_DE_JOGO))


## Reduz o tamanho da fonte do nome até ele caber na largura da pista.
func _ajustar_fonte(rotulo: Label, largura: float, tamanho_max: int) -> void:
	var t := tamanho_max
	var fonte := rotulo.get_theme_font("font")
	while t > 12 and fonte.get_string_size(rotulo.text, HORIZONTAL_ALIGNMENT_LEFT, -1, t).x > largura:
		t -= 2
	rotulo.add_theme_font_size_override("font_size", t)


## Configura o RhythmPlayer: 2 lados, notas aleatórias, BPM e duração escolhidos aqui.
func _configurar_ritmo() -> void:
	_ritmo.players = 2
	_ritmo.lane_order = PackedInt32Array([0, 1])
	_ritmo.random_notes = true
	_ritmo.random_notes_per_second = _nps
	_ritmo.random_seed = semente_aleatoria
	_ritmo.duration_seconds = _duracao
	_ritmo.sfx_enabled = false          # os sons são tocados por este script (para a CPU poder ficar quieta)
	_ritmo.save_result_in_root = false
	_ritmo.auto_start = false
	_ritmo.chart_path = _criar_chart_com_bpm()
	var humanas: Array[int] = [0]
	if not VersusEstado.p2_eh_cpu():
		humanas.append(1)
	_ritmo.lanes_humanas = humanas
	_ritmo.started.connect(_ao_comecar)
	_ritmo.judged.connect(_ao_julgar)
	_ritmo.finished.connect(_ao_acabar_o_tempo)


## O RhythmPlayer pega o BPM de um arquivo de chart. Aqui escrevemos um chart mínimo só com o BPM escolhido
## (as notas de verdade são sorteadas depois). Devolve o caminho do arquivo.
func _criar_chart_com_bpm() -> String:
	var caminho := "user://versus_chart.json"
	var f := FileAccess.open(caminho, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({
			"title": "", "bpm": _bpm, "offset": 0.0,
			"notes": [ { "beat": 4, "lane": 0, "col": 0 } ],
		}))
		f.close()
	return caminho


## O ritmo começou: pinta as pistas com a cor dos lutadores e prepara a CPU.
func _ao_comecar() -> void:
	for l in _lados:
		_ritmo.styles[l.indice]["color"] = l.lutador.cor
	if VersusEstado.p2_eh_cpu():
		_cpu = VersusCpu.new()
		_cpu.lane = 1
		_cpu.precisao = cpu_precisao[dificuldade_cpu]
		_cpu.desvio = cpu_desvio[dificuldade_cpu]
		_cpu.preparar(_ritmo.chart)
		_proximo_especial_cpu = -1.0


## Posiciona lutadores, chão e painéis (em cima de cada pista) conforme o tamanho da janela.
func _organizar_layout() -> void:
	var tela := get_viewport_rect().size
	var chao_y := tela.y - altura_do_chao
	_lados[0].view.position = Vector2(tela.x * 0.5 - distancia_lutadores, chao_y)
	_lados[1].view.position = Vector2(tela.x * 0.5 + distancia_lutadores, chao_y)
	for l in _lados:
		l.painel.global_position.x = _pista.global_position.x + _pista.lane_x[l.indice]


# ───────────────────────── LOOP PRINCIPAL ─────────────────────────

## Todo frame: contagem, relógio, música, CPU, dicas do especial, tremor de tela e fim de luta.
func _process(delta: float) -> void:
	if _fim:
		_aplicar_tremor(delta)
		return
	var t := _ritmo.song_time
	# contagem regressiva 3-2-1-LUTAR!
	if t < 0.0:
		_contagem.text = str(ceili(-t))
		_contagem.visible = true
	elif t < 0.8:
		_contagem.text = "LUTAR!"
		_contagem.visible = true
	else:
		_contagem.visible = false
	# a música só começa depois da contagem
	if t >= 0.0 and not _musica_iniciada:
		_musica_iniciada = true
		if _musica.stream != null:
			_musica.play()
	# tempo restante
	var restante := maxf(_duracao - maxf(t, 0.0), 0.0)
	_tempo_label.text = "%02d:%02d" % [int(restante) / 60, int(restante) % 60]
	# CPU
	if _cpu != null and _ritmo.is_playing:
		_cpu.atualizar(_ritmo, t)
		_pensar_especial_cpu(t)
	_atualizar_dicas()
	_aplicar_tremor(delta)


## A CPU sorteia um atraso depois que a barra enche e então solta o especial.
func _pensar_especial_cpu(t: float) -> void:
	var cpu_lado := _lados[1]
	if cpu_lado.especial < 100.0 or cpu_lado.especial_em_voo:
		_proximo_especial_cpu = -1.0
		return
	if _proximo_especial_cpu < 0.0:
		var espera_max: float = [4.0, 2.5, 1.5, 0.8][dificuldade_cpu]
		_proximo_especial_cpu = t + _rng.randf_range(espera_max * 0.3, espera_max)
	elif t >= _proximo_especial_cpu:
		_proximo_especial_cpu = -1.0
		_soltar_especial(cpu_lado)


## Mostra "ESPECIAL PRONTO" (piscando) embaixo da barra quando está cheia.
func _atualizar_dicas() -> void:
	for l in _lados:
		var pronto := l.especial >= 100.0
		if pronto:
			var tecla := tecla_especial_p1 if l.indice == 0 else tecla_especial_p2
			l.dica.text = ("ESPECIAL! TECLA %s" % OS.get_keycode_string(tecla).to_upper()) if l.humano else "ESPECIAL!"
			l.dica.visible = int(Time.get_ticks_msec() / 250) % 2 == 0
		else:
			l.dica.visible = false


## Tremida de tela (fundo e lutadores) depois de um especial.
func _aplicar_tremor(delta: float) -> void:
	_tremor = move_toward(_tremor, 0.0, delta * 30.0)
	var d := Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * _tremor
	%CamadaFundo.offset = d
	$Lutadores.position = d


# ───────────────────────── ENTRADA (ESPECIAL) ─────────────────────────

## Tecla do especial dos jogadores humanos. (O ESC é do menu de pausa, não tratamos aqui.)
func _unhandled_input(event: InputEvent) -> void:
	if _fim or not _ritmo.is_playing:
		return
	var ke := event as InputEventKey
	if ke == null or not ke.pressed or ke.echo:
		return
	if ke.physical_keycode == tecla_especial_p1 and _lados[0].humano:
		_soltar_especial(_lados[0])
	elif ke.physical_keycode == tecla_especial_p2 and _lados[1].humano:
		_soltar_especial(_lados[1])


# ───────────────────────── JULGAMENTO DAS NOTAS ─────────────────────────

## Uma nota foi julgada (acerto ou erro) em uma das pistas: aplica vida, combo, especial e animação.
func _ao_julgar(lane: int, julgamento: int, _sloppy: bool, coluna: int) -> void:
	if _fim:
		return
	var l := _lados[lane]
	var tocar_som := l.humano or sons_da_cpu
	if julgamento == RhythmConfig.Judgment.MISS:
		l.combo = 0
		l.contagem[3] += 1
		_mudar_vida(l, -dano_ao_errar)
		l.view.reagir_erro()
		if tocar_som:
			_sfx_erro.play()
		return
	# acertou
	l.combo += 1
	l.combo_max = maxi(l.combo_max, l.combo)
	l.contagem[julgamento] += 1
	l.pontos += RhythmConfig.JUDGMENT_POINTS[julgamento] + mini(l.combo, 100) * 2
	_mudar_vida(l, [cura_perfeito, cura_otimo, cura_bom][julgamento])
	if l.combo >= especial_combo_minimo and not l.especial_em_voo:
		var ganho := especial_por_acerto + minf(l.combo, 30.0) * especial_bonus_por_combo
		l.especial = minf(l.especial + ganho, 100.0)
		l.barra_especial.valor = l.especial / 100.0
	l.view.reagir_acerto(julgamento, coluna)
	if tocar_som:
		_sfx_acerto.pitch_scale = 1.0 + 0.25 * lane
		_sfx_acerto.play()


## Soma (ou subtrai) vida, atualiza a barra e verifica o K.O.
func _mudar_vida(l: Lado, delta: float) -> void:
	l.vida = clampf(l.vida + delta, 0.0, vida_maxima)
	l.barra_vida.valor = l.vida / vida_maxima
	if l.vida <= 0.0:
		_finalizar(1 - l.indice, "K.O.!")


# ───────────────────────── ESPECIAL ─────────────────────────

## Solta o golpe especial: gasta a barra, toca a pose, lança o projétil e, ao chegar, tira vida do oponente.
func _soltar_especial(l: Lado) -> void:
	if _fim or l.especial < 100.0 or l.especial_em_voo or _ritmo.song_time < 0.0:
		return
	var alvo := _lados[1 - l.indice]
	l.especial = 0.0
	l.barra_especial.valor = 0.0
	l.especial_em_voo = true
	l.view.tocar_especial()
	_sfx_especial.play()
	_mostrar_banner(l.lutador.nome_especial + "!", l.lutador.cor_especial)
	var proj := VersusProjetil.new()
	add_child(proj)
	var de := l.view.global_position + Vector2(0, -150)
	var para := alvo.view.global_position + Vector2(0, -150)
	proj.iniciar(de, para, l.lutador.cor_especial, 0.55)
	proj.chegou.connect(_especial_chegou.bind(l, alvo))


## O projétil chegou: aplica o dano, treme a tela e mostra o número do dano.
func _especial_chegou(atacante: Lado, alvo: Lado) -> void:
	atacante.especial_em_voo = false
	if _fim:
		return
	var dano := vida_maxima * atacante.lutador.dano_especial / 100.0
	alvo.view.levar_dano_especial()
	_tremor = 14.0
	_piscar_tela(atacante.lutador.cor_especial)
	_numero_flutuante("-%d" % int(round(dano)), alvo.view.global_position + Vector2(0, -260), atacante.lutador.cor_especial)
	_mudar_vida(alvo, -dano)


## Faixa grande com o nome do especial no meio da tela.
func _mostrar_banner(texto: String, cor: Color) -> void:
	_banner.text = texto
	_banner.add_theme_color_override("font_color", cor)
	_banner.modulate.a = 1.0
	_banner.scale = Vector2(1.3, 1.3)
	var t := create_tween()
	t.tween_property(_banner, "scale", Vector2.ONE, 0.15)
	t.tween_interval(0.6)
	t.tween_property(_banner, "modulate:a", 0.0, 0.3)


## Clarão colorido rápido na tela toda.
func _piscar_tela(cor: Color) -> void:
	_flash.color = Color(cor.r, cor.g, cor.b, 0.5)
	create_tween().tween_property(_flash, "color:a", 0.0, 0.3)


## Número que sobe e some (ex.: dano do especial).
func _numero_flutuante(texto: String, pos: Vector2, cor: Color) -> void:
	var l := Label.new()
	l.text = texto
	VersusEstilo.estilizar_rotulo(l, 54, cor, 8)
	l.position = pos - Vector2(60, 0)
	l.z_index = 100
	add_child(l)
	var t := create_tween().set_parallel(true)
	t.tween_property(l, "position:y", pos.y - 70.0, 0.9)
	t.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.3)
	t.chain().tween_callback(l.queue_free)


# ───────────────────────── FIM DA LUTA ─────────────────────────

## O tempo acabou: vence quem tem mais vida (empate: mais pontos; se ainda empatar, EMPATE).
func _ao_acabar_o_tempo(_pontos: int, _precisao: float, _rank: String, _combo: int) -> void:
	if _fim:
		return
	var a := _lados[0]
	var b := _lados[1]
	var vencedor := -1
	if absf(a.vida - b.vida) > 0.5:
		vencedor = 0 if a.vida > b.vida else 1
	elif a.pontos != b.pontos:
		vencedor = 0 if a.pontos > b.pontos else 1
	_finalizar(vencedor, "TEMPO ESGOTADO!")


## Encerra a luta: para ritmo e música, mostra a mensagem, poses de vitória/KO e depois o resultado.
## vencedor: 0 ou 1; -1 = empate.
func _finalizar(vencedor: int, texto: String) -> void:
	if _fim:
		return
	_fim = true
	_ritmo.stop()
	_contagem.visible = false
	var tm := create_tween()
	tm.tween_property(_musica, "volume_db", -40.0, 1.2)
	tm.tween_callback(_musica.stop)
	_mensagem.text = texto
	_mensagem.scale = Vector2(2.0, 2.0)
	create_tween().tween_property(_mensagem, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	for l in _lados:
		if vencedor == -1:
			continue
		if l.indice == vencedor:
			l.view.vitoria()
		else:
			l.view.ko()
	get_tree().create_timer(2.0).timeout.connect(_mostrar_resultado.bind(vencedor))


## Monta e mostra o painel de resultado com as estatísticas dos dois lados.
func _mostrar_resultado(vencedor: int) -> void:
	_mensagem.text = ""
	_titulo_resultado.text = "EMPATE!" if vencedor == -1 else "%s VENCEU!" % _lados[vencedor].lutador.nome_exibido
	_coluna_p1.text = _texto_estatisticas(_lados[0])
	_coluna_p2.text = _texto_estatisticas(_lados[1])
	_resultado.visible = true
	%BotaoRevanche.grab_focus()


## Texto com as estatísticas de um lado.
func _texto_estatisticas(l: Lado) -> String:
	var acertos: int = l.contagem[0] + l.contagem[1] + l.contagem[2]
	var total: int = acertos + l.contagem[3]
	var prec := 0.0
	if total > 0:
		prec = (l.contagem[0] * 1.0 + l.contagem[1] * 0.8 + l.contagem[2] * 0.5) / total * 100.0
	return ("%s\nVida: %d\nPontos: %d\nPrecisão: %.1f\nCombo máx.: %d\nPerfeitos: %d\nÓtimos: %d\nBons: %d\nErros: %d" % [
		l.lutador.nome_exibido, int(round(l.vida / vida_maxima * 100.0)), l.pontos, prec, l.combo_max,
		l.contagem[0], l.contagem[1], l.contagem[2], l.contagem[3]]).to_upper()


## Troca de cena (revanche, seleção ou modos de jogo).
func _ir_para(caminho: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(caminho)
