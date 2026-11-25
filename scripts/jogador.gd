extends CharacterBody2D

@export var speed: float = 200.0

# Referência ao nó AnimatedSprite2D (certifique-se de que ele se chama AnimatedSprite2D na sua árvore)
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _physics_process(_delta: float) -> void:
	# Pega a direção do W, A, S, D
	var direction := Input.get_vector("esquerda", "direita", "cima", "baixo")
	
	# Define a velocidade diretamente pela direção * velocidade
	velocity = direction * speed
	
	# Controla as animações com base no movimento
	_update_animations(direction)
	
	# Move o personagem considerando colisões
	move_and_slide()

func _update_animations(direction: Vector2) -> void:
	# Se o jogador estiver parado (sem apertar nenhuma tecla)
	if direction == Vector2.ZERO:
		animated_sprite.stop()
		return

	# Compara se o movimento horizontal é maior que o vertical para priorizar lados
	if abs(direction.x) > abs(direction.y):
		if direction.x < 0:
			animated_sprite.play("AndarEsquerda")
			animated_sprite.flip_h = false # Se a animação já aponta para a esquerda, não precisa inverter
		else:
			animated_sprite.play("AndarEsquerda")
			animated_sprite.flip_h = true # Ou true se a sua animação padrão foi desenhada para a esquerda
	else:
		if direction.y < 0:
			animated_sprite.play("AndarCima")
			animated_sprite.flip_h = false
		else:
			animated_sprite.play("AndarBaixo")
			animated_sprite.flip_h = false
