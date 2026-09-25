class_name Hurtbox
extends Area2D
## Área que RECEBE dano. Não decide nada sozinha: avisa o dono pelos sinais.


signal hurt(hitbox: Hitbox)
## Emitido quando um golpe chega enquanto `parrying` está ligado.
signal parried(hitbox: Hitbox)

## Enquanto true, ignora golpes (ex.: logo após tomar dano, durante o dash).
var invincible := false
## Enquanto true, golpes são APARADOS: não causam dano e avisam pelo sinal `parried`.
var parrying := false


## Retorna se o golpe foi aceito (causou dano).
func receive_hit(hitbox: Hitbox) -> bool:
	if parrying:
		parried.emit(hitbox)
		return false
	if invincible:
		return false
	hurt.emit(hitbox)
	return true
