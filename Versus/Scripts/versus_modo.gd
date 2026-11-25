extends Control
## TELA "MODO VERSUS": pergunta se o jogador quer jogar contra a CPU (um jogador) ou contra um amigo (dois jogadores).
## A interface é montada por código em _ready(). Depois da escolha vai para a seleção de personagem.

## Fundo da tela (azul do menu).
@export var cor_fundo: Color = VersusEstilo.COR_FUNDO

var _btn_um: Button


## Monta fundo, painel, título e botões.
func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	VersusEstado.limpar_escolhas()

	# fundo azul
	var fundo := ColorRect.new()
	fundo.color = cor_fundo
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)

	# painel creme central
	var painel := PanelContainer.new()
	painel.add_theme_stylebox_override("panel", VersusEstilo.caixa(VersusEstilo.COR_PAINEL, VersusEstilo.COR_BORDA, 6, 14))
	painel.set_anchors_preset(Control.PRESET_CENTER)
	painel.custom_minimum_size = Vector2(860, 0)
	painel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	painel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(painel)

	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 18)
	painel.add_child(caixa)

	var titulo := Label.new()
	titulo.text = "MODO VERSUS"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	titulo.custom_minimum_size = Vector2(0, 110)
	VersusEstilo.estilizar_rotulo(titulo, 64, VersusEstilo.COR_AMARELO, 12)
	caixa.add_child(titulo)

	var sub := Label.new()
	sub.text = "COMO VOCÊ QUER JOGAR?"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	VersusEstilo.estilizar_rotulo(sub, 28, VersusEstilo.COR_BORDA, 0)
	caixa.add_child(sub)

	_btn_um = _botao(caixa, "UM JOGADOR - CONTRA A CPU", _escolher.bind(VersusEstado.Modo.UM_JOGADOR))
	_botao(caixa, "DOIS JOGADORES - CONTRA UM AMIGO", _escolher.bind(VersusEstado.Modo.DOIS_JOGADORES))
	_botao(caixa, "VOLTAR", _voltar)

	var dica := Label.new()
	dica.text = "1P: A S D F      2P: J K L Ç"
	dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	VersusEstilo.estilizar_rotulo(dica, 20, VersusEstilo.COR_BORDA, 0)
	caixa.add_child(dica)

	_btn_um.grab_focus()   # teclado: setas cima/baixo + Enter


## Cria um botão estilizado dentro de "pai" ligado à função "acao".
func _botao(pai: Control, texto: String, acao: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(0, 74)
	VersusEstilo.estilizar_botao(b, 28)
	b.pressed.connect(acao)
	pai.add_child(b)
	return b


## Guarda o modo escolhido e vai para a seleção de personagem.
func _escolher(modo: int) -> void:
	VersusEstado.modo = modo
	get_tree().change_scene_to_file(VersusEstado.CENA_SELECAO)


## Volta para a tela "Modo de jogo".
func _voltar() -> void:
	get_tree().change_scene_to_file(VersusEstado.CENA_MODOS_DE_JOGO)


## ESC também volta.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_voltar()
