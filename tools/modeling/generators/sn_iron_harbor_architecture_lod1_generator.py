# -*- coding: utf-8 -*-
# @static-doc
# 作用：铁港建筑套件批次 A（LOD1）的**参数化真源生成器 + Blender 侧装配/自检/渲染 harness**：
# 为 5 栋 LOD0 建筑各生成一个简化版 `SN_HT_<Name>_LOD1` 单 mesh 对象，并负责 LOD0 可复现重建、
# 逐栋门禁自检、全场景 digest 回归与 EEVEE 预览渲染。
#
# - 关键依赖：`sn_iron_harbor_architecture_kit_generator.py`（Warehouse_Long 真源）、
#   `sn_iron_harbor_warehouse_short_generator.py` / `sn_iron_harbor_harbor_office_generator.py` /
#   `sn_iron_harbor_cargo_shed_generator.py` / `sn_iron_harbor_tavern_generator.py`（其余 4 栋真源）、
#   `sn_iron_harbor_materials.py`（共享 6 材质 + trim sheet cell + 盒投影 UV）、
#   `sn_iron_harbor_kit_batch2.py`（LOD0 cell 方案的唯一来源）、
#   `dryrun_lod1_batch_a.py` / `dryrun_props.py`（纯 Python 干跑）。
#
# ## 契约与约束
# - **参数化真源唯一**：本文件不复制 LOD0 尺寸/墙线/开口表，而用 `lod0(asset)` importlib 加载
#   5 个 LOD0 生成器，读取其 `TARGET_SIZE / HALF_* / WALL_* / EAVE_Z / RIDGE* / ROOF* /
#   *_OPENINGS` 常量并复用其闭合实体工具（`Part / panel / box / tb / prism_* / lprism_u /
#   lvchamfer_box / beam / rod / _stone_plinth / _gable / _cornice / _roof_section /
#   _shed_roof_section / _plinth / _chimney / _arch_lune / larc_band / revolved / ring_at`）。
#   `_check_sources()` 在 dry-run 与 Blender 构建时校验目标尺寸与 LOD0 真源一致，禁止两边漂移。
# - **LOD1 预算是硬门禁**：≤ 对应 LOD0 实测的 35%，逐栋上限为 Warehouse_Long 2 602 /
#   Warehouse_Short 1 325 / Harbor_Office 3 617 / Cargo_Shed 1 174 / Tavern 1 790（合计 10 508）。
# - **LOD1 必须保留**（需求 §5.1）：外轮廓、屋顶、大型开口（装卸门凹口/拱形入口/开敞柱廊/门廊）、
#   主要烟囱与钟楼、檐口、阳台大轮廓、石基、单坡侧棚、偏置通风管、山墙吊梁、工作台大体量、
#   悬挂招牌；允许删除小窗棂/窗框/滑轮细件/立柱/雨水斗/次要管线，栏杆可改带厚度连续实体。
#   窗体仍用 `panel()` 真凹口（不靠贴图），不得只靠贴图撑轮廓。
# - **LOD1 与 LOD0 一致性**：世界包围盒目标尺寸 ±0.02 m、轴心底面中心（zmin=0、x/y 包围盒
#   中心 = 0），材质槽 ≤6 且全为 `SN_Town_*`；每个实体闭合（边界边/非流形边/孤立点/退化面全 0），
#   UV 盒投影逐 loop 可复算、6 张 512² 贴图全部绑定。
# - **只动本批对象**：`build_all()` 只删除/重建集合 `SN_Iron_Harbor_Architecture` 内精确命名的
#   10 个 `SN_HT_*_LOD0/_LOD1`；不保存 `.blend`、不导出 GLB、不改 manifest/framework/tests/
#   docs/static/todo.md/ASSET_MAP.md（Lead 验收后处理）。
# - **共享材质坑**：6 个 `SN_Town_*` 是全局 datablock，`apply_to_object(cells=...)` 每次重建
#   node tree，因此测量/渲染前必须"轮到谁就重写一次"（`_apply_cells`）。
# - **命名/摆放**：对象 `SN_HT_<Name>_LOD0/_LOD1`；LOD0 位置与 batch2/M1 一致（y=110/150 两排），
#   LOD1 统一放工作台 y=175 一排，仅工作台摆放，不动 PortStage 槽位。
#
# ## 重点逻辑
# ### `lod0(asset)` / `_check_sources()`
# - 懒加载 + 缓存 LOD0 模块；目标尺寸以 LOD0 `TARGET_SIZE` 为准，避免 LOD1 抄数字。
# ### `build_<name>_lod1()`（5 个）
# - 每栋 = 读 LOD0 真源参数 → 用 LOD0 自己的闭合实体重建简化外壳：石基 + 带真凹口的墙板 +
#   简化屋顶/檐口 + 只保留轮廓级附件。删掉的都是门框窗棂/雨水管/小五金等不可读小件。
# ### `build_all()`
# - 先快照重建前 5 栋 LOD0 的几何签名（可复现证据）与全场景 digest（排除 10 个目标对象），
#   再重建 5 栋 LOD0（验证生成器可复现、让 Warehouse_Short 屋面修复生效）、新建 5 栋 LOD1，
#   每栋按 batch2 cells 写共享材质/UV。
# ### `report()`
# - 逐栋 16 项检查 + LOD0↔LOD1 bbox/轴心对比 + LOD0 可复现对比 + 檐口修复前后实测
#   （旧源码从 `.design/buildings/iron_harbor/a1/warehouse_short_pre_fix.py` 真实重建测量）+
#   全场景 digest/集合回归；结果落盘 `.design/buildings/iron_harbor/a1/lod1_report.json`。
# ### `render_previews(assets=None)`
# - EEVEE 1280×800：每栋 3 张 LOD1 + 3 张 LOD0/LOD1 同机位对比（LOD1 临时平移、渲染后还原）；
#   临时相机/3 盏太阳/世界背景/引擎/分辨率/隐藏状态全部在 `finally` 还原，临时对象删除。
# ### `measure_part()` / `tri_count()` / `edge_stats()` / `degenerate_faces()`
# - 纯 Python 度量（无 bpy），供 dryrun 在进 Blender 前拦住 tri 超限/开口/边界边/退化面。
# @end-static-doc

import importlib.util
import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
COLLECTION = "SN_Iron_Harbor_Architecture"
PREFIX = "SN_HT_"
MAX_MATERIAL_SLOTS = 6
OUT_DIR = os.path.join(REPO_ROOT, ".design", "buildings", "iron_harbor", "a1")
SCREENSHOT_DIR = os.path.join(REPO_ROOT, "docs", "design", "screenshots",
                              "iron_harbor_architecture")

# --------------------------------------------------------------------------- #
# 5 栋：LOD0 生成器文件 / 目标尺寸 / LOD0 预算 / LOD1 上限 / 工作台摆放
#   - LOD0 位置与 `sn_iron_harbor_kit_batch2.BUILDINGS` 一致；Warehouse_Long 用
#     `sn_iron_harbor_architecture_kit_generator.LOCATION`（M1 起就在 y=110 这一排）。
#   - LOD1 统一放在 y=175 这一排（工作台空行；与 LOD0 行保持 25 m 间距）。
#   - cells：与 batch2.BUILDINGS 完全一致；Warehouse_Long 用共享材质模块默认 cells。
# --------------------------------------------------------------------------- #
LOD1_SPECS = [
    {
        "asset": "SN_HT_Warehouse_Long",
        "module": "sn_iron_harbor_architecture_kit_generator.py",
        "builder": "build_warehouse_long_lod1",
        "lod0_location": (-48.0, 110.0, 0.0),
        "location": (-48.0, 175.0, 0.0),
        "target": (20.0, 9.0, 11.0),
        "lod0_cap": 8000,
        "cap": 2602,
        "cells": None,          # 共享材质模块默认 cells（= Warehouse_Long LOD0 的 M1 取值）
    },
    {
        "asset": "SN_HT_Warehouse_Short",
        "module": "sn_iron_harbor_warehouse_short_generator.py",
        "builder": "build_warehouse_short_lod1",
        "lod0_location": (-30.0, 150.0, 0.0),
        "location": (-30.0, 175.0, 0.0),
        "target": (11.0, 9.0, 9.5),
        "lod0_cap": 5000,
        "cap": 1325,
        "cells": {
            "SN_Town_Brick": "brick_wall", "SN_Town_Plaster": "plaster_light",
            "SN_Town_Wood": "wood_plank", "SN_Town_Iron": "iron_rust",
            "SN_Town_Stone": "stone_base", "SN_Town_Glass": "glass_dark",
        },
    },
    {
        "asset": "SN_HT_Harbor_Office",
        "module": "sn_iron_harbor_harbor_office_generator.py",
        "builder": "build_harbor_office_lod1",
        "lod0_location": (-10.0, 150.0, 0.0),
        "location": (-10.0, 175.0, 0.0),
        "target": (9.0, 8.0, 14.0),
        "lod0_cap": 14000,
        "cap": 3617,
        "cells": {
            "SN_Town_Brick": "brick_wall", "SN_Town_Plaster": "plaster_light",
            "SN_Town_Wood": "wood_plank_weathered", "SN_Town_Iron": "iron_dark",
            "SN_Town_Stone": "stone_base", "SN_Town_Glass": "glass_reflect",
        },
    },
    {
        "asset": "SN_HT_Cargo_Shed",
        "module": "sn_iron_harbor_cargo_shed_generator.py",
        "builder": "build_cargo_shed_lod1",
        "lod0_location": (10.0, 150.0, 0.0),
        "location": (10.0, 175.0, 0.0),
        "target": (8.0, 6.0, 4.5),
        "lod0_cap": 5000,
        "cap": 1174,
        "cells": {
            "SN_Town_Brick": "brick_wall", "SN_Town_Plaster": "plaster_grime",
            "SN_Town_Wood": "wood_plank", "SN_Town_Iron": "iron_rust",
            "SN_Town_Stone": "stone_base", "SN_Town_Glass": "glass_dark",
        },
    },
    {
        "asset": "SN_HT_Tavern",
        "module": "sn_iron_harbor_tavern_generator.py",
        "builder": "build_tavern_lod1",
        "lod0_location": (30.0, 150.0, 0.0),
        "location": (30.0, 175.0, 0.0),
        "target": (10.0, 8.0, 8.0),
        "lod0_cap": 8000,
        "cap": 1790,
        "cells": {
            "SN_Town_Brick": "brick_wall", "SN_Town_Plaster": "plaster_grime",
            "SN_Town_Wood": "wood_plank", "SN_Town_Iron": "iron_dark",
            "SN_Town_Stone": "stone_base_dirty", "SN_Town_Glass": "glass_reflect",
        },
    },
]

# dryrun_props.py 约定：ITEMS = [(name, location, budget, target), ...]
ITEMS = [("%s_LOD1" % s["asset"], s["location"], s["cap"], s["target"]) for s in LOD1_SPECS]
TOTAL_BUDGET = sum(s["cap"] for s in LOD1_SPECS)          # 10 508

# 每栋 LOD1 保留 / 删除项（report() 原样输出，供 Verifier 对照需求 §5.1）
DESIGN_L1 = {
    "SN_HT_Warehouse_Long": {
        "kept": ["长体量（20.0 × 9.0 × 11.0）", "2 个双高装卸门真凹口（3.0 × 5.18，凹 0.28）",
                 "山墙吊梁（牛腿 + 倒角主梁 + 吊链吊钩）", "双坡铁屋面（板厚 0.24 + 脊瓦 + 立缝）",
                 "石基（三级收分）", "人门 + 2 大窗 + 4 侧窗（真凹口）", "2 个屋面通风帽（简化）",
                 "石檐口（五级出挑线脚）", "两端山墙三角 + 铁拉杆"],
        "removed": ["窗框 / 窗棂 / 石窗台窗楣", "气窗", "滑轨 / 吊架 / 吊轮细件",
                    "落水管 / 檐沟 / 门槛平台细部", "壁柱（仅留转角轮廓）"],
    },
    "SN_HT_Warehouse_Short": {
        "kept": ["单坡侧棚（3 木柱 + 过梁 + 斜撑 + 单坡铁屋面）", "装卸门真凹口（3.0 × 4.30，凹 0.26）",
                 "偏置屋面通风管（x=1.55, y=0.55）", "不对称双坡主屋面（脊线偏心 Y_RIDGE=-1.29）",
                 "石基（三级收分）", "2 窗 + 3 后窗 + 2 侧棚窗（真凹口）", "±X 山墙三角", "石檐口"],
        "removed": ["窗框 / 窗棂 / 窗台窗楣", "招牌 / 砖壁柱", "落水管 / 檐沟",
                    "服务门台阶 / 门槛台 / 石腰线", "山墙窗 + 铁拉杆"],
    },
    "SN_HT_Harbor_Office": {
        "kept": ["三层分段（两道通长石腰线）", "拱形入口（拱肩填石 + 拱券环 + 拱心石 + 深木双门）",
                 "四面钟楼（缩为 +X / +Y 两面钟盘 + 八棱尖顶 + 铁尖 z=14.00）", "石檐口",
                 "2 个铁阳台大轮廓（石板 + 连续实体栏板）", "窗洞节奏（主立面 6 窗 + 2 落地门，+Y 6 窗）",
                 "石基 + 入口 2 级石阶", "4 根转角石壁柱", "平屋面 + 女儿墙", "屋角旗杆座（简化）",
                 "空白石匾"],
        "removed": ["窗框 / 窗棂 / 窗台窗楣 / 落地门框", "齿饰", "落水管 / 檐沟",
                    "钟盘指针 / 四面钟盘（保留 2 面）", "内壁柱", "阳台牛腿 / 栏杆立柱"],
    },
    "SN_HT_Cargo_Shed": {
        "kept": ["开敞柱廊（4 根木柱 + 石柱础 + 前檐梁 + 系梁 + 2 斜撑）", "单坡铁皮棚顶（真实厚度 0.22 + 前檐倒角）",
                 "工作台大体量", "后墙 + 高位小窗真凹口", "石基 + 前侧踏步", "±Y 低矮女墙",
                 "后挡板木带（简化）", "吊钩（简化吊链）"],
        "removed": ["12 道立缝（留 4 道） / 10 道露明椽", "货箱 / 托盘 / 木桶 / 麻袋堆", "木梯 / 吊灯 / 绞盘",
                    "铁柱箍 / 连接板 / 矮挡墙压条 / 拉杆"],
    },
    "SN_HT_Tavern": {
        "kept": ["两层轮廓（首层砖 / 二层灰泥 + 层间石腰带）", "门廊（石地面 + 2 木柱 + 廊顶）",
                 "悬挂招牌（铁托架 + 木牌）", "高砖烟囱（顶 z=8.00）", "双坡屋面 + 脊瓦",
                 "石基 + 入口门槛", "±X 山墙三角 + 石檐口", "门 / 窗真凹口（前 + 侧）"],
        "removed": ["窗框 / 窗棂 / 窗台窗楣 / 百叶窗扇", "木桶 / 落水管 / 檐沟",
                    "门廊矮栏 / 灯架 / 铁锚板 / 转角错缝石", "山墙百叶窗"],
    },
}

_LOD0_CACHE = {}
_LOD0_HASH_CACHE = {}


# --------------------------------------------------------------------------- #
# 参数化真源加载：只读 LOD0 生成器的常量与闭合实体工具
# --------------------------------------------------------------------------- #

def _load_file(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def lod0(asset):
    """按资产名加载对应 LOD0 生成器模块（缓存；纯 Python，不依赖 bpy）。"""
    if asset not in _LOD0_CACHE:
        spec = next(s for s in LOD1_SPECS if s["asset"] == asset)
        _LOD0_CACHE[asset] = _load_file(os.path.join(HERE, spec["module"]),
                                        "iron_harbor_lod0_" + asset.lower())
    return _LOD0_CACHE[asset]


def _target_of(asset):
    """目标尺寸也以 LOD0 生成器的 TARGET_SIZE 为准（dryrun 时校验一次）。"""
    return tuple(lod0(asset).TARGET_SIZE)


def _check_sources():
    """校验本文件声明的目标尺寸与 LOD0 真源一致（防止两边漂移）。"""
    for spec in LOD1_SPECS:
        src = tuple(lod0(spec["asset"]).TARGET_SIZE)
        if tuple(round(v, 6) for v in src) != tuple(round(v, 6) for v in spec["target"]):
            raise RuntimeError("target size drift for %s: source %s vs spec %s"
                               % (spec["asset"], src, spec["target"]))


# --------------------------------------------------------------------------- #
# 纯几何：5 栋 LOD1（每栋都用 LOD0 模块自己的工具与常量重建）
# --------------------------------------------------------------------------- #

def build_warehouse_long_lod1():
    """SN_HT_Warehouse_Long LOD1：长体量 + 双高门 + 山墙吊梁 + 双坡顶 + 石基。"""
    G = lod0("SN_HT_Warehouse_Long")
    m = G.Part()

    # 石基：直接复用 LOD0 的三级收分（定死 20 × 9 底面与轴心）
    G._stone_plinth(m)

    # 墙板：5 个主立面开口（2 双高门 + 人门 + 2 大窗）+ 背面服务门 + 2 后窗 + 4 侧窗
    front = [G.FRONT_OPENINGS[0], G.FRONT_OPENINGS[1], G.FRONT_OPENINGS[4],
             G.FRONT_OPENINGS[6], G.FRONT_OPENINGS[7]]
    back = [G.BACK_OPENINGS[0], G.BACK_OPENINGS[1], G.BACK_OPENINGS[3]]
    sides = [G.SIDE_OPENINGS[1], G.SIDE_OPENINGS[2]]
    m.add_multi(*G.panel("y", G.WALL_Y, -1.0, -9.75, 9.75,
                         G.WALL_BOT, G.EAVE_Z, G.PANEL_T, front))
    m.add_multi(*G.panel("y", -G.WALL_Y, 1.0, -9.75, 9.75,
                         G.WALL_BOT, G.EAVE_Z, G.PANEL_T, back))
    for side in ("left", "right"):
        m.add_multi(*G.panel("x", G._SIDE[side][1], G._SIDE[side][2],
                             -G.WALL_Y + 0.01, G.WALL_Y - 0.01,
                             G.WALL_BOT, G.EAVE_Z - 0.02, G.PANEL_T, sides))

    # 装卸门石门槛 + 人门门槛（LOD0 同款，保证门口落地）
    G._threshold(m, "front", 7.76, 1.75, 0.90)
    G._threshold(m, "front", 3.88, 1.75, 0.90)
    m.add(*G.lbox("front", -0.95, 0.95, G.PLINTH_TOP - 0.02, 0.84, -0.20, 0.02), G.STONE)

    # 石檐口（五级出挑，四面环通）
    G._cornice(m)
    # 双坡屋面（板厚 0.24 + 脊瓦 + 8 道立缝）+ 两端山墙三角（含铁拉杆）
    G._roof(m)
    G._gable(m)

    # 山墙吊梁（简化：牛腿 + 倒角主梁 + 梁端板 + 吊链 + 吊块 + 钩柄）
    m.add(*G.box((9.60, -0.34, 8.84), (9.78, 0.34, 9.28)), G.IRON)
    m.add(*G.chamfer_beam((9.30, 0.0, 9.34), (9.98, 0.0, 9.34), 0.28, 0.30, 0.03), G.WOOD)
    m.add(*G.box((9.94, -0.16, 9.19), (9.99, 0.16, 9.49)), G.IRON)
    m.add(*G.rod((9.80, 0.0, 9.06), (9.80, 0.0, 8.28), 0.026, 6), G.IRON)
    m.add(*G.box((9.73, -0.07, 8.10), (9.87, 0.07, 8.28)), G.IRON)
    m.add(*G.rod((9.80, 0.0, 8.10), (9.80, 0.0, 7.86), 0.032, 6), G.IRON)

    # 2 个屋面通风帽（简化成方形烟道 + 锥形帽，保留天际线）
    for vx in (-6.0, 6.0):
        yb = 2.60
        zb = G.EAVE_Z + (G.WALL_Y - abs(yb)) * G.ROOF_SLOPE + G.ROOF_T
        m.add(*G.box((vx - 0.30, yb - 0.30, zb - 0.24),
                     (vx + 0.30, yb + 0.30, zb + 0.60)), G.IRON)
        m.add(*G.tb(vx - 0.44, vx + 0.44, yb - 0.44, yb + 0.44,
                    zb + 0.60, zb + 0.82, 0.09), G.IRON)
        m.add(*G.box((vx - 0.20, yb - 0.20, zb + 0.82),
                     (vx + 0.20, yb + 0.20, zb + 0.90)), G.IRON)
    return m


def build_warehouse_short_lod1():
    """SN_HT_Warehouse_Short LOD1：单坡侧棚 + 装卸门 + 偏置通风管 + 不对称屋面 + 石基。"""
    G = lod0("SN_HT_Warehouse_Short")
    m = G.Part()

    G._stone_plinth(m)

    # 墙板：主立面 3 开口（装卸门 + 2 窗）、背面服务门、+Y 2 窗、−Y 2 窗
    front = [G.FRONT_OPENINGS[0], G.FRONT_OPENINGS[1], G.FRONT_OPENINGS[2]]
    back = [G.BACK_OPENINGS[0]]
    right = [G.SHED_OPENINGS[0], G.SHED_OPENINGS[1]]
    left = [G.REAR_OPENINGS[0], G.REAR_OPENINGS[2]]
    m.add_multi(*G.panel("x", G.WALL_X, -1.0, G.FRONT_U0, G.FRONT_U1,
                         G.WALL_BOT, G.EAVE_Z, G.PANEL_T, front))
    m.add_multi(*G.panel("x", -G.WALL_X, 1.0, G.FRONT_U0, G.FRONT_U1,
                         G.WALL_BOT, G.EAVE_Z, G.PANEL_T, back))
    m.add_multi(*G.panel("y", G.WALL_YP, -1.0, G.SIDE_U0, G.SIDE_U1,
                         G.WALL_BOT, G.EAVE_Z, G.PANEL_T, right))
    m.add_multi(*G.panel("y", G.WALL_YM, 1.0, G.SIDE_U0, G.SIDE_U1,
                         G.WALL_BOT, G.EAVE_Z, G.PANEL_T, left))

    # 装卸门石/铁门槛台（LOD0 同款，读得出装卸口落地）
    G._loading_apron(m, "front", G.LOADING_DOOR_UC)

    # 不对称单坡侧棚（+Y）：墙顶垫梁 + 3 柱 + 柱础 + 木过梁 + 2 斜撑 + 单坡铁屋面 + 封檐板
    m.add(*G.lbox("right", -5.30, 5.30, 4.30, 4.46, -0.12, 0.08), G.WOOD)
    for px in G.POST_XS:
        m.add(*G.vchamfer_box(px - G.POST_HALF, px + G.POST_HALF,
                              G.POST_Y - G.POST_HALF, G.POST_Y + G.POST_HALF,
                              0.67, G.POST_TOP, 0.025), G.WOOD)
        m.add(*G.vchamfer_box(px - 0.17, px + 0.17, G.POST_Y - 0.17, G.POST_Y + 0.17,
                              G.PLINTH_TOP, 0.67, 0.03), G.STONE)
    m.add(*G.box((-5.28, G.POST_Y - 0.09, G.LINTEL_Z[0]),
                 (5.28, G.POST_Y + 0.09, G.LINTEL_Z[1])), G.WOOD)
    for s in (-1.0, 1.0):
        m.add(*G.beam((0.0, G.POST_Y, 2.45),
                      (s * G.BRACE_LEN, G.POST_Y, G.LINTEL_Z[0] + 0.06), 0.12, 0.12), G.WOOD)
    m.add(*G.prism_x(G._shed_roof_section(), -G.SHED_ROOF_X, G.SHED_ROOF_X), G.IRON)
    m.add(*G.box((-5.48, G.SHED_Y1 - 0.08, 2.92), (5.48, G.SHED_Y1 - 0.01, 3.24)), G.WOOD)

    # 主双坡屋面（用修复后的 _roof_section：顶皮严格按 SLOPE 落在 ±Y 墙线上）+ 脊瓦 + 4 立缝
    for sy in (-1.0, 1.0):
        m.add(*G.prism_x(G._roof_section(sy), -G.ROOF_X, G.ROOF_X), G.IRON)
    m.add(*G.box((-5.48, G.Y_RIDGE - 0.30, 9.30),
                 (5.48, G.Y_RIDGE + 0.30, G.RIDGE_CAP_TOP)), G.IRON)
    for sy in (-1.0, 1.0):
        for sx in (-3.60, 3.60):
            ye = G.Y_RIDGE + sy * (G.ROOF_EAVE_DY - 0.08)
            ze = G.RIDGE_TOP - (G.ROOF_EAVE_DY - 0.08) * G.SLOPE + 0.030
            yr = G.Y_RIDGE + sy * 0.20
            zr = G.RIDGE_TOP - 0.20 * G.SLOPE + 0.030
            m.add(*G.beam((sx, ye, ze), (sx, yr, zr), 0.075, 0.055), G.IRON)

    # 两端山墙三角（石膏，厚度与 LOD0 相同，外皮内收 0.02 防共面）
    y0, y1 = G.FRONT_U0, G.FRONT_U1
    tri = [(y0, G.GABLE_BASE_Z), (y1, G.GABLE_BASE_Z), (G.Y_RIDGE, G.GABLE_APEX_Z)]
    m.add(*G.prism_x(tri, G.WALL_X - 0.02, G.WALL_X - G.PANEL_T - 0.02), G.PLASTER)
    m.add(*G.prism_x(tri, -G.WALL_X + 0.02, -G.WALL_X + G.PANEL_T + 0.02), G.PLASTER)

    # 石檐口（简化 5 点线脚，保留最大出挑 0.18 与檐口投影）
    prof = [(0.02, 6.98), (-0.18, 6.98), (-0.18, 7.20), (-0.10, 7.36), (0.02, 7.46)]
    for side in ("front", "back"):
        m.add(*G.lprism_u(side, G.FRONT_U0, G.FRONT_U1, prof), G.STONE)
    for side in ("right", "left"):
        m.add(*G.lprism_u(side, -5.48, 5.48, prof), G.STONE)

    # 偏心屋面通风管（轮廓识别点）：底板 + 立管 + 锥形风帽 + 顶盖
    vx, vy = G.VENT_POS
    z_roof = G.RIDGE_TOP - abs(vy - G.Y_RIDGE) * G.SLOPE
    m.add(*G.box((vx - 0.30, vy - 0.30, z_roof - 0.20),
                 (vx + 0.30, vy + 0.30, z_roof + 0.06)), G.IRON)
    m.add(*G.rod((vx, vy, z_roof + 0.02), (vx, vy, G.VENT_TOP - 0.14), G.VENT_R, 8), G.IRON)
    m.add(*G.tb(vx - 0.21, vx + 0.21, vy - 0.21, vy + 0.21,
                G.VENT_TOP - 0.14, G.VENT_TOP - 0.02, 0.07), G.IRON)
    m.add(*G.box((vx - 0.14, vy - 0.14, G.VENT_TOP - 0.03),
                 (vx + 0.14, vy + 0.14, G.VENT_TOP)), G.IRON)
    return m


def build_harbor_office_lod1():
    """SN_HT_Harbor_Office LOD1：三层分段 + 拱形入口 + 钟楼 + 檐口 + 阳台大轮廓。"""
    G = lod0("SN_HT_Harbor_Office")
    m = G.Part()

    G._stone_plinth(m)
    G._entrance_steps(m)

    # 墙板：主立面保留全部 9 个开口（拱 + 6 窗 + 2 落地门），+Y 保留 6 窗；−Y/−X 机位不可见，做实墙
    win_right = G._win_rows((-2.35, 2.35))
    m.add_multi(*G.panel("x", G.WALL_X, -1.0, G.FRONT_U[0], G.FRONT_U[1],
                         G.WALL_BOT, G.EAVE_Z, G.PANEL_T, list(G.FRONT_OPENINGS)))
    m.add_multi(*G.panel("x", -G.WALL_X, 1.0, G.BACK_U[0], G.BACK_U[1],
                         G.WALL_BOT, G.EAVE_Z, G.PANEL_T, []))
    m.add_multi(*G.panel("y", G.WALL_Y, -1.0, G.SIDE_U[0], G.SIDE_U[1],
                         G.WALL_BOT, G.EAVE_Z, G.PANEL_T, win_right))
    m.add_multi(*G.panel("y", -G.WALL_Y, 1.0, G.SIDE_U[0], G.SIDE_U[1],
                         G.WALL_BOT, G.EAVE_Z, G.PANEL_T, []))

    # 拱形入口：拱肩填石 + 6 段拱券环 + 拱心石 + 深木双门（2 扇整板）+ 铁门槛
    half_segs = 3
    for s in (-1.0, 1.0):
        m.add(*G._arch_lune("front", 0.0, G.ARCH_SPRING, G.ARCH_HALF_U, s, half_segs,
                            -0.03, G.DOOR_RECESS - 0.01), G.STONE)
    m.add(*G.larc_band("front", 0.0, G.ARCH_SPRING, G.ARCH_RING_RIN, G.ARCH_RING_ROUT,
                       -G.ARCH_FRONT_D, 0.04, 0.0, math.pi, 6), G.STONE)
    for s in (-1.0, 1.0):
        u0, u1 = sorted((s * (G.ARCH_HALF_U - 0.07), s * (G.ARCH_HALF_U + 0.35)))
        m.add(*G.lbox("front", u0, u1, 0.90, G.ARCH_SPRING + 0.28, -0.10, 0.04), G.STONE)
    m.add(*G.lbox("front", -0.17, 0.17, G.KEYSTONE_Z[0], G.KEYSTONE_Z[1], -0.18, 0.03),
          G.STONE)
    hw = G.ARCH_HALF_U - 0.04
    for s in (-1.0, 1.0):
        u0, u1 = sorted((s * 0.02, s * hw))
        m.add(*G.lbox("front", u0, u1, G.ARCH_SILL + 0.02, G.ARCH_SPRING - 0.08,
                      G.DOOR_RECESS - 0.10, G.DOOR_RECESS - 0.04), G.WOOD)
    m.add(*G.lbox("front", -G.ARCH_HALF_U, G.ARCH_HALF_U, G.ARCH_SILL - 0.01,
                  G.ARCH_SILL + 0.03, -0.02, 0.20), G.IRON)

    # 4 根转角石壁柱（简化成单根倒角柱，保留转角轮廓）
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            x0, x1 = sorted((sx * (G.WALL_X - 0.30), sx * (G.WALL_X + 0.16)))
            y0, y1 = sorted((sy * (G.WALL_Y - 0.38), sy * (G.WALL_Y + 0.10)))
            m.add(*G.vchamfer_box(x0, x1, y0, y1, G.PLINTH_TOP - 0.01,
                                  G.CORNICE_Z[0] - 0.02, 0.045), G.STONE)

    # 两道通长石腰线（三层分段的读数来源）
    for side, u0, u1 in (("front", -3.78, 3.78), ("back", -3.78, 3.78),
                         ("right", -3.94, 3.94), ("left", -3.94, 3.94)):
        for (z0, z1) in G.STRING_Z:
            m.add(*G.lbox(side, u0, u1, z0, z1, -0.10, 0.02), G.STONE)

    # 石檐口（简化 5 点线脚，主立面出挑 0.40 / 侧立面 0.30）
    z0, z1 = G.CORNICE_Z
    for side, u0, u1, dmax in (("front", -3.98, 3.98, G.CORNICE_D_X),
                                ("back", -3.98, 3.98, G.CORNICE_D_X),
                                ("right", -3.86, 3.86, G.CORNICE_D_Y),
                                ("left", -3.86, 3.86, G.CORNICE_D_Y)):
        prof = [(0.02, z0), (-dmax, z0), (-dmax, z0 + (z1 - z0) * 0.62),
                (-dmax * 0.42, z1), (0.02, z1)]
        m.add(*G.lprism_u(side, u0, u1, prof), G.STONE)

    # 平屋面板 + 女儿墙（4 块闭合板围成环）
    m.add(*G.box((-G.ROOF_OUT_X, -G.ROOF_OUT_Y, G.ROOF_Z[0]),
                 (G.ROOF_OUT_X, G.ROOF_OUT_Y, G.ROOF_Z[1])), G.IRON)
    p0, p1 = G.PARAPET_Z
    m.add(*G.box((4.00, -3.86, p0), (4.16, 3.86, p1)), G.PLASTER)
    m.add(*G.box((-4.16, -3.86, p0), (-4.00, 3.86, p1)), G.PLASTER)
    m.add(*G.box((-4.00, 3.70, p0), (4.00, 3.86, p1)), G.PLASTER)
    m.add(*G.box((-4.00, -3.86, p0), (4.00, -3.70, p1)), G.PLASTER)

    # 钟楼：砖塔身 + 石基环 + 2 面空白钟盘（+X/+Y，铁圈 + 灰泥盘面）+ 石檐环 + 八棱尖顶 + 铁尖
    th = G.TOWER_HALF
    m.add(*G.box((-th, -th, G.TOWER_Z0), (th, th, G.TOWER_Z1)), G.BRICK)
    m.add(*G.tb(-th - 0.16, th + 0.16, -th - 0.16, th + 0.16,
                G.TOWER_BASE_Z[0], G.TOWER_BASE_Z[1], 0.04), G.STONE)
    for (nx, ny) in ((1.0, 0.0), (0.0, 1.0)):
        center = (nx * th, ny * th, G.CLOCK_Z)
        m.add(*G.ring_at(center, (nx, ny, 0.0), G.CLOCK_R_OUT, G.CLOCK_R_IN,
                         -0.05, 0.03, 8), G.IRON)
        c0 = (center[0] + nx * 0.005, center[1] + ny * 0.005, center[2])
        c1 = (center[0] + nx * 0.035, center[1] + ny * 0.035, center[2])
        m.add(*G.sweep(c0, c1, G.circle(8, G.CLOCK_R_IN + 0.015)), G.PLASTER)
    m.add(*G.tb(-th - 0.18, th + 0.18, -th - 0.18, th + 0.18,
                G.TOWER_CORNICE_Z[0], G.TOWER_CORNICE_Z[1], 0.06), G.STONE)
    m.add(*G.revolved([(G.SPIRE_Z0, 1.44), (G.SPIRE_Z0 + 0.24, 1.14),
                       (G.SPIRE_Z0 + 0.64, 0.52), (G.SPIRE_Z0 + 0.88, 0.07)], 8), G.IRON)
    m.add(*G.rod((0.0, 0.0, G.SPIRE_Z0 + 0.85), (0.0, 0.0, G.FINIAL_TOP), 0.050, 6), G.IRON)

    # 2 个阳台：石板 + 连续实体栏板（需求允许栏杆换带厚度连续构件）
    for (v0, _v1) in G.FRENCH_V:
        slab_top = v0 - 0.01
        slab_bottom = slab_top - 0.13
        m.add(*G.lbox("front", -G.BALCONY_HALF_U, G.BALCONY_HALF_U,
                      slab_bottom, slab_top, -G.BALCONY_D, 0.03), G.STONE)
        rail_top = v0 + G.RAIL_H
        m.add(*G.lbox("front", -G.BALCONY_HALF_U + 0.02, G.BALCONY_HALF_U - 0.02,
                      slab_top + 0.03, rail_top, -G.BALCONY_D - 0.02,
                      -G.BALCONY_D + 0.10), G.IRON)
        for s in (-1.0, 1.0):
            ux = s * (G.BALCONY_HALF_U - 0.05)
            m.add(*G.lbox("front", ux - 0.05, ux + 0.05, slab_top + 0.03, rail_top,
                          -G.BALCONY_D - 0.02, 0.0), G.IRON)

    # 屋角旗杆座（简化：石座 + 铁杆到 13.60，低于尖顶 14.00）
    (x0, x1), (y0, y1) = G.FLAG_BASE
    m.add(*G.box((x0, y0, G.FLAG_BASE_Z[0]), (x1, y1, G.FLAG_BASE_Z[1])), G.STONE)
    cx, cy = 0.5 * (x0 + x1), 0.5 * (y0 + y1)
    m.add(*G.rod((cx, cy, G.FLAG_BASE_Z[1] - 0.04), (cx, cy, G.FLAG_POLE_Z), 0.045, 6),
          G.IRON)
    return m


def build_cargo_shed_lod1():
    """SN_HT_Cargo_Shed LOD1：开敞柱廊 + 单坡棚顶 + 工作台大体量 + 石基。"""
    G = lod0("SN_HT_Cargo_Shed")
    m = G.Part()

    G._plinth(m)
    m.add(*G.box((-3.46, -2.52, 0.20), (3.44, 2.52, G.FLOOR_TOP)), G.STONE)

    # 后墙（木拼板厚墙 + 高位小窗真凹口）
    m.add_multi(*G.panel("x", G.BACK_X, 1.0, -2.70, 2.70, 0.28, 3.56, G.WALL_T,
                         G.BACK_OPENINGS, mat_face=G.WOOD, mat_reveal=G.WOOD,
                         mat_inner=G.WOOD))
    # 后挡板木带（简化：2 条横带 + 4 根墙筋）
    for z0 in (1.90, 2.21):
        m.add(*G.box((-3.50, -2.44, z0), (-3.38, 2.44, z0 + 0.28)), G.WOOD)
    for py in (-1.68, -0.56, 0.56, 1.68):
        m.add(*G.box((-3.48, py - 0.06, 0.30), (-3.34, py + 0.06, 3.50)), G.WOOD)

    # 开敞柱廊：4 柱 + 石柱础 + 前檐梁 + 系梁 + 2 斜撑
    for py in G.POST_Y:
        m.add(*G.vchamfer_box(G.POST_X0, G.POST_X1, py - G.POST_W / 2.0,
                              py + G.POST_W / 2.0, G.POST_Z0, G.POST_Z1, 0.03), G.WOOD)
        m.add(*G.box((G.POST_X0 - 0.06, py - G.POST_W / 2.0 - 0.06, 0.26),
                     (G.POST_X1 + 0.06, py + G.POST_W / 2.0 + 0.06, 0.42)), G.STONE)
    m.add(*G.box((3.34, -2.86, G.PLATE_Z0), (3.70, 2.86, G.PLATE_Z1)), G.WOOD)
    m.add(*G.box((3.38, -2.74, G.TIE_Z0), (3.66, 2.74, G.TIE_Z1)), G.WOOD)
    for s in (-1.0, 1.0):
        m.add(*G.chamfer_beam((3.52, s * 2.46, 2.90), (3.52, s * 1.05, 3.24),
                              0.10, 0.12, 0.02), G.WOOD)

    # ±Y 低矮女墙 + 石压顶
    for s in (-1.0, 1.0):
        m.add(*G.box((-3.72, s * G.PARAPET_IN, 0.28),
                     (3.62, s * G.PARAPET_OUT, G.PARAPET_Z1)), G.WOOD)
        m.add(*G.tb(-3.74, 3.64, s * (G.PARAPET_IN - 0.02),
                    s * (G.PARAPET_OUT + 0.02), G.PARAPET_Z1, G.COPING_Z1, 0.03), G.STONE)

    # 单坡铁皮棚顶（真实厚度 0.22 + 前檐 2 段倒角）+ 4 道立缝 + 2 侧封檐板
    prof = [(-G.HALF_X, G.roof_sof_z(-G.HALF_X)),
            (-G.HALF_X, G.roof_top_z(-G.HALF_X)),
            (G.ROOF_TOP_X, G.TOP_Z),
            (3.985, 4.455),
            (G.HALF_X, 4.400),
            (G.HALF_X, G.roof_sof_z(G.HALF_X))]
    m.add(*G.prism_y(prof, -G.HALF_Y, G.HALF_Y), G.IRON)
    for sy in (-2.0, -0.5, 1.0, 2.5):
        m.add(*G.beam((-3.75, sy, G.roof_top_z(-3.75) + 0.02),
                      (G.SEAM_X1, sy, G.roof_top_z(G.SEAM_X1) + 0.02), 0.06, 0.05), G.IRON)
    for s in (-1.0, 1.0):
        m.add(*G.chamfer_beam((-3.96, s * 2.94, G.roof_sof_z(-3.96) - 0.09),
                              (3.94, s * 2.94, G.roof_sof_z(3.94) - 0.09),
                              0.06, 0.22, 0.015), G.WOOD)

    # 工作台大体量（台面 + 2 板式台腿）
    m.add(*G.box((-3.44, -0.92, 1.10), (-2.74, 0.92, 1.17)), G.WOOD)
    for s in (-1.0, 1.0):
        m.add(*G.box((-3.42, s * 0.86, 0.30), (-2.80, s * 0.80, 1.12)), G.WOOD)

    # 开敞前脸的吊钩（简化吊架 + 链 + 吊块）
    y = G.HOIST_Y
    m.add(*G.box((3.40, y - 0.09, 3.16), (3.62, y + 0.09, 3.30)), G.IRON)
    m.add(*G.rod((3.50, y, 3.14), (3.50, y, 2.28), 0.026, 6), G.IRON)
    m.add(*G.box((3.45, y - 0.07, 2.04), (3.55, y + 0.07, 2.23)), G.IRON)
    # 1 木箱 + 1 木桶（保留棚内体量层次，非必需小件已删）
    m.add(*G.box((-1.64, 1.31, 0.30), (-0.86, 2.09, 1.02)), G.WOOD)
    m.add(*G.rod((2.55, -1.85, 0.30), (2.55, -1.85, 1.12), 0.29, 10), G.WOOD)
    return m


def build_tavern_lod1():
    """SN_HT_Tavern LOD1：两层轮廓 + 门廊 + 悬挂招牌 + 高烟囱。"""
    G = lod0("SN_HT_Tavern")
    m = G.Part()

    G._plinth(m)

    # 8 块墙板（首层砖 / 二层灰泥，层间分界 = LOD0 的 STOREY_Z）：只保留可见立面的开口
    fu = G.WALL_Y - G.SIDE_T
    m.add_multi(*G.panel("x", G.WALL_XF, -1.0, -fu, fu, G.WALL_Z0, G.STOREY_Z,
                         G.PANEL_T, G.FRONT_LOW, mat_face=G.BRICK, mat_reveal=G.STONE,
                         mat_inner=G.BRICK))
    m.add_multi(*G.panel("x", G.WALL_XF, -1.0, -fu, fu, G.STOREY_Z, G.EAVE_Z,
                         G.PANEL_T, G.FRONT_HIGH, mat_face=G.PLASTER,
                         mat_reveal=G.STONE, mat_inner=G.BRICK))
    m.add_multi(*G.panel("x", G.WALL_XB, 1.0, -fu, fu, G.WALL_Z0, G.STOREY_Z,
                         G.SIDE_T, G.BACK_LOW, mat_face=G.BRICK, mat_reveal=G.STONE,
                         mat_inner=G.BRICK))
    m.add_multi(*G.panel("x", G.WALL_XB, 1.0, -fu, fu, G.STOREY_Z, G.EAVE_Z,
                         G.SIDE_T, [], mat_face=G.PLASTER, mat_reveal=G.STONE,
                         mat_inner=G.BRICK))
    right_high = [G.RIGHT_HIGH[0], G.RIGHT_HIGH[2]]
    for side, sign, low, high in (("right", -1.0, G.RIGHT_LOW, right_high),
                                  ("left", 1.0, [], [])):
        plane = G.WALL_Y if side == "right" else -G.WALL_Y
        m.add_multi(*G.panel("y", plane, sign, G.WALL_XB, G.WALL_XF, G.WALL_Z0,
                             G.STOREY_Z, G.SIDE_T, low, mat_face=G.BRICK,
                             mat_reveal=G.STONE, mat_inner=G.BRICK))
        m.add_multi(*G.panel("y", plane, sign, G.WALL_XB, G.WALL_XF, G.STOREY_Z,
                             G.EAVE_Z, G.SIDE_T, high, mat_face=G.PLASTER,
                             mat_reveal=G.STONE, mat_inner=G.BRICK))

    # 层间石腰带（四面）+ 檐口（简化 5 点线脚）
    for side, u0, u1 in (("front", -fu, fu), ("back", -fu, fu),
                         ("right", G.WALL_XB, G.WALL_XF), ("left", G.WALL_XB, G.WALL_XF)):
        m.add(*G.lbox(side, u0, u1, G.STOREY_Z - 0.02, G.STOREY_Z + 0.12, -0.13, 0.02),
              G.STONE)
    corn = [(0.02, G.EAVE_Z - 0.44), (-0.22, G.EAVE_Z - 0.44),
            (-0.22, G.EAVE_Z - 0.30), (-0.12, G.EAVE_Z - 0.10),
            (0.02, G.EAVE_Z - 0.08)]
    for side, u0, u1 in (("front", -fu, fu), ("back", -fu, fu),
                         ("right", G.WALL_XB, G.WALL_XF), ("left", G.WALL_XB, G.WALL_XF)):
        m.add(*G.lprism_u(side, u0, u1, corn), G.STONE)

    # +X 山墙三角（灰泥）+ 双坡屋面 + 脊瓦 + 4 立缝
    m.add(*G.prism_x([(-G.WALL_Y, G.EAVE_Z - 0.18), (G.WALL_Y, G.EAVE_Z - 0.18),
                      (G.WALL_Y, G.EAVE_Z - 0.04), (0.0, G.RIDGE_Z - 0.02),
                      (-G.WALL_Y, G.EAVE_Z - 0.04)],
                     G.WALL_XF - G.PANEL_T, G.WALL_XF), G.PLASTER)
    for sy in (-1.0, 1.0):
        ye = sy * G.ROOF_Y
        zt = G.ROOF_EAVE_Z + G.ROOF_T
        pts = [(0.0, G.RIDGE_Z), (ye, G.ROOF_EAVE_Z), (ye, zt - 0.06),
               (ye - sy * 0.018, zt - 0.018), (ye - sy * 0.062, zt),
               (0.0, G.RIDGE_Z + G.ROOF_T)]
        m.add(*G.prism_x(pts, G.ROOF_XB, G.ROOF_XF), G.IRON)
    m.add(*G.box((G.ROOF_XB, -0.28, G.RIDGE_Z + G.ROOF_T - 0.02),
                 (G.ROOF_XF, 0.28, G.RIDGE_Z + G.ROOF_T + 0.10)), G.IRON)
    for sy in (-1.0, 1.0):
        for sx in (-3.40, 3.40):
            ye = sy * (G.WALL_Y + 0.18)
            ze = G.RIDGE_Z - abs(ye) * G.ROOF_SLOPE + G.ROOF_T
            m.add(*G.beam((sx, ye, ze + 0.026),
                          (sx, sy * 0.20, G.RIDGE_Z + G.ROOF_T + 0.026),
                          0.075, 0.055), G.IRON)

    # 门廊：石地面 + 2 木柱 + 石柱础 + 2 斜撑 + 廊顶横梁 + 单坡廊顶
    m.add(*G.box((G.WALL_XF, -G.PORCH_HALF_W, G.PLINTH_TOP - 0.02),
                 (G.PORCH_X - 0.02, G.PORCH_HALF_W, G.PLINTH_TOP + 0.02)), G.STONE)
    for sy in (-1.0, 1.0):
        py = sy * (G.PORCH_HALF_W - 0.35)
        m.add(*G.vchamfer_box(G.PORCH_X - 0.32, G.PORCH_X - 0.10, py - 0.11, py + 0.11,
                              G.PLINTH_TOP, G.PORCH_EAVE_Z, 0.02), G.WOOD)
        m.add(*G.vchamfer_box(G.PORCH_X - 0.42, G.PORCH_X - 0.02, py - 0.19, py + 0.19,
                              G.PLINTH_TOP - 0.02, G.PLINTH_TOP + 0.16, 0.015), G.STONE)
        m.add(*G.beam((G.PORCH_X - 0.24, py, G.PORCH_EAVE_Z - 0.62),
                      (G.WALL_XF + 0.02, py, G.PORCH_EAVE_Z - 0.04), 0.09, 0.09), G.WOOD)
    m.add(*G.box((G.PORCH_X - 0.34, -G.PORCH_HALF_W + 0.10, G.PORCH_EAVE_Z - 0.16),
                 (G.PORCH_X - 0.08, G.PORCH_HALF_W - 0.10, G.PORCH_EAVE_Z - 0.02)), G.WOOD)
    lo, hi = G.PORCH_EAVE_Z, G.PORCH_TOP_Z
    porch_roof = [(G.WALL_XF + 0.02, hi), (G.PORCH_X, lo),
                  (G.PORCH_X - 0.02, lo - 0.06), (G.PORCH_X - 0.06, lo - 0.075),
                  (G.PORCH_X - 0.10, lo - 0.05), (G.WALL_XF + 0.02, hi + 0.18)]
    m.add(*G.prism_y(porch_roof, -G.PORCH_HALF_W, G.PORCH_HALF_W), G.IRON)

    # 高砖烟囱（顶 z=8.00）+ 悬挂空白招牌（铁托架 + 木牌）
    G._chimney(m)
    yc = 2.95
    m.add(*G.box((G.WALL_XF - 0.02, yc - 0.07, 3.66),
                 (G.WALL_XF + 0.62, yc + 0.07, 3.74)), G.IRON)
    m.add(*G.box((G.WALL_XF - 0.02, yc - 0.07, 3.16),
                 (G.WALL_XF + 0.58, yc + 0.07, 3.24)), G.IRON)
    m.add(*G.box((G.WALL_XF + 0.48, yc - 0.06, 3.16),
                 (G.WALL_XF + 0.56, yc + 0.06, 3.74)), G.IRON)
    m.add(*G.box((G.WALL_XF + 0.27, yc - 0.43, 3.02),
                 (G.WALL_XF + 0.33, yc + 0.43, 3.60)), G.WOOD)
    return m


BUILDERS = {
    "SN_HT_Warehouse_Long": build_warehouse_long_lod1,
    "SN_HT_Warehouse_Short": build_warehouse_short_lod1,
    "SN_HT_Harbor_Office": build_harbor_office_lod1,
    "SN_HT_Cargo_Shed": build_cargo_shed_lod1,
    "SN_HT_Tavern": build_tavern_lod1,
}


def build_all_geometry():
    """纯 Python：{SN_HT_<Name>_LOD1: Part}。dryrun_props.py 的入口。"""
    _check_sources()
    return {spec["asset"] + "_LOD1": BUILDERS[spec["asset"]]() for spec in LOD1_SPECS}


# --------------------------------------------------------------------------- #
# 纯 Python 自检工具（dryrun / report 共用；不 import bpy）
# --------------------------------------------------------------------------- #

def tri_count(faces):
    return sum(max(0, len(f) - 2) for f, _m in faces)


def edge_stats(faces):
    from collections import Counter
    counter = Counter()
    for face, _m in faces:
        n = len(face)
        for i in range(n):
            a, b = face[i], face[(i + 1) % n]
            counter[(min(a, b), max(a, b))] += 1
    return (sum(1 for c in counter.values() if c == 1),
            sum(1 for c in counter.values() if c > 2))


def degenerate_faces(verts, faces):
    bad = 0
    for face, _m in faces:
        if len(set(face)) != len(face):
            bad += 1
            continue
        p0 = verts[face[0]]
        for i in range(1, len(face) - 1):
            p1, p2 = verts[face[i]], verts[face[i + 1]]
            ux, uy, uz = p1[0] - p0[0], p1[1] - p0[1], p1[2] - p0[2]
            vx, vy, vz = p2[0] - p0[0], p2[1] - p0[1], p2[2] - p0[2]
            cx, cy, cz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
            if (cx * cx + cy * cy + cz * cz) ** 0.5 * 0.5 < 1e-9:
                bad += 1
                break
    return bad


def measure_part(part):
    """纯 Python 度量：tri/顶点/尺寸/包围盒/zmin/边界边/非流形/退化面。"""
    xs = [v[0] for v in part.verts]
    ys = [v[1] for v in part.verts]
    zs = [v[2] for v in part.verts]
    boundary, nonman = edge_stats(part.faces)
    mats = []
    for _f, mat in part.faces:
        if mat not in mats:
            mats.append(mat)
    return {
        "tris": tri_count(part.faces),
        "verts": len(part.verts),
        "size": [round(max(xs) - min(xs), 6), round(max(ys) - min(ys), 6),
                 round(max(zs) - min(zs), 6)],
        "bbox": [[round(min(xs), 6), round(min(ys), 6), round(min(zs), 6)],
                 [round(max(xs), 6), round(max(ys), 6), round(max(zs), 6)]],
        "zmin": round(min(zs), 9),
        "pivot_xy": [round(0.5 * (min(xs) + max(xs)), 9),
                     round(0.5 * (min(ys) + max(ys)), 9)],
        "boundary_edges": boundary,
        "non_manifold_edges": nonman,
        "degenerate_faces": degenerate_faces(part.verts, part.faces),
        "materials": mats,
        "material_slots": len(mats),
    }


# --------------------------------------------------------------------------- #
# Blender 侧：材质 / 对象 / 全场景 digest
# --------------------------------------------------------------------------- #

_RESULTS = {}
_BASELINE = {}
_PREBUILD = {}


def _load_materials():
    return _load_file(os.path.join(HERE, "sn_iron_harbor_materials.py"),
                      "sn_iron_harbor_materials")


def _load_batch2():
    return _load_file(os.path.join(HERE, "sn_iron_harbor_kit_batch2.py"),
                      "sn_iron_harbor_kit_batch2")


def _ensure_collection():
    import bpy
    col = bpy.data.collections.get(COLLECTION)
    if col is None:
        col = bpy.data.collections.new(COLLECTION)
        bpy.context.scene.collection.children.link(col)
    return col


def _make_object(name, part, location, collection, grey_materials):
    """把纯 Python Part 变成单 mesh 对象（每面材质 → 材质槽），UV/材质随后由共享模块写。"""
    import bmesh
    import bpy

    mesh = bpy.data.meshes.new(name + "_mesh")
    mesh.from_pydata([tuple(v) for v in part.verts], [], [list(f) for f, _m in part.faces])
    mesh.update()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()

    slots = []
    for _face, mat_name in part.faces:
        if mat_name not in slots:
            slots.append(mat_name)
    if len(slots) > MAX_MATERIAL_SLOTS:
        raise RuntimeError("%s: 材质槽 %d > 上限 %d" % (name, len(slots), MAX_MATERIAL_SLOTS))
    for mat_name in slots:
        mesh.materials.append(grey_materials(mat_name))
    index = {m: i for i, m in enumerate(slots)}
    for poly, (_face, mat_name) in zip(mesh.polygons, part.faces):
        poly.material_index = index[mat_name]
        poly.use_smooth = False

    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler = (0.0, 0.0, 0.0)
    obj.scale = (1.0, 1.0, 1.0)
    return obj


def _grey_material(name):
    """灰阶占位材质（贴图缺失时 apply_to_object 会退回它；正常路径会被覆盖）。"""
    import bpy
    mat = bpy.data.materials.get(name)
    if mat is not None:
        return mat
    tints = {"SN_Town_Brick": 0.345, "SN_Town_Plaster": 0.560, "SN_Town_Wood": 0.215,
             "SN_Town_Iron": 0.120, "SN_Town_Stone": 0.445, "SN_Town_Glass": 0.050}
    tint = tints.get(name, 0.5)
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (tint, tint, tint, 1.0)
    mat.diffuse_color = (tint, tint, tint, 1.0)
    return mat


def _apply_cells(obj, cells):
    """把**本栋**的 trim-sheet cell 写进 6 个共享材质 datablock，并返回 UV/贴图核验。

    坑（batch2 §3）：6 个材质是全局 datablock，`apply_to_object()` 每次重建 node tree，
    所以每栋测量/渲染前必须"轮到谁就重新写一次"。
    """
    mats = _load_materials()
    res = mats.apply_to_object(obj, cells=cells)
    res["verify"] = mats.verify_object(obj)
    return res


def _geo_sig(obj):
    import hashlib
    mesh = obj.data
    vs = tuple((round(v.co.x, 5), round(v.co.y, 5), round(v.co.z, 5))
               for v in mesh.vertices)
    fs = tuple((tuple(p.vertices), p.material_index) for p in mesh.polygons)
    return hashlib.sha256(repr((vs, fs)).encode()).hexdigest()


def _short_roof_metrics(mesh):
    """从 Warehouse_Short 网格实测主屋面顶皮与立缝檐口端（修复前后对比用）。

    取 y ≈ Y_RIDGE（脊线，z 顶 9.36）与 y ≈ ye-0.06（檐口倒角起点）两个顶皮采样点，
    线性外推到 ±Y 墙线（y = Y_RIDGE ± 2.89），即为该处顶皮高度；再取 y≈1.84 的
    最低 IRON 顶点作为立缝檐口端底皮，差值即"悬空"量。
    """
    G = lod0("SN_HT_Warehouse_Short")
    ridge_y = G.Y_RIDGE
    ye = ridge_y + G.ROOF_EAVE_DY - 0.06

    def top_z_at(y0):
        zs = [v.co.z for v in mesh.vertices if abs(v.co.y - y0) < 1e-4 and 7.0 < v.co.z < 9.5]
        return max(zs) if zs else None

    z_ridge = top_z_at(ridge_y)
    z_eave = top_z_at(ye)
    wall_line = G.EAVE_Z
    out = {"ridge_top_z": round(z_ridge, 5) if z_ridge else None,
           "eave_top_z_at_%0.3f" % ye: round(z_eave, 5) if z_eave else None,
           "wall_line_z": wall_line}
    if z_ridge and z_eave:
        slope = (z_ridge - z_eave) / (ye - ridge_y)
        y_wall = ridge_y + (G.WALL_YP - ridge_y)
        z_at_wall = z_ridge - (y_wall - ridge_y) * slope
        out["effective_slope"] = round(slope, 6)
        out["top_z_at_wall_line"] = round(z_at_wall, 5)
        out["top_minus_wall_line_cm"] = round((z_at_wall - wall_line) * 100.0, 3)
    seam_y = ridge_y + G.ROOF_EAVE_DY - 0.08
    seam_bottoms = [v.co.z for v in mesh.vertices
                    if abs(v.co.y - seam_y) < 0.016 and 7.15 < v.co.z < 7.50]
    if seam_bottoms and z_ridge and z_eave:
        slope = (z_ridge - z_eave) / (ye - ridge_y)
        roof_at_seam = z_ridge - (seam_y - ridge_y) * slope
        out["seam_bottom_z"] = round(min(seam_bottoms), 5)
        out["seam_float_cm"] = round((min(seam_bottoms) - roof_at_seam) * 100.0, 3)
    return out


def _pre_fix_short_metrics(current_mesh):
    """用 .design/buildings/iron_harbor/a1/warehouse_short_pre_fix.py（HEAD 版本生成器）
    重建修复前的 Warehouse_Short 几何并在内存里测量——檐口修复的"修复前"数字来自
    实际旧参数化真源的运行，不是手算。返回 (before_metrics, vertex_delta)。"""
    import bpy

    path = os.path.join(OUT_DIR, "warehouse_short_pre_fix.py")
    if not os.path.exists(path):
        return None, None
    try:
        old = _load_file(path, "warehouse_short_pre_fix_source")
        part = old.build_all_geometry()[old.NAME]
    except Exception as exc:      # noqa: BLE001 - 旧源不可用时只记录原因
        return None, {"error": repr(exc)}
    mesh = bpy.data.meshes.new("TMP_PRE_FIX_SHORT_mesh")
    mesh.from_pydata([tuple(v) for v in part.verts], [],
                     [list(f) for f, _m in part.faces])
    mesh.update()
    obj = bpy.data.objects.new("TMP_PRE_FIX_SHORT", mesh)
    bpy.context.scene.collection.objects.link(obj)
    try:
        before = _short_roof_metrics(mesh)
        old_co = [tuple(round(c, 5) for c in v) for v in part.verts]
        new_co = [tuple(round(c, 5) for c in v.co) for v in current_mesh.vertices]
        changed = 0
        max_delta = 0.0
        for a, b in zip(old_co, new_co):
            d = max(abs(a[i] - b[i]) for i in range(3))
            if d > 1e-6:
                changed += 1
                max_delta = max(max_delta, d)
        delta = {"tris_before": tri_count(part.faces),
                 "tris_after": len(current_mesh.loop_triangles),
                 "verts_before": len(part.verts), "verts_after": len(current_mesh.vertices),
                 "changed_vertices": changed,
                 "max_vertex_delta_m": round(max_delta, 6)}
        return before, delta
    finally:
        bpy.data.objects.remove(obj, do_unlink=True)
        if mesh.users == 0:
            bpy.data.meshes.remove(mesh)


def _excuse_names():
    return {"%s_LOD0" % s["asset"] for s in LOD1_SPECS} | \
           {"%s_LOD1" % s["asset"] for s in LOD1_SPECS}


def scene_digest(exclude_names=None):
    """除 10 个套件对象外的全场景指纹（含几何哈希、世界矩阵、材质槽、集合、可见性）。"""
    import hashlib
    import json
    import bpy

    exclude = set(exclude_names or _excuse_names())
    rows = []
    for o in bpy.data.objects:
        if o.name in exclude:
            continue
        mesh = o.data if o.type == "MESH" else None
        tris = 0
        if mesh:
            mesh.calc_loop_triangles()
            tris = len(mesh.loop_triangles)
        mw = o.matrix_world
        rows.append({
            "name": o.name, "type": o.type,
            "data": o.data.name if o.data else None,
            "loc": [round(v, 6) for v in o.location],
            "rot": [round(v, 6) for v in o.rotation_euler],
            "scale": [round(v, 6) for v in o.scale],
            "dims": [round(v, 6) for v in o.dimensions],
            "world": [round(mw[i][j], 6) for i in range(4) for j in range(4)],
            "hide_render": bool(o.hide_render), "hide_viewport": bool(o.hide_viewport),
            "parent": o.parent.name if o.parent else None,
            "colls": sorted(c.name for c in o.users_collection),
            "mats": [m.name if m else None for m in (mesh.materials if mesh else [])],
            "geo": _geo_sig(o) if o.type == "MESH" else None,
            "tris": tris,
        })
    rows.sort(key=lambda r: r["name"])
    digest = hashlib.sha256(json.dumps(rows, sort_keys=True).encode()).hexdigest()
    return digest, len(rows), rows


def _collection_state():
    import bpy
    return {c.name: {"objects": len(c.objects),
                     "children": sorted(ch.name for ch in c.children)}
            for c in bpy.data.collections}


def build_all():
    """重建 5 栋 LOD0（验证可复现）+ 新建 5 栋 LOD1；只删/建本批 10 个对象。"""
    import bpy

    collection = _ensure_collection()
    mats = _load_materials()
    targets = _excuse_names()

    # 1) 基线：重建前的 LOD0 几何签名（可复现证据）+ 全场景 digest
    _PREBUILD.clear()
    for spec in LOD1_SPECS:
        obj = bpy.data.objects.get(spec["asset"] + "_LOD0")
        if obj is not None:
            mesh = obj.data
            mesh.calc_loop_triangles()
            xs = [v.co.x for v in mesh.vertices]
            ys = [v.co.y for v in mesh.vertices]
            zs = [v.co.z for v in mesh.vertices]
            _PREBUILD[obj.name] = {
                "geo_sig": _geo_sig(obj), "tris": len(mesh.loop_triangles),
                "verts": len(mesh.vertices),
                "size": [round(max(xs) - min(xs), 6), round(max(ys) - min(ys), 6),
                         round(max(zs) - min(zs), 6)],
                "zmin": round(min(zs), 9),
                "verts_co": [tuple(round(c, 5) for c in v.co) for v in mesh.vertices],
            }
            if spec["asset"] == "SN_HT_Warehouse_Short":
                _PREBUILD[obj.name]["roof_metrics"] = _short_roof_metrics(mesh)
    _BASELINE["digest"], _BASELINE["count"], _BASELINE["rows"] = scene_digest(targets)
    _BASELINE["collections"] = _collection_state()
    _BASELINE["materials"] = sorted(m.name for m in bpy.data.materials)
    _BASELINE["objects_total"] = len(bpy.data.objects)

    # 2) 只删本批 10 个对象（集合内、名字精确匹配）
    for obj in list(collection.objects):
        if obj.name in targets:
            old_mesh = obj.data
            bpy.data.objects.remove(obj, do_unlink=True)
            if old_mesh is not None and old_mesh.users == 0:
                bpy.data.meshes.remove(old_mesh)
    for stale in [me for me in bpy.data.meshes
                  if me.users == 0 and me.name.split("_mesh")[0] in targets]:
        bpy.data.meshes.remove(stale)

    # 3) 重建 5 栋 LOD0（用现有生成器，证明可复现；Warehouse_Short 含檐口修复）
    built = []
    for spec in LOD1_SPECS:
        G = lod0(spec["asset"])
        if spec["asset"] == "SN_HT_Warehouse_Long":
            part = G.build_warehouse_long()
        else:
            part = G.build_all_geometry()[G.NAME]
        name = spec["asset"] + "_LOD0"
        obj = _make_object(name, part, spec["lod0_location"], collection, _grey_material)
        tex = _apply_cells(obj, spec["cells"])
        _RESULTS[name] = {"spec": spec, "lod": "LOD0", "object": obj, "part": part,
                          "texture": tex, "gen": G}
        built.append((name, tri_count(part.faces)))

    # 4) 新建 5 栋 LOD1
    _check_sources()
    for spec in LOD1_SPECS:
        part = BUILDERS[spec["asset"]]()
        name = spec["asset"] + "_LOD1"
        obj = _make_object(name, part, spec["location"], collection, _grey_material)
        tex = _apply_cells(obj, spec["cells"])
        _RESULTS[name] = {"spec": spec, "lod": "LOD1", "object": obj, "part": part,
                          "texture": tex, "gen": lod0(spec["asset"])}
        built.append((name, tri_count(part.faces)))

    bpy.context.view_layer.update()
    return built


def _mesh_metrics(obj):
    import bmesh
    import bpy  # noqa: F401  (确保 Blender 环境)

    mesh = obj.data
    mesh.calc_loop_triangles()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    loose = sum(1 for v in bm.verts if not v.link_edges)
    degen = sum(1 for f in bm.faces if f.calc_area() < 1e-9)
    nonman = sum(1 for e in bm.edges if not e.is_manifold)
    boundary = sum(1 for e in bm.edges if e.is_boundary)
    bm.free()
    xs = [v.co.x for v in mesh.vertices]
    ys = [v.co.y for v in mesh.vertices]
    zs = [v.co.z for v in mesh.vertices]
    return {
        "tris": len(mesh.loop_triangles), "verts": len(mesh.vertices),
        "size": [round(max(xs) - min(xs), 4), round(max(ys) - min(ys), 4),
                 round(max(zs) - min(zs), 4)],
        "bbox": [[round(min(xs), 6), round(min(ys), 6), round(min(zs), 6)],
                 [round(max(xs), 6), round(max(ys), 6), round(max(zs), 6)]],
        "zmin": round(min(zs), 6),
        "pivot_xy": [round(0.5 * (min(xs) + max(xs)), 6),
                     round(0.5 * (min(ys) + max(ys)), 6)],
        "loose_verts": loose, "degenerate_faces": degen,
        "non_manifold_edges": nonman, "boundary_edges": boundary,
        "material_slots": [m.name if m else None for m in mesh.materials],
    }


def report():
    """逐栋自检 + LOD0↔LOD1 对比 + LOD0 可复现 + 檐口修复前后 + 全场景回归。"""
    import json
    import os
    import bpy

    os.makedirs(OUT_DIR, exist_ok=True)
    mats = _load_materials()
    out = {"objects": {}, "checks_by_lod": {}, "regression": {}, "cornice_fix": {}}

    for spec in LOD1_SPECS:
        for lod in ("LOD0", "LOD1"):
            name = spec["asset"] + "_" + lod
            entry = _RESULTS.get(name)
            if entry is None:
                out["objects"][name] = {"missing": True}
                continue
            obj = entry["object"]
            # 本栋的 cell 必须在测量前重新写回（全局 datablock 坑）
            tex = _apply_cells(obj, spec["cells"])
            verify = tex.get("verify") or {}
            vchecks = verify.get("checks") or {}
            met = _mesh_metrics(obj)
            target = spec["target"]
            checks = {
                "tris_within_cap": met["tris"] <= (spec["cap"] if lod == "LOD1" else spec["lod0_cap"]),
                "size_matches_target_0.02": all(
                    abs(met["size"][i] - target[i]) <= 0.02 for i in range(3)),
                "grounded_zmin_zero": abs(met["zmin"]) <= 1e-6,
                "pivot_ground_centre": abs(met["pivot_xy"][0]) <= 1e-6 and
                                       abs(met["pivot_xy"][1]) <= 1e-6,
                "material_slots_le_6": 0 < len(met["material_slots"]) <= MAX_MATERIAL_SLOTS,
                "palette_only": all(m in mats.MATERIAL_SURFACES
                                    for m in met["material_slots"] if m),
                "loose_verts_zero": met["loose_verts"] == 0,
                "degenerate_faces_zero": met["degenerate_faces"] == 0,
                "non_manifold_zero": met["non_manifold_edges"] == 0,
                "boundary_edges_zero": met["boundary_edges"] == 0,
                "uv_loops_complete": bool(vchecks.get("uv_loops_complete")),
                "uv_projection_ok": bool(vchecks.get("uv_projection_ok")),
                "no_collapsed_uv_faces": bool(vchecks.get("no_collapsed_uv_faces")),
                "all_images_bound": bool(vchecks.get("all_images_bound")),
                "images_512": bool(vchecks.get("images_512")),
                "geometry_unchanged_by_uv": bool(tex.get("geometry_unchanged")),
            }
            checks["all_pass"] = all(checks.values())
            out["objects"][name] = {
                "asset": spec["asset"], "lod": lod, "object": obj.name,
                "location": list(spec["location"] if lod == "LOD1" else spec["lod0_location"]),
                "target": list(target),
                "cap": spec["cap"] if lod == "LOD1" else spec["lod0_cap"],
                "measured": met,
                "uv": {"uv_layer": tex.get("uv_layer"), "uv_loops": tex.get("uv_loops"),
                       "uv_range_u": tex.get("uv_range_u"),
                       "uv_range_v": tex.get("uv_range_v"),
                       "textured_slots": tex.get("textured_slots"),
                       "bound_images": verify.get("bound_images"),
                       "material_usage": verify.get("material_usage"),
                       "cells": spec["cells"] or "default(M1 warehouse_long)"},
                "checks": checks,
                "design": DESIGN_L1.get(spec["asset"]) if lod == "LOD1" else None,
            }

        rec0 = out["objects"].get(spec["asset"] + "_LOD0", {})
        rec1 = out["objects"].get(spec["asset"] + "_LOD1", {})
        if rec0.get("measured") and rec1.get("measured"):
            m0, m1 = rec0["measured"], rec1["measured"]
            delta = [round(m1["size"][i] - m0["size"][i], 6) for i in range(3)]
            bbox_delta = [round(m1["bbox"][0][i] - m0["bbox"][0][i], 6) for i in range(3)] + \
                         [round(m1["bbox"][1][i] - m0["bbox"][1][i], 6) for i in range(3)]
            ratio = m1["tris"] / float(m0["tris"]) if m0["tris"] else None
            out["checks_by_lod"][spec["asset"]] = {
                "lod0_tris": m0["tris"], "lod1_tris": m1["tris"],
                "lod1_cap": spec["cap"], "tri_ratio": round(ratio, 5) if ratio else None,
                "cap_35pct_ok": m1["tris"] <= spec["cap"],
                "ratio_ok": m1["tris"] <= 0.35 * m0["tris"] + 1e-9,
                "bbox_size_delta_m": delta,
                "bbox_corner_delta_m": bbox_delta,
                "bbox_match_0.02": all(abs(d) <= 0.02 for d in delta) and
                                   all(abs(d) <= 0.02 for d in bbox_delta),
                "zmin_match": abs(m1["zmin"] - m0["zmin"]) <= 1e-6,
                "pivot_match": all(abs(m1["pivot_xy"][i] - m0["pivot_xy"][i]) <= 1e-6
                                   for i in range(2)),
            }

        # LOD0 可复现（重建前后几何签名对比）
        pre = _PREBUILD.get(spec["asset"] + "_LOD0")
        entry0 = _RESULTS.get(spec["asset"] + "_LOD0")
        if pre and entry0:
            obj = entry0["object"]
            sig = _geo_sig(obj)
            now = [tuple(round(c, 5) for c in v.co) for v in obj.data.vertices]
            changed = 0
            max_delta = 0.0
            if len(pre["verts_co"]) == len(now):
                for a, b in zip(pre["verts_co"], now):
                    d = max(abs(a[i] - b[i]) for i in range(3))
                    if d > 1e-6:
                        changed += 1
                        max_delta = max(max_delta, d)
            else:
                changed = -1
            measured0 = out["objects"][spec["asset"] + "_LOD0"]["measured"]
            out["checks_by_lod"].setdefault(spec["asset"], {})["reproducible"] = {
                "before_tris": pre["tris"], "after_tris": measured0["tris"],
                "tris_equal": pre["tris"] == measured0["tris"],
                "before_size": pre["size"], "after_size": measured0["size"],
                "geo_sig_equal": pre["geo_sig"] == sig,
                "changed_vertices": changed,
                "max_vertex_delta_m": round(max_delta, 6),
                "mesh_name": obj.data.name,
            }
            if spec["asset"] == "SN_HT_Warehouse_Short":
                after = _short_roof_metrics(obj.data)
                before, vdelta = _pre_fix_short_metrics(obj.data)
                out["cornice_fix"] = {
                    "before_from_head_source": before,
                    "before_from_scene_object": pre.get("roof_metrics"),
                    "after": after,
                    "vertex_delta": vdelta,
                    "expected_top_z_at_wall_line": lod0("SN_HT_Warehouse_Short").EAVE_Z,
                    "deltas": {
                        "top_gap_cm_before": (before or {}).get("top_minus_wall_line_cm"),
                        "top_gap_cm_after": after.get("top_minus_wall_line_cm"),
                        "seam_float_cm_before": (before or {}).get("seam_float_cm"),
                        "seam_float_cm_after": after.get("seam_float_cm"),
                    },
                }

    # 全场景回归
    digest, count, rows = scene_digest()
    collections = _collection_state()
    legacy = {}
    for name in ("SN_HT_Warehouse_Long", "SN_HT_Warehouse_Short", "SN_HT_Harbor_Office",
                 "SN_HT_Cargo_Shed", "SN_HT_Tavern", "SN_HT_Fence_Row",
                 "SN_HT_Dock_Worker_A", "SN_HT_Dock_Worker_B", "SN_HT_Rowboat",
                 "SN_HT_Cargo_Lighter"):
        obj = bpy.data.objects.get(name)
        legacy[name] = None if obj is None else {
            "location": [round(v, 4) for v in obj.location],
            "dims": [round(v, 4) for v in obj.dimensions],
            "colls": sorted(c.name for c in obj.users_collection),
            "tris": len(obj.data.loop_triangles) if obj.type == "MESH" else None,
        }
    baseline_rows = {r["name"]: r for r in _BASELINE.get("rows", [])}
    after_rows = {r["name"]: r for r in rows}
    missing = sorted(set(baseline_rows) - set(after_rows))
    added = sorted(set(after_rows) - set(baseline_rows))
    modified = []
    for name in sorted(set(baseline_rows) & set(after_rows)):
        a, b = baseline_rows[name], after_rows[name]
        if json.dumps(a, sort_keys=True) != json.dumps(b, sort_keys=True):
            modified.append(name)
    out["regression"] = {
        "excluded_from_digest": sorted(_excuse_names()),
        "baseline_count": _BASELINE.get("count"), "after_count": count,
        "baseline_objects_total": _BASELINE.get("objects_total"),
        "after_objects_total": len(bpy.data.objects),
        "digest_matches_baseline": _BASELINE.get("digest") == digest,
        "digest_baseline": _BASELINE.get("digest"), "digest_after": digest,
        "missing_objects": missing, "added_objects": added,
        "modified_objects": modified,
        "collections_before": _BASELINE.get("collections"),
        "collections_after": collections,
        "collections_match": _BASELINE.get("collections") == collections,
        "legacy_sn_harbor_town_row": legacy,
        "sn_harbor_town_collection_objects": len(
            bpy.data.collections.get("SN_Harbor_Town").objects
            if bpy.data.collections.get("SN_Harbor_Town") else []),
    }
    out["final_material_cells"] = {m: (bpy.data.materials[m].node_tree.nodes.get("TrimSheet").image.name
                                        if bpy.data.materials.get(m) and
                                        bpy.data.materials[m].node_tree.nodes.get("TrimSheet") else None)
                                    for m in mats.MATERIAL_SURFACES}

    with open(os.path.join(OUT_DIR, "lod1_report.json"), "w", encoding="utf-8") as handle:
        json.dump(out, handle, ensure_ascii=False, indent=1)

    brief = {
        "tri": {k: (v["measured"]["tris"], v["cap"]) for k, v in out["objects"].items()
                if v.get("measured")},
        "lod_compare": out["checks_by_lod"],
        "regression": {k: out["regression"][k] for k in
                       ("digest_matches_baseline", "baseline_count", "after_count",
                        "missing_objects", "added_objects", "modified_objects",
                        "collections_match")},
        "cornice_fix": out["cornice_fix"],
    }
    print("LOD1_REPORT " + repr(brief))
    return out


# --------------------------------------------------------------------------- #
# Blender 侧：预览渲染（EEVEE 1280×800；每栋 3 张 LOD1 + 1 张 LOD0/LOD1 同机位对比）
# --------------------------------------------------------------------------- #

_VIEWS = (
    ("street_3q", (1.0, 0.62, 0.34), 40.0, "PERSP"),
    ("front_x", (1.0, 0.0, 0.0), 40.0, "ORTHO"),
    ("roof", (0.18, 0.34, 1.0), 52.0, "PERSP"),
)


def _bbox_world(objs):
    from mathutils import Vector
    pts = []
    for o in objs:
        pts.extend(o.matrix_world @ Vector(c) for c in o.bound_box)
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


def _render(objs, centre, radius, tag, name, cam, cam_data, scene, out_dir):
    import os
    from mathutils import Vector
    files = []
    for vtag, direction, lens, ctype in _VIEWS:
        if tag and vtag != tag:
            continue
        d = Vector(direction).normalized()
        if ctype == "ORTHO":
            cam.location = centre + d * (radius * 3.4)
            cam.rotation_euler = (d * -1.0).to_track_quat("-Z", "Y").to_euler()
            cam_data.type = "ORTHO"
            cam_data.ortho_scale = max(radius * 2.0 * 1.25, 1.0)
        else:
            cam.location = centre + d * (radius * 3.2)
            cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
            cam_data.type = "PERSP"
            cam_data.lens = lens
        scene.render.resolution_x, scene.render.resolution_y = 1280, 800
        scene.render.resolution_percentage = 100
        path = os.path.join(out_dir, "%s_%s_1280x800.png" % (name, vtag))
        scene.render.filepath = path
        print("[lod1-render] %s %s cam=%s type=%s" % (
            name, vtag, tuple(round(v, 2) for v in cam.location), cam_data.type))
        import bpy
        bpy.ops.render.render(write_still=True)
        files.append(path)
    return files


def render_previews(assets=None):
    """渲染 LOD1 三视图 + LOD0/LOD1 同机位对比图（1280×800，EEVEE）。

    只在传入的资产上工作；临时相机 / 3 盏太阳 / 世界背景 / 引擎 / 分辨率全部在 finally
    里还原，临时对象删除。对比图做法：临时把 LOD1 平移到 LOD0 旁边（同一机位同时入画），
    渲染后立即还原位置。
    """
    import bpy

    bpy.context.view_layer.update()
    out_dir = SCREENSHOT_DIR
    os.makedirs(out_dir, exist_ok=True)
    scene = bpy.context.scene
    saved = {"engine": scene.render.engine,
             "res": (scene.render.resolution_x, scene.render.resolution_y,
                     scene.render.resolution_percentage),
             "filepath": scene.render.filepath, "camera": scene.camera}

    cam_data = bpy.data.cameras.new("TMP_LOD1_CAM")
    cam = bpy.data.objects.new("TMP_LOD1_CAM", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    lights = []
    for lname, energy, rot, color in (
            ("TMP_LOD1_KEY", 2.6, (48.0, 0.0, 128.0), (1.0, 0.96, 0.90)),
            ("TMP_LOD1_FILL", 0.55, (62.0, 0.0, 8.0), (0.80, 0.87, 1.0)),
            ("TMP_LOD1_RIM", 0.9, (18.0, 0.0, 210.0), (0.92, 0.94, 1.0))):
        data = bpy.data.lights.new(lname, "SUN")
        data.energy = energy
        data.angle = 0.105
        data.color = color
        ob = bpy.data.objects.new(lname, data)
        ob.rotation_euler = [math.radians(v) for v in rot]
        scene.collection.objects.link(ob)
        lights.append(ob)

    world = scene.world
    bg = next((n for n in world.node_tree.nodes if n.type == "BACKGROUND"), None) \
        if world and world.node_tree else None
    saved_bg = tuple(bg.inputs["Color"].default_value) if bg else None
    saved_strength = float(bg.inputs["Strength"].default_value) if bg else None
    if bg:
        bg.inputs["Color"].default_value = (0.040, 0.045, 0.055, 1.0)
        bg.inputs["Strength"].default_value = 0.35
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    if hasattr(scene, "eevee"):
        scene.eevee.taa_render_samples = 32
    saved_image = (scene.render.image_settings.file_format,
                   scene.render.image_settings.color_mode)
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"

    wanted = set(assets) if assets else {s["asset"] for s in LOD1_SPECS}
    managed = _excuse_names()
    hidden = {}
    for o in bpy.data.objects:
        if o.type == "MESH":
            hidden[o] = o.hide_render
            o.hide_render = True
    files = []
    moved = {}
    try:
        for spec in LOD1_SPECS:
            if spec["asset"] not in wanted:
                continue
            entry1 = _RESULTS.get(spec["asset"] + "_LOD1")
            entry0 = _RESULTS.get(spec["asset"] + "_LOD0")
            if entry1 is None or entry0 is None:
                continue
            obj1, obj0 = entry1["object"], entry0["object"]
            _apply_cells(obj1, spec["cells"])
            _apply_cells(obj0, spec["cells"])
            obj1.hide_render = False
            bpy.context.view_layer.update()
            lo, hi = _bbox_world([obj1])
            centre = (lo + hi) * 0.5
            radius = max((hi - lo).length * 0.5, 1.0)
            files += _render([obj1], centre, radius, None,
                             "%s_LOD1" % spec["asset"], cam, cam_data, scene, out_dir)
            # ---- 同机位对比：LOD1 临时移到 LOD0 +X 侧，两个对象同框 ----
            obj0.hide_render = False
            width0 = (obj0.dimensions.x if obj0.dimensions.x > 0 else
                      abs(spec["target"][0]))
            moved[obj1] = tuple(obj1.location)
            obj1.location = (obj0.location.x + width0 + 3.0, obj0.location.y, 0.0)
            bpy.context.view_layer.update()
            lo, hi = _bbox_world([obj0, obj1])
            centre = (lo + hi) * 0.5
            radius = max((hi - lo).length * 0.5, 1.0)
            files += _render([obj0, obj1], centre, radius, None,
                             "%s_LOD1_vs_LOD0" % spec["asset"], cam, cam_data, scene,
                             out_dir)
            for o, loc in moved.items():
                o.location = loc
            moved.clear()
            obj1.hide_render = True
            obj0.hide_render = True
            bpy.context.view_layer.update()
    finally:
        for o, loc in moved.items():
            o.location = loc
        for o, state in hidden.items():
            try:
                o.hide_render = state
            except ReferenceError:
                pass
        for ob in lights:
            data = ob.data
            bpy.data.objects.remove(ob, do_unlink=True)
            bpy.data.lights.remove(data)
        bpy.data.objects.remove(cam, do_unlink=True)
        bpy.data.cameras.remove(cam_data)
        if bg is not None and saved_bg is not None:
            bg.inputs["Color"].default_value = saved_bg
            if saved_strength is not None:
                bg.inputs["Strength"].default_value = saved_strength
        scene.render.image_settings.file_format, scene.render.image_settings.color_mode = saved_image
        scene.camera = saved["camera"]
        scene.render.engine = saved["engine"]
        scene.render.resolution_x, scene.render.resolution_y, \
            scene.render.resolution_percentage = saved["res"]
        scene.render.filepath = saved["filepath"]
    print("LOD1_PREVIEW " + repr({"count": len(files),
                                  "files": [os.path.basename(f) for f in files]}))
    return files


if "bpy" in globals():   # executed inside Blender
    print("sn_iron_harbor_architecture_lod1_generator: call build_all() / report() / "
          "render_previews(assets=None); pure-python dryrun: build_all_geometry()")
