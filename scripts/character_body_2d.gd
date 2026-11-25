extends CharacterBody2D

@export var speed: float = 60.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# Lista com os prefixos dos visuais/skins disponíveis que você criou no AnimatedSprite2D
var npc_skins: Array[String] = ["npc1", "npc2", "npc3"] 
var selected_skin: String = ""

var movement_direction: Vector2 = Vector2.ZERO
var timer: float = 0.0

func _ready() -> void:
	# 1. Escolhe uma skin aleatoriamente ao nascer na cena
	selected_skin = npc_skins.pick_random()
	
	# 2. Escolhe o primeiro destino aleatório
	_choose_new_direction()

func _physics_process(delta: float) -> void:
	# Atualiza o temporizador para trocar de direção periodicamente
	timer -= delta
	if timer <= 0:
		_choose_new_direction()

	# Aplica o movimento
	velocity = movement_direction * speed
	_update_animation()
	
	move_and_slide()

# Escolhe para onde o NPC vai andar e quanto tempo vai durar
func _choose_new_direction() -> void:
	# Sorteia se ele vai ficar parado (Vector2.ZERO) ou andar para alguma direção
	var choices = [
		Vector2.ZERO, 
		Vector2.UP, 
		Vector2.DOWN, 
		Vector2.LEFT, 
		Vector2.RIGHT
	]
	movement_direction = choices.pick_random()
	
	# Sorteia quanto tempo (entre 1 e 3 segundos) ele vai manter essa ação
	timer = randf_range(1.0, 3.0)

# Atualiza a animação com base na skin sorteada e na direção atual
func _update_animation() -> void:
	if movement_direction == Vector2.ZERO:
		animated_sprite.stop()
		return

	# Define o eixo predominante para escolher a animação correta
	if abs(movement_direction.x) > abs(movement_direction.y):
		animated_sprite.play(selected_skin + "_direita")
		animated_sprite.flip_h = movement_direction.x < 0 # Inverte se for para a esquerda
	else:
		animated_sprite.flip_h = false
		if movement_direction.y < 0:
			animated_sprite.play(selected_skin + "_cima")
		else:
			animated_sprite.play(selected_skin + "_baixo")
