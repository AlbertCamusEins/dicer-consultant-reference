extends Node

# 战斗状态枚举
enum BattleState {
	WAITING,         # 等待开始
	ENEMY_ROLLING,   # 敌方投掷阶段
	PLAYER_ROLLING,  # 玩家投掷阶段
	PLAYER_ACTING,   # 玩家行动阶段
	ENEMY_ACTING,    # 敌方行动阶段
	FINISHED         # 战斗结束
}

# 基础属性
var current_state: BattleState = BattleState.WAITING
var player_team: Dictionary = {}  # 存储玩家当前角色数据
var enemy_team: Dictionary = {}   # 存储敌方当前角色数据
var reroll_count: int = 0        # 当前可用的重投次数

# 骰子结果
var player_dice_results: Dictionary = {
	"frien": 0,     # 当前朝上的伙伴骰子面
	"action": 0,    # 当前朝上的行动骰子面
	"hex": 0        # 当前朝上的法术骰子面
}

var enemy_dice_results: Dictionary = {
	"frien": 0,
	"action": 0,
	"hex": 0
}

# 战斗效果
var active_effects: Array = []    # 当前回合激活的效果
var ongoing_effects: Array = []   # 持续性效果

# 信号
signal battle_state_changed(new_state: BattleState)
signal dice_rolled(is_player: bool, results: Dictionary)
signal effect_triggered(effect_data: Dictionary)
signal battle_ended(victory: bool)

func _init():
	randomize()

# 开始新的战斗
func start_battle(player_data: Dictionary, enemy_data: Dictionary) -> void:
	player_team = player_data
	enemy_team = enemy_data
	current_state = BattleState.ENEMY_ROLLING
	emit_signal("battle_state_changed", current_state)
	_enemy_roll_phase()

# 敌方投掷阶段
func _enemy_roll_phase() -> void:
	enemy_dice_results = _roll_dice()
	emit_signal("dice_rolled", false, enemy_dice_results)
	
	current_state = BattleState.PLAYER_ROLLING
	emit_signal("battle_state_changed", current_state)

# 玩家投掷阶段
func player_roll_dice() -> void:
	if current_state != BattleState.PLAYER_ROLLING:
		return
		
	player_dice_results = _roll_dice()
	emit_signal("dice_rolled", true, player_dice_results)
	
	# 检查重投机会
	if _check_reroll_opportunity(player_dice_results):
		reroll_count += _calculate_reroll_bonus(player_dice_results)
	
	current_state = BattleState.PLAYER_ACTING
	emit_signal("battle_state_changed", current_state)

# 通用骰子投掷逻辑
func _roll_dice() -> Dictionary:
	return {
		"frien": randi() % 6,
		"action": randi() % 6,
		"hex": randi() % 6
	}

# 检查是否获得重投机会
func _check_reroll_opportunity(results: Dictionary) -> bool:
	var counts = {}
	for value in results.values():
		if not counts.has(value):
			counts[value] = 0
		counts[value] += 1
	
	for count in counts.values():
		if count >= 2:
			return true
	return false

# 计算重投奖励数量
func _calculate_reroll_bonus(results: Dictionary) -> int:
	var counts = {}
	for value in results.values():
		if not counts.has(value):
			counts[value] = 0
		counts[value] += 1
	
	var bonus = 0
	for count in counts.values():
		if count == 2:
			bonus += 1
		elif count == 3:
			bonus += 3
	return bonus

# 执行玩家行动
func execute_player_action(action_type: String) -> void:
	if current_state != BattleState.PLAYER_ACTING:
		return
		
	# 处理行动效果
	var effect = _resolve_action(action_type, true)
	if effect:
		active_effects.append(effect)
		emit_signal("effect_triggered", effect)
	
	# 如果所有行动都已执行，进入敌方行动阶段
	if _are_all_actions_executed():
		current_state = BattleState.ENEMY_ACTING
		emit_signal("battle_state_changed", current_state)
		_enemy_action_phase()

# 解析行动效果
func _resolve_action(action_type: String, is_player: bool) -> Dictionary:
	var effect = {}
	# TODO: 实现具体的行动效果解析逻辑
	
	return effect

# 敌方行动阶段
func _enemy_action_phase() -> void:
	# 按照预设AI逻辑执行敌方行动
	# TODO: 实现敌方AI决策逻辑
	
	# 结算所有效果
	_resolve_all_effects()
	
	# 检查战斗是否结束
	if _check_battle_end():
		_end_battle()
	else:
		# 开始新回合
		current_state = BattleState.ENEMY_ROLLING
		emit_signal("battle_state_changed", current_state)
		_enemy_roll_phase()

# 结算所有效果
func _resolve_all_effects() -> void:
	for effect in active_effects:
		_apply_effect(effect)
	
	# 更新持续性效果
	for effect in ongoing_effects:
		if effect.has("duration"):
			effect.duration -= 1
			if effect.duration <= 0:
				ongoing_effects.erase(effect)
			else:
				_apply_effect(effect)

# 应用效果
func _apply_effect(effect: Dictionary) -> void:
	# TODO: 实现效果应用逻辑
	pass

# 检查战斗是否结束
func _check_battle_end() -> bool:
	var player_defeated = _is_team_defeated(player_team)
	var enemy_defeated = _is_team_defeated(enemy_team)
	
	return player_defeated or enemy_defeated

# 检查队伍是否战败
func _is_team_defeated(team: Dictionary) -> bool:
	# TODO: 实现队伍战败判定逻辑
	return false

# 结束战斗
func _end_battle() -> void:
	current_state = BattleState.FINISHED
	var victory = not _is_team_defeated(player_team)
	emit_signal("battle_ended", victory)

# 使用重投
func use_reroll() -> bool:
	if reroll_count <= 0:
		return false
	
	reroll_count -= 1
	return true

# 检查所有行动是否已执行
func _are_all_actions_executed() -> bool:
	# TODO: 实现行动完成检查逻辑
	return true
