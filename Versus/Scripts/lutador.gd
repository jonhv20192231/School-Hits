class_name Lutador
extends Resource
## DADOS DE UM PERSONAGEM LUTADOR  (um arquivo .tres por personagem, em res://Versus/Dados/)
##
## COMO CRIAR UM PERSONAGEM NOVO (sem mexer em código):
##   1. No FileSystem: clique direito em Versus/Dados > Novo Recurso > "Lutador" > salve como  meu_personagem.tres
##   2. Preencha os campos abaixo no Inspetor (nome, sprite frames, retrato, voz...).
##   3. Abra  Versus/Dados/elenco.tres  e adicione o novo arquivo na lista "Lutadores".
## Pronto: ele aparece sozinho na seleção de personagem.
##
## ANIMAÇÕES que o SpriteFrames deve ter (as com "opcional" podem faltar: o jogo escolhe uma parecida):
##   idle         pose parada (obrigatória)
##   hit_0, hit_1 ...  poses de ACERTO. Cada nota usa uma delas (coluna % quantidade). Pode ter 1, 2, 3...
##   perfect      (opcional) pose de acerto PERFEITO
##   miss_0, miss_1 ... poses de ERRO (tomando dano), tocadas em sequência a cada erro
##   special      (opcional) pose ao soltar o ESPECIAL
##   ko           (opcional) pose de derrotado
##   vitoria      (opcional) pose de vencedor (pode ser em loop)
## Os sprites devem olhar para a DIREITA (o jogo espelha sozinho o lutador do lado direito) e todos os
## quadros devem ter o MESMO tamanho de imagem, com o personagem centralizado e os pés na base.

@export_group("Identidade")
## Nome mostrado na seleção, na barra de vida (em cima da pista) e no resultado.
@export var nome_exibido: String = "NOVO LUTADOR"
## Cor do personagem (pista, cursor e detalhes da interface).
@export var cor: Color = Color(1.0, 0.85, 0.2)

@export_group("Imagens")
## Imagem do quadradinho na grade de seleção. Se ficar vazio, o jogo recorta a cabeça do quadro "idle".
@export var retrato: Texture2D
## SpriteFrames com as animações (veja a lista no topo deste arquivo).
@export var sprite_frames: SpriteFrames
## Tamanho do personagem na luta (1.0 = tamanho original da imagem).
@export_range(0.5, 6.0, 0.05) var escala_sprite: float = 2.4
## Quantos pixels (da imagem original) existem ABAIXO dos pés do personagem. Use 0 se os pés tocam a base da imagem.
@export var deslocamento_pes: float = 0.0
## Animações que NÃO devem ser espelhadas quando o lutador está no lado direito (ex.: imagens com texto desenhado).
@export var animacoes_sem_espelhar: PackedStringArray = PackedStringArray(["perfect", "miss_1"])

@export_group("Voz da seleção")
## Áudio tocado quando o jogador confirma este personagem na seleção. Arraste o arquivo (.mp3, .ogg, .wav) aqui.
@export var voz_selecao: AudioStream
## Por quanto tempo o áudio toca (em segundos) antes de ser cortado. 0 = toca o áudio inteiro.
@export_range(0.0, 30.0, 0.1, "or_greater", "suffix:s") var voz_duracao: float = 2.0
## Volume do áudio da seleção.
@export_range(-40.0, 6.0, 0.5, "suffix:dB") var voz_volume_db: float = 0.0

@export_group("Especial")
## Nome do golpe especial (aparece na tela quando é usado).
@export var nome_especial: String = "ESPECIAL"
## Dano do especial, em % da vida máxima do oponente.
@export_range(1.0, 100.0, 1.0, "suffix:%") var dano_especial: float = 25.0
## Cor do efeito do especial.
@export var cor_especial: Color = Color(1.0, 0.7, 0.2)


## Devolve a imagem para a grade de seleção: o "retrato" se existir; senão um recorte automático
## da cabeça e ombros do primeiro quadro da animação "idle".
func obter_retrato() -> Texture2D:
	if retrato != null:
		return retrato
	if sprite_frames == null:
		return null
	var nome := &"idle" if sprite_frames.has_animation(&"idle") else StringName("")
	if nome == &"":
		var todas := sprite_frames.get_animation_names()
		if todas.is_empty():
			return null
		nome = StringName(todas[0])
	var tex := sprite_frames.get_frame_texture(nome, 0)
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null:
		return tex
	var usado := img.get_used_rect()
	if usado.size.x <= 0 or usado.size.y <= 0:
		return tex
	var lado := mini(usado.size.x, int(usado.size.y * 0.5))
	var cx := usado.position.x + usado.size.x / 2
	var x0 := clampi(cx - lado / 2, 0, maxi(img.get_width() - lado, 0))
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = Rect2(x0, usado.position.y, lado, lado)
	return atlas


## Tamanho (em pixels da imagem original) do quadro "idle". Usado para posicionar o sprite pelos pés.
func tamanho_quadro() -> Vector2:
	if sprite_frames == null:
		return Vector2(100, 100)
	var nome := &"idle" if sprite_frames.has_animation(&"idle") else StringName("")
	if nome == &"":
		var todas := sprite_frames.get_animation_names()
		if todas.is_empty():
			return Vector2(100, 100)
		nome = StringName(todas[0])
	var tex := sprite_frames.get_frame_texture(nome, 0)
	return tex.get_size() if tex != null else Vector2(100, 100)
