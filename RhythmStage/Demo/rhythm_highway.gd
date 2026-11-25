class_name RhythmHighway
extends Control
## Organiza as pistas na tela: SÓ aparecem as lanes (pista + nome) dos jogadores ativos,
## centralizadas. Com 1 jogador, só a pista e o nome dele; com 2, as duas; com 3, todas.
## Reorganiza sozinho a cada vez que o RhythmPlayer começa uma música.
##
## Como montar: este Control tem como filhos um Control por lane (fundo + Label com o nome),
## a linha de acerto e um RhythmNoteField (que desenha as notas). Veja rhythm_demo.tscn.

## Avisa que as pistas mudaram de lugar (os personagens se ajustam a isso).
signal layout_changed

@export var player: RhythmPlayer
## Um Control por lane, na ordem: ANA (0), MARCOS (1), JUNPEI (2).
@export var lane_nodes: Array[NodePath] = []
## Linha de acerto (opcional): é esticada para cobrir só as pistas visíveis.
@export var hit_line: Control

## Posição x de cada lane dentro deste Control (só vale para as lanes visíveis).
var lane_x := PackedFloat32Array([0.0, 260.0, 520.0])


func _ready() -> void:
	if player == null:
		push_warning("RhythmHighway: aponte a propriedade 'player' para um RhythmPlayer.")
		return
	player.started.connect(relayout)
	if player.play != null:   # o player já começou antes de este nó ficar pronto
		relayout()


## Centro (x global) da pista de uma lane. Usado para posicionar o personagem embaixo dela.
func lane_center_x(lane: int) -> float:
	return global_position.x + lane_x[lane] + RhythmConfig.LANE_W * 0.5


func relayout() -> void:
	var active: Array = []
	for lane in RhythmConfig.lanes.size():
		if player.is_lane_active(lane):
			active.append(lane)

	var count := active.size()
	var total_w := count * RhythmConfig.LANE_W + maxi(count - 1, 0) * RhythmConfig.LANE_GAP
	var start_x := (size.x - total_w) * 0.5
	var step := RhythmConfig.LANE_W + RhythmConfig.LANE_GAP

	for lane in RhythmConfig.lanes.size():
		var slot := active.find(lane)
		if slot >= 0:
			lane_x[lane] = start_x + slot * step
		var node: Control = null
		if lane < lane_nodes.size():
			node = get_node_or_null(lane_nodes[lane]) as Control
		if node != null:
			node.visible = slot >= 0
			if slot >= 0:
				node.position.x = lane_x[lane]

	if hit_line != null:
		hit_line.position.x = start_x
		hit_line.size.x = total_w

	for child in get_children():
		if child is RhythmNoteField:
			child.lane_x = lane_x
	layout_changed.emit()
