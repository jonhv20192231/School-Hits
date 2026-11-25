extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Sessão de botões para selecionar musicas

func _on_musica_01_pressed() -> void:
	get_tree().change_scene_to_file("res://CenasMusicas/musica_01.tscn")
	
func _on_musica_02_pressed() -> void:
	get_tree().change_scene_to_file("res://CenasMusicas/musica_02.tscn")
	
func _on_musica_03_pressed() -> void:
	get_tree().change_scene_to_file("res://CenasMusicas/musica_03.tscn")
	
func _on_musica_04_pressed() -> void:
	get_tree().change_scene_to_file("res://CenasMusicas/musica_04.tscn")
	
func _on_musica_05_pressed() -> void:
	get_tree().change_scene_to_file("res://CenasMusicas/musica_05.tscn")


func _on_sair_pressed() -> void:
	get_tree().change_scene_to_file("res://Cenas/modos_de_jogo.tscn")
	
	
func _on_musica_06_pressed() -> void:
	get_tree().change_scene_to_file("res://CenasMusicas/musica_06.tscn")
	
func _on_musica_07_pressed() -> void:
	get_tree().change_scene_to_file("res://CenasMusicas/musica_07.tscn")
	
func _on_musica_08_pressed() -> void:
	get_tree().change_scene_to_file("res://CenasMusicas/musica_08.tscn")
