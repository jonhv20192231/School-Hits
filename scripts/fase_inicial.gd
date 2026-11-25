extends Node2D
## LOBBY (pátio escolar) — usado pela fase_inicial E pela fase_final (as duas cenas usam este script).
## Parquinho cheio de crianças brincando, fliperama animado e a caixa de fala dos meninos da ciranda
## quando o jogador chega perto. O cenário vem da cena Cenas/patio_escolar.tscn (nó "PatioEscolar").

const Crianca := preload("res://scripts/lobby/crianca.gd")
const Zonas := preload("res://scripts/lobby/lobby_zonas.gd")
const Brinquedos := preload("res://scripts/lobby/brinquedos.gd")
const BalaoFala := preload("res://scripts/lobby/balao_fala.gd")

const NOME_JOGADOR := "Marcos"

@export var corredores := 12                 # crianças correndo pelo gramado
@export var duplas_pega_pega := 2            # cada dupla = 2 crianças (uma pega a outra)
@export var distancia_dialogo := 150.0       # distância da ciranda que abre a caixa de fala
@export var ordenar_com_jogador := true      # criança passa na frente/atrás do jogador conforme o Y

# Ciranda no parquinho de areia (lado direito).
const CENTRO_CIRANDA := Vector2(2800, 3055)
const RAIO_CIRANDA := 30.0
const AREA_PEGA_PEGA_AREIA := Rect2(2860, 3015, 140, 80)

# Quem fala na caixa: "quem" = índice da criança da ciranda (0 a 3).
const FALAS := [
	{"quem": 0, "emote": "Surprised", "texto": "Olha quem apareceu... é o %s."},
	{"quem": 1, "emote": "Evil", "texto": "A gente tá no meio da ciranda, não tem lugar pra você."},
	{"quem": 2, "emote": "Angry", "texto": "Você é muito chato! Só reclama e estraga a brincadeira de todo mundo."},
	{"quem": 3, "emote": "Angry", "texto": "Ninguém quer brincar com você, %s. Vai embora!"},
	{"quem": 0, "emote": "Evil", "texto": "Vai procurar outra coisa pra fazer. A gente não vai te chamar."},
]
const NOMES := ["Davi", "Caio", "Theo", "Enzo"]
const CORES := [Color(1.0, 0.85, 0.4), Color(0.55, 0.85, 1.0), Color(0.6, 1.0, 0.6), Color(1.0, 0.6, 0.7)]
# (folha NPC_x, variante 0-2) dos meninos da ciranda
const PELES_CIRANDA := [[6, 0], [7, 1], [8, 2], [9, 0]]

var _zonas: RefCounted
var _zona_areia: RefCounted
var _combos: Array = []
var _camada: Node2D
var _brinquedos: Node2D
var _balao: CanvasLayer
var _jogador: Node2D
var _ciranda: Array = []
var _retratos: Array = []


func _ready() -> void:
	randomize()
	_zonas = Zonas.new()
	_zona_areia = Zonas.new()
	_zona_areia.limites = AREA_PEGA_PEGA_AREIA
	_zona_areia.bloqueios = [] as Array[Rect2]
	_zona_areia.arvores = [] as Array[Vector2]

	var painel_antigo := get_node_or_null("Panel")
	if painel_antigo != null:
		painel_antigo.visible = false
	var npcs_antigos := get_node_or_null("npc")
	if npcs_antigos != null:
		npcs_antigos.queue_free()
	_jogador = get_node_or_null("Entidades/Jogador")

	_esconder_marcador_do_portal()
	_animar_fliperama()
	_sortear_peles()

	_camada = Node2D.new()
	_camada.name = "Criancas"
	_camada.y_sort_enabled = true
	add_child(_camada)
	_integrar_decoracao_do_patio()

	_brinquedos = Brinquedos.new()
	_brinquedos.name = "Brinquedos"
	add_child(_brinquedos)
	var tiles := get_node_or_null("TileMapLayer_outros") as TileMapLayer
	if tiles != null:
		move_child(_brinquedos, tiles.get_index() + 1)
	_brinquedos.preparar(tiles)

	_balao = BalaoFala.new()
	add_child(_balao)
	_balao.linha_exibida.connect(_ao_mudar_fala)

	_criar_ciranda()
	_criar_pega_pega_na_areia()
	_criar_criancas_dos_brinquedos()
	_criar_corredores()
	_criar_pega_pega_no_gramado()

	if ordenar_com_jogador and _jogador != null:
		_jogador.reparent.call_deferred(_camada, true)


func _process(_delta: float) -> void:
	if _jogador == null:
		return
	var dist := _jogador.global_position.distance_to(CENTRO_CIRANDA)
	if not _balao.esta_aberto() and dist < distancia_dialogo:
		_balao.abrir(_montar_falas())
	elif _balao.esta_aberto() and dist > distancia_dialogo + 50.0:
		_balao.fechar()
		for c in _ciranda:
			c.esconder_emote()


## O portal "MudarCena" vem com uma imagem de teste (images.jpg) que apareceria na porta do pátio: esconde só a imagem
## (a área que troca de cena continua funcionando).
func _esconder_marcador_do_portal() -> void:
	for portal in find_children("MudarCena", "Area2D", true, false):
		var img := portal.get_node_or_null("AnimatedSprite2D")
		if img != null:
			img.visible = false


## Toca a animação "fliperama" em todos os fliperamas (nós no grupo "fliperama" ou um AnimatedSprite2D solto na fase).
func _animar_fliperama() -> void:
	var lista: Array = get_tree().get_nodes_in_group("fliperama")
	var solto := get_node_or_null("AnimatedSprite2D")
	if solto != null:
		lista.append(solto)
	for f in lista:
		var fliper := f as AnimatedSprite2D
		if fliper != null and fliper.sprite_frames != null and fliper.sprite_frames.has_animation("fliperama"):
			fliper.play("fliperama")


## Passa árvores, postes, bancos e fliperamas do pátio (nó "PatioEscolar/Decoracao") para a camada das crianças,
## assim o jogador e as crianças passam na frente ou atrás deles conforme o Y.
func _integrar_decoracao_do_patio() -> void:
	var deco := find_child("Decoracao", true, false)
	if deco == null:
		return
	for item in deco.get_children():
		item.reparent(_camada, true)


func _sortear_peles() -> void:
	for folha in range(1, 16):
		for variante in 3:
			if not PELES_CIRANDA.has([folha, variante]):
				_combos.append([folha, variante])
	_combos.shuffle()


func _nova_crianca(pele: Array, adicionar := true) -> Node2D:
	var c: Node2D = Crianca.new()
	c.configurar(pele[0], pele[1])
	if adicionar:
		_camada.add_child(c)
	return c


func _pele_aleatoria() -> Array:
	return _combos.pop_back()


func _montar_falas() -> Array:
	var falas: Array = []
	for f in FALAS:
		var q: int = f.quem
		falas.append({
			"nome": NOMES[q],
			"texto": f.texto.replace("%s", NOME_JOGADOR),
			"cor": CORES[q],
			"retrato": _retratos[q],
		})
	return falas


func _ao_mudar_fala(indice: int) -> void:
	for c in _ciranda:
		c.esconder_emote()
	var fala: Dictionary = FALAS[indice]
	_ciranda[fala.quem].mostrar_emote(fala.emote)


func _criar_ciranda() -> void:
	for i in PELES_CIRANDA.size():
		var c := _nova_crianca(PELES_CIRANDA[i])
		c.rodar_ciranda(CENTRO_CIRANDA, RAIO_CIRANDA, TAU * i / PELES_CIRANDA.size(), 1.5)
		_ciranda.append(c)
		_retratos.append(Crianca.retrato_para(PELES_CIRANDA[i][0], PELES_CIRANDA[i][1]))


func _criar_pega_pega_na_areia() -> void:
	var a := _nova_crianca(_pele_aleatoria())
	var b := _nova_crianca(_pele_aleatoria())
	a.position = _zona_areia.limites.get_center()
	b.position = a.position + Vector2(40, 10)
	a.vagar(_zona_areia, 95.0)
	b.perseguir(a, _zona_areia, 85.0)
	a.fugindo_de = b


func _criar_criancas_dos_brinquedos() -> void:
	for lado in 2:
		_brinquedos.sentar_no_balanco(lado, _nova_crianca(_pele_aleatoria(), false))
		_brinquedos.sentar_na_gangorra(lado, _nova_crianca(_pele_aleatoria(), false))


func _criar_corredores() -> void:
	for i in corredores:
		var c := _nova_crianca(_pele_aleatoria())
		c.position = _zonas.ponto_aleatorio()
		c.vagar(_zonas, randf_range(80.0, 135.0))


func _criar_pega_pega_no_gramado() -> void:
	for i in duplas_pega_pega:
		var fugitivo := _nova_crianca(_pele_aleatoria())
		var pegador := _nova_crianca(_pele_aleatoria())
		fugitivo.position = _zonas.ponto_aleatorio()
		pegador.position = fugitivo.position + Vector2(50, 0)
		fugitivo.vagar(_zonas, 120.0)
		fugitivo.chance_de_parar = 0.0
		fugitivo.fugindo_de = pegador
		pegador.perseguir(fugitivo, _zonas, 110.0)
