# Dicer 数据规范表

更新日期：2026-03-22

本文档用于整理当前项目中 `character`、`enemies`、`bosses`、`hexes`、`equipments`、`items`、`statuses`、`traits` 的数据编写规范，方便开发人员按表填写 JSON 条目。

当前运行时实际加载的文件如下：

- `GameData/characters.json`
- `GameData/enemies.json`
- `GameData/bosses.json`
- `GameData/hexes.json`
- `GameData/equipments_v2.json`
- `GameData/items.json`
- `GameData/statuses_v2.json`
- `GameData/traits_v2.json`
- `GameData/encounters_test.json`

所有数据文件统一要求：

- 编码：`UTF-8`
- 格式：标准 JSON，不写注释，不写尾逗号
- 顶层结构：通常为 `{ "表名": { "id": { ... } } }`
- 条目 ID：由外层 key 提供，除少数运行时对象外，不建议在条目内部重复写同一份 `id`
- 路径：统一使用 Godot 资源路径，例如 `res://Assets/dice-Lina.png`
- 枚举值：当前数据层主要使用整数，不要写浮点；旧数据里出现的 `0.0/1.0` 虽可被读取，但新条目不要继续沿用

## 通用命名建议

| 项 | 规范 |
| --- | --- |
| 角色 ID | `fc###`，如 `fc001` |
| 敌人 ID | `fb###`，如 `fb001` |
| Boss ID | `boss###`，如 `boss001` |
| Hex ID | `fh###`，如 `fh001` |
| 装备 ID | `eq###` |
| 物品 ID | `it###` |
| 状态 ID | `st###` |
| Trait ID | 角色 Trait 用 `t###`，装备 Trait 用 `eqt###` |
| 名称字段 | 推荐小写或固定风格，避免同表内混用多种命名风格 |

## 1. Characters

文件：`GameData/characters.json`

顶层格式：

```json
{
  "characters": {
    "fc001": {
      "...": "..."
    }
  }
}
```

### 字段规范

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `name` | `String` | 是 | 角色显示名；运行时也会被当作角色逻辑名使用，建议全表唯一 |
| `texture_path` | `String` | 是 | 角色骰面贴图路径；战斗立绘不会直接使用该路径，而是按战斗立绘解析规则回退到 `char-*.png` |
| `base_health` | `int` | 是 | 初始生命值 |
| `experience` | `int` | 否 | 初始经验，通常填 `0` |
| `countdown` | `int` | 是 | 行动倒计时 |
| `traits` | `Array[String]` | 建议 | Trait ID 列表；无 trait 时写 `[]` |
| `prime_hex_id` | `String` | 建议 | 初始 Prime Hex ID |
| `peak_hex_id` | `String` | 否 | 预留字段，可空字符串 |
| `soul_hex_id` | `String` | 否 | 预留字段，可空字符串 |
| `slot_limit` | `int` | 否 | 该角色骰面可被放入的最大次数；未填时按运行时默认处理 |

### 兼容字段

| 旧字段 | 新字段 | 说明 |
| --- | --- | --- |
| `trait_id` | `traits` | 仍有兼容读取，但新数据不要再写 |
| `prime_hex` | `prime_hex_id` | 仍有兼容读取，但新数据不要再写 |
| `peak_hex` | `peak_hex_id` | 同上 |
| `soul_hex` | `soul_hex_id` | 同上 |

### 编写要求

- `traits` 必须写成数组，不要混写成字符串。
- `prime_hex_id / peak_hex_id / soul_hex_id` 若没有内容，统一写 `""`。
- `name` 会参与战斗和存档映射，改名会影响历史存档兼容。
- 角色战斗立绘当前优先通过角色数据里的 `legacy_name` 解析为 `res://Assets/char-<legacy_name>.png`；若未命中，再尝试把 `texture_path` 中的 `dice-` 前缀替换成 `char-`。两者都缺失时会回退到 `res://Assets/blank-dice.png`。

## 2. Enemies

文件：`GameData/enemies.json`

顶层格式：

```json
{
  "enemies": {
    "fb001": {
      "...": "..."
    }
  }
}
```

### 字段规范

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `name` | `String` | 是 | 敌人基础名称 |
| `texture_path` | `String` | 是 | 敌方骰面贴图路径；战斗立绘优先按敌人立绘解析规则回退到 `enemy-*.png` |
| `base_health` | `int` | 是 | 初始生命值 |
| `trait` | `String` | 否 | 旧版文本 trait 描述；当前不是结构化 trait 系统 |
| `weight` | `int` 或 `float` | 是 | 遭遇权重，用于 encounter 难度计算；新数据建议写整数 |
| `equipment` | `Array[String]` | 建议 | 敌方装备骰面池，元素为装备 ID |
| `hexes` | `Array[String]` | 建议 | 敌方法术骰面池，元素为 Hex ID |
| `countdown` | `int` | 是 | 行动倒计时 |
| `health_per_occupied_face` | `int` | 否 | 若大于 `0`，则在新战斗初始化敌方骰面后，以“该敌人实际占用的 `enemy_frien` 面数 × 该值”覆盖其初始生命值 |

### 编写要求

- `equipment` 和 `hexes` 建议始终显式填写数组，即使为空也写 `[]`。
- `weight` 虽然当前样例里有 `2.0` 这类浮点，新条目建议统一改为整数，避免无意义的小数。
- 当前敌人结构化 trait 尚未接入 `traits_v2.json`；如需可执行被动，请先补运行时代码。
- `health_per_occupied_face` 仅在“新开战斗 / 测试战”初始化时生效；恢复中的战斗状态不重算。
- 所有数据文件统一使用 `UTF-8` 编码保存，避免文档或 JSON 出现乱码。
- 敌人战斗立绘当前优先通过敌人数据里的 `legacy_name` 解析为 `res://Assets/enemy-<legacy_name>.png`；若未命中，再尝试把 `texture_path` 中的 `dice-` 前缀替换成 `enemy-`，最后才直接尝试 `texture_path` 本身。三者都缺失时会回退到 `res://Assets/blank-dice.png`。

## 3. Bosses

文件：`GameData/bosses.json`

顶层格式：

```json
{
  "bosses": {
    "boss001": {
      "...": "..."
    }
  }
}
```

### 当前已生效字段

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `name` | `String` | 是 | Boss 名称 |
| `texture_path` | `String` | 是 | Boss 贴图路径 |
| `base_health` | `int` | 是 | 初始生命值 |
| `trait` | `String` | 否 | 当前仅作为旧版文本描述 |
| `weight` | `int` | 否 | 目前 Boss 随机逻辑不依赖该值，但可保留 |

### 重要说明

- 当前战斗初始化阶段对 `bosses.json` 的装备与 hex 装载支持不完整。
- 换句话说，Boss 数据目前应按“精简版 enemy 数据”来写，不要默认 `equipment`、`hexes`、结构化 trait 一定会自动生效。
- 如果后续要让 Boss 拥有独立装备或 Hex 池，需要同时补 `battle_scene.gd` 的敌方骰面装载逻辑。
- Boss 战斗立绘当前复用敌人立绘解析规则，资源命名建议仍按 `enemy-<legacy_name>.png` 或可从 `texture_path` 的 `dice-` 前缀稳定映射。

## 3.1 战斗场景立绘实例化与排版规则

本章按代码中的“常量 / 变量定义”和“函数调用链”解释战斗场景里的立绘排版逻辑。相关实现主要分布在 `BattleManager.gd`、`player_character.gd`、`enemy_character.gd`。

### 一、实例化入口

- `BattleManager.spawn_character_at_position(character_data, pos, current_health)`：
  实例化 `res://Scenes/player_character.tscn`，节点名使用 `character_name`，加入 `frien` 分组，并先把节点放到传入的 `pos`。
- `BattleManager.spawn_enemy_at_position(data, pos, current_health)`：
  实例化 `res://Scenes/enemy_character.tscn`，节点名优先使用 `unique_id`，否则使用 `enemy_name`，加入 `enemy` 分组，并先把节点放到传入的 `pos`。
- `spawn_player_visuals_from_current_faces()`、`spawn_visuals_from_current_data()`、`spawn_portraits()`：
  这些函数会先按旧式锚点生成立绘，再调用 `apply_battle_layout()` 做统一排版。
- 玩家初始锚点：
  `ally_base_position = Vector2(200, 600)`，相邻偏移 `character_offset = Vector2(200, 0)`。
- 敌人初始锚点：
  `enemy_base_position = Vector2(1800, 600)`，相邻偏移 `enemy_offset = Vector2(-200, 0)`。
- 这些初始坐标只是生成阶段的临时位置，最终显示位置以 `apply_battle_layout()` 的计算结果为准。

### 二、BattleManager 中与排版相关的常量和变量

- `const BATTLE_LAYOUT_VIEWPORT_SIZE := Vector2(1920.0, 1080.0)`：
  立绘排版按 1920x1080 视口计算。
- `const BATTLE_LAYOUT_SAFE_MARGIN_X := 48.0`：
  左右安全边距基准；玩家区域左边界直接使用它。
- `const BATTLE_LAYOUT_TOP_MARGIN := 56.0`：
  排版时允许占用的顶部安全边距。
- `const BATTLE_LAYOUT_BOTTOM_MARGIN := 56.0`：
  排版时允许占用的底部安全边距。
- `const BATTLE_LAYOUT_BASELINE_Y := 600.0`：
  双方立绘默认试图对齐到的基准纵坐标。
- `const BATTLE_LAYOUT_ALLY_REGION := Rect2(BATTLE_LAYOUT_SAFE_MARGIN_X, 0.0, 780.0, BATTLE_LAYOUT_VIEWPORT_SIZE.y)`：
  玩家立绘横向可用区域，等价于 `Rect2(48, 0, 780, 1080)`。
- `const BATTLE_LAYOUT_ENEMY_REGION := Rect2(1092.0, 0.0, 780.0, BATTLE_LAYOUT_VIEWPORT_SIZE.y)`：
  敌人立绘横向可用区域，等价于 `Rect2(1092, 0, 780, 1080)`。
- `const BATTLE_LAYOUT_DEFAULT_GAP := 8.0`：
  同侧多个单位之间的默认水平间距。
- `const BATTLE_LAYOUT_MIN_GAP := 4.0`：
  空间不足时允许压缩到的最小水平间距。
- `const BATTLE_LAYOUT_MIN_SCALE_FACTOR := 0.72`：
  排版系统允许把立绘缩到默认尺寸的最小倍数。
- `const FRONT_UNIT_MOVE_DURATION := 0.2`：
  角色骰触发前排移动时使用的默认 x 轴 tween 时长。
- `const BATTLE_LAYOUT_MIN_STATUS_WIDTH := 180.0`：
  状态栏允许的最小宽度。
- `const BATTLE_LAYOUT_MAX_STATUS_WIDTH := 200.0`：
  状态栏允许的最大宽度。
- `var _battle_layout_refresh_queued: bool = false`：
  避免同一帧重复刷新排版；用于把多次 UI 变化合并成一次布局计算。
- `var _ally_display_order / _enemy_display_order`：
  运行时维护双方立绘显示顺序；玩家顺序的尾部视为前排，敌人顺序的头部视为前排。

### 三、玩家与敌人立绘节点中的常量和变量

玩家与敌人节点都各自维护一套用于计算内部 UI 的常量；两者逻辑一致，但部分间距不同。

#### 玩家立绘 `player_character.gd`

- `const DEFAULT_PORTRAIT_SCALE := 6.0`：
  立绘的初始放大倍率。
- `const DEFAULT_STATUS_MAX_WIDTH := 180.0`：
  当外部没传排版结果时，状态栏默认最大宽度。
- `const STATUS_MAX_LINES := 2`：
  状态栏最多显示两行。
- `const STATUS_TOP_GAP := 50.0`：
  立绘顶端到状态栏的距离。
- `const COUNTDOWN_MARGIN := 8.0`：
  立绘左边缘到倒计时文字的额外横向距离。
- `const BOTTOM_GAP := 6.0`：
  立绘底部到血条的垂直距离。
- `const HEALTH_LABEL_GAP := 6.0`：
  血条到底部生命值文本的垂直距离。
- `const SHIELD_GAP := 8.0`：
  护盾图标和护盾数字之间的横向距离。
- `var _layout_data: Dictionary = {}`：
  缓存最近一次外部传入的排版结果，例如位置、缩放、状态栏宽度。

#### 敌人立绘 `enemy_character.gd`

- `const DEFAULT_PORTRAIT_SCALE := 6.0`：
  敌人立绘的初始放大倍率。
- `const DEFAULT_STATUS_MAX_WIDTH := 180.0`：
  敌人状态栏默认最大宽度。
- `const STATUS_MAX_LINES := 2`：
  敌人状态栏最多两行。
- `const STATUS_TOP_GAP := 50.0`：
  敌人立绘顶端到状态栏的距离。
- `const COUNTDOWN_MARGIN := 16.0`：
  敌人立绘左边缘到倒计时文字的额外横向距离，比玩家更大。
- `const BOTTOM_GAP := 6.0`：
  敌人立绘底部到血条的垂直距离。
- `const HEALTH_LABEL_GAP := 10.0`：
  敌人血条到底部生命值文本的垂直距离。
- `const SHIELD_GAP := 8.0`：
  护盾图标和护盾数字之间的横向距离。
- `var _layout_data: Dictionary = {}`：
  缓存最近一次排版结果。

### 四、`apply_battle_layout()` 及相关函数的运行顺序

#### 1. 触发布局刷新

- `queue_battle_layout_refresh()`：
  如果当前还没有排版任务，就把 `_battle_layout_refresh_queued` 设为 `true`，并 `call_deferred("_flush_battle_layout_refresh")`。
- `refresh_battle_layout_if_needed()`：
  只是一个转发入口，内部直接调用 `queue_battle_layout_refresh()`。
- 玩家和敌人立绘中的 `_update_layout_from_state()`：
  当生命、护盾、状态、倒计时变化时，会重新应用本地布局，并通知 `BattleManager.queue_battle_layout_refresh()` 重新做整队排版。

#### 2. 真正执行排版

- `_flush_battle_layout_refresh()`：
  把 `_battle_layout_refresh_queued` 还原为 `false`，然后调用 `apply_battle_layout()`。
- `apply_battle_layout(layout = {})`：
  如果外部没有直接传入 `layout`，先调用 `compute_battle_layout()` 生成；然后分别取 `frien` 和 `enemy` 分组中的节点，把对应的 `layout[unit_id]` 传给每个节点的 `apply_layout()`；最后发出 `battle_layout_changed` 信号。
- `animate_battle_layout_transition(layout, duration)`：
  用 `Tween` 只补间各立绘的 `position.x`，等待动画结束后再统一套用最终布局；用于角色骰前排移动。

#### 3. 计算双方队伍的排版结果

- `compute_battle_layout()`：
  先通过 `_get_battle_team_nodes("frien")` 和 `_get_battle_team_nodes("enemy")` 收集双方节点；再分别把玩家节点和敌人节点交给 `_compute_team_layout()`；最后把两边结果合并成一个总字典返回。
- `_get_battle_team_nodes(group_name)`：
  遍历当前场景根节点的所有子节点，筛出属于 `frien` 或 `enemy` 分组的对象。

#### 4. 计算某一侧队伍如何排

- `_compute_team_layout(nodes, region)`：
  这是核心函数。
- 第一步：
  先按 `BattleManager` 当前维护的队伍显示顺序整理这一侧节点，再计算这一侧有多少单位 `unit_count`；没有单位就直接返回空字典。
- 第二步：
  计算状态栏宽度
  `status_max_width = clampf(region.size.x / unit_count - 20.0, 180.0, 200.0)`。
- 第三步：
  用 `_build_layout_metrics_for_nodes(nodes, 1.0, status_max_width)` 先按原始缩放做一次预估，得到每个节点的外接包围盒。
- 第四步：
  用 `_resolve_layout_gap()` 计算当前可用宽度下的实际间距，再用 `_compute_required_layout_width()` 统计总宽度。
- 第五步：
  如果总宽度超出当前阵营区域宽度，就调用 `_resolve_layout_scale_factor()` 求一个缩放因子，再重新生成一轮 metrics；如果还是超宽且单位数大于 1，则直接把间距压到 `BATTLE_LAYOUT_MIN_GAP`。
- 第六步：
  计算横向起点 `start_x`，使整排内容在当前阵营区域里居中。
- 第七步：
  逐个节点向右推进 `cursor_x`。每个节点的位置并不是直接取包围盒左上角，而是用
  `node_x = cursor_x - local_bounds.position.x`
  把节点锚点放到一个能让其外接矩形正确落位的位置。
- 第八步：
  纵向位置先以 `BATTLE_LAYOUT_BASELINE_Y` 为目标，再根据顶部和底部安全边距计算 `min_y` / `max_y`，最后用 `clampf()` 把节点压回可见范围。
- 第九步：
  生成该单位的布局字典：
  `position`、`portrait_scale`、`status_max_width`、`bounds`。

#### 5. 辅助计算函数

- `_build_layout_metrics_for_nodes(nodes, scale_factor, status_max_width)`：
  逐个节点调用 `get_default_portrait_scale()` 和 `get_layout_metrics()`，拿到每个立绘在当前缩放下的包围盒。
- `_compute_required_layout_width(metrics_list, gap)`：
  把所有节点的 `local_bounds.size.x` 加起来，再加上单位之间的间距，得到整排总宽度。
- `_resolve_layout_gap(metrics_list, available_width, default_gap)`：
  根据“总可用宽度减去所有单位宽度后的剩余空间”反推理论间距，再把结果限制在 `4.0` 到 `8.0` 之间。
- `_resolve_layout_scale_factor(metrics_list, available_width, unit_count)`：
  当默认尺寸放不下时，根据总宽度和最小间距要求反推缩放倍率，并保证不会低于 `0.72`。

### 五、单个立绘节点如何响应 `apply_layout()`

#### 1. 入口函数

- `player_character.apply_layout(layout_data)` / `enemy_character.apply_layout(layout_data)`：
  先缓存 `_layout_data`；如果 `layout_data` 里有 `position` 就直接更新节点位置；然后取出 `portrait_scale` 和 `status_max_width`，交给 `get_layout_metrics()` 重新计算，再调用 `_apply_metrics()` 真正落到控件上。
  前排移动 tween 结束后，仍会回到这条入口应用最终布局，因此移动期间只改 `x`，结束后再做一次完整静态对齐。

#### 2. 计算本地包围盒

- `get_layout_metrics(portrait_scale, status_max_width)`：
  输入是“当前应该使用的立绘缩放”和“状态栏宽度上限”，输出是整个节点内部 UI 的几何结果。
- `portrait_rect`：
  以立绘中心为原点，计算缩放后的立绘矩形。
- `bar_width = clampf(portrait_size.x * 0.82, 132.0, 220.0)`：
  血条宽度取立绘宽度的 82%，再限制到 132 到 220 之间。
- `bar_rect`：
  血条位于立绘底部下方，偏移量由 `BOTTOM_GAP` 决定。
- `health_rect`：
  生命值文本位于血条下方，偏移量由 `HEALTH_LABEL_GAP` 决定。
- `status_rect`：
  状态栏位于立绘上方，和立绘顶部之间的距离由 `STATUS_TOP_GAP` 控制，最多两行。
- `countdown_rect`：
  倒计时文字放在立绘左侧，横向距离由 `COUNTDOWN_MARGIN` 控制；若状态栏存在，则会向下让位，避免重叠。
- `shield_rect`：
  护盾图标和数字整体位于血条左边，图标和数字间距由 `SHIELD_GAP` 控制。
- `local_bounds`：
  把立绘、血条、生命值、倒计时、状态栏、护盾区域不断 `merge()`，生成该节点的最终外接矩形。BattleManager 的整队排版正是依赖这个矩形来算间距和缩放。

#### 3. 应用到节点

- `_apply_metrics(metrics)`：
  把上一步得到的各个矩形和尺寸写回 `portrait_sprite`、`status_label`、`countdown_label`、`health_bar`、`health_label`、`shield_label` 等实际控件。
- `_update_collision_shape(portrait_size)`：
  根据立绘尺寸调整点击 / 选中区域。宽度取 `max(portrait_size.x * 0.72, 128.0)`，高度取 `max(portrait_size.y * 0.84, 128.0)`。

### 六、可直接用于查代码的规则摘要

- `DEFAULT_PORTRAIT_SCALE = 6.0`：
  立绘默认放大倍率。
- `STATUS_TOP_GAP = 50.0`：
  立绘顶端到状态栏的距离。
- `BOTTOM_GAP = 6.0`：
  立绘底部到血条的距离。
- `HEALTH_LABEL_GAP = 6.0 / 10.0`：
  玩家 / 敌人血条到血量文字的距离。
- `COUNTDOWN_MARGIN = 8.0 / 16.0`：
  玩家 / 敌人立绘左缘到倒计时文字的距离。
- `SHIELD_GAP = 8.0`：
  护盾图标和数字的距离。
- `BATTLE_LAYOUT_DEFAULT_GAP = 8.0`：
  同侧角色之间的默认水平间距。
- `BATTLE_LAYOUT_MIN_GAP = 4.0`：
  同侧角色之间允许压缩到的最小水平间距。
- `BATTLE_LAYOUT_MIN_SCALE_FACTOR = 0.72`：
  整排过宽时，最小允许缩到默认尺寸的 72%。
- `FRONT_UNIT_MOVE_DURATION = 0.2`：
  角色骰触发前排移动时的默认动画时长。

### 七、角色骰前排移动规则

- 当前仅 `frien` 与 `enemy_frien` 会触发前排立绘移动。
- 触发条件是：当前正面最终成功解析到有效角色实例。
- 玩家前排定义为最右；敌人前排定义为最左。
- 该移动只允许改 `position.x`，不改 `position.y`、立绘缩放、状态栏、血条、倒计时布局。
- 其余同侧角色按原相对顺序整体让位，不会只移动单个目标导致重叠。
- 若当前正面为未填角色面，且回退解析后仍没有有效角色 ID，则本次不进行立绘移动。

## 4. Hexes

文件：`GameData/hexes.json`

顶层格式：

```json
{
  "hexes": {
    "fh001": {
      "...": "..."
    }
  }
}
```

### 顶层字段

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `name` | `String` | 是 | Hex 名称 |
| `hex_desc` | `String` | 建议 | 描述文本 |
| `texture_path` | `String` | 是 | 骰面贴图路径 |
| `slot_limit` | `int` | 否 | 该 Hex 可被放入的最大次数 |
| `cast_condition` | `int` | 否 | 默认施法朝向；当 `effect_data` 内各效果未单独写 `cast_condition` 时生效 |
| `target_data` | `Array[Dictionary]` | 是 | 目标选择定义 |
| `effect_data` | `Array[Dictionary]` | 是 | 效果定义 |
| `is_peak` | `bool` | 否 | 角色专属扩展标记 |
| `is_soul` | `bool` | 否 | 角色专属扩展标记 |
| `owner_character` | `String` | 否 | 专属所属角色 ID 或名称；当前主要是数据标记 |

### 枚举值

#### `cast_condition` / `condition.dice_reference.face`

| 值 | 含义 |
| --- | --- |
| `0` | `UP` 正面 |
| `1` | `DOWN` 反面 |
| `2` | `SIDE` 侧面 |

#### `target_data[].team`

| 值 | 含义 |
| --- | --- |
| `0` | `ALLY` |
| `1` | `ENEMY` |

#### `target_data[].type`

| 值 | 含义 |
| --- | --- |
| `0` | `CHARACTER` |
| `1` | `DICEFACE` |
| `2` | `DICE` |

#### `target_data[].condition.dice_reference.type`

| 值 | 含义 |
| --- | --- |
| `0` | `FRIEND` |
| `1` | `EQUIPMENT` |
| `2` | `HEX` |

#### `effect_data[].type`

| 值 | 含义 |
| --- | --- |
| `0` | `HEALTH_CHANGE`，生命变化；负数为伤害，正数为治疗 |
| `1` | `STATUS_APPLY`，施加状态 |
| `2` | `SPECIAL`，特殊效果 |
| `3` | `SHIELD_CHANGE`，护盾变化 |

### `target_data` 结构

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `team` | `int` | 是 | 目标队伍 |
| `type` | `int` | 是 | 目标类型 |
| `condition` | `Dictionary` | 否 | 目标条件 |
| `index` | `int` | 是 | 目标索引，供 `effect_data.target_index` 引用 |

#### `condition` 常用写法

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `dice_reference.type` | `int` | 参考哪类骰子 |
| `dice_reference.face` | `int` | 参考朝向 |
| `selector` | `String` | 显式角色目标选择器；推荐用于前后排、生命排序、状态筛选 |
| `status_id` | `String` | 当 `selector = status_ally/status_enemy` 时必填 |
| `status_check` | `Array` | 预留，当前代码基本未消费 |
| `index` | `int` | 预留，当前代码基本未消费 |

#### `condition.selector` 可用值

| 值 | 说明 |
| --- | --- |
| `front_ally` | 当前施法者同侧前排 |
| `front_enemy` | 当前施法者对侧前排 |
| `back_ally` | 当前施法者同侧后排 |
| `back_enemy` | 当前施法者对侧后排 |
| `lowest_health_ally` | 当前施法者同侧生命最低的存活单位，平票全选 |
| `lowest_health_enemy` | 当前施法者对侧生命最低的存活单位，平票全选 |
| `highest_health_ally` | 当前施法者同侧生命最高的存活单位，平票全选 |
| `highest_health_enemy` | 当前施法者对侧生命最高的存活单位，平票全选 |
| `status_ally` | 当前施法者同侧所有带指定状态的存活单位 |
| `status_enemy` | 当前施法者对侧所有带指定状态的存活单位 |

#### 前后排定义

- 玩家队伍：最右为前排，最左为后排。
- 敌人队伍：最左为前排，最右为后排。
- 若某侧当前仅有 1 个存活单位，则该单位同时视为前排与后排。
- 新数据不要再用 `condition.dice_reference.face = 1` 表达“底面/后排目标”；该旧写法仅保留兼容含义，不再推荐新增使用。

### `effect_data` 结构

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `type` | `int` | 是 | 效果类型 |
| `target_index` | `Array[int]` | 是 | 对应 `target_data.index` |
| `read_target_index` | `Array[int]` | 否 | 只读取这些目标的数据，不对这些目标直接施加效果 |
| `cast_condition` | `int` | 否 | 该效果单独的触发朝向 |
| `value` | `int` | 条件必填 | `HEALTH_CHANGE / SHIELD_CHANGE` 时使用 |
| `read_status_id` | `String` | 否 | 当效果需要按目标已有状态层数计算数值时，读取的状态 ID |
| `read_value_per_stack` | `int` | 否 | 每读取 1 层 `read_status_id` 时，按效果类型追加数值；`HEALTH_CHANGE` 追加到 `value`，`STATUS_APPLY` 追加到最终 `stack_count` |
| `read_char_stat` | `String` | 否 | 当效果需要按读目标的角色/敌人运行时数值计算时，读取的数值字段；当前支持 `current_health / max_health / shield / countdown / base_countdown` |
| `read_value_per_point` | `int` | 否 | 每读取 1 点 `read_char_stat` 时，按效果类型追加数值；`HEALTH_CHANGE / SHIELD_CHANGE` 追加到 `value`，`STATUS_APPLY` 追加到最终 `stack_count` |
| `status_id` | `String` | 建议 | `STATUS_APPLY` 时优先使用；会自动从状态表补齐 `status_info` |
| `status_info` | `Dictionary` | 可选 | 直接内联状态定义；若写了 `status_id`，运行时会用状态表补全并覆盖关键字段 |
| `special_id` | `String` | `SPECIAL` 时使用 | 特殊逻辑标识 |
| `steps` | `int` | `special_id = retreat` 时必填 | 后退步数，必须为正整数 |
| `traits` | `Array[String]` | 建议 | Hex Trait ID 列表；无 trait 时写 `[]` |

### Hex 编写要求

- 新条目优先使用 `status_id`，不要手写一整份不完整的 `status_info`。
- `target_index` 一律写数组，如 `[0]`，不要混写单值。
- 若本次效果只需要“取某目标的数据作为计算输入”，不要给该目标写假伤害或空效果；应在当前效果上补 `read_target_index`。
- `read_target_index` 表示“读取目标”，`target_index` 表示“实际承受效果的目标”，两者语义不要混用。
- 当 `HEALTH_CHANGE` 需要按某状态层数动态结算时，写 `value + read_status_id + read_value_per_stack`；最终数值 = `value + 状态总层数 * read_value_per_stack`。
- 当 `HEALTH_CHANGE / SHIELD_CHANGE` 需要按角色运行时数值动态结算时，写 `value + read_char_stat + read_value_per_point`；最终数值 = `value + 运行时数值总和 * read_value_per_point`。
- 当 `STATUS_APPLY` 需要按某状态层数动态决定施加层数时，也可写 `read_target_index + read_status_id + read_value_per_stack`；最终层数 = `stack_count + 状态总层数 * read_value_per_stack`。若未显式填写 `stack_count`，则以状态表默认 `stack_count` 作为基础层数。
- 当 `STATUS_APPLY` 需要按角色运行时数值动态决定施加层数时，也可写 `read_target_index + read_char_stat + read_value_per_point`；最终层数 = `stack_count + 运行时数值总和 * read_value_per_point`。若未显式填写 `stack_count`，则以状态表默认 `stack_count` 作为基础层数。
- `read_status_id` 与 `read_char_stat` 可同时存在；最终增量为“状态层数增量 + 运行时数值增量”。
- `read_char_stat` 只读取角色/敌人的运行时战斗状态；若 `read_target_index` 指向骰子、骰面或无效目标，则该目标按 `0` 处理。
- 伤害写负数，治疗写正数。
- 若不同朝向对应不同效果，应把 `cast_condition` 写在各个 `effect_data` 项上，不要只依赖顶层 `cast_condition`。
- `traits` 仅写 Trait ID，不混写描述文本。
- `traits` 当前只接受数组格式，不做旧字段兼容。
- Hex Trait 事件已接入 `spell_cast_before`、`spell_effect_before`、`spell_effect_after`、`spell_cast_after`。
- `lowest_health_*` / `highest_health_*` 一律按运行时 `current_health` 比较，不按生命百分比比较。
- `status_ally` / `status_enemy` 默认返回全部匹配目标；若没有匹配状态，则解析结果为空。

#### `target_data` 示例

后排敌人：

```json
[
  {
    "team": 1,
    "type": 0,
    "condition": {
      "selector": "back_enemy"
    },
    "index": 0
  }
]
```

生命最低敌人：

```json
[
  {
    "team": 1,
    "type": 0,
    "condition": {
      "selector": "lowest_health_enemy"
    },
    "index": 0
  }
]
```

生命最高友军：

```json
[
  {
    "team": 0,
    "type": 0,
    "condition": {
      "selector": "highest_health_ally"
    },
    "index": 0
  }
]
```

带有指定状态的敌军：

```json
[
  {
    "team": 1,
    "type": 0,
    "condition": {
      "selector": "status_enemy",
      "status_id": "st009"
    },
    "index": 0
  }
]
```

### Hex 特殊效果现状

当前数据中已出现：

| `special_id` | 说明 |
| --- | --- |
| `burn_consume` | 消耗目标身上的 Burn 再处理后续效果 |
| `flip_dice` | 按指定方向翻转目标骰子；当前支持 `UP / DOWN / LEFT / RIGHT` |
| `roll_dice` | 令目标骰子重新投掷一次，走完整投掷动画与结果结算 |
| `advance` | 令目标角色前进若干步；只改队伍站位，不改骰状态 |
| `retreat` | 令目标角色后退若干步；只改队伍站位，不改骰状态 |

新增 `special_id` 前，需要先确认 `BattleManager.gd` 内已有对应逻辑。

#### `flip_dice` 补充规范

当 `type = 2` 且 `special_id = "flip_dice"` 时，建议补充以下字段：

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `flip_direction` | `String` | 是 | 翻转方向，当前支持 `UP`、`DOWN`、`LEFT`、`RIGHT` |

推荐写法：

```json
{
  "type": 2,
  "special_id": "flip_dice",
  "flip_direction": "LEFT",
  "target_index": [1]
}
```

与 `flip_dice` 配套时，`target_data` 应优先写成 `type = 2` 的 `DICE` 目标。  
当前设计口径下，`flip_dice` 不只是视觉翻面，而是一次完整的投掷结果更新，因此会继续触发这次结果更新后的整套后续结算，包括 `global_tick`。  
如果后续需要“只改朝向、不推进节奏”的弱翻面效果，不应直接复用 `flip_dice`。

#### `roll_dice` 补充规范

当 `type = 2` 且 `special_id = "roll_dice"` 时，不需要额外方向字段。

推荐写法：

```json
{
  "type": 2,
  "special_id": "roll_dice",
  "target_index": [1]
}
```

与 `roll_dice` 配套时，`target_data` 也应优先写成 `type = 2` 的 `DICE` 目标。  
`roll_dice` 会让目标骰子重新播放投掷动画，并按正常投掷逻辑更新结果与后续结算。

#### `retreat` 补充规范

当 `type = 2` 且 `special_id = "retreat"` 时，建议补充以下字段：

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `steps` | `int` | 是 | 后退步数，必须为正整数 |

推荐写法：

```json
{
  "type": 2,
  "special_id": "retreat",
  "steps": 2,
  "target_index": [0]
}
```

`retreat` 只对角色目标生效；若目标解析为骰子或骰面，则该目标会被忽略。  
多人命中时按当前结算顺序逐个后退；每次后退都会立即更新当前队伍顺序。  
`retreat` 不改变角色骰当前朝向，不触发重新投掷，也不修改骰子、骰面或角色状态。

#### `advance` 补充规范

当 `type = 2` 且 `special_id = "advance"` 时，建议补充以下字段：

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `steps` | `int` | 是 | 前进步数，必须为正整数 |

推荐写法：

```json
{
  "type": 2,
  "special_id": "advance",
  "steps": 2,
  "target_index": [0]
}
```

`advance` 只对角色目标生效；若目标解析为骰子或骰面，则该目标会被忽略。  
多人命中时按当前结算顺序逐个前进；每次前进都会立即更新当前队伍顺序。  
玩家侧前排定义为最右，敌人侧前排定义为最左；若目标已在前排，则本次不移动。  
`advance` 不改变角色骰当前朝向，不触发重新投掷，也不修改骰子、骰面或角色状态。

## 5. Equipments

文件：`GameData/equipments_v2.json`

顶层格式：

```json
{
  "equipments": {
    "eq001": {
      "...": "..."
    }
  }
}
```

### 字段规范

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `equipment_name` | `String` | 是 | 装备名称 |
| `texture_path` | `String` | 是 | 骰面贴图路径 |
| `slot_limit` | `int` | 否 | 最大嵌入次数 |
| `attack_bonus` | `int` | 否 | 攻击加值 |
| `defense_bonus` | `int` | 否 | 防御加值 |
| `traits` | `Array[String]` | 建议 | 结构化装备 Trait ID 列表 |
| `trait_descs` | `Array[String]` | 建议 | 文本描述数组，用于 UI 展示 |
| `tags` | `Array[String]` | 否 | 锻造标签，例如 `Sharp`、`Thick`、`Mythic`、`Critical` |
| `forged_variant_id` | `String` | 否 | 锻造分支 ID |
| `is_forged` | `bool` | 否 | 是否已锻造 |

### 编写要求

- `traits` 只写 Trait ID，不要混写描述文本。
- `trait_descs` 只写展示文案，不参与逻辑。
- 即使没有 trait，也建议显式写 `traits: []` 和 `trait_descs: []`。
- 需要接入锻造系统的装备，必须保证 `tags / forged_variant_id / is_forged` 的数据风格一致。

### 兼容说明

- 旧版装备曾把 `traits` 当文本字段使用；当前 `equipments_v2.json` 已切换为结构化 ID 数组。
- 新数据不要再把 `traits` 写成字符串。

## 6. Items

文件：`GameData/items.json`

顶层格式：

```json
{
  "items": {
    "it001": {
      "...": "..."
    }
  }
}
```

### 字段规范

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `item_name` | `String` | 是 | 物品名称 |
| `type` | `int` | 是 | 物品类型 |
| `description` | `String` | 建议 | 文本说明 |
| `texture_path` | `String` | 是 | 图标路径 |
| `price` | `int` | 是 | 商店价格 |
| `effect_id` | `String` | 是 | 物品效果类型 |
| `effect_params` | `Dictionary` | 否 | 效果参数 |
| `max_uses` | `int` | 否 | 最大使用次数，`-1` 表示无限 |
| `current_uses` | `int` | 否 | 运行时字段；静态配置通常不写 |
| `charge_type` | `int` | 否 | 充能来源 |
| `max_charge` | `int` | 否 | 满充能需求 |
| `current_charge` | `int` | 否 | 运行时字段；静态配置通常不写 |

### `type` 枚举

| 值 | 含义 |
| --- | --- |
| `0` | `PASSIVE` 被动物品 |
| `1` | `ACTIVE` 主动物品 |
| `2` | `CONSUMABLE` 消耗品 |

### `charge_type` 枚举

| 值 | 含义 |
| --- | --- |
| `0` | `NONE` 无充能 |
| `1` | `RALLY` 友方行动前充能 |
| `2` | `TICK` 全局 tick 充能 |

### 当前代码中已支持的 `effect_id`

| `effect_id` | 说明 | 目标类型 |
| --- | --- | --- |
| `heal` | 治疗 | `ally` |
| `damage` | 伤害 | `enemy` |
| `gain_gold` | 获得金币 | `none` |
| `reroll` | 获得重投次数 | `none` |
| `buff_damage` | 当前仅作为被动占位 | `none` |

### Item 编写要求

- 静态配置时通常不要写 `item_id`，外层 key 已经是 ID。
- `current_uses` 和 `current_charge` 主要用于运行时存档，静态表可以不写。
- 如果 `max_charge > 0`，则该物品必须通过充能后才能使用。
- `ACTIVE` 类型通常需要配套 `charge_type / max_charge`；`CONSUMABLE` 常用 `max_uses: 1`。

### 特殊兼容说明

- `it004` 当前在 `ItemManager.gd` 里有兼容覆盖逻辑，会被强制当成金币测试道具处理。
- 如果要把 `it004` 改回正常道具，需要同步修改运行时代码。

## 7. Statuses

文件：`GameData/statuses_v2.json`

顶层格式：

```json
{
  "statuses": {
    "st001": {
      "...": "..."
    }
  }
}
```

### 字段规范

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `status_name` | `String` | 是 | 状态名称；运行时合并状态时按该名称归并 |
| `texture_path` | `String` | 否 | 图标路径 |
| `status_type` | `int` 或 `String` | 是 | 状态语义分类 |
| `category` | `int` 或 `String` | 是 | 行为分类 |
| `status_target` | `int` 或 `String` | 是 | 作用目标类型 |
| `duration` | `int` | 是 | 默认持续时间；`-1` 表示永久 |
| `stack_count` | `int` | 否 | 每次施加时增加的层数，默认 `1` |
| `max_stacks` | `int` | 否 | 最大层数；`-1` 表示无限 |
| `description` | `String` | 建议 | 描述文本 |
| `effects` | `Dictionary` | 是 | 行为参数 |

### `status_type` 枚举

| 值 | 含义 |
| --- | --- |
| `0` 或 `"buff"` | `BUFF` |
| `1` 或 `"debuff"` | `DEBUFF` |
| `2` 或 `"special"` | `SPECIAL` |

### `category` 枚举

| 值 | 含义 |
| --- | --- |
| `0` 或 `"dot"` | `DoT` |
| `1` 或 `"damage_mod"` | `DAMAGE_MOD` |
| `2` 或 `"crowd_control"` | `CROWD_CONTROL` |
| `3` 或 `"aggro"` | `AGGRO` |

### `status_target` 枚举

| 值 | 含义 |
| --- | --- |
| `0` 或 `"character"` | `CHARACTER` |
| `1` 或 `"dice"` | `DICE` |
| `2` 或 `"dice_face"` | `DICE_FACE` |

### `effects` 常用键

#### `DoT`

| 键 | 类型 | 说明 |
| --- | --- | --- |
| `tick_damage` | `int` | 每次 tick 伤害 |
| `tick_phase` | `String` | 当前主要用 `global_tick`；`after_action` 也兼容为 `global_tick` |

### 倒数类状态的当前结算口径

- 若 `slow` / `speedup` 这类带有 `on_apply_*countdown_delta` 的状态，在目标已经进入本次序列的施法/行动队列后才被施加，则本次已锁定行动不回溯修改。
- 这类倒数改变量会顺延到该目标本次行动开始、倒数重置为 `base_countdown` 后再生效；也就是下一次行动的起始倒数变为 `base_countdown + delta`。
- 同一序列内新施加、且带有 `duration_tick_phase = "after_action"` 的倒数类状态，不会在目标这次已排队行动的 `after_action` 中立刻衰减。
- 因此，不要为了补偿这个结算口径而在 CSV 里手动多写 1 点 `duration`。

#### `DAMAGE_MOD`

| 键 | 类型 | 说明 |
| --- | --- | --- |
| `outgoing_damage_add` | `int` | 造成伤害加算 |
| `incoming_damage_add` | `int` | 受到伤害加算 |
| `outgoing_damage_mul` | `float` | 造成伤害乘算 |
| `incoming_damage_mul` | `float` | 受到伤害乘算 |

#### `CROWD_CONTROL`

| 键 | 类型 | 说明 |
| --- | --- | --- |
| `skip_action` | `bool` | 跳过行动 |
| `disable_flip` | `bool` | 禁止翻面 |
| `disable_roll` | `bool` | 禁止投掷 |
| `exclude_from_next_friend_roll` | `bool` | 下次友方角色掷骰时排除该角色 |

### Status 编写要求

- 新状态必须补齐 `category`、`status_target`、`effects`，不要再写旧版半结构化状态。
- 建议统一使用整数枚举，虽然代码也兼容字符串。
- `status_name` 用于运行时合并同名状态，改名会改变叠层和刷新逻辑。
- `status_name` 是显示/兼容字段，不是安全的逻辑主键；不要使用本地化名、翻译文本或 `status.xxx.name` 这类 key 去做状态匹配。
- 当前项目已知存在“把状态本地化名当状态键”会导致结算错误的风险；状态相关判断一律优先使用稳定的状态 `id`。
- `duration == -1` 表示永久状态。

## 8. Traits

文件：`GameData/traits_v2.json`

顶层格式：

```json
{
  "traits": {
    "t001": {
      "...": "..."
    }
  }
}
```

### 顶层字段

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `source_kind` | `String` | 是 | 来源类型，当前使用 `character`、`equipment`、`enemy`、`hex` |
| `template_type` | `String` | 否 | 模板分类，仅作数据组织和说明 |
| `listener_scope` | `String` | 否 | 监听范围描述，目前主要用于文档/UI，不是强约束 |
| `name` | `String` | 是 | Trait 名称 |
| `desc` | `String` | 建议 | Trait 描述 |
| `target_data` | `Array[Dictionary]` | 角色 trait 建议填写 | 目标定义，结构与 Hex 的 `target_data` 类似 |
| `runtime_defaults` | `Dictionary` | 装备 trait 建议填写 | 装备 trait 的运行时状态初始值 |
| `triggers` | `Array[Dictionary]` | 是 | 触发器列表 |

### `source_kind`

| 值 | 说明 |
| --- | --- |
| `character` | 角色 Trait |
| `equipment` | 装备 Trait |

### 当前已接入的角色 Trait 事件

| 事件名 | 说明 |
| --- | --- |
| `rolled` | 掷骰后 |
| `reinforce` | 投掷角色骰后 |
| `rally` | 施法前 |
| `ambush` | 倒数前 |
| `endure` | 受伤后 |
| `deploy` | 亮出时 |
| `chosen` | 投出+施法 |
| `last_breath` | 角色生命结算后死亡、但在移除前触发；推荐作为亡语统一事件 |

### 当前已接入的装备 Trait 事件

| 事件名 | 说明 |
| --- | --- |
| `equipment_face_up` | 装备面朝上时 |
| `equipment_face_up_lost` | 失去正面时 |
| `ally_action_before` | 友方行动前 |
| `ally_action_after` | 友方行动后 |
| `enemy_action_damage_before` | 敌方伤害结算前 |
| `status_applied_after` | 状态施加后 |

### 角色 Trait 的 `trigger.actions[].type`

| 值 | 含义 |
| --- | --- |
| `0` | 生命变化 |
| `1` | 施加状态 |
| `3` | 护盾变化 |
| `advance` | 令目标角色前进若干步 |
| `retreat` | 令目标角色后退若干步 |

### `retreat` 动作补充字段

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `steps` | `int` | 是 | 后退步数，必须为正整数 |

推荐写法：

```json
{
  "type": "retreat",
  "steps": 1,
  "target_index": [0]
}
```

`retreat` 只对角色目标生效；若目标不是角色，则该目标会被忽略。  
该动作只改变目标在当前队伍中的站位，不改变骰状态。

### `advance` 动作补充字段

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `steps` | `int` | 是 | 前进步数，必须为正整数 |

推荐写法：

```json
{
  "type": "advance",
  "steps": 1,
  "target_index": [0]
}
```

`advance` 只对角色目标生效；若目标不是角色，则该目标会被忽略。  
玩家侧前进方向为向右/前排，敌人侧前进方向为向左/前排；若目标已在前排，则该动作不生效。  
该动作只改变目标在当前队伍中的站位，不改变骰状态。

### `status_apply` 动作补充字段

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `status_id` | `String` | 是 | 要施加的状态 ID |
| `duration` | `int` | 否 | 覆盖状态表默认持续时间；未填写时沿用状态表 |
| `stack_count` | `int` | 否 | 覆盖本次施加的层数；未填写时沿用状态表 |
| `max_stacks` | `int` | 否 | 覆盖本次施加使用的最大层数限制；未填写时沿用状态表 |

- `duration == 0` 可用于构造“已有状态时只加层、不刷新时长”的 trait 效果。
- 对首次施加的 DoT，`duration == 0` 不会再额外触发一次 tick，并会在同轮状态清理时移除。

### 装备 Trait 当前已实现的动作类型

| `type` | 说明 |
| --- | --- |
| `runtime_adjust` | 调整运行时数值 |
| `runtime_set` | 设置运行时数值 |
| `deal_front_enemy_damage` | 对正面敌人造成伤害 |
| `consume_ammo_or_reload` | 消耗弹药攻击，否则装填 |
| `consume_ammo_and_damage` | 消耗弹药并造成伤害 |
| `negate_damage_if_armed` | 若已架起则抵消本次敌方伤害 |

### `triggers` 结构

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `event` | `String` | 是 | 事件名 |
| `conditions` | `Dictionary` | 否 | 触发条件 |
| `actions` | `Array[Dictionary]` | 是 | 动作列表 |

### 当前已支持的触发条件键

| 键 | 类型 | 说明 |
| --- | --- | --- |
| `status_id` | `String` | 仅当本次事件涉及特定状态时触发 |
| `target_team` | `String` | 例如 `ally` / `enemy` |
| `hex_id` | `String` | 仅当本次事件来自指定 Hex 时触发 |
| `actor_side` | `String` | `player` / `enemy` |
| `trigger_face` | `int` | 仅当施法朝向匹配时触发 |
| `effect_type` | `int` | 仅当 effect 类型匹配时触发 |
| `effect_index` | `int` | 仅当 effect 序号匹配时触发 |

### Trait 编写要求

- 角色 trait 使用 `target_data + target_index` 这套目标索引机制。
- 装备 trait 如果有状态机需求，必须把初始值写入 `runtime_defaults`。
- 新增事件名或动作类型前，必须先确认 `TraitManager.gd` 和 `BattleManager.gd` 已支持。
- 亡语、被击杀触发、死亡反制这类效果，推荐统一使用 `last_breath`，不要优先依赖 `enemy_death_before` / `enemy_death_after` 这类兼容事件。
- `source_kind = equipment` 的 trait 才会被 `EquipmentData.traits` 消费。
- `source_kind = hex` 的 trait 才会被 `HexData.traits` 消费。

### 当前已接入的 Hex Trait 事件

| 事件名 | 说明 |
| --- | --- |
| `spell_cast_before` | 整个法术开始结算前 |
| `spell_effect_before` | 单个 `effect_data` 结算前 |
| `spell_effect_after` | 单个 `effect_data` 结算后 |
| `spell_cast_after` | 整个法术全部结算后 |

### 当前已接入的 Hex Trait 模板行为

| 名称 | 说明 |
| --- | --- |
| `swift` | Hex 掷出为正面时立即发动；若同一次投掷也让倒数归零，则该 Hex 仍只发动一次 |

## 9. 推荐模板

### Character 模板

```json
"fc999": {
  "name": "NewHero",
  "texture_path": "res://Assets/dice-NewHero.png",
  "base_health": 180,
  "experience": 0,
  "countdown": 3,
  "traits": ["t999"],
  "prime_hex_id": "fh999",
  "peak_hex_id": "",
  "soul_hex_id": "",
  "slot_limit": 6
}
```

### Enemy 模板

```json
"fb999": {
  "name": "NewEnemy",
  "texture_path": "res://Assets/dice-NewEnemy.png",
  "base_health": 24,
  "trait": "",
  "weight": 3,
  "equipment": ["eq001"],
  "hexes": ["fh001"],
  "countdown": 3
}
```

### Equipment 模板

```json
"eq999": {
  "equipment_name": "new_weapon",
  "texture_path": "res://Assets/dice-new-weapon.png",
  "slot_limit": 3,
  "attack_bonus": 2,
  "defense_bonus": 0,
  "traits": ["eqt999"],
  "trait_descs": ["Trait description for UI."],
  "tags": ["Sharp"],
  "forged_variant_id": "",
  "is_forged": false
}
```

### Status 模板

```json
"st999": {
  "status_name": "new_status",
  "texture_path": "res://Assets/status-new-status.png",
  "status_type": 1,
  "category": 2,
  "status_target": 0,
  "duration": 1,
  "stack_count": 1,
  "max_stacks": 1,
  "description": "Describe the effect.",
  "effects": {
    "skip_action": true
  }
}
```

### Trait 模板

```json
"t999": {
  "source_kind": "character",
  "template_type": "generic",
  "listener_scope": "owner_only",
  "name": "new_trait",
  "desc": "When deployed, gain 1 shield.",
  "target_data": [
    {
      "team": 0,
      "type": 0,
      "condition": {
        "self": true
      },
      "index": 0
    }
  ],
  "triggers": [
    {
      "event": "deploy",
      "actions": [
        {
          "type": 3,
          "value": 1,
          "target_index": [0]
        }
      ]
    }
  ]
}
```

### Hex Trait 模板

```json
"ht999": {
  "source_kind": "hex",
  "template_type": "generic",
  "listener_scope": "spell_owner",
  "name": "new_hex_trait",
  "desc": "After this hex resolves, deal 1 extra damage to affected enemies.",
  "target_data": [
    {
      "team": 1,
      "type": 0,
      "condition": {
        "selector": "context_character_targets"
      },
      "index": 0
    }
  ],
  "triggers": [
    {
      "event": "spell_cast_after",
      "conditions": {
        "hex_id": "fh999"
      },
      "actions": [
        {
          "type": "health_change",
          "value": -1,
          "target_index": [0]
        }
      ]
    }
  ]
}
```

## 10. 编写前检查清单

- 文件保存为 `UTF-8`
- 顶层 key 名正确
- 条目 ID 未与现有数据冲突
- 引用的 `trait / status / equipment / hex / item` ID 已存在
- 枚举值使用整数，不使用浮点
- 空数组写 `[]`，空字符串写 `""`
- 新增特殊事件、特殊动作、特殊效果前，先确认运行时代码已支持

## 11. Hex supplemental fields

- `effect_data[].overflow_to_shield`: `bool`
- Only used when `effect_data[].type = 0` (`HEALTH_CHANGE`) and `value > 0`
- Semantics: healing beyond max health is converted into shield on the same target
- If omitted or `false`, excess healing is discarded as before

## 12. Hex template entries

### 12.1 Hex target template

最小可用的单目标 `target_data` 模板：

```json
[
  {
    "team": 1,
    "type": 0,
    "condition": {
      "dice_reference": {
        "type": 0,
        "face": 0
      }
    },
    "index": 0
  }
]
```

目标为 `self` 的模板：

```json
[
  {
    "team": 0,
    "type": 0,
    "condition": {
      "self": true
    },
    "index": 0
  }
]
```

常见变体：

- 友方正面角色：`"team": 0, "type": 0`
- 敌方正面角色：`"team": 1, "type": 0`
- 整颗骰子目标：把 `"type"` 改成 `2`
- 后排目标：优先使用 `condition.selector = "back_ally"` 或 `condition.selector = "back_enemy"`
- 同一 Hex 需要多组目标时，按组分配 `index: 0 / 1 / 2 ...`

### 12.2 Hex effect template

直接伤害 / 治疗：

```json
[
  {
    "type": 0,
    "value": -4,
    "target_index": [0]
  }
]
```

按另一组目标的状态层数计算治疗 / 伤害：

```json
[
  {
    "type": 0,
    "value": 0,
    "read_target_index": [1],
    "read_status_id": "st002",
    "read_value_per_stack": 4,
    "target_index": [0]
  }
]
```

这表示：

- 实际效果落在 `target_index: [0]`
- 只读取 `read_target_index: [1]` 上 `st002` 的总层数
- 最终数值为 `0 + 燃烧总层数 * 4`

按另一组目标的运行时生命值 / 护甲计算伤害或护甲：

```json
[
  {
    "type": 0,
    "value": -4,
    "read_target_index": [1],
    "read_char_stat": "current_health",
    "read_value_per_point": 1,
    "target_index": [0]
  },
  {
    "type": 3,
    "value": 0,
    "read_target_index": [1],
    "read_char_stat": "shield",
    "read_value_per_point": 1,
    "target_index": [0]
  }
]
```

施加状态：

```json
[
  {
    "type": 1,
    "status_id": "st002",
    "target_index": [0]
  }
]
```

施加状态并覆盖本次 `duration / stack_count`：

```json
[
 {
    "type": 1,
    "status_id": "st002",
    "status_info": {
      "duration": 2,
      "stack_count": 1
    },
    "target_index": [0]
  }
]
```

按另一组目标的 Burn 层数施加 Poison：

```json
[
  {
    "type": 1,
    "status_id": "st009",
    "stack_count": 0,
    "read_target_index": [1],
    "read_status_id": "st002",
    "read_value_per_stack": 1,
    "target_index": [0]
  }
]
```

这表示：

- 实际效果落在 `target_index: [0]`
- 只读取 `read_target_index: [1]` 上 `st002` 的总层数
- 最终施加层数为 `0 + 燃烧总层数 * 1`
- 若想保留 Poison 自身默认基础层数，可把 `stack_count` 改为 `1` 或直接省略，让运行时改为 `默认层数 + 燃烧总层数 * read_value_per_stack`

按另一组目标的倒数决定施加层数：

```json
[
  {
    "type": 1,
    "status_id": "st009",
    "read_target_index": [1],
    "read_char_stat": "countdown",
    "read_value_per_point": 1,
    "target_index": [0]
  }
]
```

只延长已有状态，不增加层数：

```json
[
  {
    "type": "status_extend",
    "status_id": "st002",
    "duration": 2,
    "target_index": [0]
  }
]
```

特殊效果：

```json
[
  {
    "type": 2,
    "special_id": "flip_dice",
    "flip_direction": "LEFT",
    "target_index": [1]
  }
]
```

多段效果组合：

```json
[
  {
    "type": 1,
    "status_id": "st002",
    "target_index": [0]
  },
  {
    "type": 0,
    "value": -4,
    "target_index": [0]
  }
]
```

模板使用规则：

- `target_index` 一律写成数组，如 `[0]`
- 常规 Hex 效果仍优先使用数值 `type: 0 / 1 / 2 / 3`
- `status_extend` 是当前已支持的字符串动作类型，专用于“只延长、不叠层”
- 不要再用 `status_apply + stack_count: 0` 或 `status_apply + duration: 0` 表达“只延长状态”

