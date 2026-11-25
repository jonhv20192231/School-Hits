extends Node2D
## Criança do lobby, montada a partir das folhas Assets/Personagens/Alunos(npc)/NPC_x.png.
## Propositalmente NÃO é CharacterBody2D: o portal "MudarCena" reage a qualquer
## CharacterBody2D que encoste nele, e uma criança correndo não pode trocar de fase.
## A origem do nó fica nos pés da criança (bom para o y-sort com o jogador).

enum Modo { PARADA, VAGAR, CIRANDA, PERSEGUIR }

const FOLHA := "res://Assets/Personagens/Alunos(npc)/NPC_%d.png"
const EMOTE := "res://Assets/Personagens/Emotes dos personagens/%s_emote_16x16.png"
const DIRECOES := ["baixo", "esquerda", "cima", "direita"]

static var _cache_frames: Dictionary = {}

var sprite: AnimatedSprite2D
var modo: Modo = Modo.PARADA
var direcao := "baixo"
var velocidade := 80.0
var zona: RefCounted
var chance_de_parar := 0.4
var fugindo_de = null          # outra criança (quando está fugindo no pega-pega)
var perseguindo = null         # outra criança (quando é o pegador)

var centro := Vector2.ZERO     # ciranda
var raio := 30.0
var vel_angular := 1.4
var angulo := 0.0

var _alvo := Vector2.ZERO
var _tem_alvo := false
var _espera := 0.0
var _emote: AnimatedSprite2D
var _tempo_emote := 0.0


static func frames_para(folha: int, variante: int) -> SpriteFrames:
	var chave := "%d_%d" % [folha, variante]
	if _cache_frames.has(chave):
		return _cache_frames[chave]
	var textura: Texture2D = load(FOLHA % folha)
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var linha_base := 1 + variante * 4          # cada folha tem 3 variantes de pele, 4 linhas cada
	for d in DIRECOES.size():
		for tipo in ["parado", "andar"]:
			var nome := "%s_%s" % [tipo, DIRECOES[d]]
			frames.add_animation(nome)
			frames.set_animation_loop(nome, true)
			frames.set_animation_speed(nome, 3.0 if tipo == "parado" else 8.0)
			var coluna0 := 0 if tipo == "parado" else 4   # colunas 0-3 = idle, 4-7 = walk
			for i in 4:
				var atlas := AtlasTexture.new()
				atlas.atlas = textura
				atlas.region = Rect2((coluna0 + i) * 16, (linha_base + d) * 16, 16, 16)
				frames.add_frame(nome, atlas)
	_cache_frames[chave] = frames
	return frames


static func retrato_para(folha: int, variante: int) -> Texture2D:
	var atlas := AtlasTexture.new()
	atlas.atlas = load(FOLHA % folha)
	atlas.region = Rect2(0, (1 + variante * 4) * 16, 16, 16)
	return atlas


func configurar(folha: int, variante: int, escala := 2.0) -> void:
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = frames_para(folha, variante)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(escala, escala)
	sprite.offset = Vector2(0, -7)
	add_child(sprite)
	sprite.play("parado_baixo")


func pose(tipo: String, dir: String, rapidez := 1.0) -> void:
	direcao = dir
	_tocar(tipo, dir, rapidez)


func vagar(nova_zona: RefCounted, vel: float) -> void:
	zona = nova_zona
	velocidade = vel
	modo = Modo.VAGAR
	_espera = randf_range(0.0, 1.5)


func rodar_ciranda(novo_centro: Vector2, novo_raio: float, ang_inicial: float, vel_ang: float) -> void:
	modo = Modo.CIRANDA
	centro = novo_centro
	raio = novo_raio
	angulo = ang_inicial
	vel_angular = vel_ang
	position = centro + Vector2(cos(angulo), sin(angulo)) * raio


func perseguir(outra, nova_zona: RefCounted, vel: float) -> void:
	zona = nova_zona
	velocidade = vel
	perseguindo = outra
	fugindo_de = null
	modo = Modo.PERSEGUIR


func mostrar_emote(nome: String, duracao := 0.0) -> void:
	if _emote == null:
		_emote = AnimatedSprite2D.new()
		_emote.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_emote.scale = Vector2(2, 2)
		_emote.position = Vector2(0, -44)
		_emote.z_index = 20
		add_child(_emote)
	var textura: Texture2D = load(EMOTE % nome)      # cada emote tem 4 frames de 16x16 lado a lado
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", 6.0)
	frames.set_animation_loop("default", false)
	for i in int(textura.get_width() / 16):
		var atlas := AtlasTexture.new()
		atlas.atlas = textura
		atlas.region = Rect2(i * 16, 0, 16, 16)
		frames.add_frame("default", atlas)
	_emote.sprite_frames = frames
	_emote.play("default")
	_emote.visible = true
	_tempo_emote = duracao       # 0 = fica até esconder_emote()


func esconder_emote() -> void:
	if _emote != null:
		_emote.visible = false
	_tempo_emote = 0.0


func _process(delta: float) -> void:
	match modo:
		Modo.VAGAR:
			_vagar(delta)
		Modo.CIRANDA:
			_ciranda(delta)
		Modo.PERSEGUIR:
			_perseguir(delta)
	if _emote != null and _emote.visible:
		_emote.position.y = -44.0 + sin(Time.get_ticks_msec() * 0.009) * 2.0
		if _tempo_emote > 0.0:
			_tempo_emote -= delta
			if _tempo_emote <= 0.0:
				_emote.visible = false


func _vagar(delta: float) -> void:
	if _espera > 0.0:
		_espera -= delta
		_tocar("parado", direcao)
		return
	if not _tem_alvo:
		var afastar: Vector2 = Vector2.INF
		if fugindo_de != null:
			afastar = fugindo_de.position
		var ponto: Vector2 = zona.ponto_livre(position, afastar)
		if not ponto.is_finite():
			_espera = 0.4
			return
		_alvo = ponto
		_tem_alvo = true
	_andar_ate(_alvo, delta)
	if position.distance_to(_alvo) < 2.0:
		_tem_alvo = false
		if randf() < chance_de_parar:
			_espera = randf_range(0.6, 2.4)


func _perseguir(delta: float) -> void:
	if _espera > 0.0:
		_espera -= delta
		_tocar("parado", direcao)
		return
	if perseguindo == null:
		modo = Modo.VAGAR
		return
	_andar_ate(perseguindo.position, delta)
	if position.distance_to(perseguindo.position) < 18.0:
		_pegou()


func _pegou() -> void:
	var outra = perseguindo
	perseguindo = null
	fugindo_de = outra
	modo = Modo.VAGAR
	_tem_alvo = false
	_espera = 1.3
	chance_de_parar = 0.0
	outra.fugindo_de = null
	outra.modo = Modo.PERSEGUIR
	outra.perseguindo = self
	outra._espera = 0.7
	outra.mostrar_emote("Exclamation", 1.0)


func _ciranda(delta: float) -> void:
	angulo += vel_angular * delta
	position = centro + Vector2(cos(angulo), sin(angulo)) * raio
	var tangente := Vector2(-sin(angulo), cos(angulo)) * signf(vel_angular)
	direcao = _direcao_de(tangente)
	_tocar("andar", direcao, 0.85)


func _andar_ate(destino: Vector2, delta: float) -> void:
	var para := destino - position
	var dist := para.length()
	if dist < 0.001:
		return
	var passo := minf(velocidade * delta, dist)
	position += para / dist * passo
	direcao = _direcao_de(para)
	_tocar("andar", direcao, velocidade / 70.0)


func _direcao_de(v: Vector2) -> String:
	if absf(v.x) > absf(v.y) * 1.25:
		return "direita" if v.x > 0.0 else "esquerda"
	if absf(v.y) > absf(v.x) * 1.25:
		return "baixo" if v.y > 0.0 else "cima"
	return direcao


func _tocar(tipo: String, dir: String, rapidez := 1.0) -> void:
	var nome := "%s_%s" % [tipo, dir]
	if sprite.animation != nome:
		sprite.play(nome)
	sprite.speed_scale = rapidez
