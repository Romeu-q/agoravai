extends PlayerState
## Parry em PROJÉTIL: o tempo fica em câmera lenta, o projétil fica "na mão"
## (na frente do jogador, na pose do Throw.png) e você MIRA com o mouse.
## SEGURE o botão de parry, mire e SOLTE: um corte INVERTIDO
## devolve o projétil na direção escolhida; ele explode ao acertar.
## DEMOROU? O projétil pisca laranja e explode NA SUA MÃO.
##
## Outros projéteis que chegarem durante a mira também são pegos e saem juntos,
## num leque.


## Abertura (graus) entre os projéteis quando há mais de um na mão.
const SPREAD_DEGREES := 12.0
## Quanto tempo (real) a pose de arremesso fica depois de lançar.
const THROW_POSE_TIME := 0.18
## Nos últimos X segundos (reais) da mira o projétil pisca laranja: vai explodir!
const WARNING_TIME := 0.6
## Linha de mira: comprimento (px), distância entre os pontos (= largura da
## textura aim_dots.png) e velocidade com que os pontos "andam" (px/s reais).
const AIM_LENGTH := 90.0
const AIM_DOT_SPACING := 8.0
const AIM_MARCH_SPEED := 40.0

var _march := 0.0

var aim := Vector2.RIGHT
var real_time_left := 0.0
var thrown := false


func enter() -> void:
	player.velocity = Vector2.ZERO
	player.sprite.play("extract")   # a animação que usa o Throw.png
	aim = player.get_aim_direction()
	real_time_left = player.parry_aim_time
	thrown = false
	# Cliques feitos ANTES do parry (ainda no buffer) lançariam o projétil na
	# hora, sem dar tempo de mirar. Só vale clique feito durante a mira.
	player.clear_input_buffer()

	# A guarda continua levantada: projéteis que chegarem agora também são pegos.
	player.hurtbox.parrying = true
	player.hurtbox.parried.connect(_on_parried)

	Juice.slow_motion(player.parry_slow_scale)
	Juice.focus(0.12)   # zoom enquanto mira: foco no momento
	Sound.play("slowmo", 0.0)
	_color_aim_line(Palette.GREEN)
	player.aim_line.visible = true
	_update_aim_line(0.0)   # já nasce no lugar certo


func exit() -> void:
	# Saiu antes de lançar (ex.: tomou dano)? Solta o que estava na mão.
	if not thrown:
		_throw()
	player.hurtbox.parried.disconnect(_on_parried)
	player.hurtbox.parrying = false
	player.slash_effect.visible = false
	player.aim_line.visible = false
	Juice.slow_motion(1.0)
	Juice.focus(0.0)
	player.can_parry = true


func physics_update(delta: float) -> void:
	# `delta` vem em câmera lenta (x0.15). Dividindo pela escala de tempo, temos
	# o tempo REAL: a mira dura parry_aim_time segundos de verdade.
	var real_delta := delta / Engine.time_scale

	if thrown:
		real_time_left -= real_delta
		if real_time_left <= 0.0:
			transitioned.emit(&"idle")
		return

	var new_aim := player.get_aim_direction()
	if new_aim != Vector2.ZERO:
		aim = new_aim
	player.update_facing(aim)
	_hold_projectiles()
	_update_aim_line(real_delta)

	real_time_left -= real_delta
	# SOLTOU o botão de parry: lança para onde está mirando.
	# (Se você já tinha soltado antes de pegar o projétil, aperte e solte de novo.)
	if Input.is_action_just_released("parry"):
		_throw()
	elif real_time_left <= 0.0:
		_fail()
	elif real_time_left <= WARNING_TIME:
		# Aviso: pisca laranja (cor de PERIGO) ~10 vezes por segundo.
		var blink := int(real_time_left * 20.0) % 2 == 0
		for projectile in player.caught_projectiles:
			projectile.paint(Palette.WARM if blink else player.horn_color)
		_color_aim_line(Palette.WARM if blink else Palette.GREEN)


## Linha de mira pontilhada: sai da "mão" na direção da mira.
## Os pontos ANDAM para frente (como formigas em fila): começamos a linha um
## pouquinho mais para trás a cada frame, e o desenho repetido parece deslizar.
func _update_aim_line(real_delta: float) -> void:
	_march = fmod(_march + real_delta * AIM_MARCH_SPEED, AIM_DOT_SPACING)
	var hand := player.hurtbox.global_position + aim * player.parry_hold_distance
	var start := hand + aim * (_march - AIM_DOT_SPACING)
	player.aim_line.points = PackedVector2Array([start, hand + aim * AIM_LENGTH])


## Cor da linha com brilho (acima de 1.0 = Glow).
func _color_aim_line(color: Color) -> void:
	player.aim_line.default_color = Color(color.r * Juice.GLOW, color.g * Juice.GLOW,
		color.b * Juice.GLOW)


## Posiciona os projéteis na frente do jogador, apontando para a mira.
func _hold_projectiles() -> void:
	# De trás para frente: remover um item não bagunça os índices que faltam.
	for i in range(player.caught_projectiles.size() - 1, -1, -1):
		if not is_instance_valid(player.caught_projectiles[i]):
			player.caught_projectiles.remove_at(i)

	var center := player.hurtbox.global_position
	var count := player.caught_projectiles.size()
	for i in count:
		# Leque: o do meio vai reto, os outros abrem para os lados.
		var offset := deg_to_rad((i - (count - 1) / 2.0) * SPREAD_DEGREES)
		var direction := aim.rotated(offset)
		player.caught_projectiles[i].hold(center + direction * player.parry_hold_distance, direction)


func _throw() -> void:
	thrown = true
	player.aim_line.visible = false
	real_time_left = THROW_POSE_TIME
	Juice.slow_motion(1.0)
	Juice.focus(0.0)
	_hold_projectiles()   # garante as posições finais antes de lançar

	var count := player.caught_projectiles.size()
	for i in count:
		var offset := deg_to_rad((i - (count - 1) / 2.0) * SPREAD_DEGREES)
		var projectile := player.caught_projectiles[i]
		projectile.blast_radius *= player.throw_blast_scale   # melhoria ESTILHACO
		projectile.launch(aim.rotated(offset))
	player.caught_projectiles.clear()

	# Corte INVERTIDO: o slash sai no sentido contrário ao último golpe.
	player.slash_flipped = not player.slash_flipped
	player.attack_pivot.rotation = aim.angle()
	player.slash_effect.flip_v = player.slash_flipped
	player.slash_effect.speed_scale = 1.5
	player.slash_effect.visible = true
	player.slash_effect.stop()
	player.slash_effect.play("slash")
	player.sprite.stop()
	player.sprite.play("extract")

	var hand := player.hurtbox.global_position + aim * player.parry_hold_distance
	Juice.neon_burst(hand, 8, aim, 35.0,
		{"weights_main": Vector3(1.0, 1.0, 1.5), "weights_special": Vector3(1.5, 1.5, 0.5)})
	Juice.ring(hand, Color.WHITE, 8.0, 0.15)
	Sound.play("throw")
	Juice.hitstop(0.05)
	Juice.shake(0.3)
	Juice.punch(0.1)


## Demorou demais: os projéteis explodem NA MÃO e acertam o jogador.
func _fail() -> void:
	thrown = true   # nada para lançar no exit()
	player.aim_line.visible = false
	# Baixa a guarda ANTES, senão o parry apararia a própria explosão.
	player.hurtbox.parrying = false
	_hold_projectiles()
	for projectile in player.caught_projectiles:
		projectile.detonate()
	player.caught_projectiles.clear()
	transitioned.emit(&"idle")


## Chegou outro golpe durante a mira: projétil é pego também; corpo a corpo atordoa.
func _on_parried(hitbox: Hitbox) -> void:
	var projectile := hitbox as Projectile
	if projectile and not thrown:
		projectile.catch(player.horn_color)
		player.caught_projectiles.append(projectile)
		player.add_soul(player.parry_soul)
		Juice.ring(projectile.global_position, Color.WHITE, 8.0, 0.12)
		Sound.play("parry_open")
		Juice.shake(0.15)
	elif hitbox.owner is Enemy:
		(hitbox.owner as Enemy).get_parried(player.global_position)
