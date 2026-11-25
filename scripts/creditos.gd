extends Control

# Caminho para a cena do seu jogo (troque pelo caminho da sua fase inicial)
@export_file("*.tscn") var next_scene_path: String = "res://Cenas/fase_inicial.tscn"

@onready var video_player: VideoStreamPlayer = $VideoStreamPlayer
@onready var skip_button: Button = $CanvasLayer/PularCutscene

func _ready() -> void:
	# Conecta o sinal do botão "Pular"
	
	
	# Conecta o sinal de quando o vídeo termina sozinho
	video_player.finished.connect(_on_video_finished)
	
	# Garante que o vídeo comece a rodar
	video_player.play()

# Chamado se o jogador clicar no botão de pular
func _on_skip_button_pressed() -> void:
	_change_to_next_scene()

# Chamado automaticamente quando o vídeo chega ao fim
func _on_video_finished() -> void:
	_change_to_next_scene()

# Função auxiliar para trocar de cena
func _change_to_next_scene() -> void:
	if next_scene_path != "":
		get_tree().change_scene_to_file("res://Cenas/menu.tscn")
