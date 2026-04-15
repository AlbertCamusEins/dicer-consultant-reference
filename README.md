# Dicer

`Dicer` 是一个使用 Godot 4 开发的骰面构筑 Roguelike 原型项目。  
玩家围绕三类核心骰子进行构筑与战斗：

- `Frien`：角色骰，决定出场角色与角色引用
- `Equipment`：装备骰，提供攻防加成与 trait 机制
- `Hex`（代码中为 `hex2`）：法术骰，按朝向触发效果

本文档按当前代码状态整理，更新于 **2026-04-04**。

## 运行环境

- 引擎版本：Godot `4.4.1`
- 主入口场景：`Scenes/main_menu_scene.tscn`
- 当前项目使用 `Mobile` renderer 配置运行

## 当前开发进度（可玩主流程）

目前已经具备完整可跑通的一局流程：

1. 主菜单开始新游戏
2. 初始角色 3 选 1（`select_initial_friend`）
3. 进入骰面定制界面，配置 `Frien / Equipment / Hex`
4. 进入程序生成地图，按层推进
5. 在房间间移动并触发内容（战斗、商店、HR、Pantry、Boss 等）
6. 战斗结算获得金币与奖励
7. 击败 Boss 后进入下一层（当前上限第 4 层）
8. 中途可保存并继续游戏（场景状态与 run 数据会持久化）
9. 主菜单可进入独立战斗测试入口（`test_prep`），选择角色 / 装备 / Hex / 敌人后直接开始测试战斗

## 已实现系统

### 1. Run 与存档

- `RunData` 维护当前层数、金币、重投次数、锻造点、库存、骰面布局与角色当前生命
- 额外持久化局内进度状态：
  - Pantry 休息冷却（`rest_available / rest_cooldown`）
  - HR 外派状态（角色名、剩余战斗数、奖励金币）
  - 任务系统状态（可领取任务、进行中任务、已完成任务、失败任务、任务计数器）
  - 已完成的骰面定制状态与已保存的骰面布局
  - 存档级战斗教程已展示标记（`has_seen_battle_tutorial`），用于控制首次战斗教程仅在该存档首次战斗时弹出
- `GameManager` 负责新开局、继续游戏、场景状态保存与全局存档读写
- 支持从地图、战斗、商店场景恢复到上次中断状态
- 存档使用 UTF-8 JSON 写入与读取（`to_utf8_buffer()` / `get_string_from_utf8()`）
- 全局设置也已并入同一份 UTF-8 存档，当前持久化：
  - 语言
  - 骰子动画 2 倍速开关
  - 全屏与分辨率
  - 主音量 / 音乐 / 音效 / 环境音
  - 后台静音
- 角色获得经验并升级时，会按升级次数直接结算锻造点

### 1.1 设置界面

- 主菜单与暂停菜单共用同一个设置弹窗：`Scenes/settings_popup.tscn`
- 设置界面使用 `TabContainer`，包含：
  - `Gameplay`
  - `Video`
  - `Sound`
  - `Interaction`（当前为空占位）
- 交互模式为“先修改，点 `Apply` 后统一生效并保存”
- `Gameplay` 当前支持：
  - 语言切换（`zh_CN / en`）
  - 骰子动画 2 倍速（仅影响骰子 `rotate` 动画速度，不改战斗逻辑）
  - 跳过首次战斗教程（全局设置，写入同一份存档）
- `Video` 当前支持：
  - 全屏切换
  - 固定预设分辨率切换（当前预设：`1280x720 / 1600x900 / 1920x1080`）
- `Sound` 当前支持：
  - `Master / Music / SFX / Ambient` 四路音量
  - 后台静音
- 语言切换在已打开界面中支持立即重本地化；静态 key 文本由 `LocalizationManager` 保留原始 key 后重翻
- 声音设置通过运行时确保音频总线存在，不依赖额外总线资源文件

### 2. 地图与房间

- `LevelMapGenerator` 按楼层程序生成地图
- 地图主题包含：`FRONT_DESK / OFFICE / CORRIDOR / SHOP / HR_DEPT / PANTRY / BOSS_ROOM / SOLITARY`
- 地图拓扑保持“无环树”结构，不通过补边制造回路
- 当前按楼层强约束非前台分叉结构：
  - 第 1 层：非前台不出现 `T` 形或十字路口
  - 第 2 层：至少出现 1 个非前台 `T` 形节点
  - 第 3 层：至少出现 1 个非前台十字路口节点
- 地图生成流程已改为“两阶段”：
  - 先生成满足楼层目标的保底骨架
  - 再随机扩张补足该层目标房间数
- 非前台 `T` 形 / 十字路口会被记录为保留分叉节点，特殊房间不会占用这些节点
- 特殊房间的当前放置规则：
  - `Boss` 放在最长死路末端
  - `Shop / HR` 优先放在死路
  - `Pantry` 不会放在 `neighbor_count >= 3` 的分叉节点上
- 当前楼层房间数与死路范围：
  - 第 1 层：`10` 房间，`3~4` 条死路
  - 第 2 层：`15` 房间，`4~5` 条死路
  - 第 3 层：`19` 房间，`5~7` 条死路
  - 第 4 层：`22` 房间，`5~6` 条死路
- `MapStateManager` 持久化：
  - 已探索房间
  - 已清理房间
  - 已清理敌人
  - 当前房间位置
  - 房间内商店状态
- Boss 胜利后会重置地图并推进楼层

### 3. 战斗系统

- 支持普通战、精英战、Boss 战
- 遭遇来源：
  - 普通 / 精英战：`encounters_test.json`
  - Boss 战：`bosses.json`
- 核心机制已接入：
  - 角色生命 / 护盾
  - `countdown` 行动节奏
  - 伤害与治疗结算（含装备加成）
  - 状态系统（角色 / 整骰 / 单面）
  - trait 事件触发
  - 物品使用（含目标选择）
  - 敌方镜像骰面与多单位战斗
  - 空白骰面判定与角色骰空面重定向
  - 分类概率修正投掷
  - 战斗内骰面展开查看层（只读）
- 战斗流程：
  - 进入战斗后，所有骰子初始化
- 若当前存档首次进入 `battle_scene`，且设置中未勾选“跳过战斗教程”，会弹出战斗教程覆盖层
  - 玩家每次投掷任一骰子
  - 投掷后触发 `global_tick`，玩家角色和敌人的 `countdown` 减少 1
  - `global_tick` 会触发角色 trait、状态衰减与相关效果
  - 若 `countdown` 为 0，则角色按顺序行动；法术名称取决于 `hex2` 当前正面
  - 若 `hex2` 当前正面为未填面，则本次不施放法术
  - 若 `equipment` 当前正面为未填面，则本次按空白装备面处理：不提供攻防加成，也不触发 face-up 装备 trait
  - 若角色骰当前正面为未填面，则任何“按当前正面角色面取角色”的逻辑都会重定向到该角色骰最大已填 slot 对应的角色；若没有有效角色面，则该引用返回空并安全跳过
  - 若 `frien` 或 `enemy_frien` 当前正面解析不到有效角色，则不会触发前排立绘移动；只有成功解析到有效角色时，才会先播放“移动到前排”的 x 轴 tween，再继续后续 `reinforce / deploy / cast` 链
  - 战斗中角色阵亡后不再重写其他角色骰面；骰面布局保持战斗开始时的嵌入结果
  - 施放法术、触发 trait 和状态等行为后，会检查目标角色生命变化；若生命小于等于 0，则目标死亡，并继续判定胜负
  - 玩家胜利：本场战斗中的所有敌人死亡
  - 玩家失败：所有玩家角色死亡
  - Boss 战胜利后进入下一层

### 3.0A 分类概率修正投掷

- 当前战斗中的掷骰结果不再对候选面做纯均匀随机，而是使用“按结果类别统计欠账并回归期望”的加权随机。
- 概率修正按“结果类别”而不是“面索引”生效：
  - 相同角色面视为同一类结果
  - 相同装备面视为同一类结果
  - 相同 Hex 面视为同一类结果
  - 空白面统一视为 `blank` 一类结果
- 因此 `1:1`、`3:2:1`、带空白面的组合，都会按当前候选面集合中的类别占比，尽量向期望概率回归。
- 修正逻辑只作用于当前可投候选面；若某些面因状态效果被排除，本次投掷会以过滤后的候选面重新计算期望分布。
- 该修正状态按 `dice_type` 独立维护，并在每场新战斗 / 测试战开始时重置，不跨战斗继承。
- 当前实现目标是“降低短期内明显偏离期望的连偏”，而不是把投掷改成固定配比发牌；整体手感仍保持随机。
- 战斗界面右上角 `Layout button` 可打开只读查看层：
  - 使用 `CanvasLayer + TabContainer`
  - 固定 6 个页签，对应 `frien / equipment / hex2 / enemy_frien / enemy_equipment / enemy_hex2`
  - 每页固定显示 6 个面位，按运行时 `EmbeddedDiceFaces` 渲染，而不是战斗开始快照
  - 当前朝上面会高亮
  - 角色减员后，被清空的角色面会保留格子并显示为空白/失效态
  - 该界面仅供查看，不支持战斗内骰面定制

### 3.1 法术与受击动画

- 当前仅为 `fh001`（火球术）接入了战斗内演出，属于针对单个法术的临时实现，尚未抽象为通用法术动画系统。
- 只要玩家或敌方实际施放 `fh001`，且本次结算存在有效角色目标，就会触发该演出。
- 法术动画资源：
  - 中场火球：`res://Assets/anim-fireball-Sheet.png`
  - 目标受击：`res://Assets/anim-firecrack-Sheet.png`
- 当前演出顺序：
  - 先在战场中场区域播放火球动画，时长 `0.5` 秒
  - 火球结束后，在每个法术目标位置播放受击动画，时长 `0.1` 秒
  - 受击动画结束后，再显示本次火球术造成的血量变化
- 当前尺寸与定位规则：
  - 火球动画按 2 倍尺寸显示
  - 火球生成位置在玩家与敌方队伍之间的中场区域，纵向优先对齐首个目标
  - 受击动画生成在目标单位位置
- 多个角色在同一轮内连续施放火球术时，演出按“火球 + 受击”为一个完整序列顺序播放，避免后续请求覆盖前一发的受击动画数据。

### 3.1A 战斗立绘前排移动

- 当 `frien` 或 `enemy_frien` 掷出有效角色正面时，会先把该角色立绘移动到本侧前排：
  - 玩家前排为最右
  - 敌人前排为最左
- 该移动只使用 `Tween` 修改 `position.x`，不改 `y`、缩放、状态栏尺寸或其他本地 UI 布局参数。
- 其余同侧角色会保持原相对顺序整体让位。
- 该动画优先级高于施法与角色行动；必须等待移动完成后，才继续后续 `reinforce / deploy / cast / countdown` 结算。
- 若当前正面为未填角色面，且最终也无法解析到有效角色，则本次不会发生立绘移动。

### 3.2 首次战斗教程

- 教程以战斗场景上的覆盖层形式显示，不切换到独立场景流程
- 教程主体使用隐藏标签页的 `TabContainer`，共 7 页
- 首次弹出条件：
  - `GameManager.current_run != null`
  - 不是战斗测试模式
  - 当前存档的 `has_seen_battle_tutorial == false`
  - `settings.gameplay.skip_battle_tutorial == false`
- 每次进入 `res://Scenes/battle_scene.tscn` 都会先检查 `has_seen_battle_tutorial`；首次自动弹出时会立即写回存档
  - 教程允许中途点击跳过/关闭；关闭后不会回滚该存档的已展示标记，因此同一存档后续不会再次自动弹出
- 教程页内容当前包括：
  - 主界面区域说明
  - 骰子区交互说明
  - 倒数机制说明
  - 角色骰 / 装备骰 / 法术骰说明
  - 胜利与失败条件

### 4. 奖励、商店、临时房间

- `battle_result` 场景支持：
  - 金币奖励
  - Hex 奖励
  - Equipment 奖励
  - Item 奖励（含主动道具替换确认）
- `shop_scene` 当前支持：
  - 四类商品槽位（Hex / Equipment / Active Item / Passive Item）
  - 购买、刷新、卖出
  - 主动道具冲突替换确认
  - 房间级商店状态保存（离开后可恢复）
- `pantry_scene` 当前支持：
  - 选择一位队伍角色，恢复其最大生命的 30%
  - 休息后进入 3 场战斗冷却，战斗结算后逐场递减
  - 锻造系统：
	- 消耗 `forge point` 对装备进行一次锻造
	- 当前可锻造装备限制为 `sword / magicbook / hand_crossbow`
	- 根据装备 `tag` 提供可选锻造分支：`Sharp / Thick / Mythic / Critical`
	- 锻造后写入 `forged_variant_id / is_forged`
	- 已锻造装备不会再次出现在锻造列表中
	- 锻造结果会同步回库存、当前嵌入骰面与已保存的装备骰布局，并立即存档
	- 当前版本主要完成数据流、显示名与 trait 描述接入；具体战斗效果仍为占位描述
  - Spell Reforge 面板已接入入口，但当前仍为未实装占位
- `hr_dept_scene` 当前支持：
  - 雇佣角色
  - 外派角色
	- 只能外派未嵌入当前骰面的角色
	- 外派后经过 3 场战斗归来
	- 归来后可领取 50 金币奖励
  - 任务系统
	- 可刷新并领取任务报价
	- 支持任务进度追踪、提交与奖励领取
	- 任务事件由战斗、金币、外派等 run 内行为驱动
	- 已接入的任务变体包括：构筑约束、遭遇覆盖、借出道具、抵押物

### 5. 骰面构筑

- `custom_dice_scene` 支持三类玩家骰的定制流程
- 三类玩家骰 `Frien / Equipment / Hex` 都至少需要装填 1 个有效面，才能完成定制并返回地图继续推进
- `EmbeddedDiceFaces` 与 `Inventory` 同步持久化
- 库存内已做同名角色 / 装备 / Hex 去重处理（按名称）
- 玩家可使用本局 `inventory` 中的所有骰面定制骰子；每个骰面除非具有限位 `x`，否则可装备至多 6 个到对应骰子上（限位 `x`：可用最多 `x` 个）
- 玩家不再需要将所有骰子填满；未填面会保留为空白面，并可在战斗中被正常掷出
- 自动填充改为“尽量填入可用面”，不再要求必须补满 6 面
- 在定制中，或定制结束后，进入其他节点再重返定制界面时，玩家可任意装上或取下骰面
- 从已装槽位移除骰面时，会同步清空槽位显示、运行时嵌入数据与已保存布局，不再残留旧骰面逻辑
- 装备骰面定制与初始角色选择流程已兼容锻造字段，锻造后的装备名称与状态可被正常带入后续界面与存档

## 数据驱动内容

核心内容由 `GameData/` 中的 JSON 驱动：

- `characters.json`
- `equipments_v2.json`
- `hexes.json`
- `hex_animations.json`
- `enemies.json`
- `bosses.json`
- `items.json`
- `encounters_test.json`（当前运行时实际加载的遭遇表）
- `quests.json`
- `statuses_v2.json`
- `traits_v2.json`

补充说明：

- 仓库中仍保留 `encounters.json`，但 `GameDataManager` 当前加载的是 `encounters_test.json`
- 数据字段编写规范另见 `Dicer数据规范表.md`

`GameDataManager` 在启动时统一加载并提供查询接口，同时也维护战斗测试模式使用的临时配置。

### 6.1 CSV 源数据与增量更新工作流

当前项目已经形成“`CsvData/` 作为编辑源，`GameData/` 与 `Localization/` 作为运行时产物”的数据工作流：

- 内容设计与日常改表优先修改 `CsvData/*.csv`
- 运行时读取的是 `GameData/*.json` 与 `Localization/*.json`
- `tools/csv_to_json.py` 用于把 CSV 转成运行时 JSON
- `tools/json_to_csv.py` 用于把当前 JSON 反向整理回 CSV

当前转换工具支持“全量转换”和“单表转换”两种模式：

- 全量转换：适合批量改动后统一生成全部运行时文件
- 单表转换：适合日常增量更新，例如只改 `traits.csv`、`encounters.csv` 或 `localization.csv`
- 单表模式下，工具仍会校验所需本地化 key，避免只改一张表后把显示文本依赖改坏

推荐日常流程：

1. 修改目标 CSV 或 `localization.csv`
2. 优先运行单文件转换，做最小范围更新
3. 需要验证产物但不想覆盖正式文件时，输出到 `Generated/`

示例命令：

```bash
python tools/csv_to_json.py --input-csv ./CsvData/traits.csv --project-root .
python tools/csv_to_json.py --input-csv ./CsvData/localization.csv --project-root .
python tools/csv_to_json.py --input-dir ./CsvData --project-root . --output-root ./Generated
```

编码约定：

- CSV 输入按 `UTF-8` / `UTF-8 BOM` 解码
- 生成的 `GameData/*.json` 与 `Localization/*.json` 统一按 `UTF-8` 编码写出
- 存档读写同样统一走 UTF-8 路径
- 文档与数据文件也建议统一使用 `UTF-8` 保存，避免中文内容或本地化文本出现乱码

## 当前内容规模（按现有数据文件统计）

- 角色：4
- 装备：7
- Hex：13
- 敌人：11
- Boss：2
- 物品：4
- 遭遇组：16
- 任务：5
- 状态：13
- Trait：15

## 关键脚本

- `Scripts/GameManager.gd`：run 生命周期、场景状态、存档
- `Scripts/LocalizationManager.gd`：翻译资源加载、界面重本地化
- `Scripts/database/RunData.gd`：局内数据
- `Scripts/database/LevelMapGenerator.gd`：地图生成与房间内容分配
- `Scripts/database/MapStateManager.gd`：地图探索状态持久化
- `Scripts/database/BattleManager.gd`：战斗状态机与结算核心
- `Scripts/scenes scripts/map_scene.gd`：地图交互与进房流程
- `Scripts/scenes scripts/battle_scene.gd`：战斗场景初始化与恢复
- `Scripts/scenes scripts/battle_dice_layout_overlay.gd`：战斗内骰面展开查看层
- `Scripts/scenes scripts/battle_tutorial_overlay.gd`：首次战斗教程翻页与关闭逻辑
- `Scripts/scenes scripts/shop_scene.gd`：商店购买 / 刷新 / 卖出
- `Scripts/scenes scripts/pantry_scene.gd`：Pantry 休息、锻造与 Spell Reforge 入口
- `Scripts/scenes scripts/hr_dispatch_scene.gd`：角色外派与奖励领取
- `Scripts/scenes scripts/hr_task_scene.gd`：任务领取、提交与奖励领取
- `Scripts/scenes scripts/custom_dice_scene.gd`：骰面构筑入口
- `Scripts/scenes scripts/settings_popup.gd`：设置界面、暂存状态与 Apply 流程
- `Scenes/battle_tutorial_overlay.tscn`：战斗教程覆盖层静态 UI
- `Scenes/battle_dice_layout_overlay.tscn`：战斗内骰面展开查看层静态 UI
- `Scripts/database/QuestManager.gd`：任务报价、进度推进、任务变体与奖励结算

## 已知问题

详见 `known_bugs.txt`，当前主要包括：

1. 战斗中返回主菜单后，消耗品使用状态可能保存不完整
2. 持有多个同名消耗品时，消耗顺序与 UI 显示可能不一致
3. 面对多个同名敌人时，`enemy_frien` 骰子的结果显示无法明确区分具体个体
4. 读取战斗存档后，敌方法术骰识别可能异常

## 下一阶段重点

1. 完善地图房间功能与场景衔接，减少临时实现
2. 扩充角色 / 装备 / Hex / 敌人 / 遭遇内容量
3. 修复已知稳定性问题（奖励、存档恢复、UI）
4. 继续推进平衡性与数值打磨
