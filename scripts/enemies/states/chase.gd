extends EnemyState
## POSICIONAMENTO (o "cérebro" do monstro enquanto não está atacando).
## - Ataque corpo a corpo pronto: vai para cima, chegando pelo FLANCO.
## - Ataque recarregando: fica rodeando o jogador na distância preferida,
##   trocando de sentido de vez em quando (fica imprevisível).
## - Sempre se afasta dos outros monstros (não empilham).
## Quando pode e consegue uma vaga de ataque, vai para o Windup (o aviso).


var strafe_sign := 1.0   # 1 = horário, -1 = anti-horário
var strafe_timer := 0.0


func enter() -> void:
	enemy.sprite.play("walk")
	enemy.release_attack()   # voltou a se posicionar: libera a vaga para outro
	_pick_strafe()


func physics_update(delta: float) -> void:
	if not enemy.has_target():
		enemy.steer(Vector2.ZERO, delta)
		return

	if _try_start_attack():
		return

	var to_target := enemy.direction_to_target()
	var distance := enemy.distance_to_target()
	enemy.face(to_target)

	strafe_timer -= delta
	if strafe_timer <= 0.0 or enemy.is_on_wall():
		_pick_strafe()   # bateu na parede ou deu o tempo: muda o sentido

	var desired: Vector2
	if enemy.can_attack or enemy.preferred_distance <= 0.0:
		# Vai para cima, mas em curva (flanco): ângulo que diminui ao chegar perto.
		var closeness := clampf(distance / 120.0, 0.0, 1.0)
		desired = to_target.rotated(enemy.flank_angle * strafe_sign * closeness)
	else:
		# Rodeia: componente "em volta" (tangente) + corrige a distância (radial).
		var radial := 0.0
		if distance > enemy.preferred_distance + enemy.distance_tolerance:
			radial = 1.0
		elif distance < enemy.preferred_distance - enemy.distance_tolerance:
			radial = -1.0
		# orthogonal() = vetor perpendicular (90°): andar nele é andar em volta.
		var tangent := to_target.orthogonal() * strafe_sign
		desired = (to_target * radial + tangent * 0.8).normalized()

	enemy.steer(desired * enemy.speed, delta)


## Decide se ataca agora. Precisa: estar em condições E conseguir uma vaga.
func _try_start_attack() -> bool:
	var wants_melee := enemy.can_attack and enemy.distance_to_target() <= enemy.attack_range
	var wants_shot := not wants_melee and enemy.wants_to_shoot()
	if not (wants_melee or wants_shot) or not enemy.try_claim_attack():
		return false
	enemy.next_action = &"attack" if wants_melee else &"shoot"
	transitioned.emit(&"windup")
	return true


func _pick_strafe() -> void:
	strafe_sign = -strafe_sign if randf() < 0.7 else strafe_sign
	strafe_timer = randf_range(enemy.strafe_time_min, enemy.strafe_time_max)
