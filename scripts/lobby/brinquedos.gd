extends Node2D
## Balanço e gangorra animados do lobby.
## Os desenhos originais são tiles da camada "TileMapLayer_outros"; aqui eles são apagados
## em tempo de execução e substituídos pelos PNGs de Assets/Cenários/Animados/.

const PASTA := "res://Assets/Cenários/Animados/"

# Canto superior esquerdo (em pixels do mundo) de cada PNG.
const ORIGEM_BALANCO := Vector2(1664, 3008)
const ORIGEM_GANGORRA := Vector2(1684, 3160)

# Células de tile a apagar (balanço: linhas 188-197 / gangorra: linhas 198-201, colunas 104-116).
const FONTE_TILE := 18
const CELULAS_BALANCO := Rect2i(104, 188, 13, 10)
const CELULAS_GANGORRA := Rect2i(104, 198, 13, 4)

var _t := 0.0
var _pendulos: Array = []          # {no, fase, vel, amp}
var _gangorra_a: Sprite2D
var _gangorra_b: Sprite2D
var _gangorra_kids: Array = []     # {kid, a, b}


func preparar(camada: TileMapLayer) -> void:
	if camada != null:
		_apagar_tiles(camada, CELULAS_BALANCO)
		_apagar_tiles(camada, CELULAS_GANGORRA)
	_montar_balanco()
	_montar_gangorra()


## lado 0 = assento azul, 1 = assento amarelo
func sentar_no_balanco(lado: int, kid: Node2D) -> void:
	var no: Node2D = _pendulos[lado].no
	no.add_child(kid)
	kid.position = Vector2(0, 90)
	kid.pose("andar", "baixo", 0.45)


## lado 0 = ponta esquerda (olha para a direita), 1 = ponta direita
func sentar_na_gangorra(lado: int, kid: Node2D) -> void:
	add_child(kid)
	if lado == 0:
		_gangorra_kids.append({"kid": kid, "a": ORIGEM_GANGORRA + Vector2(32, 26), "b": ORIGEM_GANGORRA + Vector2(36, 51)})
		kid.pose("parado", "direita")
	else:
		_gangorra_kids.append({"kid": kid, "a": ORIGEM_GANGORRA + Vector2(124, 51), "b": ORIGEM_GANGORRA + Vector2(128, 26)})
		kid.pose("parado", "esquerda")
	kid.position = _gangorra_kids.back().a


func _process(delta: float) -> void:
	_t += delta
	for p in _pendulos:
		var amplitude := deg_to_rad(p.amp + 3.0 * sin(_t * 0.35 + p.fase))
		p.no.rotation = amplitude * sin(_t * p.vel + p.fase)
	if _gangorra_a != null:
		var s := sin(_t * TAU / 2.8)
		var peso := smoothstep(-0.3, 0.3, s)       # 0 = ponta esquerda alta, 1 = ponta direita alta
		_gangorra_a.modulate.a = 1.0 - peso
		_gangorra_b.modulate.a = peso
		for g in _gangorra_kids:
			var pos: Vector2 = g.a.lerp(g.b, peso)
			pos.y -= 5.0 * sin(peso * PI)
			g.kid.position = pos


func _apagar_tiles(camada: TileMapLayer, area: Rect2i) -> void:
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			if camada.get_cell_source_id(Vector2i(x, y)) == FONTE_TILE:
				camada.erase_cell(Vector2i(x, y))


func _sprite(arquivo: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(PASTA + arquivo)
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return s


func _montar_balanco() -> void:
	var estrutura := _sprite("balanco_estrutura.png")
	estrutura.position = ORIGEM_BALANCO
	add_child(estrutura)
	var assentos := [
		{"arq": "balanco_azul.png", "pivo": Vector2(76, 22), "local": Vector2(28, 0), "fase": 0.0},
		{"arq": "balanco_amarelo.png", "pivo": Vector2(134.5, 22), "local": Vector2(27.5, 0), "fase": 1.9},
	]
	for a in assentos:
		var no := Node2D.new()
		no.position = ORIGEM_BALANCO + a.pivo
		add_child(no)
		var s := _sprite(a.arq)
		s.position = -a.local
		no.add_child(s)
		_pendulos.append({"no": no, "fase": a.fase, "vel": 2.3, "amp": 11.0})


func _montar_gangorra() -> void:
	_gangorra_a = _sprite("gangorra_a.png")
	_gangorra_a.position = ORIGEM_GANGORRA
	add_child(_gangorra_a)
	_gangorra_b = _sprite("gangorra_b.png")
	_gangorra_b.position = ORIGEM_GANGORRA
	_gangorra_b.modulate.a = 0.0
	add_child(_gangorra_b)
