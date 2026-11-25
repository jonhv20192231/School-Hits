extends Area2D

# Permite escolher qual cena carregar diretamente pelo Inspetor do Godot
@export_file("*.tscn") var target_scene: String = ""

func _ready() -> void:
	# Conecta o sinal nativo 'body_entered' via código
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	# Verifica se quem entrou na área é o Jogador (CharacterBody2D)
	if body is CharacterBody2D: # Ou `if body.is_in_group("Player"):`
		_change_scene()

func _change_scene() -> void:
	if target_scene != "":
		get_tree().change_scene_to_file(target_scene)
	else:
		print("AVISO: Nenhuma cena alvo configurada para este portal!")
