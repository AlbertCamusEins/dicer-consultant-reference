# Dicer 顾问参考仓库说明

本仓库用于向项目顾问开放当前阶段所需的核心数值、规则、验证与说明材料。

开放范围：

- `CsvData/`
- `GameData/`
- `Scripts/database/`
- `Scripts/dev/`
- 根目录文档：
  - `README.md`
  - `Dicer数据规范表.md`
  - `自动化战斗测试系统配置说明.md`
  - `Dicer设计思路汇总.md`
  - `dicer_tutorial_storyboard_v2.md`

当前协作建议：

- 日常数值与内容编辑优先查看 `CsvData/`
- 运行时结果与实际生效数据对照查看 `GameData/`
- 战斗、状态、Trait、任务、地图等规则解释查看 `Scripts/database/`
- 自动化战斗测试与校验脚本查看 `Scripts/dev/`

建议优先阅读顺序：

1. `README.md`
2. `Dicer设计思路汇总.md`
3. `Dicer数据规范表.md`
4. `CsvData/README.md`
5. `自动化战斗测试系统配置说明.md`
6. `Scripts/database/GameDataManager.gd`
7. `Scripts/database/BattleManager.gd`
8. `Scripts/database/TraitManager.gd`

补充说明：

- `CsvData/` 是当前更适合作为策划协作入口的编辑源。
- `GameData/` 更适合用于查看运行时落地结果与联调。
- 本仓库未包含 `Assets/`、`Scenes/`、`Localization/`、`Generated/`、历史备份包等非本阶段必需内容。
