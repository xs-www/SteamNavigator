# `tools/modeling/generators/sn_paddle_steamer_generator.py`

> 作用：`SN_Paddle_Steamer`（澳大利亚内河明轮蒸汽船）的**参数化真源生成器 + Blender 侧装配/自检**：

- 类型：项目配置/数据文件

纯 Python 由顶部参数表生成船体、舷墙、明轮、舱室、雨棚、烟囱、旗帜与属具的几何，Blender 侧只做
集合 / 材质 / 空物体层级 / 父级 / 文字铭牌。

## 契约与约束
- 船体尺寸 24.4×8.7×10.5 m（dryrun 容差 0.8）、水线轴心（z=0，龙骨底 −1.32、烟囱顶 9.15）、
  `SN_PS_Root` 单根节点（工作台 (45,0,0)）、既有 `SN_PS_*` 命名/父子层级不变；
  tri 预算 ≤12 000（批次 C 对外上限沿用既有实测 11 764，改动不得超）；本船材质槽 9（批次 C +1）：
  SN_White / SN_Iron_Hull / SN_Iron_Red / SN_Wood_Deck / SN_Metal / SN_Brass /
  SN_Flag_Blue / SN_Flag_White / SN_PS_UpperWhite（仅本船使用的上层建筑二级白）。
  其中 SN_White 仅本船使用；其余共享材质数值一律保持原值（其它船/建筑/道具零变化）。
- 不变量：明轮 8 个 45° 旋转角与轮罩/船体/明轮台零穿插、澳洲旗（蓝底红白）、ENTERPRISE 铭牌
  文字/位置、上层建筑布局与船体结构不变；只改材质明度、压条厚度与后部雨棚构造。
- 几何全部来自 `build_all_geometry()`；Blender 侧只在 `build_all()` 建集合/空物体/文字，
  不手工摆点；不导出 GLB、不保存 .blend（由 Lead 在验收后处理）。

## 重点逻辑
### 参数区（COLORS / REUSE_COLORS / STATIONS / PROFILE / CANOPY / BULWARK…）
- 船型、开窗、雨棚、明轮、旗帜全部由顶部常量驱动；批次 C 精修只动：
  ① `CANOPY` + `build_canopy()`：厚平板 → 4 条纵向分缝薄板（缝宽 0.11）+ 2 道横肋 + 3 对细柱 +
     微拱；后段 3.0 m（原长 28%）完全露空，露出艉部游步甲板与栏杆；
  ② 明度层次：仅提亮本船独占的 `SN_White`（船身 0.870/0.850/0.800）；新增本船局部材质
     `SN_PS_UpperWhite`（0.680/0.672/0.655）作上层建筑/舱室二级白（`MAT_WHITE_2`，+1 槽）；
     甲板沿用原共享 `SN_Wood_Deck`，形成 白船身 0.870 > 舱室 0.680 > 甲板 0.300 的层级；
  ③ `CAP_T` / 舷墙压条内外偏移 / 水线带与舷缘带厚度 / 舱室红腰带 / 雨棚红封檐适度加粗。
### `build_all_geometry()` / `build_all()` / `report()`
- `build_all_geometry()` 返回 {对象名: (Part, 父级键)}，纯 Python 可 dryrun；
- `build_all()` 幂等重建集合 + 空物体层级 + 文字铭牌；`report()` 只读统计 tri/bbox/材质。
### `dryrun_paddle_steamer.py` / `verify_paddle_steamer_scene.py`
- 纯 Python 拦几何缺陷（tri/bbox/z 范围/边界边/退化/材质/命名/父级/镜像）；
- Blender 内只读验收覆盖层级、明轮 8 角度穿插、连通岛浮空、其它对象回归基线。

模块索引：[tools](../../README.md)
