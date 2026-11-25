class_name VersusEstilo
extends RefCounted
## VISUAL COMPARTILHADO das telas do versus: fonte, cores e funções para estilizar botões e textos,
## além de um gerador de "bips" (efeitos sonoros simples, sem precisar de arquivos de áudio).

## Fonte do jogo (a mesma dos outros menus).
const FONTE: FontFile = preload("res://Assets/fonte/MonsterFriendFore.otf")
## Azul do fundo, creme dos painéis, azul-escuro das bordas e amarelo dos títulos (cores do menu "Modo de jogo").
const COR_FUNDO := Color("5468c4")
const COR_PAINEL := Color("f4f1e6")
const COR_BORDA := Color("22306b")
const COR_AMARELO := Color("ffd45a")


## Cria uma caixa (StyleBoxFlat) com fundo, borda e cantos arredondados.
static func caixa(fundo: Color, borda: Color, espessura: int = 4, raio: int = 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fundo
	sb.border_color = borda
	sb.set_border_width_all(espessura)
	sb.set_corner_radius_all(raio)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


## Deixa um botão com a cara do menu (creme com borda azul; amarelo ao passar o mouse/foco).
static func estilizar_botao(b: Button, tamanho_fonte: int = 28) -> void:
	b.add_theme_font_override("font", FONTE)
	b.add_theme_font_size_override("font_size", tamanho_fonte)
	b.add_theme_color_override("font_color", COR_BORDA)
	b.add_theme_color_override("font_hover_color", COR_BORDA)
	b.add_theme_color_override("font_focus_color", COR_BORDA)
	b.add_theme_color_override("font_pressed_color", COR_BORDA)
	b.add_theme_stylebox_override("normal", caixa(COR_PAINEL, COR_BORDA))
	b.add_theme_stylebox_override("hover", caixa(COR_AMARELO, COR_BORDA))
	b.add_theme_stylebox_override("focus", caixa(COR_AMARELO, Color("c0392b")))
	b.add_theme_stylebox_override("pressed", caixa(Color("ffe9a0"), COR_BORDA))


## Estiliza um Label: fonte do jogo, tamanho, cor e contorno escuro.
static func estilizar_rotulo(l: Label, tamanho: int, cor: Color = Color.WHITE, contorno: int = 6) -> void:
	l.add_theme_font_override("font", FONTE)
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.15))
	l.add_theme_constant_override("outline_size", contorno)


## Gera um "bip" (onda quadrada) com a frequência e duração dadas. Use com um AudioStreamPlayer.
static func bip(freq: float, segundos: float, volume: float = 0.35) -> AudioStreamWAV:
	var taxa := 22050
	var n := int(taxa * segundos)
	var dados := PackedByteArray()
	dados.resize(n * 2)
	for i in n:
		var env := 1.0 - float(i) / float(n)
		var onda := 1.0 if fmod(float(i) * freq / taxa, 1.0) < 0.5 else -1.0
		dados.encode_s16(i * 2, int(onda * env * volume * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = taxa
	w.data = dados
	return w
