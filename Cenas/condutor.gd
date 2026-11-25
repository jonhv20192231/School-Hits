extends Node

@export var intervalo_minimo: float = 0.35
@export var intervalo_maximo: float = 1.2
@export var velocidade_notas: float = 350.0
@export var largura_nota: float = 42.0
@export var altura_nota: float = 24.0

@onready var container_notas: Node2D = \
	$"../Pistas/TrackSusie/ContainerDeNotas"

var tempo_para_nota: float = 0.0
var gerador := RandomNumberGenerator.new()


func _ready() -> void:
	gerador.randomize()
	sortear_proximo_intervalo()


func _process(delta: float) -> void:
	tempo_para_nota -= delta

	if tempo_para_nota <= 0.0:
		criar_nota()
		sortear_proximo_intervalo()

	for nota in container_notas.get_children():
		nota.position.y += velocidade_notas * delta

		if nota.position.y > 1200.0:
			nota.queue_free()


func sortear_proximo_intervalo() -> void:
	tempo_para_nota = gerador.randf_range(
		intervalo_minimo,
		intervalo_maximo
	)


func criar_nota() -> void:
	var nota := ColorRect.new()

	nota.name = "NotaAleatoria"
	nota.color = Color(0.75, 0.2, 1.0, 1.0)
	nota.size = Vector2(largura_nota, altura_nota)

	# Posição horizontal centralizada na pista.
	var largura_pista: float = 100.0
	var centro_x: float = largura_pista / 2.0

	nota.position = Vector2(
		centro_x - largura_nota / 2.0,
		-altura_nota
	)

	container_notas.add_child(nota)
