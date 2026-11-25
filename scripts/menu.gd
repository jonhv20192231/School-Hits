extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.





func _on_iniciar_pressed() -> void:
	#Próxima cena ao pressionar
	get_tree().change_scene_to_file("res://Cenas/modos_de_jogo.tscn")
	


func _on_ajudar_pressed() -> void:
	get_tree().change_scene_to_file("res://Cenas/menu_ajuda.tscn")
	



func _on_sair_pressed() -> void:
	# Fecha o jogo
	get_tree().quit()
