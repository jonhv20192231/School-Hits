class_name VersusPista
extends RhythmHighway
## PISTAS DO VERSUS: em vez de centralizar as pistas (RhythmHighway original), coloca a pista do P1
## na ESQUERDA da tela e a pista do P2/CPU na DIREITA. Reorganiza sozinho quando a janela muda de tamanho.

## Distância (px) entre a borda da tela e cada pista.
@export var margem_lateral: float = 60.0


func _ready() -> void:
	super._ready()
	resized.connect(relayout)   # reposiciona se o tamanho da janela mudar
	relayout()


## Posiciona as duas pistas (lane 0 à esquerda, lane 1 à direita) e avisa os personagens/HUD.
func relayout() -> void:
	lane_x[0] = margem_lateral
	lane_x[1] = size.x - margem_lateral - RhythmConfig.LANE_W
	for lane in 2:
		var node: Control = null
		if lane < lane_nodes.size():
			node = get_node_or_null(lane_nodes[lane]) as Control
		if node != null:
			node.visible = true
			node.position.x = lane_x[lane]
	for child in get_children():
		if child is RhythmNoteField:
			child.lane_x = lane_x   # o NoteField desenha as notas nessas posições
	layout_changed.emit()
