class_name UpgradeLibrary
## Lista de TODAS as melhorias do jogo. Criou um .tres novo? Adicione aqui.
## (preload carrega o arquivo quando o jogo abre; é uma lista fixa e segura.)


const ALL: Array[Upgrade] = [
	preload("res://resources/upgrades/vigor.tres"),
	preload("res://resources/upgrades/sharp_blade.tres"),
	preload("res://resources/upgrades/light_steps.tres"),
	preload("res://resources/upgrades/swift_shadow.tres"),
	preload("res://resources/upgrades/soul_hunger.tres"),
	preload("res://resources/upgrades/steady_guard.tres"),
	preload("res://resources/upgrades/shrapnel.tres"),
	preload("res://resources/upgrades/quick_focus.tres"),
]


## Sorteia `count` melhorias diferentes que o jogador ainda pode pegar.
static func pick(player: Player, count := 3) -> Array[Upgrade]:
	var options: Array[Upgrade] = []
	for upgrade in ALL:
		if player.get_upgrade_level(upgrade) < upgrade.max_level:
			options.append(upgrade)
	options.shuffle()
	var result: Array[Upgrade] = []
	for i in mini(count, options.size()):
		result.append(options[i])
	return result
