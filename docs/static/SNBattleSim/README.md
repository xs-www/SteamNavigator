# `SNBattleSim`

> 独立 2D 舰队战斗规则试验台：验证固定船体、多武器、视野/战争迷雾、直射/炮击/侧弦齐射、货船护航与用户自定义武器。

## 文件索引

| 文件 | 职责 | 文档 |
| --- | --- | --- |
| `README.md` | 源文件：README.md | 本页 |
| `css/app.css` | 定义战斗模拟器的深海战术台视觉、三栏布局、舰体装配弹窗、FSM 工作台和战场状态样式。 | [查看](./css/app.css.md) |
| `docs/FSM_MOD_CONTRACT.md` | 源文件：FSM_MOD_CONTRACT.md | 本页 |
| `greybox.html` | 源文件：greybox.html | 本页 |
| `index.html` | 战斗模拟器新版入口，承载 2D 战场、Mod 蓝图舰体装配、独立 FSM 工作台与工程持久化入口。 | [查看](./index.html.md) |
| `js/app.mjs` | 连接战斗画布、Mod 蓝图舰体装配、双层工程持久化、配置交换与实时模拟控制。 | [查看](./js/app.mjs.md) |
| `js/camera.mjs` | 为无限 2D 战场计算能容纳全部在场舰船的跟随镜头，并提供世界坐标到画布坐标的转换。 | [查看](./js/camera.mjs.md) |
| `js/catalog.mjs` | 定义战斗模拟器固定的三种船体、内置武器与视野组件，并提供可编辑武器的规范化入口。 | [查看](./js/catalog.mjs.md) |
| `js/combat_hud.mjs` | 把战斗中单个武器挂载的冷却数据转换为舰船头顶装填条可直接使用的显示状态。 | [查看](./js/combat_hud.mjs.md) |
| `js/fsm_editor.mjs` | 渲染独立 FSM 工作台，支持状态拖放、端口拉线、空白处快速建状态、Delete 删除及按选中状态过滤的聚合转移编辑。 | [查看](./js/fsm_editor.mjs.md) |
| `js/loadout.mjs` | 维护模拟器舰船装配数据、固定船体派生数值与舰队默认配置，并集中给出非法装配原因。 | [查看](./js/loadout.mjs.md) |
| `js/mod_format.mjs` | 定义模拟器扩展模组的数据类型，解析游戏约定 definitions 外壳，并生成可写入 mods/ 的标准模组文件集合。 | [查看](./js/mod_format.mjs.md) |
| `js/range_overlay.mjs` | 把所选舰的视野与逐武器射程/射界转换为可绘制的圆形或扇形覆盖层。 | [查看](./js/range_overlay.mjs.md) |
| `js/simulation.mjs` | 执行确定性的 2D 俯视角舰队战斗，处理视野接触、货船行为、多武器冷却、炮弹飞行与战斗终局。 | [查看](./js/simulation.mjs.md) |
| `js/tactic_library.mjs` | 维护默认与自定义状态机库，迁移旧版随舰战术，并解析每艘船唯一挂载的状态机。 | [查看](./js/tactic_library.mjs.md) |
| `js/tactics.mjs` | 定义开发者模式 FSM 的状态动作、模块化条件、AND/OR 聚合转移和确定性状态转换。 | [查看](./js/tactics.mjs.md) |
| `mods/README.md` | 源文件：README.md | 本页 |
| `start.bat` | Windows 双击启动 SNBattleSim；缺少 Node.js 时先安装最新 LTS，再启动本地服务并打开浏览器。 | [查看](./start.bat.md) |
| `tests/simulation.test.mjs` | 覆盖装配、十状态 FSM、状态机库挂载、模组目录/ZIP 往返、视野、武器射界和确定性战斗结果。 | [查看](./tests/simulation.test.mjs.md) |
| `tools/cli.mjs` | 提供无浏览器的模组校验、状态机检查、确定性战斗快跑与示例模组导出，供 Agent 快速调试。 | [查看](./tools/cli.mjs.md) |
| `tools/mod_io.mjs` | 为本地服务和 CLI 安全读取散装或 ZIP 形式的 SNBattleSim 模组，并导出游戏可识别的模组包。 | [查看](./tools/mod_io.mjs.md) |
| `tools/serve.mjs` | 以零依赖本地 HTTP 服务启动 SNBattleSim，避免浏览器 file 协议阻止 ES 模块加载。 | [查看](./tools/serve.mjs.md) |
| `tools/workspace_io.mjs` | 在 SNBattleSim/user_data 中原子读写模拟器工程，作为浏览器 localStorage 之外的明确持久化副本。 | [查看](./tools/workspace_io.mjs.md) |

## 模块契约

- 不接入 Godot 主流程或战役存档；装配配置与战斗运行时严格分离。
- 船体固定为 small / medium / large 三种；武器与视野组件数据驱动，新增武器不得修改模拟核心。
- 相同 seed、装配和 tick 序列产生相同结果；浏览器界面只通过 BattleSimulation 公共接口驱动战斗。战斗世界无边界，镜头按全部在场船只包围盒独立取景。
- greybox.html 保留为压力与冲撞专项旧灰盒；新版入口为 index.html，使用零依赖本地服务器加载 ES 模块。
