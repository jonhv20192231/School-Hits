extends Node2D
## PÁTIO ESCOLAR (cena compartilhada pela fase_inicial e pela fase_final).
## A cena patio_escolar.tscn contém o chão (TileMapLayer "Chao"), as cercas-vivas com colisão ("Cercas"),
## a fachada da escola com a porta, o pavilhão do fliperama, o parquinho de areia, árvores, postes e bancos.
## Este script só faz dois acabamentos em tempo de execução:
##   • limita a câmera do jogador às bordas do pátio (não mostra o "vazio" fora do mapa);
##   • faz a seta da porta balançar para indicar o lugar que leva à próxima fase.

## Retângulo (em pixels do mundo) que a câmera do jogador pode mostrar.
@export var limites_camera: Rect2 = Rect2(1632, 2368, 1440, 928)
## Liga/desliga o limite de câmera.
@export var ajustar_camera: bool = true
## Seta que balança sobre o caminho da porta (nó filho "SetaPorta").
@onready var _seta: Node2D = get_node_or_null("SetaPorta")
var _seta_y := 0.0
var _t := 0.0


## Aplica os limites na câmera do jogador (procura o nó "Jogador" na cena atual).
func _ready() -> void:
	if _seta != null:
		_seta_y = _seta.position.y
	if not ajustar_camera:
		return
	var raiz := get_tree().current_scene
	var jogador := raiz.find_child("Jogador", true, false) if raiz != null else null
	var cam := jogador.get_node_or_null("Camera2D") as Camera2D if jogador != null else null
	if cam != null:
		cam.limit_left = int(limites_camera.position.x)
		cam.limit_top = int(limites_camera.position.y)
		cam.limit_right = int(limites_camera.end.x)
		cam.limit_bottom = int(limites_camera.end.y)


## Balança a seta da porta.
func _process(delta: float) -> void:
	_t += delta
	if _seta != null:
		_seta.position.y = _seta_y + sin(_t * 4.0) * 6.0
