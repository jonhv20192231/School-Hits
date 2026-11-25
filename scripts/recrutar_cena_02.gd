extends Node2D

func _ready() -> void:
	$AnimatedSprite2D.play("comemora")
	



func _on_proximofase_pressed() -> void:
	get_tree().change_scene_to_file("res://Cenas/cena_ritmo_02.tscn")
