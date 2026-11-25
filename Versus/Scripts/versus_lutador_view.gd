class_name VersusLutadorView
extends AnimatedSprite2D
## O LUTADOR NA TELA DA BATALHA. Mostra as poses do SpriteFrames do "Lutador" conforme o que acontece:
## acertou nota (hit_*/perfect), errou (miss_*), soltou especial (special), tomou o especial, KO e vitória.
## O ponto (0,0) deste nó fica nos PÉS do personagem, então basta posicioná-lo no chão da arena.

## Quanto tempo (s) a pose de acerto fica antes de voltar para "idle".
@export var tempo_pose_acerto: float = 0.16
## Quanto tempo (s) a pose de erro fica na tela.
@export var tempo_pose_erro: float = 0.45
## Usa a animação "perfect" nos acertos PERFEITOS (se o personagem tiver).
@export var usar_pose_perfect: bool = true
## Balanço (px) do personagem parado, para ele parecer vivo.
@export var balanco: float = 3.0

var lutador: Lutador          # dados do personagem que está sendo mostrado
var lado: int = 0             # 0 = esquerda (olha para a direita); 1 = direita (espelhado)
var _offset_base := Vector2.ZERO
var _reverter: float = 0.0    # segundos até voltar para o idle
var _travado := false         # true depois do KO/vitória (não volta mais para o idle)
var _bloqueio_especial: float = 0.0   # enquanto > 0 a pose do especial não é trocada por acertos/erros
var _tempo: float = 0.0
var _n_hit := 0               # quantas animações hit_N existem
var _n_miss := 0              # quantas animações miss_N existem
var _prox_miss := 0           # próxima pose de erro da sequência
var _tween: Tween


## Prepara o sprite com os dados do lutador. lado: 0 = esquerda, 1 = direita.
func configurar(p_lutador: Lutador, p_lado: int) -> void:
	lutador = p_lutador
	lado = p_lado
	sprite_frames = lutador.sprite_frames
	_n_hit = _contar("hit_")
	_n_miss = _contar("miss_")
	scale = Vector2.ONE * lutador.escala_sprite
	centered = false
	var tam := lutador.tamanho_quadro()
	_offset_base = Vector2(-tam.x * 0.5, -(tam.y - lutador.deslocamento_pes))
	offset = _offset_base
	_criar_sombra()
	_idle()


## Conta quantas animações existem com o prefixo (hit_0, hit_1... ou miss_0, miss_1...).
func _contar(prefixo: String) -> int:
	var n := 0
	while sprite_frames != null and sprite_frames.has_animation(StringName(prefixo + str(n))):
		n += 1
	return n


## Elipse escura no chão, atrás do personagem.
func _criar_sombra() -> void:
	var s := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(Vector2(cos(a) * 38.0, sin(a) * 7.0 + 2.0))
	s.polygon = pts
	s.color = Color(0, 0, 0, 0.35)
	s.show_behind_parent = true
	add_child(s)


## Toca uma animação (se existir) e define por quanto tempo ela fica. Espelha conforme o lado.
func _tocar(anim: String, duracao: float) -> void:
	if sprite_frames == null or not sprite_frames.has_animation(StringName(anim)):
		return
	flip_h = (lado == 1) and not lutador.animacoes_sem_espelhar.has(anim)
	play(StringName(anim))
	_reverter = duracao


## Volta para a pose parada.
func _idle() -> void:
	flip_h = (lado == 1)
	if sprite_frames != null and sprite_frames.has_animation(&"idle"):
		play(&"idle")
	_reverter = 0.0


## Balança parado e volta ao idle quando o tempo da pose acaba; apaga o "flash" colorido aos poucos.
func _process(delta: float) -> void:
	_tempo += delta
	self_modulate = self_modulate.lerp(Color.WHITE, minf(delta * 8.0, 1.0))
	_bloqueio_especial = maxf(_bloqueio_especial - delta, 0.0)
	if _travado:
		return
	if _reverter > 0.0:
		_reverter -= delta
		if _reverter <= 0.0:
			_idle()
	else:
		offset.y = _offset_base.y + sin(_tempo * 7.0) * balanco


## Acertou uma nota. julgamento: 0 = PERFEITO, 1 = ÓTIMO, 2 = BOM. coluna escolhe qual pose hit_N usar.
func reagir_acerto(julgamento: int, coluna: int) -> void:
	if _travado or _bloqueio_especial > 0.0:
		return
	offset.y = _offset_base.y
	if julgamento == 0 and usar_pose_perfect and sprite_frames.has_animation(&"perfect"):
		_tocar("perfect", tempo_pose_acerto * 1.8)
	elif _n_hit > 0:
		_tocar("hit_%d" % (coluna % _n_hit), tempo_pose_acerto)
	_pulsar(1.05)


## Errou uma nota: toca a próxima pose de erro, pisca de vermelho e treme um pouco.
func reagir_erro() -> void:
	if _travado or _bloqueio_especial > 0.0:
		return
	offset.y = _offset_base.y
	if _n_miss > 0:
		_tocar("miss_%d" % _prox_miss, tempo_pose_erro)
		_prox_miss = (_prox_miss + 1) % _n_miss
	self_modulate = Color(1.0, 0.45, 0.45)
	_tremer(6.0, 0.18)


## Solta o golpe especial (pose "special", ou "perfect"/hit como reserva).
func tocar_especial(duracao: float = 0.9) -> void:
	if _travado:
		return
	offset.y = _offset_base.y
	_bloqueio_especial = duracao
	for nome in ["special", "perfect", "hit_0"]:
		if sprite_frames.has_animation(StringName(nome)):
			_tocar(nome, duracao)
			break
	_pulsar(1.18)


## Tomou o especial do oponente: pose de dor, recuo e flash.
func levar_dano_especial() -> void:
	_bloqueio_especial = 0.0
	if _travado:
		return
	offset.y = _offset_base.y
	var anim := "miss_1" if sprite_frames.has_animation(&"miss_1") else ("miss_%d" % maxi(_n_miss - 1, 0))
	_tocar(anim, 0.8)
	self_modulate = Color(1.0, 0.3, 0.3)
	_tremer(16.0, 0.45)


## Derrotado: pose de KO e fica escurecido.
func ko() -> void:
	_travado = true
	var anim := "ko" if sprite_frames.has_animation(&"ko") else ("miss_%d" % maxi(_n_miss - 1, 0))
	flip_h = (lado == 1) and not lutador.animacoes_sem_espelhar.has(anim)
	play(StringName(anim))
	offset.y = _offset_base.y
	modulate = Color(0.6, 0.6, 0.7)


## Vencedor: pose de vitória (animação "vitoria", ou "special"/"perfect") pulando de alegria.
func vitoria() -> void:
	_travado = true
	for nome in ["vitoria", "special", "perfect", "idle"]:
		if sprite_frames.has_animation(StringName(nome)):
			flip_h = (lado == 1) and not lutador.animacoes_sem_espelhar.has(nome)
			play(StringName(nome))
			break
	if _tween:
		_tween.kill()
	_tween = create_tween().set_loops()
	_tween.tween_property(self, "offset:y", _offset_base.y - 18.0, 0.25).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(self, "offset:y", _offset_base.y, 0.25).set_trans(Tween.TRANS_SINE)


## Dá um "soquinho" de escala (cresce e volta).
func _pulsar(fator: float) -> void:
	var base := Vector2.ONE * lutador.escala_sprite
	scale = base * fator
	var t := create_tween()
	t.tween_property(self, "scale", base, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Tremida rápida horizontal (px de amplitude, duração em segundos).
func _tremer(amplitude: float, duracao: float) -> void:
	var x0 := position.x
	var t := create_tween()
	var passos := 6
	for i in passos:
		var f := 1.0 - float(i) / passos
		t.tween_property(self, "position:x", x0 + (amplitude if i % 2 == 0 else -amplitude) * f, duracao / passos)
	t.tween_property(self, "position:x", x0, 0.02)
