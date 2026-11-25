class_name RhythmCharacter
extends AnimatedSprite2D
## Personagem do palco. A cada ACERTO da lane dele, toca a animação de tocar no SpriteFrames;
## a cada ERRO, toca "miss" (se existir) e pisca em vermelho.
##
## Animações esperadas no SpriteFrames (veja sprites/ana_frames.tres, no painel SpriteFrames do editor):
##   idle            parado (loop)
##   hit_0, hit_1... uma por coluna da lane; se faltar alguma, usa col % (quantidade de hit_N)
##   miss            (opcional) pose de erro
##
## Para reaproveitar: coloque um AnimatedSprite2D, troque o SpriteFrames, anexe este script,
## aponte "player" para o RhythmPlayer e escolha a "lane" (0 = ANA, 1 = MARCOS, 2 = JUNPEI).

@export var player: RhythmPlayer
## (Opcional) RhythmHighway: o personagem fica embaixo da pista da lane dele, mesmo quando ela é centralizada.
@export var highway: RhythmHighway
@export_range(0, 2) var lane := 0
## Some da tela quando a lane dele não tem jogador (1 ou 2 jogadores).
@export var hide_when_inactive := true
## Quanto tempo (s) a pose de acerto fica na tela antes de voltar ao idle.
@export var hit_hold_time := 0.16
## "Pulinho" de escala a cada acerto (1.0 = sem efeito).
@export var pop_scale := 1.06

var _variants := 1
var _revert := 0.0
var _base_scale := Vector2.ONE
var _tween: Tween


func _ready() -> void:
	_base_scale = scale
	_variants = 0
	while sprite_frames != null and sprite_frames.has_animation("hit_%d" % _variants):
		_variants += 1
	_variants = maxi(_variants, 1)
	_play_idle()

	if player == null:
		push_warning("RhythmCharacter: aponte a propriedade 'player' para um RhythmPlayer.")
		return
	player.judged.connect(_on_judged)
	player.started.connect(_on_started)
	if highway != null:
		highway.layout_changed.connect(_refresh)
	if player.play != null:
		_refresh()


func _on_started() -> void:
	_refresh()
	_play_idle()


## Mostra/esconde o personagem e o posiciona embaixo da pista dele.
func _refresh() -> void:
	var active := player.is_lane_active(lane)
	visible = active or not hide_when_inactive
	modulate = Color.WHITE if active else Color(1, 1, 1, 0.4)
	if active and highway != null:
		global_position.x = highway.lane_center_x(lane)


func _on_judged(l: int, judgment: int, _sloppy: bool, col: int) -> void:
	if l != lane:
		return
	if judgment == RhythmConfig.Judgment.MISS:
		_miss()
	else:
		_hit(col)


func _hit(col: int) -> void:
	var anim := "hit_%d" % (col % _variants)
	if sprite_frames != null and sprite_frames.has_animation(anim):
		stop()
		play(anim)
		set_frame_and_progress(0, 0.0)   # reinicia, mesmo se for a mesma animação de antes
	_revert = hit_hold_time
	self_modulate = Color.WHITE
	_pop()


func _miss() -> void:
	if sprite_frames != null and sprite_frames.has_animation("miss"):
		stop()
		play("miss")
		set_frame_and_progress(0, 0.0)
	_revert = hit_hold_time * 1.6
	self_modulate = Color(1.0, 0.45, 0.45)


func _play_idle() -> void:
	if sprite_frames != null and sprite_frames.has_animation("idle"):
		play("idle")


func _pop() -> void:
	if pop_scale == 1.0:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	scale = _base_scale * pop_scale
	_tween = create_tween()
	_tween.tween_property(self, "scale", _base_scale, 0.12)


func _process(delta: float) -> void:
	if _revert > 0.0:
		_revert -= delta
		if _revert <= 0.0:
			_play_idle()
	# o vermelho do erro some sozinho
	self_modulate = self_modulate.lerp(Color.WHITE, minf(1.0, 10.0 * delta))
