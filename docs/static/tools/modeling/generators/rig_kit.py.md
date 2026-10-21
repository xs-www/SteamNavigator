# `tools/modeling/generators/rig_kit.py`

> 作用：Steam Navigator 船体帆索部件库 `rig_kit`（纯 Python，不 import bpy）——

- 类型：项目配置/数据文件

把原先焊死在 3 艘船生成器里的桅杆 / 横桁 / 斜桁 / 帆杠 / 艏斜桁 / 帆面 / 索具
收敛成一套**参数化部件函数**，船型生成器只保留「布局」（桅位、后倾、帆角、锚点），
几何全部由本库组合；独立 `SN_Rig_*` 套件资产也从同一份函数导出，不维护第二套几何。

## 分层
- `RigBuilder`：Part 适配器。包住任意船体 `Part` 与它的基本体模块（`prims`），
  统一 `add(vf, material)` 与材质键（`wood / wood_dark / deck / metal / brass /
  canvas / canvas_shade / iron`）。SF/PF 的 Part 是 `add(vf, mat)`；铁甲舰是
  `add(verts, faces, mat)`（`legacy=True`），基本体各自保留，保证重构逐位一致。
- 通用积木：`rope / ropes / spar / spar_jaws / block`。
- 船型部件（sail 帆船 / steam 蒸汽船 / ironclad 铁甲舰）：`schooner_mast`,
  `schooner_gaff_sail`, `schooner_headsails`, `schooner_standing_rigging`,
  `schooner_running_rigging`, `steamer_mast`, `steamer_yard`, `steamer_bowsprit`,
  `steamer_rigging`, `ironclad_masts`, `ironclad_rigging`。

## 几何不变量
- 本库函数只接收「数值 + 材质键 + 布局字典」，不使用某艘船的模块级常量；
  帆船 / 蒸汽船 / 铁甲舰三型各自的原构造顺序被原样保留，调用顺序 = 面顺序，
  因此 3 艘船重构后逐对象顶点 / 面 digest 必须与基线完全一致
  （见 `rig_kit_baseline.py`）。
- 单位米、+X 船首、+Z 向上；帆面是单层曲面（双面材质），其余为闭合壳体。

用法：
```python
import rig_kit, ship_parts.core as core
part = core.Part()
b = rig_kit.builder(part, core)
rig_kit.schooner_mast(b, {"lower": 10.8, "top": 17.0, "gallant": 21.3, ...})
```

模块索引：[tools](../../README.md)
