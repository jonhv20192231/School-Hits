class_name VersusBarra
extends Control
## BARRA (vida ou especial) desenhada por código. Suaviza as mudanças e, na vida, mostra um "rastro" amarelo
## do dano recente (como nos jogos de luta). Defina "valor" de 0 a 1 que ela se anima sozinha.

## Valor atual (0 a 1). Mude por código: barra.valor = vida / vida_maxima
var valor: float = 1.0:
	set(v):
		valor = clampf(v, 0.0, 1.0)

## Cor da barra cheia. Se "cor_por_nivel" estiver ligado, vai de verde (cheia) a vermelho (quase vazia).
@export var cor_barra: Color = Color("4cd964")
## Cor da barra pela quantidade: verde > amarelo > vermelho (usada na barra de vida).
@export var cor_por_nivel: bool = true
## Mostra o rastro amarelo quando o valor cai (barra de vida).
@export var usar_rastro: bool = true
## Barra enche da direita para a esquerda (usada no lado direito da tela).
@export var invertido: bool = false
## Pisca quando está 100% cheia (barra de especial pronta).
@export var piscar_quando_cheia: bool = false
## Cor da moldura.
@export var cor_moldura: Color = Color(1, 1, 1, 0.9)

var _visual: float = 1.0   # valor mostrado (persegue "valor")
var _rastro: float = 1.0   # valor do rastro (desce devagar)
var _tempo: float = 0.0


## Anima os valores mostrados e pede para redesenhar.
func _process(delta: float) -> void:
	_tempo += delta
	_visual = move_toward(_visual, valor, delta * 1.6)
	if valor > _rastro:
		_rastro = valor
	else:
		_rastro = move_toward(_rastro, valor, delta * 0.35)
	queue_redraw()


## Desenha fundo, rastro, barra e moldura.
func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0, 0, 0, 0.65))
	var pad := 2.0
	var area := r.grow(-pad)
	if usar_rastro and _rastro > _visual:
		draw_rect(_faixa(area, _rastro), Color("ffd23f"))
	var cor := cor_barra
	if cor_por_nivel:
		cor = Color("ff4b4b").lerp(Color("ffd23f"), clampf(_visual * 2.0, 0.0, 1.0))
		cor = cor.lerp(Color("4cd964"), clampf(_visual * 2.0 - 1.0, 0.0, 1.0))
	if piscar_quando_cheia and _visual >= 0.999:
		cor = cor.lerp(Color.WHITE, 0.5 + 0.5 * sin(_tempo * 12.0))
	draw_rect(_faixa(area, _visual), cor)
	draw_rect(r, cor_moldura, false, 2.0)


## Retângulo preenchido até "frac" da área (da esquerda, ou da direita se invertido).
func _faixa(area: Rect2, frac: float) -> Rect2:
	var w := area.size.x * clampf(frac, 0.0, 1.0)
	if invertido:
		return Rect2(area.position.x + area.size.x - w, area.position.y, w, area.size.y)
	return Rect2(area.position.x, area.position.y, w, area.size.y)
