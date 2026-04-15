extends Node

var common_actions: Dictionary = {}
var uncommon_actions: Dictionary = {}
var characters: Dictionary = {}
var hexes: Dictionary = {}
var enemies: Dictionary = {}


var attack_data: Dictionary = {}
var shield_data: Dictionary = {}
var cast_data: Dictionary = {}

var fireball_data: Dictionary = {}
var cover_data: Dictionary = {}
var cut_data: Dictionary = {}
var target_locked_data: Dictionary = {}

var sheep_data: Dictionary = {}
var rabbit_data: Dictionary = {}


func _ready():
	initialize_action_data()
	initialize_character_data()
	initialize_hex_data()
	initialize_enemy_data()

func initialize_action_data():
	# 使用字典初始化角色数据
	var attack = {
		"action_name": "Attack",
		"texture_path": "res://Assets/dice-attack.png",
		"effect": "Deal damage"
	}
	var shield = {
		"action_name": "Shield",
		"texture_path": "res://Assets/dice-shield.png",
		"effect": "Grant shield"
	}
	var cast = {
		"action_name": "Cast",
		"texture_path": "res://Assets/dice-cast.png",
		"effect": "Cast spell",
		"is_special": true
	}
	
	common_actions["attack"] = ActionData.new().init(attack)
	common_actions["shield"] = ActionData.new().init(shield)
	uncommon_actions["cast"] = ActionData.new().init(cast)
	
	attack_data = attack
	shield_data = shield
	cast_data = cast



func initialize_character_data():
	# 使用字典初始化角色数据
	var Lina = {
		"character_name": "Lina",
		"texture_path": "res://Assets/dice-Lina.png",
		"health": 18,
		"traits": "Deal 1 more when casting hex-dice",
		"prime_hex": "fireball"
	}
	var Slime = {
		"character_name": "Slime",
		"texture_path": "res://Assets/dice-Slime.png",
		"health": 20,
		"traits": "resist 1 from attack",
		"prime_hex": "cover"
	}
	var Bob = {
		"character_name": "Bob",
		"texture_path": "res://Assets/dice-Bob.png",
		"health": 22,
		"traits": "+1 for attack",
		"prime_hex": "cut"
	}
	var Robin = {
		"character_name": "Robin",
		"texture_path": "res://Assets/dice-Robin.png",
		"health": 16,
		"traits": "",
		"prime_hex": "target_locked"
	}
	
	characters["Lina"] = CharacterData.new().init(Lina)
	characters["Slime"] = CharacterData.new().init(Slime)
	characters["Bob"] = CharacterData.new().init(Bob)
	characters["Robin"] = CharacterData.new().init(Robin)

func initialize_hex_data():
	var fireball = {
		"hex_name": "fireball",
		"texture_path": "res://Assets/dice-fireball.png",
		"cast_condition": HexData.DiceFace.UP,
		"target_data": [{
			"team": HexData.TargetTeam.ENEMY,
			"type": HexData.TargetType.CHARACTER,
			"condition":{
				"dice_reference":{
					"type": HexData.DiceType.FRIEND,
					"face": HexData.DiceFace.UP
				}
			},
			"index": 0
		}],
		"effect_data":[{
			"type": HexData.EffectType.HEALTH_CHANGE,
			"value": -6,
			"target_index": [0]
		}]
	}
	var cover = {
		"hex_name": "cover",
		"texture_path": "res://Assets/dice-cover.png",
		"cast_condition": HexData.DiceFace.UP,
		"target_data": [{
			"team": HexData.TargetTeam.ENEMY,
			"type": HexData.TargetType.CHARACTER,
			"condition":{
				"dice_reference":{
					"type": HexData.DiceType.FRIEND,
					"face": HexData.DiceFace.UP
				}
			},
			"index": 0
		}],
		"effect_data":[{
			"type": HexData.EffectType.HEALTH_CHANGE,
			"value": -4,
			"target_index": [0]
		}]
	}
	var cut = {
		"hex_name": "cut",
		"texture_path": "res://Assets/dice-cut.png",
		"cast_condition": HexData.DiceFace.UP,
		"target_data": [{
			"team": HexData.TargetTeam.ENEMY,
			"type": HexData.TargetType.CHARACTER,
			"condition":{
				"dice_reference":{
					"type": HexData.DiceType.FRIEND,
					"face": HexData.DiceFace.UP
				}
			},
			"index": 0
		}],
		"effect_data":[{
			"type": HexData.EffectType.HEALTH_CHANGE,
			"value": -5,
			"target_index": [0]
		}]
	}
	var target_locked = {
		"hex_name": "target_locked",
		"texture_path": "res://Assets/dice-target_locked.png",
		"cast_condition": HexData.DiceFace.UP,
		"target_data": [{
			"team": HexData.TargetTeam.ENEMY,
			"type": HexData.TargetType.CHARACTER,
			"condition":{
				"dice_reference":{
					"type": HexData.DiceType.FRIEND,
					"face": HexData.DiceFace.UP
				}
			},
			"index": 0
		}],
		"effect_data":[{
			"type": HexData.EffectType.HEALTH_CHANGE,
			"value": -5,
			"target_index": [0]
		}]
	}
	
	hexes["fireball"] = HexData.new().init(fireball)
	hexes["cover"] = HexData.new().init(cover)
	hexes["cut"] = HexData.new().init(cut)
	hexes["target_locked"] = HexData.new().init(target_locked)
	
	
	fireball_data = fireball
	cover_data = cover
	cut_data = cut
	target_locked_data = target_locked

func initialize_enemy_data():
	var sheep = {
		"enemy_name": "sheep",
		"texture_path": "res://Assets/enemy-sheep.png",
		"health": 2
	}
	#var rabbit = {
		#"enemy_name": "rabbit",
		#"texture_path": "res://Assets/enemy-rabbit.png",
		#"health": 18
	#}
	
	enemies["sheep"] = EnemyData.new().init(sheep)
	#enemies["rabbit"] = EnemyData.new().init(rabbit)
	
	sheep_data = sheep
	#rabbit_data = rabbit


func get_all_common_actions() -> Array:
	return common_actions.values()

func get_all_uncommon_actions() -> Array:
	return uncommon_actions.values()

func get_all_characters() -> Array:
	return characters.values()

func get_all_hexes() -> Array:
	return  hexes.values()

func get_all_enemies() -> Array:
	return enemies.values()
