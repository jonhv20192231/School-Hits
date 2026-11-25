extends RefCounted
## Define por onde as crianças podem andar (coordenadas do mundo da fase_inicial).
## Para ajustar: mude os retângulos de "bloqueios" e a lista de "arvores".

# Gramado inteiro do parque (dentro das cercas-vivas).
var limites := Rect2(1695, 2575, 1305, 665)

# Áreas onde NÃO se pode andar: palco do fliperama, postes, balanço, gangorra,
# parquinho de areia (com a cerca colorida).
var bloqueios: Array[Rect2] = [
	Rect2(2055, 2630, 510, 225),
	Rect2(2020, 2690, 34, 165),
	Rect2(2561, 2690, 34, 165),
	Rect2(2246, 3115, 30, 155),
	Rect2(2326, 3115, 30, 155),
	Rect2(1692, 3020, 152, 145),
	Rect2(1680, 3165, 160, 65),
	Rect2(2712, 2840, 318, 365),
]

# Centros aproximados das árvores (as crianças desviam delas).
var arvores: Array[Vector2] = [
	Vector2(1790, 2621), Vector2(1726, 2665), Vector2(1790, 2681), Vector2(1805, 2844),
	Vector2(1964, 2973), Vector2(2108, 3145), Vector2(2395, 2905), Vector2(2704, 2572),
	Vector2(2831, 2621), Vector2(2912, 2715), Vector2(2735, 2779), Vector2(2973, 3194),
	Vector2(2720, 3227),
]
var raio_arvore := 30.0


func bloqueado(p: Vector2, folga := 14.0) -> bool:
	if not limites.has_point(p):
		return true
	for r in bloqueios:
		if r.grow(folga).has_point(p):
			return true
	for a in arvores:
		if a.distance_to(p) < raio_arvore + folga * 0.5:
			return true
	return false


func caminho_livre(a: Vector2, b: Vector2) -> bool:
	var passos := int(a.distance_to(b) / 12.0) + 1
	for i in range(1, passos + 1):
		if bloqueado(a.lerp(b, float(i) / passos), 6.0):
			return false
	return true


func ponto_aleatorio() -> Vector2:
	for i in 60:
		var p := Vector2(
			randf_range(limites.position.x, limites.end.x),
			randf_range(limites.position.y, limites.end.y))
		if not bloqueado(p):
			return p
	return limites.get_center()


## Sorteia um destino livre a até "alcance" pixels de "origem".
## Se "afastar_de" for informado, escolhe o mais distante dele (usado por quem foge).
func ponto_livre(origem: Vector2, afastar_de := Vector2.INF, alcance := 420.0) -> Vector2:
	var melhor := Vector2.INF
	var melhor_nota := -1.0
	for i in 16:
		var p := origem + Vector2.from_angle(randf() * TAU) * randf_range(80.0, alcance)
		if bloqueado(p) or not caminho_livre(origem, p):
			continue
		if not afastar_de.is_finite():
			return p
		var nota := p.distance_to(afastar_de)
		if nota > melhor_nota:
			melhor_nota = nota
			melhor = p
	return melhor
