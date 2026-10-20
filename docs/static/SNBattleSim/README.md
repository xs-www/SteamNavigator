# `SNBattleSim`

> 独立 2D 舰队战斗规则试验台：验证固定船体、多武器、视野/战争迷雾、直射/炮击/侧弦齐射、货船护航与用户自定义武器。

## 文件索引

| 文件 | 职责 | 文档 |
| --- | --- | --- |
| `README.md` | 源文件：README.md | 本页 |
| `css/app.css` | 定义战斗模拟器的深海战术台视觉、三栏响应式布局、装配控件和战场状态样式。 | [查看](./css/app.css.md) |
| `greybox.html` | 源文件：greybox.html | 本页 |
| `index.html` | 战斗模拟器新版入口，承载 2D 战场、双舰队装配器、自定义武器目录与配置交换界面。 | [查看](./index.html.md) |
| `js/app.mjs` | 连接战斗画布、舰队装配器、自定义武器表单、配置导入导出与实时模拟控制。 | [查看](./js/app.mjs.md) |
| `js/camera.mjs` | 为无限 2D 战场计算能容纳全部在场舰船的跟随镜头，并提供世界坐标到画布坐标的转换。 | [查看](./js/camera.mjs.md) |
| `js/catalog.mjs` | 定义战斗模拟器固定的三种船体、内置武器与视野组件，并提供可编辑武器的规范化入口。 | [查看](./js/catalog.mjs.md) |
| `js/combat_hud.mjs` | 把战斗中单个武器挂载的冷却数据转换为舰船头顶装填条可直接使用的显示状态。 | [查看](./js/combat_hud.mjs.md) |
| `js/loadout.mjs` | 维护模拟器舰船装配数据、固定船体派生数值与舰队默认配置，并集中给出非法装配原因。 | [查看](./js/loadout.mjs.md) |
| `js/range_overlay.mjs` | 把所选舰的视野与逐武器射程/射界转换为可绘制的圆形或扇形覆盖层。 | [查看](./js/range_overlay.mjs.md) |
| `js/simulation.mjs` | 执行确定性的 2D 俯视角舰队战斗，处理视野接触、货船行为、多武器冷却、炮弹飞行与战斗终局。 | [查看](./js/simulation.mjs.md) |
| `js/tactics.mjs` | 定义可随舰船配置保存的声明式战术状态机，并把战场量测转换为侦索、接近、交战、脱离或规避状态。 | [查看](./js/tactics.mjs.md) |
| `tests/simulation.test.mjs` | 覆盖三种固定船体、多武器装配、货船派生值、视野发现、自定义武器校验和确定性战斗结果。 | [查看](./tests/simulation.test.mjs.md) |
| `tools/serve.mjs` | 以零依赖本地 HTTP 服务启动 SNBattleSim，避免浏览器 file 协议阻止 ES 模块加载。 | [查看](./tools/serve.mjs.md) |

## 模块契约

- 不接入 Godot 主流程或战役存档；装配配置与战斗运行时严格分离。
- 船体固定为 small / medium / large 三种；武器与视野组件数据驱动，新增武器不得修改模拟核心。
- 相同 seed、装配和 tick 序列产生相同结果；浏览器界面只通过 BattleSimulation 公共接口驱动战斗。战斗世界无边界，镜头按全部在场船只包围盒独立取景。
- greybox.html 保留为压力与冲撞专项旧灰盒；新版入口为 index.html，使用零依赖本地服务器加载 ES 模块。
