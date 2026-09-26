class_name Upgrade
extends Resource
## Uma MELHORIA escolhida entre waves.
## É um Resource: cada melhoria é um arquivo .tres em resources/upgrades/,
## editável no Inspector. Para criar uma nova: duplique um .tres, mude os
## valores e adicione na lista do UpgradeLibrary.


## Qual atributo do jogador a melhoria altera.
enum Stat { MAX_HEALTH, DAMAGE, SPEED, DASH_COOLDOWN, SOUL_GAIN, PARRY_WINDOW, BLAST, HEAL_SPEED }

@export var title := ""
@export_multiline var description := ""
@export var stat: Stat
## Quanto muda. Números inteiros (vida, dano) ou porcentagens (0.2 = 20%).
@export var amount := 0.0
## Cor do card (use as cores da Palette).
@export var color := Color.WHITE
## Quantas vezes pode ser escolhida na mesma partida.
@export var max_level := 3


func apply(player: Player) -> void:
	match stat:
		Stat.MAX_HEALTH:
			player.health.max_health += int(amount)
			player.health.heal(int(amount))   # emite health_changed: a HUD cria o pip novo
		Stat.DAMAGE:
			player.attack_area.damage += int(amount)
		Stat.SPEED:
			player.speed *= 1.0 + amount
		Stat.DASH_COOLDOWN:
			player.dash_cooldown *= 1.0 - amount
		Stat.SOUL_GAIN:
			player.soul_per_hit = roundi(player.soul_per_hit * (1.0 + amount))
			player.parry_soul = roundi(player.parry_soul * (1.0 + amount))
		Stat.PARRY_WINDOW:
			player.parry_window += amount
			player.parry_extend_window += amount
		Stat.BLAST:
			player.throw_blast_scale += amount
		Stat.HEAL_SPEED:
			player.heal_time *= 1.0 - amount
