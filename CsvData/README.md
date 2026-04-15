# CSV Data Source

Run and overwrite the runtime JSON files:

```bash
python tools/csv_to_json.py --input-dir ./CsvData --project-root .
```

Run and convert a single table CSV file:

```bash
python tools/csv_to_json.py --input-csv ./CsvData/traits.csv --project-root .
python tools/csv_to_json.py --input-csv ./CsvData/hexes.csv --project-root .
python tools/csv_to_json.py --input-csv ./CsvData/enemies.csv --project-root .
python tools/csv_to_json.py --input-csv ./CsvData/encounters.csv --project-root .
python tools/csv_to_json.py --input-csv ./CsvData/statuses.csv --project-root .
python tools/csv_to_json.py --input-csv ./CsvData/characters.csv --project-root .
python tools/csv_to_json.py --input-csv ./CsvData/equipments.csv --project-root .
```

Run and convert only localization.csv:

```bash
python tools/csv_to_json.py --input-csv ./CsvData/localization.csv --project-root .
```

Run and write to a separate directory without touching the live files:

```bash
python tools/csv_to_json.py --input-dir ./CsvData --project-root . --output-root ./Generated
```

Run and write a single CSV conversion to a separate directory:

```bash
python tools/csv_to_json.py --input-csv ./CsvData/encounters.csv --project-root . --output-root ./Generated
```

This produces:

- `Generated/GameData/*.json`
- `Generated/Localization/*.json`

Reverse conversion, overwrite the source CSV files from runtime JSON:

```bash
python tools/json_to_csv.py --input-dir . --project-root .
```

Reverse conversion for a single table JSON file:

```bash
python tools/json_to_csv.py --input-json ./GameData/encounters_test.json --project-root .
```

Reverse conversion and write to a separate directory:

```bash
python tools/json_to_csv.py --input-dir . --project-root . --output-root ./GeneratedCsv
```

Reverse conversion for a single JSON file and write to a separate directory:

```bash
python tools/json_to_csv.py --input-json ./GameData/encounters_test.json --project-root . --output-root ./GeneratedCsv
```

Reverse conversion output:

- `CsvData/*.csv`

`json_to_csv.py` rules:

- `--input-dir` expects a directory containing `GameData/` and `Localization/`.
- If `--output-root` is omitted, the converter overwrites the live CSV files under `CsvData/`.
- If `--output-root` is provided, it generates `CsvData/` under that directory instead.
- `--input-json` supports one file at a time:
  - For a table JSON such as `GameData/encounters_test.json`, the converter generates that table CSV plus `CsvData/localization.csv`.
  - For `Localization/zh_CN.json` or `Localization/en.json`, the converter generates only `CsvData/localization.csv`.
  - Single-file mode still reads the sibling localization JSON files and validates any localization keys referenced by the selected table JSON.

Inputs:

- `characters.csv`
- `equipments.csv`
- `hexes.csv`
- `hex_animations.csv`
- `enemies.csv`
- `bosses.csv`
- `items.csv`
- `encounters.csv`
- `statuses.csv`
- `traits.csv`
- `quests.csv`
- `localization.csv`

Rules:

- Each row represents one entry and `id` is the primary key.
- Arrays and objects must be written as JSON strings inside the CSV cell.
- Empty cells mean "omit this field", except for fields the converter fills with defaults.
- `localization.csv` uses `key,zh_CN,en`.
- CSV input is decoded with `UTF-8` / `UTF-8 BOM` and generated JSON is encoded as `UTF-8`.
- If `--output-root` is omitted, the converter overwrites the runtime JSON files in `GameData/` and `Localization/`.
- If `--output-root` is provided, the same folder structure is generated under that directory instead.
- `--input-csv` supports one file at a time:
  - For a table CSV such as `traits.csv`, the converter generates that table's target JSON plus `Localization/zh_CN.json` and `Localization/en.json`.
  - For `localization.csv`, the converter generates only the localization JSON files.
  - Table single-file mode still reads `localization.csv` from the same directory and validates the localization keys required by the selected table.

## Target Selectors

`hexes.csv` and `traits.csv` both support explicit character target selectors through `target_data[].condition.selector`.

Row concept:

- Player side: rightmost is front row, leftmost is back row.
- Enemy side: leftmost is front row, rightmost is back row.
- If a side has only one unit, that unit is both front row and back row.

Supported selectors:

- `front_ally`
- `front_enemy`
- `back_ally`
- `back_enemy`
- `lowest_health_ally`
- `lowest_health_enemy`
- `highest_health_ally`
- `highest_health_enemy`
- `status_ally`
- `status_enemy`

Rules:

- `lowest_health_*` / `highest_health_*` compare runtime `current_health`.
- Ties resolve to all tied alive units.
- Dead units are excluded from rank and status selectors.
- `status_ally` / `status_enemy` require `condition.status_id`.
- Existing `has_status_id` / `lacks_status_id` can still be used as extra filters after selector resolution.
- Do not use `condition.dice_reference.face = 1` to represent a back-row target anymore. Use `selector: "back_ally"` or `selector: "back_enemy"` instead.

Examples:

Back-row enemy:

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

Lowest-health enemy:

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

Highest-health ally:

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

Enemy units with a status:

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

## Hex Status Apply

For `hexes.csv`, when a spell applies a status, prefer `status_id` instead of writing a full `status_info` payload by hand.

Recommended default form:

```json
[
  {
    "type": 1,
    "status_id": "st009",
    "target_index": [0]
  }
]
```

This uses the status defaults from `statuses.csv`, including:

- `duration`
- `stack_count`
- `max_stacks`
- `effects`

If a specific hex should override only this application's duration or stack count, keep `status_id` and add a minimal `status_info` override:

```json
[
  {
    "type": 1,
    "status_id": "st009",
    "status_info": {
      "duration": 2,
      "stack_count": 3
    },
    "target_index": [0]
  }
]
```

Guidelines:

- Change a status's global default behavior in `statuses.csv`.
- Change only one hex's application count or duration in that hex's `effect_data`.
- Avoid hand-writing full `status_info` objects unless you intentionally want to override multiple status fields.
- Prefer integer enum values in JSON cells, for example `0` / `1`, not `0.0` / `1.0`.
- Runtime protection: a status applied during the current roll/Swift resolution will not immediately tick or lose duration in that same `global_tick`. Do not add an extra duration in CSV just to compensate for the current turn's tick order.
- Countdown protection: if a newly applied status changes countdown on a target that has already entered this sequence's action queue, that countdown delta is deferred until the target resets countdown for its next action. This keeps the current action unchanged, and the next action countdown becomes `base_countdown + delta`.
- For `slow` / `speedup` with `duration_tick_phase: "after_action"`, if they are applied in the same sequence as the target's already-queued action, they also do not decay in that same action's `after_action` step.

## Hex Runtime Stat Reads

For `hexes.csv`, an effect can also scale from a read target's runtime character/enemy stat.

Fields:

- `read_char_stat`
- `read_value_per_point`

Supported `read_char_stat` values:

- `current_health`
- `max_health`
- `shield`
- `countdown`
- `base_countdown`

Behavior:

- `read_target_index` still defines which targets are read from.
- `target_index` still defines which targets receive the effect.
- If multiple read targets are listed, their stat values are summed first.
- If a read target resolves to a dice or dice face instead of a character/enemy, it contributes `0`.
- `read_char_stat` can be combined with `read_status_id`; both bonuses are added together.

Formulas:

- `HEALTH_CHANGE`: `value + total_status_stacks * read_value_per_stack + total_stat_value * read_value_per_point`
- `SHIELD_CHANGE`: `value + total_status_stacks * read_value_per_stack + total_stat_value * read_value_per_point`
- `STATUS_APPLY`: `stack_count + total_status_stacks * read_value_per_stack + total_stat_value * read_value_per_point`

Examples:

```json
[
  {
    "type": 0,
    "value": -4,
    "read_target_index": [1],
    "read_char_stat": "current_health",
    "read_value_per_point": 1,
    "target_index": [0]
  }
]
```

```json
[
  {
    "type": 3,
    "value": 0,
    "read_target_index": [1],
    "read_char_stat": "shield",
    "read_value_per_point": -1,
    "target_index": [0]
  }
]
```

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

## Status Extend

For `hexes.csv` and `traits.csv`, when an effect should only extend an existing status without adding stacks, prefer the explicit `status_extend` action.

Recommended form:

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

Default behavior:

- Only affects targets that already have the status.
- Does not create a new status if the target currently lacks it.
- Adds to the current `duration` instead of refreshing stacks.
- Does not trigger status apply hooks such as `status_applied_before` / `status_applied_after`.

Do not use the following patterns to express "extend only":

- `status_apply` with `stack_count: 0`
- `status_apply` with `duration: 0`
- hand-written `status_info` that creates a `0`-stack or `0`-duration status instance

## Retreat

For `hexes.csv` and `traits.csv`, use `retreat` when an effect should move a character backward within its current team order without changing any dice state.

Hex form:

```json
[
  {
    "type": 2,
    "special_id": "retreat",
    "steps": 2,
    "target_index": [0]
  }
]
```

Trait action form:

```json
[
  {
    "event": "ally_spell_resolved_after",
    "actions": [
      {
        "type": "retreat",
        "steps": 1,
        "target_index": [0]
      }
    ]
  }
]
```

Rules:

- `steps` must be a positive integer.
- Player side retreats toward the left/back; enemy side retreats toward the right/back.
- If `a + x` exceeds the team size, the unit stops at the back of its team.
- If the target is already at the back, the effect is a no-op.
- Only character targets are affected; dice and dice-face targets are ignored.
- Multi-target effects resolve one target at a time in the current target order.
- `retreat` does not change face-up results, does not reroll dice, and does not modify dice, face, or character statuses.

## Advance

For `hexes.csv` and `traits.csv`, use `advance` when an effect should move a character forward within its current team order without changing any dice state.

Hex form:

```json
[
  {
    "type": 2,
    "special_id": "advance",
    "steps": 2,
    "target_index": [0]
  }
]
```

Trait action form:

```json
[
  {
    "event": "ally_spell_resolved_after",
    "actions": [
      {
        "type": "advance",
        "steps": 1,
        "target_index": [0]
      }
    ]
  }
]
```

Rules:

- `steps` must be a positive integer.
- Player side advances toward the right/front; enemy side advances toward the left/front.
- If movement would pass the front of the team, the unit stops at the front.
- If the target is already at the front, the effect is a no-op.
- Only character targets are affected; dice and dice-face targets are ignored.
- Multi-target effects resolve one target at a time in the current target order.
- `advance` does not change face-up results, does not reroll dice, and does not modify dice, face, or character statuses.

## Update Guide

Use this table to decide whether changing a CSV also requires updating `localization.csv`.

| CSV file | Only update this CSV | Also update `localization.csv` |
| --- | --- | --- |
| `characters.csv` | `texture_path`, `base_health`, `experience`, `countdown`, `traits`, `prime_hex_id`, `peak_hex_id`, `soul_hex_id`, `slot_limit` | Add a character, change the displayed character name, or manually change `display_name_key` |
| `equipments.csv` | `texture_path`, `slot_limit`, `attack_bonus`, `defense_bonus`, `traits` | Add equipment, change the displayed equipment name, change `trait_descs`, or manually change `display_name_key` / `trait_desc_keys` |
| `hexes.csv` | `texture_path`, `slot_limit`, `cast_condition`, `target_data`, `effect_data`, `traits`, `enemy_owned` | Add a hex, change the displayed hex name, change the hex description, or manually change `display_name_key` / `description_key` |
| `enemies.csv` | `texture_path`, `base_health`, `traits`, `weight`, `equipment`, `hexes`, `countdown`, `health_per_occupied_face` | Add an enemy, change the displayed enemy name, or manually change `display_name_key` |
| `bosses.csv` | `texture_path`, `base_health`, `traits`, `weight` | Add a boss, change the displayed boss name, or manually change `display_name_key` |
| `items.csv` | `type`, `texture_path`, `price`, `effect_id`, `effect_params`, `max_uses`, `charge_type`, `current_charge`, `max_charge` | Add an item, change the displayed item name, change the item description, or manually change `display_name_key` / `description_key` |
| `encounters.csv` | All fields | Never required |
| `statuses.csv` | `texture_path`, `status_type`, `category`, `status_target`, `duration`, `stack_count`, `max_stacks`, `hover_description`, `effects` | Add a status, change the displayed status name, change the status description or hover description, or manually change `display_name_key` / `description_key` |
| `traits.csv` | `source_kind`, `template_type`, `listener_scope`, `target_data`, `triggers`, `runtime_defaults`, `timed_escape` | Add a trait, change the displayed trait name, change the trait description, or manually change `display_name_key` / `description_key` |
| `quests.csv` | `category`, `prerequisites`, `requirements`, `variants`, `time_limit`, `rewards`, `failure` | Add a quest, change the displayed quest title, or manually change `title_key` |
| `localization.csv` | Translation text itself | This file is the translation source |

Quick rule:

- Change gameplay logic or data shape: update the table CSV.
- Change displayed text: update `localization.csv`.
- Add new content with visible text: update both the table CSV and `localization.csv`.
