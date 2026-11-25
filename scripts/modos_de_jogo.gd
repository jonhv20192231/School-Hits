extends Control

#Sinais de botões para quando o usuário pressionar
#Ele ir para próxima cena.

#CÓDIGO SECRETO: o botão "Modo versus" começa invisível e desativado.
#Ele só aparece quando o jogador digita, em sequência, as teclas J O A O nesta tela.
const CODIGO_VERSUS: Array[int] = [KEY_J, KEY_O, KEY_A, KEY_O]

#Fica true depois que o código for digitado (vale até fechar o jogo, assim o botão
#continua liberado quando o jogador volta do modo versus para esta tela).
static var versus_liberado := false

#Últimas teclas digitadas (guarda só a quantidade do código).
var _digitado: Array[int] = []

@onready var _botao_versus: Button = $ModoVersus

func _ready() -> void:
	#Esconde o botão, a menos que o código já tenha sido digitado antes.
	_mostrar_botao_versus(versus_liberado, false)

#Lê as teclas: guarda as últimas 4 e, se forem J O A O, libera o botão do modo versus.
func _unhandled_input(event: InputEvent) -> void:
	var tecla := event as InputEventKey
	if tecla == null or not tecla.pressed or tecla.echo or versus_liberado:
		return
	_digitado.append(tecla.physical_keycode)
	if _digitado.size() > CODIGO_VERSUS.size():
		_digitado.pop_front()
	if _digitado == CODIGO_VERSUS:
		versus_liberado = true
		_mostrar_botao_versus(true, true)

#Mostra/esconde o botão do modo versus (visível e clicável só quando liberado).
#animar = true faz o botão "pular" na tela ao aparecer.
func _mostrar_botao_versus(liberado: bool, animar: bool) -> void:
	_botao_versus.visible = liberado
	_botao_versus.disabled = not liberado
	if liberado and animar:
		_botao_versus.pivot_offset = _botao_versus.size / 2.0
		_botao_versus.scale = Vector2(0.2, 0.2)
		create_tween().tween_property(_botao_versus, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_um_jogador_pressed() -> void:
	get_tree().change_scene_to_file("res://cutscenes/cutscene_01.tscn")
	
func _on_coop_pressed() -> void:
	get_tree().change_scene_to_file("res://Cenas/cena_ritmo_coop_01.tscn")
	
func _on_modo_livre_pressed() -> void:
	get_tree().change_scene_to_file("res://SelecaoMusica/selecao_musica.tscn")
	
#Botão "Modo versus": abre a tela que pergunta 1 jogador (contra a CPU) ou 2 jogadores.
func _on_modo_versus_pressed() -> void:
	get_tree().change_scene_to_file("res://Versus/Cenas/versus_modo.tscn")
	
func _on_sair_pressed() -> void:
	get_tree().change_scene_to_file("res://Cenas/menu.tscn")
