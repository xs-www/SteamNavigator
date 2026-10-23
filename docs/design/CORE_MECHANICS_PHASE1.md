# 核心机制补全 Phase 1：部件状态、舰载武器与维修回归

> 状态：Implemented（2026-10-23）  
> 策略：L1 纵向补丁；保持现有 Content / Save / State Schema 2.0，不新增内容类型，不改现有内容 ID。  
> 范围：玩家旗舰的模块性能衰减、船厂武器购买与装配、损伤—维修闭环回归。舰队多船、弹药、战术瞄准、单件维修留到后续阶段。

## 1. 背景与目标

Schema 2.0 已把 `modules`、`hulls`、`weapons` 与战斗内容提升为 active，运行时也已经具备：

- `ship.module_instances` 的稳定实例 id 与 `condition`；
- `ShipOps.stats()`、航行预览/结算与维修报价；
- 船体 `weapon_sockets`、`ship.weapon_loadout`、视觉装配和自动战斗武器解析；
- 船厂模块购买/仓库/装配流程。

当前缺口是这些能力尚未形成同一条玩家闭环：模块 condition 只计入维修费，不改变性能；武器会由战斗层按 socket class 自动补默认值，玩家无法在船厂购买或装配；损伤、性能下降、付费维修、性能恢复没有端到端回归证据。

Phase 1 的目标是关闭这三处缺口，同时继续遵守“内容数值来自 Core JSON、命令事务化、查询只读、FrameworkApi 注册、旧存档惰性补齐”的项目契约。

## 2. 决策

### 2.1 Module condition 对性能的统一规则

`condition` 先夹取到 `[0, 1]`。模块的重量不随状态变化；能力贡献按状态衰减：

| 能力 | 规则 |
| --- | --- |
| 锅炉速度 | `base_speed × speed_mul × condition`；0 状态只保留现有全船最低速度保护 |
| 锅炉煤耗/水耗 | 保持内容定义值；损坏不会凭空减少完成同一路程所需的运行成本 |
| 导航/安全乘数 | 在中性值 1 与定义值之间按 condition 线性插值 |
| 导航/安全加值 | 定义加值乘 condition |
| 布尔能力 | 仅 condition > 0 时生效 |
| `modifiers` add | `value × condition` |
| `modifiers` mul | `1 + (value - 1) × condition` |
| 货舱容量 | 每个货舱 `capacity × condition` 后求和 |
| 客舱容量 | `floor(passenger_capacity × condition)` |

这样 1.0 与现状完全一致、0.0 明确失效、中间状态连续变化。`cargo` / `passenger` 已超出受损容量时不删除货物或旅客，但新装载、接单和配置校验必须看到降低后的容量。

### 2.2 武器所有权与装配

武器继续是独立的 `weapons` 内容类型，不伪装成 `modules`。持久状态使用已有投影并扩展港口仓库：

```text
ship.weapon_loadout[] = { socket, weapon_id }
data.warehouses[port_id].weapons = { weapon_id: qty }
```

新增公共命令：

- `ship.install_weapon {socket, weapon_id, source}`，`source ∈ {purchase, warehouse}`；
- `ship.uninstall_weapon {socket}`，卸下后进入当前港仓库。

共同规则：必须有对局、停靠在有 shipyard 的港口；socket 必须属于当前 hull；weapon 的 `weapon_class` / `mount_class` 必须匹配 socket class；购买扣 `purchase_price` 并记支出；武器重量计入全船重量；替换时旧武器进入当前港仓库；所有失败由命令事务回滚。

更换 hull 后按 socket 名与 class 保留兼容装配，其余武器进入当前港仓库，避免资产丢失。旧存档缺 `weapon_loadout` / 仓库 `weapons` 时按空集合读取，不做版本迁移。

### 2.3 战斗不再赠送默认武器

玩家武器以 `ship.weapon_loadout` 为唯一运行时真源：空 socket 就是未装配，不再按 class 自动选择注册表中的第一件武器。敌舰仍按 `enemy_archetypes.weapon_sockets` 的内容定义解析默认武器，因为那是敌人原型的一部分。

`shipyard.view` 增加 `weapon_sockets`、`weapon_candidates` 与 `warehouse.weapons`；船厂界面增加“武器”分类，展示槽位、已装武器、购买/安装/卸下动作。视觉层继续消费同一份 `weapon_loadout`，无需第二套状态。

## 3. 事务、兼容与错误码

新增稳定错误码：`missing_socket`、`unknown_socket`、`unknown_weapon`、`weapon_class_mismatch`、`insufficient_money`、`weight_limit`、`warehouse_empty`。既有 `no_run`、`not_at_port`、`no_shipyard` 复用。

- 查询不得通过“补齐仓库键”修改真实状态；缺键直接投影为空。
- 命令成功后才写 `weapon_loadout`、仓库、金币与统计。
- 更换 hull 的武器回仓与 hull/module 替换处于同一个 `ship.install_module` 事务。
- Save / State Schema 版本保持 `2.0`；新增字段均为可选惰性字段。

## 4. 验收矩阵

### 4.1 部件状态

- 满状态派生值与既有基线一致。
- 锅炉 50% / 0% 时速度按规则下降，维修后恢复。
- 导航、安全、货舱、客舱与通用 modifiers 分别覆盖加法、乘法、布尔和容量衰减。
- 损坏不改变模块重量；旧存档缺实例表仍按 100% 读取。

### 4.2 武器购买与装配

- FrameworkApi 注册两个新命令，船厂查询给出 socket、候选、价格、重量与 blocker。
- 购买成功扣款、记支出、写 loadout，并由 combat / visual plan 读取同一武器。
- class 不匹配、资金不足、超重、非船厂港口均失败且状态哈希不变。
- 替换/卸下进入当前港仓库；从仓库重装不重复扣款。
- hull 更换保留兼容 socket，回收不兼容武器。
- 保存/加载后 loadout 与仓库武器数量不变。

### 4.3 损伤与维修回归

至少一条端到端用例覆盖：事件 `damage_module` → `ShipOps.stats` / 航行视图性能下降 → `supply.view` 报价含部件损耗 → `supply.repair` 扣款并恢复船体与模块 → 性能回到损伤前；另覆盖资金不足时原子回滚。

## 5. 实施顺序与回滚

1. 补纯规则：condition 缩放、WeaponOps、重量与 hull 重配协调。
2. 接命令注册与船厂 ViewModel，再接 UI。
3. 调整战斗玩家武器解析，更新既有测试的显式 loadout。
4. 补 focused tests，再跑 schema / 静态文档 / Godot 全量门禁。
5. 更新 `@static-doc`、生成 `docs/static/`，同步 PROJECT_STATUS / KNOWN_LIMITS / todo。

回滚按文件级补丁即可；没有内容 ID、Schema 版本或不可逆存档迁移。若 UI 切片出现风险，领域命令与查询仍可独立验收，但 Phase 1 不以“仅后端可用”作为最终完成。
