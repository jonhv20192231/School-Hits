class_name VersusProjetil
extends Node2D
## EFEITO DO ESPECIAL: uma bola de energia com rastro que voa de um lutador até o outro.
## Use:  var p := VersusProjetil.new(); add_child(p); p.iniciar(de, para, cor, 0.5); p.chegou.connect(...)

## Emitido quando o projétil chega ao alvo (aí o dano é aplicado).
signal chegou

var _de := Vector2.ZERO
var _para := Vector2.ZERO
var _cor := Color.WHITE
var _duracao := 0.5
var _t := 0.0
var _ativo := false


## Começa o voo. "de"/"para" são posições globais; "duracao" em segundos.
func iniciar(de: Vector2, para: Vector2, cor: Color, duracao: float = 0.5) -> void:
	_de = de
	_para = para
	_cor = cor
	_duracao = maxf(duracao, 0.05)
	_t = 0.0
	_ativo = true
	z_index = 50
	global_position = de


## Move o projétil e avisa quando chegou.
func _process(delta: float) -> void:
	if not _ativo:
		return
	_t += delta
	var k := clampf(_t / _duracao, 0.0, 1.0)
	global_position = _de.lerp(_para, k * k * (3.0 - 2.0 * k))   # começa e termina suave
	queue_redraw()
	if k >= 1.0:
		_ativo = false
		chegou.emit()
		queue_free()


## Desenha o rastro (círculos que somem para trás) e o núcleo brilhante.
func _draw() -> void:
	var dir := (_de - _para).normalized()
	for i in 8:
		var a := 1.0 - float(i) / 8.0
		draw_circle(dir * i * 16.0, 30.0 * a + 6.0, Color(_cor.r, _cor.g, _cor.b, 0.28 * a))
	draw_circle(Vector2.ZERO, 34.0, Color(_cor.r, _cor.g, _cor.b, 0.45))
	draw_circle(Vector2.ZERO, 22.0, _cor)
	draw_circle(Vector2.ZERO, 11.0, Color.WHITE)
