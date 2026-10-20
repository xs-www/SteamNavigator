# -*- coding: utf-8 -*-
# @static-doc
# 作用：铁港建筑套件**批次 B**（三栋新原型 LOD0 + LOD1）的**参数化真源生成器 + Blender 侧
# 装配/自检/渲染 harness**：纯 Python 生成 `SN_HT_Boiler_House` / `SN_HT_Workshop_Row` /
# `SN_HT_Brick_Tenement` 的 LOD0 与 LOD1 单 mesh 几何，并负责工作台建对象、共享材质/UV、逐栋门禁
# 自检、LOD0↔LOD1 bbox 对比、全场景 digest 回归与 EEVEE 预览渲染（含 LOD0/LOD1 同机位对比）。
# 第二阶段 LOD1 使用同一份 LOD0 真源常量，只保留需求 §6 的轮廓识别点。
#
# - 关键依赖：`sn_iron_harbor_materials.py`（6 个 `SN_Town_*` 材质 + trim-sheet cell + 盒投影 UV）、
#   `sn_iron_harbor_kit_batch2.py`（report/render 模板参考）、
#   `docs/design/MODELING_REQUIREMENTS_NEXT_BATCH.md` §6.1–6.4（尺寸/tri/必须包含项/轮廓门禁）、
#   `docs/design/IRON_HARBOR_ARCHITECTURE_PROTOTYPES_LOD0_BUILD.md`（构建报告 + LOD1 章节）。
#
# ## 契约与约束
# - **参数化真源唯一**：三栋的尺寸、墙线、开洞表、构件坐标全部由本文件的模块常量与
#   `build_boiler_house() / build_workshop_row() / build_brick_tenement()`（LOD0）及
#   `build_*_lod1()`（LOD1，读同一组常量）生成；导出都从这里重建；禁止只在 `.blend` 里手改。
# - **三角面区间/上限**：LOD0 = BH/WR 6 000–7 500（cap 8 000）、BT 9 000–12 000（cap 14 000）；
#   LOD1 = BH/WR cap 2 800、BT cap 4 900，且 ≤ 对应 LOD0 实测的 35%（dryrun/Blender 双重校验）。
# - **必须包含项**（需求 §6）：BH = 错落屋顶 + 高砖烟囱 + 外露粗管 + 侧墙百叶 + 煤槽/灰斗 +
#   检修平台；WR = 3 个连续工坊 bay + ≥2 种门宽 + 锯齿采光顶 + 墙面风机 + 雨棚 + 外置楼梯/猫道；
#   BT = 三层砖立面 + 成列真凹窗洞 + 转角壁柱 + 后侧铁质逃生楼梯 + 多个烟囱 + 首层小店雨棚/封板。
#   每个必须项/轮廓点在 `Part` 里用 `m.group(tag)` 打标，`report()` / `report_lod1()` 用 tag 的
#   面数/tri/包围盒给出**几何证据**（不是口头声明）。
# - **LOD1 保留/删除**：保留外轮廓、屋顶、主要开口、烟囱/平台/楼梯等大轮廓；删除窗框/窗棂/窗台
#   窗楣/隅石/落水管/次要管线，百叶改整板、栏杆改连续实体板、屋面立缝减半（见 `LOD1_SPECS`）。
# - **通用门禁**：+X 为正向；轴心底面中心（zmin=0、x/y 包围盒中心 = 0）；LOD1 与 LOD0 局部 bbox
#   逐轴 ≤0.02 m；材质槽 ≤6 且只用 `SN_Town_*`；窗/门真凹口；网格健康孤立点/退化面/非流形边/
#   边界边 = 0（每个实体闭合，独立闭合实体拼装）。
# - **只动本批对象**：`build_all()` 只删/建 3 个 LOD0，`build_lod1()` 只删/建 3 个 LOD1（y=225）；
#   所有其它对象（A 批 10 个 + 三栋 LOD0 + 旧场景）不得被改动（digest 回归）。
#   不保存 `.blend`、不导出 GLB、不改 framework/dev_mods/manifest/tests/docs-static/todo/ASSET_MAP。
# - **共享材质坑**：6 个 `SN_Town_*` 是全局 datablock，`apply_to_object(cells=...)` 每次重建
#   node tree，所以测量/渲染前必须"轮到谁就重写一次"（`_apply_cells`；LOD1 沿用 LOD0 cells）。
#
# ## 重点逻辑
# ### `Part.group(tag)` + `feature_report()`
# - 每个必须包含项/立面构件在生成时用 `with m.group("chimney"): ...` 打标；`feature_report()`
#   把标签翻译成「面数 / tri / 包围盒」，供 report 输出硬证据（如 chimney 顶 z=12.00）。
# ### `build_boiler_house()` / `build_workshop_row()` / `build_brick_tenement()`
# - 三栋 LOD0 全部用同一套闭合实体工具（`box / tb / prism_* / panel / lprism_u / lbox / beam /
#   rod / arch_band`）拼装：石基 → 带真凹口的墙板 → 屋顶 → 附件。
# ### `build_*_lod1()` + `build_all_geometry_lod1()`
# - 读同一组 LOD0 常量重建简化外壳：BH 保留烟囱/3 条主粗管/检修平台（连续栏板）/错落屋顶/煤场围墙；
#   WR 保留 3 联锯齿顶 + 3 面天窗带 + 3 樘不同宽 bay 门 + 外置楼梯/猫道 + 风机；BT 保留三层体量/
#   主立面凹窗/店面封板/3 烟囱/逃生楼梯大轮廓。纯 Python 入口供 `dryrun_prototypes_lod1.py` 干跑。
# ### `build_all()` / `report()` / `render_previews()`（LOD0）
# - `build_all()`：先删旧 LOD0 再抓基线 → 只建 3 个对象 → 按栋写共享材质/UV。
# - `report()`：tri 区间/上限、尺寸 ±0.10、zmin/轴心、材质槽、网格健康、UV/贴图、必须项证据、
#   墙面打断、差异项、全场景 digest 回归；落盘 `prototypes_report.json`。
# - `render_previews()`：EEVEE 1280×800，每栋 3 张 + 三栋 lineup；`finally` 还原相机/灯/世界/
#   引擎/分辨率/隐藏状态并删临时对象。
# ### `build_lod1()` / `report_lod1()` / `render_lod1_previews()`（LOD1，y=225）
# - `build_lod1()`：先删旧 LOD1 再抓基线（258 对象）→ 建 3 个 LOD1 → 按栋写同一 cells；
# - `report_lod1()`：cap/35%、LOD0↔LOD1 bbox/轴心对比、健康/UV/轮廓 tag 证据、全场景 digest 回归
#   （期望 258→261，除 3 个 LOD1 外零改动，LOD0/A 批逐对象状态不变）；落盘 `lod1_report.json`。
# - `render_lod1_previews()`：每栋 3 张 LOD1 + 3 张 LOD0/LOD1 同机位对比（LOD1 临时平移，渲染后
#   还原），命名含 `_LOD1_` / `_LOD1_vs_LOD0_`；`finally` 还原所有临时场景状态。
# @end-static-doc

import importlib.util
import math
import os
from contextlib import contextmanager

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
COLLECTION = "SN_Iron_Harbor_Architecture"
PREFIX = "SN_HT_"
MAX_MATERIAL_SLOTS = 6
OUT_DIR = os.path.join(REPO_ROOT, ".design", "buildings", "iron_harbor", "b1")
SCREENSHOT_DIR = os.path.join(REPO_ROOT, "docs", "design", "screenshots",
                              "iron_harbor_architecture")

BRICK = "SN_Town_Brick"
PLASTER = "SN_Town_Plaster"
WOOD = "SN_Town_Wood"
IRON = "SN_Town_Iron"
STONE = "SN_Town_Stone"
GLASS = "SN_Town_Glass"
PALETTE = (BRICK, PLASTER, WOOD, IRON, STONE, GLASS)

# --------------------------------------------------------------------------- #
# 三栋新原型：目标尺寸 / tri 区间 / 硬上限 / 工作台摆放 / 共享材质 cell 方案
#   - 工作台 y=200 一排（x=-45 / 0 / 45），不与 y=110/150 的 5 栋 LOD0、y=175 的 5 栋 LOD1 冲突。
#   - cells 每栋不同：BH 烟熏砖 + 锈铁（锅炉房）；WR 干净砖 + 反射玻璃（工坊）；
#     BT 暖砖 + 脏石基 + 风化木（住宅/小店），同图集不同行，不新增贴图。
# --------------------------------------------------------------------------- #
PROTOTYPES = [
    {
        "asset": "SN_HT_Boiler_House",
        "kind": "boiler_house",
        "target": (12.0, 10.0, 12.0),
        "tris_band": (6000, 7500),
        "cap": 8000,
        "location": (-45.0, 200.0, 0.0),
        "cells": {"SN_Town_Brick": "brick_wall_soot", "SN_Town_Plaster": "plaster_grime",
                  "SN_Town_Wood": "wood_plank_weathered", "SN_Town_Iron": "iron_rust",
                  "SN_Town_Stone": "stone_base_dirty", "SN_Town_Glass": "glass_dark"},
    },
    {
        "asset": "SN_HT_Workshop_Row",
        "kind": "workshop_row",
        "target": (18.0, 7.0, 8.5),
        "tris_band": (6000, 7500),
        "cap": 8000,
        "location": (0.0, 200.0, 0.0),
        "cells": {"SN_Town_Brick": "brick_wall", "SN_Town_Plaster": "plaster_light",
                  "SN_Town_Wood": "wood_plank", "SN_Town_Iron": "iron_dark",
                  "SN_Town_Stone": "stone_base", "SN_Town_Glass": "glass_reflect"},
    },
    {
        "asset": "SN_HT_Brick_Tenement",
        "kind": "brick_tenement",
        "target": (10.0, 8.0, 12.0),
        "tris_band": (9000, 12000),
        "cap": 14000,
        "location": (45.0, 200.0, 0.0),
        "cells": {"SN_Town_Brick": "brick_wall", "SN_Town_Plaster": "plaster_grime",
                  "SN_Town_Wood": "wood_plank_weathered", "SN_Town_Iron": "iron_dark",
                  "SN_Town_Stone": "stone_base_dirty", "SN_Town_Glass": "glass_dark"},
    },
]

# dryrun_props.py 约定
ITEMS = [("%s_LOD0" % p["asset"], p["location"], p["cap"], p["target"]) for p in PROTOTYPES]
TOTAL_BUDGET = sum(p["cap"] for p in PROTOTYPES)

# 必须包含项（需求 §6）→ 生成器内的 Part tag
REQUIRED_FEATURES = {
    "SN_HT_Boiler_House": ["stone_base", "main_walls", "annex_walls", "roof_main", "roof_annex",
                           "chimney", "pipes", "platform", "louvers", "coal_chute",
                           "windows", "doors", "cornices", "pilasters"],
    "SN_HT_Workshop_Row": ["stone_base", "walls", "sawtooth_roof", "clerestory_glazing",
                           "bay_doors", "windows", "wall_fans", "canopies",
                           "external_stair", "catwalk", "pilasters", "cornices"],
    "SN_HT_Brick_Tenement": ["stone_base", "walls", "windows", "corner_piers", "string_courses",
                             "cornice", "parapet", "chimneys", "fire_escape", "shopfront",
                             "awning", "doors", "downpipes"],
}

# 与现有 5 栋的差异（需求 §6.4：屋顶 / 开口节奏 / 附件组合 / 主色，至少三项不同）
VARIATION = {
    "SN_HT_Boiler_House": {
        "roof": "双坡主屋面（8.7）+ 低平附房屋面（4.8）+ 高砖烟囱（12.0）错落三段",
        "opening_rhythm": "主立面 2 个高窗 + 工业山墙；长墙 3 组高窗 + 百叶/煤槽（非住宅窗列）",
        "attachments": "外露蒸汽管、检修平台 + 栏杆、侧墙百叶、煤槽/灰斗、烟囱爬梯",
        "palette": "brick_wall_soot + iron_rust + stone_base_dirty（烟熏工业档）",
        "unlike_existing": "现有 5 栋没有烟囱塔 + 外露管线 + 平台组合；屋顶为双坡+平顶错落，不是单一体量",
    },
    "SN_HT_Workshop_Row": {
        "roof": "3 联锯齿采光顶（每跨 5.6 m，垂直玻璃天窗面 + 高侧椽口）",
        "opening_rhythm": "3 个连续工坊 bay，门宽 3.6 / 2.4 / 3.0 三种，门上方高窗；长墙节奏均匀",
        "attachments": "墙面风机 ×2、铁雨棚 ×2、外置楼梯 + 连廊猫道、山墙工坊招牌",
        "palette": "brick_wall + glass_reflect + iron_dark（干净工业档）",
        "unlike_existing": "现有 5 栋无锯齿顶、无连续 3 bay 门节奏、无外置楼梯/猫道",
    },
    "SN_HT_Brick_Tenement": {
        "roof": "平屋面 + 女儿墙 + 3 个砖烟囱（10.7–12.0），无塔楼",
        "opening_rhythm": "三层砖立面：首层店面封板 + 2/3 层各 3 扇成列凹窗（窗间墙窄）",
        "attachments": "外挂铁质逃生楼梯（3 平台 + 2 梯段）、转角壁柱/隅石、层间石腰带、店招雨棚",
        "palette": "brick_wall + plaster_grime + stone_base_dirty + glass_dark（暖砖住宅档）",
        "unlike_existing": "窄高街屋 + 多烟囱 + 外挂逃生楼梯，与港务办公楼（钟楼地标）明显区分",
    },
}


# 真实凹深证据（窗 ≥0.08 / 门 ≥0.12，单位 m；与各 build_* 的 panel openings 一一对应）
RECESS = {
    "SN_HT_Boiler_House": {"windows": [0.16, 0.16, 0.16, 0.16, 0.16, 0.14, 0.12],
                           "doors": [0.28, 0.24, 0.24]},
    "SN_HT_Workshop_Row": {"windows": [0.16, 0.16, 0.16, 0.16, 0.16, 0.16, 0.14, 0.12],
                           "doors": [0.28, 0.24, 0.26]},
    "SN_HT_Brick_Tenement": {"windows": [0.16, 0.16, 0.12],
                             "doors": [0.20, 0.24, 0.30]},
}


def _check_specs():
    for spec in PROTOTYPES:
        if not (spec["tris_band"][0] <= spec["cap"] <= 20000):
            raise RuntimeError("bad budget declaration: %r" % (spec,))


# =========================================================================== #
# 1. 闭合实体工具（与 kit / batch2 生成器同一套语言；纯 Python，不 import bpy）
# =========================================================================== #

class Part:
    """顶点 / 面 / 每面材质的累积器，附带 `group(tag)` 特征打标。"""

    def __init__(self):
        self.verts = []
        self.faces = []
        self.tags = []          # [(tag, face_start, face_end), ...]
        self._open = []

    def add(self, verts, faces, material):
        offset = len(self.verts)
        self.verts.extend(verts)
        for face in faces:
            self.faces.append((tuple(i + offset for i in face), material))

    def add_multi(self, verts, faces):
        offset = len(self.verts)
        self.verts.extend(verts)
        for face, material in faces:
            self.faces.append((tuple(i + offset for i in face), material))

    @contextmanager
    def group(self, tag):
        start = len(self.faces)
        self._open.append(tag)
        try:
            yield
        finally:
            self._open.pop()
            self.tags.append((tag, start, len(self.faces)))


def _tri(faces):
    return sum(max(0, len(f) - 2) for f, _m in faces)


def feature_report(part, digits=4):
    """tag → {faces, tris, bbox}（用真实几何给"必须包含项"作证）。"""
    out = {}
    for tag, start, end in part.tags:
        sub = part.faces[start:end]
        if not sub:
            continue
        idx = set()
        for face, _m in sub:
            idx.update(face)
        xs = [part.verts[i][0] for i in idx]
        ys = [part.verts[i][1] for i in idx]
        zs = [part.verts[i][2] for i in idx]
        rec = out.setdefault(tag, {"faces": 0, "tris": 0,
                                   "bbox": [[float("inf")] * 3, [float("-inf")] * 3]})
        rec["faces"] += len(sub)
        rec["tris"] += _tri(sub)
        rec["bbox"][0] = [round(min(rec["bbox"][0][0], min(xs)), digits),
                          round(min(rec["bbox"][0][1], min(ys)), digits),
                          round(min(rec["bbox"][0][2], min(zs)), digits)]
        rec["bbox"][1] = [round(max(rec["bbox"][1][0], max(xs)), digits),
                          round(max(rec["bbox"][1][1], max(ys)), digits),
                          round(max(rec["bbox"][1][2], max(zs)), digits)]
    return out


def rect_pts(x0, x1, y0, y1, z):
    return [(x0, y0, z), (x1, y0, z), (x1, y1, z), (x0, y1, z)]


def hexa(bottom, top):
    verts = list(bottom) + list(top)
    faces = [(0, 3, 2, 1), (4, 5, 6, 7),
             (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    return verts, faces


def box(lo, hi):
    x0, x1 = sorted((lo[0], hi[0]))
    y0, y1 = sorted((lo[1], hi[1]))
    z0, z1 = sorted((lo[2], hi[2]))
    return hexa(rect_pts(x0, x1, y0, y1, z0), rect_pts(x0, x1, y0, y1, z1))


def tb(x0, x1, y0, y1, z0, z1, ti=0.0):
    """收分盒：顶面相对底面四边内收 ti。"""
    x0, x1 = sorted((x0, x1))
    y0, y1 = sorted((y0, y1))
    ti = min(ti, 0.45 * (x1 - x0), 0.45 * (y1 - y0))
    return hexa(rect_pts(x0, x1, y0, y1, z0),
                rect_pts(x0 + ti, x1 - ti, y0 + ti, y1 - ti, z1))


def prism_z(pts, z0, z1):
    n = len(pts)
    verts = [(x, y, z0) for x, y in pts] + [(x, y, z1) for x, y in pts]
    faces = [tuple(range(n - 1, -1, -1)), tuple(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, n + j, n + i))
    return verts, faces


def prism_x(pts, x0, x1):
    n = len(pts)
    verts = [(x0, y, z) for y, z in pts] + [(x1, y, z) for y, z in pts]
    faces = [tuple(range(n - 1, -1, -1)), tuple(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, n + j, n + i))
    return verts, faces


def prism_y(pts, y0, y1):
    n = len(pts)
    verts = [(x, y0, z) for x, z in pts] + [(x, y1, z) for x, z in pts]
    faces = [tuple(range(n - 1, -1, -1)), tuple(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, n + j, n + i))
    return verts, faces


def _basis(p0, p1):
    dx, dy, dz = (p1[0] - p0[0], p1[1] - p0[1], p1[2] - p0[2])
    length = math.sqrt(dx * dx + dy * dy + dz * dz)
    d = (dx / length, dy / length, dz / length)
    ref = (0.0, 0.0, 1.0) if abs(d[2]) < 0.9 else (1.0, 0.0, 0.0)
    u = (d[1] * ref[2] - d[2] * ref[1],
         d[2] * ref[0] - d[0] * ref[2],
         d[0] * ref[1] - d[1] * ref[0])
    ul = math.sqrt(u[0] ** 2 + u[1] ** 2 + u[2] ** 2)
    u = (u[0] / ul, u[1] / ul, u[2] / ul)
    v = (d[1] * u[2] - d[2] * u[1],
         d[2] * u[0] - d[0] * u[2],
         d[0] * u[1] - d[1] * u[0])
    return u, v


def sweep(p0, p1, section):
    u, v = _basis(p0, p1)
    verts = []
    for p in (p0, p1):
        for a, b in section:
            verts.append((p[0] + a * u[0] + b * v[0],
                          p[1] + a * u[1] + b * v[1],
                          p[2] + a * u[2] + b * v[2]))
    n = len(section)
    faces = []
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, n + j, n + i))
    for i in range(1, n - 1):
        faces.append((0, i + 1, i))
        faces.append((n, n + i, n + i + 1))
    return verts, faces


def beam(p0, p1, w, h=None):
    h = w if h is None else h
    return sweep(p0, p1, [(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)])


def rod(p0, p1, r, sides=8):
    pts = [(r * math.cos(2.0 * math.pi * i / sides),
            r * math.sin(2.0 * math.pi * i / sides)) for i in range(sides)]
    return sweep(p0, p1, pts)


def vchamfer_box(x0, x1, y0, y1, z0, z1, ch):
    x0, x1 = sorted((x0, x1))
    y0, y1 = sorted((y0, y1))
    z0, z1 = sorted((z0, z1))
    if x1 - x0 < 2.0 * ch or y1 - y0 < 2.0 * ch:
        return box((x0, y0, z0), (x1, y1, z1))
    pts = [(x0 + ch, y0), (x1 - ch, y0), (x1, y0 + ch), (x1, y1 - ch),
           (x1 - ch, y1), (x0 + ch, y1), (x0, y1 - ch), (x0, y0 + ch)]
    return prism_z(pts, z0, z1)


def chamfer_beam(p0, p1, w, h=None, ch=0.02):
    h = w if h is None else h
    a, b = w / 2.0, h / 2.0
    c = min(ch, a * 0.4, b * 0.4)
    section = [(-a + c, -b), (a - c, -b), (a, -b + c), (a, b - c),
               (a - c, b), (-a + c, b), (-a, b - c), (-a, -b + c)]
    return sweep(p0, p1, section)


def sides(wx, wy):
    """立面局部坐标：u = 立面水平坐标，v = 世界 Z，d = 自墙外皮向内的凹深（<0 凸出）。"""
    return {"front": ("x", wx, -1.0), "back": ("x", -wx, 1.0),
            "right": ("y", wy, -1.0), "left": ("y", -wy, 1.0)}


def lp(side, u, v, d):
    axis, plane, sign = side
    if axis == "y":
        return (u, plane + sign * d, v)
    return (plane + sign * d, u, v)


def lbox(side, u0, u1, v0, v1, d0, d1):
    return box(lp(side, u0, v0, d0), lp(side, u1, v1, d1))


def lhexa(side, rect_a, rect_b):
    def pts(r):
        return [lp(side, r[0], r[2], r[4]), lp(side, r[1], r[2], r[4]),
                lp(side, r[1], r[3], r[4]), lp(side, r[0], r[3], r[4])]
    return hexa(pts(rect_a), pts(rect_b))


def lvchamfer_box(side, u0, u1, v0, v1, d0, d1, ch):
    a = lp(side, u0, v0, d0)
    b = lp(side, u1, v1, d1)
    return vchamfer_box(a[0], b[0], a[1], b[1], a[2], b[2], ch)


def lprism_u(side, u0, u1, pts):
    n = len(pts)
    verts = [lp(side, u0, v, d) for d, v in pts] + [lp(side, u1, v, d) for d, v in pts]
    faces = [tuple(range(n - 1, -1, -1)), tuple(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, n + j, n + i))
    return verts, faces


def lprism_d(side, pts, d0, d1):
    n = len(pts)
    verts = [lp(side, u, v, d0) for u, v in pts] + [lp(side, u, v, d1) for u, v in pts]
    faces = [tuple(range(n - 1, -1, -1)), tuple(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, n + j, n + i))
    return verts, faces


def arch_band(side, uc, vc, r_in, r_out, d0, d1, a0, a1, segs):
    """局部 (u,v) 平面内的圆弧环带，沿 d 挤出成闭合壳体（窗楣/门券）。"""
    rings = []
    for k in range(segs + 1):
        a = a0 + (a1 - a0) * k / float(segs)
        ca, sa = math.cos(a), math.sin(a)
        ox, oz = uc + r_out * ca, vc + r_out * sa
        ix, iz = uc + r_in * ca, vc + r_in * sa
        rings.append([lp(side, ox, oz, d0), lp(side, ox, oz, d1),
                      lp(side, ix, iz, d1), lp(side, ix, iz, d0)])
    verts = [p for r in rings for p in r]
    faces = []
    for k in range(segs):
        a_, b_ = k * 4, (k + 1) * 4
        for i in range(4):
            j = (i + 1) % 4
            faces.append((a_ + i, a_ + j, b_ + j, b_ + i))
    faces.append((3, 2, 1, 0))
    faces.append((segs * 4, segs * 4 + 1, segs * 4 + 2, segs * 4 + 3))
    return verts, faces


def panel(axis, plane, sign, u0, u1, v0, v1, t, openings,
          mat_face=BRICK, mat_reveal=STONE, mat_inner=BRICK):
    """闭合厚墙板 + 矩形真凹口（逐字沿用 kit 参考实现，凹口/侧壁/内面共享网格线）。"""
    verts = []
    index = {}

    def pid(u, v, d):
        key = (round(u, 6), round(v, 6), round(d, 6))
        i = index.get(key)
        if i is None:
            i = len(verts)
            index[key] = i
            if axis == "y":
                verts.append((u, plane + sign * d, v))
            else:
                verts.append((plane + sign * d, u, v))
        return i

    us = [u0, u1]
    vs = [v0, v1]
    for (a, b, c, d, _dep, _bm) in openings:
        us.extend([a, b])
        vs.extend([c, d])
    us = sorted(set(round(x, 6) for x in us))
    vs = sorted(set(round(x, 6) for x in vs))

    def in_opening(cu, cv):
        for (a, b, c, d, _dep, _bm) in openings:
            if a - 1e-9 <= cu <= b + 1e-9 and c - 1e-9 <= cv <= d + 1e-9:
                return True
        return False

    faces = []
    for i in range(len(us) - 1):
        for j in range(len(vs) - 1):
            cu = 0.5 * (us[i] + us[i + 1])
            cv = 0.5 * (vs[j] + vs[j + 1])
            if in_opening(cu, cv):
                continue
            faces.append(((pid(us[i], vs[j], 0.0), pid(us[i + 1], vs[j], 0.0),
                           pid(us[i + 1], vs[j + 1], 0.0), pid(us[i], vs[j + 1], 0.0)),
                          mat_face))
    for i in range(len(us) - 1):
        for j in range(len(vs) - 1):
            faces.append(((pid(us[i], vs[j], t), pid(us[i + 1], vs[j], t),
                           pid(us[i + 1], vs[j + 1], t), pid(us[i], vs[j + 1], t)),
                          mat_inner))
    for j in range(len(vs) - 1):
        faces.append(((pid(u0, vs[j], 0.0), pid(u0, vs[j + 1], 0.0),
                       pid(u0, vs[j + 1], t), pid(u0, vs[j], t)), mat_face))
        faces.append(((pid(u1, vs[j], 0.0), pid(u1, vs[j + 1], 0.0),
                       pid(u1, vs[j + 1], t), pid(u1, vs[j], t)), mat_face))
    for i in range(len(us) - 1):
        faces.append(((pid(us[i], v0, 0.0), pid(us[i + 1], v0, 0.0),
                       pid(us[i + 1], v0, t), pid(us[i], v0, t)), mat_face))
        faces.append(((pid(us[i], v1, 0.0), pid(us[i + 1], v1, 0.0),
                       pid(us[i + 1], v1, t), pid(us[i], v1, t)), mat_face))
    for (a, b, c, d, depth, back_mat) in openings:
        dz = min(depth, t - 0.05)
        va = [x for x in vs if c - 1e-9 <= x <= d + 1e-9]
        ua = [x for x in us if a - 1e-9 <= x <= b + 1e-9]
        for k in range(len(va) - 1):
            faces.append(((pid(a, va[k], 0.0), pid(a, va[k + 1], 0.0),
                           pid(a, va[k + 1], dz), pid(a, va[k], dz)), mat_reveal))
            faces.append(((pid(b, va[k], 0.0), pid(b, va[k + 1], 0.0),
                           pid(b, va[k + 1], dz), pid(b, va[k], dz)), mat_reveal))
        for k in range(len(ua) - 1):
            faces.append(((pid(ua[k], c, 0.0), pid(ua[k + 1], c, 0.0),
                           pid(ua[k + 1], c, dz), pid(ua[k], c, dz)), mat_reveal))
            faces.append(((pid(ua[k], d, 0.0), pid(ua[k + 1], d, 0.0),
                           pid(ua[k + 1], d, dz), pid(ua[k], d, dz)), mat_reveal))
        for k in range(len(ua) - 1):
            for m_ in range(len(va) - 1):
                faces.append(((pid(ua[k], va[m_], dz), pid(ua[k + 1], va[m_], dz),
                               pid(ua[k + 1], va[m_ + 1], dz), pid(ua[k], va[m_ + 1], dz)),
                              back_mat))
    return verts, faces


# =========================================================================== #
# 2. 通用构件
# =========================================================================== #

def window(m, side, uc, vc, w, h, depth, sill=True, lintel=True,
           bars=(True, True), arch_rise=0.0, frame_mat=WOOD, sill_mat=STONE):
    """窗：木框 + 铁棂 + 石窗台 + 石窗楣（可选砖/石券）。开口由 panel 挖真凹口。"""
    hw, hh = w / 2.0, h / 2.0
    back = depth - 0.02
    for s_ in (-1.0, 1.0):
        ua = uc + s_ * (hw + 0.03)
        ub = uc + s_ * (hw - 0.10)
        m.add(*lvchamfer_box(side, min(ua, ub), max(ua, ub), vc - hh, vc + hh,
                             -0.03, back, 0.02), frame_mat)
    m.add(*lbox(side, uc - hw + 0.05, uc + hw - 0.05, vc + hh - 0.10, vc + hh + 0.04,
                -0.03, back), frame_mat)
    m.add(*lbox(side, uc - hw + 0.05, uc + hw - 0.05, vc - hh - 0.04, vc - hh + 0.09,
                -0.03, back), frame_mat)
    if bars[0]:
        m.add(*lbox(side, uc - 0.025, uc + 0.025, vc - hh, vc + hh, -0.02, depth - 0.05),
              IRON)
    if bars[1]:
        m.add(*lbox(side, uc - hw, uc + hw, vc - 0.025, vc + 0.025, -0.02, depth - 0.05),
              IRON)
    if sill:
        m.add(*lhexa(side,
                     (uc - hw - 0.16, uc + hw + 0.16, vc - hh - 0.14, vc - hh + 0.02, -0.02),
                     (uc - hw - 0.12, uc + hw + 0.12, vc - hh - 0.10, vc - hh + 0.02,
                      -0.11)), sill_mat)
    if lintel:
        m.add(*lbox(side, uc - hw - 0.16, uc + hw + 0.16, vc + hh + 0.03, vc + hh + 0.20,
                    -0.07, 0.02), sill_mat)
    if arch_rise > 0.0:
        m.add(*arch_band(side, uc, vc + hh - 0.02, hw + 0.02, hw + 0.02 + arch_rise,
                         -0.05, 0.01, 0.10 * math.pi, 0.90 * math.pi, 4), BRICK)


def door(m, side, uc, v0, v1, w, depth, double=False, leaf_mat=WOOD, frame_mat=WOOD,
         threshold=True):
    hw = w / 2.0
    for s_ in (-1.0, 1.0):
        ua = uc + s_ * (hw + 0.04)
        ub = uc + s_ * (hw - 0.10)
        m.add(*lvchamfer_box(side, min(ua, ub), max(ua, ub), v0, v1,
                             -0.03, depth - 0.04, 0.025), frame_mat)
    m.add(*lbox(side, uc - hw + 0.05, uc + hw - 0.05, v1 - 0.12, v1 + 0.04,
                -0.03, depth - 0.04), frame_mat)
    n = 2 if double else 1
    for k in range(n):
        if n == 1:
            u0, u1 = uc - hw + 0.06, uc + hw - 0.06
        elif k == 0:
            u0, u1 = uc - hw + 0.06, uc - 0.03
        else:
            u0, u1 = uc + 0.03, uc + hw - 0.06
        m.add(*lbox(side, u0, u1, v0 + 0.04, v1 - 0.10, depth - 0.10, depth - 0.03), leaf_mat)
        for vz in (v0 + 0.35, v1 - 0.45):
            m.add(*lbox(side, u0 + 0.05, u1 - 0.05, vz - 0.04, vz + 0.04,
                        depth - 0.12, depth - 0.095), IRON)
        m.add(*lbox(side, u0 + (u1 - u0) * 0.70, u0 + (u1 - u0) * 0.80,
                    v0 + 0.95, v0 + 1.03, depth - 0.16, depth - 0.09), IRON)
    if threshold:
        m.add(*lbox(side, uc - hw - 0.05, uc + hw + 0.05, v0 - 0.02, v0 + 0.06,
                    -0.02, depth - 0.02), STONE)


def pilaster(m, side, uc, v0, v1, w=0.40, d=0.14, mat=BRICK):
    m.add(*lvchamfer_box(side, uc - w / 2.0, uc + w / 2.0, v0 + 0.18, v1 - 0.14,
                         -d, 0.02, 0.035), mat)
    m.add(*lbox(side, uc - w / 2.0 - 0.05, uc + w / 2.0 + 0.05, v0, v0 + 0.18,
                -d - 0.03, 0.02), STONE)
    m.add(*lbox(side, uc - w / 2.0 - 0.06, uc + w / 2.0 + 0.06, v1 - 0.14, v1 + 0.06,
                -d - 0.04, 0.02), STONE)


def string_band(m, side, u0, u1, z0, z1, d=0.08):
    m.add(*lbox(side, u0, u1, z0, z1, -d, 0.02), STONE)


def cornice(m, side, u0, u1, z0, z1, dmax=0.30):
    h = z1 - z0
    prof = [(0.03, z0), (-0.16, z0), (-0.16, z0 + 0.24 * h),
            (-dmax, z0 + 0.34 * h), (-dmax, z0 + 0.74 * h),
            (-0.20, z0 + 0.90 * h), (0.03, z1)]
    m.add(*lprism_u(side, u0, u1, prof), STONE)


def quoins(m, wx, wy, sx, sy, zs, block=0.55, depth=0.10):
    ax, ay = abs(wx), abs(wy)
    for i, z in enumerate(zs):
        w = block if i % 2 == 0 else block * 0.78
        x0, x1 = sorted((sx * (ax - w + 0.10), sx * (ax + depth)))
        y0, y1 = sorted((sy * (ay - w + 0.10), sy * (ay + depth)))
        m.add(*box((x0, y0, z), (x1, y1, z + 0.38)), STONE)


def louver(m, side, uc, v0, v1, w, slats=8, d0=-0.10):
    hw = w / 2.0
    # 外框
    m.add(*lbox(side, uc - hw, uc + hw, v0, v0 + 0.09, d0, 0.02), IRON)
    m.add(*lbox(side, uc - hw, uc + hw, v1 - 0.09, v1, d0, 0.02), IRON)
    m.add(*lbox(side, uc - hw, uc - hw + 0.09, v0 + 0.09, v1 - 0.09, d0, 0.02), IRON)
    m.add(*lbox(side, uc + hw - 0.09, uc + hw, v0 + 0.09, v1 - 0.09, d0, 0.02), IRON)
    # 斜百叶片（薄板，逐片出挑 0.04）
    span = (v1 - 0.18) - (v0 + 0.18)
    for k in range(slats):
        z = v0 + 0.18 + span * k / float(max(1, slats - 1))
        m.add(*lbox(side, uc - hw + 0.07, uc + hw - 0.07, z - 0.035, z + 0.035,
                    d0 - 0.035, d0 + 0.02), IRON)
    # 凹底封板（铁）
    m.add(*lbox(side, uc - hw + 0.05, uc + hw - 0.05, v0 + 0.05, v1 - 0.05,
                0.12, 0.16), IRON)


def ladder(m, x, y0, y1, z0, z1, rungs=12, rail=0.05, out=0.06, axis="y"):
    """竖向铁爬梯：2 根侧轨 + n 根横档（axis 决定横档方向）。"""
    if axis == "y":
        for yy in (y0, y1):
            m.add(*box((x - rail / 2, yy - rail / 2, z0), (x + rail / 2, yy + rail / 2, z1)),
                  IRON)
        step = (z1 - z0) / float(rungs)
        for k in range(rungs):
            z = z0 + step * (k + 0.5)
            m.add(*box((x - out / 2, y0, z - 0.025), (x + out / 2, y1, z + 0.025)), IRON)
    else:
        for xx in (x - (y1 - y0) / 2.0, x + (y1 - y0) / 2.0):
            m.add(*box((xx - rail / 2, y0 - rail / 2, z0),
                       (xx + rail / 2, y0 + rail / 2, z1)), IRON)
        step = (z1 - z0) / float(rungs)
        for k in range(rungs):
            z = z0 + step * (k + 0.5)
            m.add(*box((x - (y1 - y0) / 2.0, y0 - out / 2, z - 0.025),
                       (x + (y1 - y0) / 2.0, y0 + out / 2, z + 0.025)), IRON)


def railing(m, poly, z0, height=1.10, post_step=0.9, mid=True):
    """沿折线 poly=[(x,y),...] 的栏杆：立柱 + 顶杆 + 中杆（全部闭合实体）。"""
    for (ax, ay), (bx, by) in zip(poly, poly[1:]):
        length = math.hypot(bx - ax, by - ay)
        n = max(2, int(math.ceil(length / post_step)) + 1)
        for k in range(n):
            t = k / float(n - 1)
            px, py = ax + (bx - ax) * t, ay + (by - ay) * t
            m.add(*box((px - 0.035, py - 0.035, z0), (px + 0.035, py + 0.035,
                                                     z0 + height)), IRON)
        m.add(*beam((ax, ay, z0 + height), (bx, by, z0 + height), 0.055, 0.06), IRON)
        if mid:
            m.add(*beam((ax, ay, z0 + height * 0.52), (bx, by, z0 + height * 0.52),
                        0.045, 0.045), IRON)


def pipe_run(m, pts, r=0.12, flanges=(), sides=8):
    """外露粗管：逐段圆柱 + 节点法兰盘 + 墙卡。"""
    for a, b in zip(pts, pts[1:]):
        m.add(*rod(a, b, r, sides), IRON)
    for idx, ax in flanges:
        p = pts[idx]
        if idx > 0:
            d = (pts[idx][0] - pts[idx - 1][0], pts[idx][1] - pts[idx - 1][1],
                 pts[idx][2] - pts[idx - 1][2])
            ln = math.sqrt(sum(v * v for v in d))
            d = tuple(v / ln for v in d)
        else:
            d = (1.0, 0.0, 0.0)
        p0 = (p[0] - d[0] * 0.04, p[1] - d[1] * 0.04, p[2] - d[2] * 0.04)
        p1 = (p[0] + d[0] * 0.04, p[1] + d[1] * 0.04, p[2] + d[2] * 0.04)
        m.add(*rod(p0, p1, r + 0.05, sides), IRON)


def chimney(m, x0, x1, y0, y1, z0, z1, segments=5, mat=BRICK):
    """工业砖烟囱：石基座 + 分段收分砖身 + 石腰环 + 石压顶 + 铁冠/防雨帽 + 爬梯。

    顶部（铁防雨帽）顶面严格 = z1，保证包围盒 Z 上限由它定死。
    """
    m.add(*tb(x0 - 0.15, x1 + 0.15, y0 - 0.15, y1 + 0.15, z0, z0 + 0.55, 0.04), STONE)
    shaft_z0 = z0 + 0.55
    cap_h = 0.22
    crown_h = max(0.45, (z1 - shaft_z0) * 0.18)
    shaft_top = z1 - cap_h - crown_h
    h = (shaft_top - shaft_z0) / float(segments)
    for k in range(segments):
        a = 0.018 * k
        zz0 = shaft_z0 + h * k - (0.03 if k else 0.0)
        zz1 = shaft_z0 + h * (k + 1)
        m.add(*tb(x0 + a, x1 - a, y0 + a, y1 - a, zz0, zz1, 0.018), mat)
        m.add(*tb(x0 + a - 0.07, x1 - a + 0.07, y0 + a - 0.07, y1 - a + 0.07,
                  zz1 - 0.10, zz1 + 0.02, 0.02), STONE)
    a = 0.018 * segments
    m.add(*tb(x0 + a - 0.16, x1 - a + 0.16, y0 + a - 0.16, y1 - a + 0.16,
              shaft_top, shaft_top + cap_h, 0.05), STONE)
    cx, cy = 0.5 * (x0 + x1), 0.5 * (y0 + y1)
    r = 0.5 * min(x1 - x0, y1 - y0) * 0.55
    crown_z0 = shaft_top + cap_h
    m.add(*rod((cx, cy, crown_z0 - 0.02), (cx, cy, z1 - 0.18), r, 8), IRON)
    m.add(*tb(cx - r - 0.10, cx + r + 0.10, cy - r - 0.10, cy + r + 0.10,
              z1 - 0.18, z1, 0.12), IRON)
    for s_ in (-1.0, 1.0):
        m.add(*beam((cx + s_ * (r + 0.04), cy, crown_z0 + 0.06),
                    (cx + s_ * 0.5 * (x1 - x0 - a), cy, crown_z0 + 0.30), 0.06, 0.06),
              IRON)
    ladder(m, x0 + 0.02, y0 + 0.35, y1 - 0.35, z0 + 0.55, shaft_top - 0.10,
           rungs=max(4, int((shaft_top - z0) / 0.55)), axis="y")


def brick_chimney(m, x0, x1, y0, y1, z0, z1, pots=2):
    """住宅砖烟囱：两段收分砖身 + 石压顶 + 陶土烟囱帽（顶面 = z1）。"""
    m.add(*tb(x0 - 0.06, x1 + 0.06, y0 - 0.06, y1 + 0.06, z0, z0 + 0.10, 0.02), STONE)
    mid = z0 + (z1 - z0) * 0.55
    m.add(*tb(x0, x1, y0, y1, z0 + 0.08, mid, 0.02), BRICK)
    m.add(*tb(x0 + 0.03, x1 - 0.03, y0 + 0.03, y1 - 0.03, mid - 0.02, z1 - 0.26, 0.02),
          BRICK)
    m.add(*tb(x0 - 0.05, x1 + 0.05, y0 - 0.05, y1 + 0.05, z1 - 0.28, z1 - 0.14, 0.03),
          STONE)
    cx, cy = 0.5 * (x0 + x1), 0.5 * (y0 + y1)
    if pots == 1:
        spots = ((cx, cy),)
    else:
        dx = (x1 - x0) * 0.22
        spots = ((cx - dx, cy), (cx + dx, cy))
    for (px, py) in spots:
        m.add(*rod((px, py, z1 - 0.16), (px, py, z1), 0.11, 8), IRON)


def fan_unit(m, side, uc, vc, r=0.5, depth=0.30):
    """墙面风机：底座环 + 筒体 + 轮毂 + 4 叶 + 护网。"""
    p0 = lp(side, uc, vc, -0.02)
    p1 = lp(side, uc, vc, -depth)
    m.add(*rod(p0, p1, r, 10), IRON)
    m.add(*rod(lp(side, uc, vc, -depth + 0.01), lp(side, uc, vc, -depth - 0.05),
               r * 0.35, 8), IRON)
    for k in range(4):
        a = math.pi * 0.25 + k * math.pi / 2.0
        # 叶片装在筒口平面内（用局部 u/v 坐标的细长盒）
        du, dv = math.cos(a) * r * 0.62, math.sin(a) * r * 0.62
        m.add(*lbox(side, uc + du - 0.10, uc + du + 0.10, vc + dv - 0.10, vc + dv + 0.10,
                    -depth - 0.06, -depth + 0.01), IRON)
    for k in range(3):
        dv = (k - 1) * r * 0.55
        m.add(*lbox(side, uc - r * 0.9, uc + r * 0.9, vc + dv - 0.018, vc + dv + 0.018,
                    -depth - 0.02, -depth + 0.03), IRON)


def canopy(m, side, uc, half_w, z_wall, depth, drop=0.40):
    """雨棚：单坡铁皮挑檐 + 2 道斜撑 + 铁封边。"""
    pts = [(-0.02, z_wall), (-depth, z_wall - drop), (-depth, z_wall - drop - 0.06),
           (-0.02, z_wall - 0.10)]
    m.add(*lprism_u(side, uc - half_w, uc + half_w,
                    [(d, z) for d, z in pts]), IRON)
    for s_ in (-1.0, 1.0):
        ux = uc + s_ * (half_w - 0.18)
        m.add(*beam(lp(side, ux, z_wall - 0.05, -0.04),
                    lp(side, ux, z_wall - drop + 0.06, -depth + 0.06), 0.06, 0.06), IRON)
    m.add(*lbox(side, uc - half_w, uc + half_w, z_wall - drop - 0.09, z_wall - drop - 0.02,
                -depth - 0.03, -depth + 0.04), IRON)


def vent_cowl(m, x, y, z, r=0.28):
    m.add(*box((x - r, y - r, z - 0.18), (x + r, y + r, z + 0.10)), IRON)
    m.add(*rod((x, y, z + 0.08), (x, y, z + 0.62), r * 0.55, 8), IRON)
    m.add(*tb(x - r * 0.95, x + r * 0.95, y - r * 0.95, y + r * 0.95,
              z + 0.62, z + 0.84, 0.10), IRON)


def downpipe(m, side, uy, z0, z1, r=0.06):
    m.add(*lb2(side, uy, z1, r + 0.10, -0.20, 0.02), IRON)
    m.add(*rod(lp(side, uy, z1 - 0.10, -0.10), lp(side, uy, z0, -0.10), r, 8), IRON)
    for vz in (z0 + 0.6, z0 + 0.5 * (z1 - z0), z1 - 0.9):
        m.add(*lbox(side, uy - 0.035, uy + 0.035, vz - 0.045, vz + 0.045, -0.16, 0.01),
              IRON)
    m.add(*lb2(side, uy, z0 + 0.30, r + 0.07, -0.18, 0.02), IRON)


def lb2(side, uy, z, half, d0, d1):
    """落水管口的石块/铁块（小方盒）。"""
    return lbox(side, uy - half, uy + half, z - half, z + half, d0, d1)


def steps(m, side, uc, half_w, z0, z1, n=3, depth=0.45):
    """门口石台阶（n 级，保持在包围盒内）。"""
    for k in range(n):
        h0 = z0 + (z1 - z0) * k / float(n)
        h1 = z0 + (z1 - z0) * (k + 1) / float(n)
        d_out = depth * (1.0 - k / float(n))
        m.add(*lbox(side, uc - half_w + 0.06 * k, uc + half_w - 0.06 * k,
                    h0, h1, -d_out, 0.02), STONE)


# =========================================================================== #
# 3. 原型 1：SN_HT_Boiler_House（12 × 10 × 12，6000–7500 tri）
# =========================================================================== #

BH = {
    "target": (12.0, 10.0, 12.0),
    "base_x": 6.0, "base_y": 5.0,
    "wx_back": -5.8, "wx_front": 5.3, "wy": 4.7,
    "main_x0": -5.8, "main_x1": 1.8,
    "annex_x0": 1.8, "annex_x1": 5.3,
    "annex_y1": 0.5,
    "plinth_top": 0.55, "main_eave": 6.85, "annex_top": 4.60,
    "ridge": 8.56, "roof_t": 0.22,
    "chimney": (3.4, 5.2, 2.2, 4.0), "chimney_top": 12.0,
}


def build_boiler_house():
    C = BH
    m = Part()
    wx_b, wx_f, wy = C["wx_back"], C["wx_front"], C["wy"]
    mx0, mx1 = C["main_x0"], C["main_x1"]
    ax0, ax1, ay1 = C["annex_x0"], C["annex_x1"], C["annex_y1"]
    ptop, eave, atop = C["plinth_top"], C["main_eave"], C["annex_top"]
    S = sides(wx_f, wy)
    s_front, s_back = S["front"], S["back"]
    s_right, s_left = S["right"], S["left"]

    # ---- 石基（12 × 10 底面，三级收分） ----
    with m.group("stone_base"):
        m.add(*tb(-C["base_x"], C["base_x"], -C["base_y"], C["base_y"], 0.0, 0.22, 0.08), STONE)
        m.add(*tb(-5.94, 5.94, -4.94, 4.94, 0.22, 0.42, 0.04), STONE)
        m.add(*tb(-5.88, 5.88, -4.88, 4.88, 0.42, ptop, 0.03), STONE)

    # ---- 主厂房墙板（+Y 右墙：3 高窗 + 百叶 + 煤槽；-Y 左墙：2 窗 + 百叶 + 灰斗；
    #      -X 背墙：服务门 + 2 窗；+X 共享墙：实墙（下部被附房包住）） ----
    right_open = [
        (-5.05, -3.75, 2.60, 5.10, 0.16, GLASS),   # 高窗 1
        (-3.05, -1.75, 2.60, 5.10, 0.16, GLASS),   # 高窗 2
        (-1.05, 0.25, 2.60, 5.10, 0.16, GLASS),    # 高窗 3
        (0.55, 1.55, 3.60, 5.55, 0.14, IRON),      # 侧墙百叶
        (-5.45, -4.45, 0.60, 2.00, 0.14, WOOD),    # 煤槽口
    ]
    left_open = [
        (-4.65, -3.35, 2.70, 5.10, 0.16, GLASS),
        (-2.55, -1.25, 2.70, 5.10, 0.16, GLASS),
        (-0.55, 0.75, 3.30, 5.25, 0.14, IRON),     # 侧墙百叶
        (-5.45, -4.55, 0.60, 1.90, 0.14, WOOD),    # 灰斗口
    ]
    back_open = [
        (-0.75, 0.75, 0.60, 2.95, 0.24, WOOD),     # 后服务门
        (-3.45, -2.15, 2.70, 5.10, 0.16, GLASS),
        (2.15, 3.45, 2.70, 5.10, 0.16, GLASS),
        (-1.20, 1.20, 5.60, 6.20, 0.14, GLASS),    # 高位气窗
    ]
    with m.group("main_walls"):
        m.add_multi(*panel("y", wy, -1.0, mx0 - 0.02, mx1, ptop, eave, 0.42, right_open))
        m.add_multi(*panel("y", -wy, 1.0, mx0 - 0.02, mx1, ptop, eave, 0.42, left_open))
        m.add_multi(*panel("x", wx_b, 1.0, -wy - 0.02, wy + 0.02, ptop, eave, 0.42, back_open))
        m.add_multi(*panel("x", mx1, -1.0, -wy - 0.02, wy + 0.02, ptop + 0.02, eave, 0.42, []))

    # ---- 附房墙板（+X 前墙：主入口 + 窗；-Y 左墙：窗；+Y 右墙：服务门） ----
    annex_front_open = [
        (-2.35, -0.05, 0.55, 3.55, 0.28, WOOD),    # 主入口双开门
        (-4.35, -3.15, 1.40, 3.00, 0.16, GLASS),
        (-2.10, -0.30, 3.70, 4.30, 0.12, GLASS),   # 门上气窗
        (0.00, 0.44, 1.40, 3.00, 0.16, GLASS),     # 窄窗
    ]
    annex_left_open = [(3.10, 4.30, 1.40, 2.90, 0.16, GLASS)]
    annex_right_open = [(2.30, 3.50, 0.55, 2.70, 0.24, WOOD)]
    with m.group("annex_walls"):
        m.add_multi(*panel("x", ax1, -1.0, -wy - 0.02, ay1 + 0.02, ptop, atop, 0.40,
                     annex_front_open))
        m.add_multi(*panel("y", -wy, 1.0, ax0, ax1 + 0.02, ptop, atop, 0.40,
                     annex_left_open))
        m.add_multi(*panel("y", ay1, -1.0, ax0 - 0.02, ax1 + 0.02, ptop, atop, 0.40,
                     annex_right_open))

    # ---- 门窗构件 ----
    with m.group("windows"):
        # 主厂房右墙 3 高窗
        for uc in (-4.40, -2.40, -0.40):
            window(m, s_right, uc, 3.85, 1.30, 2.50, 0.16)
        # 左墙 2 高窗
        for uc in (-4.00, -1.90):
            window(m, s_left, uc, 3.90, 1.30, 2.40, 0.16)
        # 背墙 2 窗 + 高气窗
        for uc in (-2.80, 2.80):
            window(m, s_back, uc, 3.90, 1.30, 2.40, 0.16)
        window(m, s_back, 0.0, 5.90, 2.40, 0.60, 0.14, sill=False, lintel=False,
               bars=(True, False))
        # 附房前墙 2 窗
        window(m, s_front, -3.75, 2.20, 1.20, 1.60, 0.16)
        window(m, s_front, 0.22, 2.20, 0.44, 1.60, 0.16)
        window(m, s_left, 3.70, 2.15, 1.20, 1.50, 0.16)
        # 附房门上气窗
        window(m, s_front, -1.20, 4.00, 1.80, 0.60, 0.12, sill=False, lintel=False,
               bars=(True, False))
    with m.group("doors"):
        door(m, s_front, -1.20, 0.55, 3.55, 2.30, 0.28, double=True)
        door(m, s_back, 0.0, 0.60, 2.95, 1.50, 0.24)
        door(m, sides(ax1, ay1)["right"], 2.90, 0.55, 2.70, 1.20, 0.24)
        steps(m, s_front, -1.20, 1.35, 0.0, ptop + 0.06, n=3, depth=0.42)

    # ---- 侧墙百叶（在 panel 的凹口里） ----
    with m.group("louvers"):
        louver(m, s_right, 1.05, 3.60, 5.55, 1.00)
        louver(m, s_left, 0.10, 3.30, 5.25, 1.30)

    # ---- 煤槽 / 灰斗（外凸料斗 + 铁盖板） ----
    with m.group("coal_chute"):
        # 煤槽：料斗外凸 0.3，顶部开口框 + 铁盖
        m.add(*tb(-5.45, -4.45, wy - 0.02, 4.96, 0.60, 2.00, 0.06), IRON)
        m.add(*box((-5.50, 4.70, 1.98), (-4.40, 4.99, 2.06)), IRON)
        m.add(*box((-5.42, 4.84, 0.60), (-4.48, 4.99, 0.74)), STONE)
        # 灰斗：更小、带铁盖
        m.add(*tb(-5.45, -4.55, -4.96, -wy + 0.02, 0.60, 1.90, 0.06), IRON)
        m.add(*box((-5.48, -4.99, 1.86), (-4.52, -4.70, 1.96)), IRON)

    # ---- 主屋面：双坡铁屋面（脊沿 X）+ 脊瓦 + 立缝 + 山墙 ----
    ridge = C["ridge"]
    with m.group("roof_main"):
        for sy in (-1.0, 1.0):
            ye = sy * 5.0
            zt = ridge - abs(ye) * ((ridge - 6.78) / 5.0)
            pts = [(0.0, ridge - 0.22), (ye, zt - 0.22), (ye, zt - 0.06),
                   (ye - sy * 0.02, zt - 0.02), (ye - sy * 0.07, zt),
                   (0.0, ridge)]
            m.add(*prism_x(pts, -6.0, 2.0), IRON)
        m.add(*box((-5.92, -0.34, ridge - 0.02), (1.95, 0.34, ridge + 0.16)), IRON)
        for sy in (-1.0, 1.0):
            for sx in (-4.8, -2.6, -0.4, 1.4):
                m.add(*beam((sx, sy * 4.55, ridge - 4.55 * ((ridge - 6.78) / 5.0) + 0.03),
                            (sx, sy * 0.25, ridge - 0.25 * ((ridge - 6.78) / 5.0) + 0.03),
                            0.075, 0.055), IRON)
        # 两端山墙（砖 + 石压顶 + 铁拉杆）
        for x0, x1, sgn in ((wx_b, wx_b + 0.42, -1.0), (mx1 - 0.42, mx1, 1.0)):
            m.add(*prism_x([(-4.70, 6.72), (4.70, 6.72), (4.70, 6.86),
                            (0.0, ridge - 0.01), (-4.70, 6.86)], x0, x1), BRICK)
            m.add(*beam((x1 if sgn > 0 else x0, -4.55, 6.82),
                        (x1 if sgn > 0 else x0, 0.0, ridge - 0.08), 0.10, 0.14), STONE)
            m.add(*beam((x1 if sgn > 0 else x0, 4.55, 6.82),
                        (x1 if sgn > 0 else x0, 0.0, ridge - 0.08), 0.10, 0.14), STONE)
        for x in (-4.4, 0.6):
            m.add(*box((x - 0.05, -3.6, 7.55), (x + 0.05, 3.6, 7.62)), IRON)
        # 2 个脊部通风帽
        for x in (-3.4, 0.4):
            vent_cowl(m, x, 0.0, ridge + 0.10, r=0.30)

    # ---- 附房屋面：平顶 + 女儿墙 + 除尘旋风筒 ----
    with m.group("roof_annex"):
        m.add(*box((ax0 - 0.02, -4.68, atop - 0.02), (ax1 + 0.02, ay1 + 0.02, atop + 0.20)),
              IRON)
        m.add(*box((ax1 - 0.06, -4.72, atop + 0.18), (ax1 + 0.06, ay1 + 0.04, atop + 0.52)),
              BRICK)
        m.add(*box((ax0 - 0.02, ay1 - 0.06, atop + 0.18), (ax1 + 0.02, ay1 + 0.06,
                                                          atop + 0.52)), BRICK)
        m.add(*box((ax0 - 0.02, -4.78, atop + 0.18), (ax1 + 0.02, -4.66, atop + 0.52)),
              BRICK)
        m.add(*box((ax1 - 0.10, -4.76, atop + 0.48), (ax1 + 0.10, ay1 + 0.08, atop + 0.58)),
              STONE)
        # 除尘旋风筒
        m.add(*rod((3.0, -2.6, atop + 0.18), (3.0, -2.6, atop + 1.30), 0.42, 10), IRON)
        m.add(*tb(2.50, 3.50, -3.10, -2.10, atop + 1.28, atop + 1.55, 0.12), IRON)
        m.add(*rod((3.0, -2.6, atop + 1.54), (3.0, -2.6, atop + 1.95), 0.20, 8), IRON)
        m.add(*beam((3.0, -2.6, atop + 1.90), (5.15, -2.6, atop + 1.96), 0.16, 0.16), IRON)

    # ---- 高砖烟囱（轮廓识别点 1） ----
    with m.group("chimney"):
        cx0, cx1, cy0, cy1 = C["chimney"]
        chimney(m, cx0, cx1, cy0, cy1, ptop, C["chimney_top"])
        # 烟囱与附房屋面之间的泛水石
        m.add(*tb(cx0 - 0.20, cx1 + 0.20, cy0 - 0.20, cy1 + 0.20,
                  atop + 0.10, atop + 0.28, 0.05), STONE)

    # ---- 外露粗蒸汽管（轮廓识别点 2）：右墙横管 + 附房前墙立管/横管 + 烟囱立管 ----
    with m.group("pipes"):
        y_pipe = wy + 0.10
        pipe_run(m, [(-5.30, y_pipe, 5.95), (1.20, y_pipe, 5.95),
                     (1.20, y_pipe, 3.20), (2.60, y_pipe - 0.0, 3.20)],
                 r=0.13, flanges=((1, 0.13), (2, 0.13)))
        pipe_run(m, [(-4.60, y_pipe, 5.35), (1.20, y_pipe, 5.35)],
                 r=0.11, flanges=((1, 0.11),))
        # 附房 +X 前墙：立管 + 横管（固定机位正面可见的粗管）
        x_pipe = ax1 + 0.13
        pipe_run(m, [(x_pipe, -2.75, 0.80), (x_pipe, -2.75, 4.30),
                     (x_pipe, -0.30, 4.30)], r=0.13,
                 flanges=((0, 0.13), (1, 0.13)))
        pipe_run(m, [(x_pipe, -4.20, 0.90), (x_pipe, -4.20, 3.90)], r=0.10,
                 flanges=((0, 0.10),))
        for vz in (1.30, 2.40, 3.50):
            m.add(*box((ax1, -2.83, vz - 0.05), (ax1 + 0.30, -2.67, vz + 0.05)), IRON)
        # 烟囱 +X 面立管
        pipe_run(m, [(5.27, 3.10, 5.10), (5.27, 3.10, 10.40)], r=0.12,
                 flanges=((0, 0.12), (1, 0.12)))
        for vz in (6.20, 7.60, 9.00):
            m.add(*box((5.20, 2.98, vz - 0.05), (5.40, 3.22, vz + 0.05)), IRON)
        # 从附房屋面通到烟囱的立管
        pipe_run(m, [(3.05, 1.10, atop + 0.20), (3.05, 1.10, 6.60),
                     (3.05, 2.00, 6.60), (3.05, 2.00, 9.40)],
                 r=0.12, flanges=((1, 0.12), (2, 0.12)))
        # 管卡 / 支架
        for x in (-4.6, -2.2, 0.2):
            m.add(*box((x - 0.05, wy, 5.78), (x + 0.05, wy + 0.30, 6.02)), IRON)
            m.add(*box((x - 0.05, wy, 5.18), (x + 0.05, wy + 0.28, 5.42)), IRON)

    # ---- 煤场围墙（把烟囱院封闭成可读的工业院落；+X 面 2.55 m 砖墙 + 铁门） ----
    with m.group("yard_wall"):
        m.add_multi(*panel("x", ax1, -1.0, 2.30, wy + 0.02, ptop, 2.55, 0.30,
                           [], mat_face=BRICK, mat_reveal=STONE, mat_inner=BRICK))
        m.add(*tb(ax1 - 0.34, ax1 + 0.02, 2.26, wy + 0.06, 2.55, 2.68, 0.03), STONE)
        # 铁门（0.55..2.26，与围墙同高，5 根竖栅 + 上下横档）
        for k in range(5):
            gy = 0.72 + k * 0.36
            m.add(*box((ax1 - 0.06, gy - 0.025, ptop), (ax1 + 0.02, gy + 0.025, 2.30)),
                  IRON)
        for gz in (0.90, 2.14):
            m.add(*box((ax1 - 0.06, 0.62, gz - 0.04), (ax1 + 0.02, 2.22, gz + 0.04)),
                  IRON)

    # ---- 检修平台（轮廓识别点 3）：烟囱 +Y 侧 2.0 × 0.85 m 铁平台 + 栏杆 + 爬梯 ----
    with m.group("platform"):
        px0, px1 = 2.90, 4.90
        py0, py1 = wy - 0.70, wy + 0.14
        pz = 6.10
        m.add(*box((px0, py0, pz - 0.10), (px1, py1, pz)), IRON)
        for xx in (3.05, 3.95, 4.80):
            m.add(*beam((xx, 4.00, pz - 0.10), (xx, 4.94, 5.70), 0.06, 0.08), IRON)
        railing(m, [(px0 + 0.04, py1 - 0.04), (px1 - 0.04, py1 - 0.04)], pz,
                height=1.10, post_step=0.75)
        railing(m, [(px0 + 0.04, py0 + 0.04), (px0 + 0.04, py1 - 0.04)], pz,
                height=1.10, post_step=0.55, mid=False)
        railing(m, [(px1 - 0.04, py0 + 0.04), (px1 - 0.04, py1 - 0.04)], pz,
                height=1.10, post_step=0.55, mid=False)
        m.add(*box((px0 + 0.04, py0 + 0.04, pz), (px1 - 0.04, py1 - 0.04, pz + 0.10)),
              IRON)
        # 烟囱 +Y 面爬梯（从地面到平台）
        ladder(m, 4.35, 4.03, 4.51, 0.55, pz - 0.10, rungs=11, axis="x")

    # ---- 附房入口石匾 / 雨棚 / 门口标志 ----
    with m.group("cornices"):
        s_main_front = ("x", mx1, -1.0)
        for sd, u0, u1 in ((s_right, mx0 - 0.02, mx1 + 0.02),
                           (s_left, mx0 - 0.02, mx1 + 0.02),
                           (s_back, -wy - 0.02, wy + 0.02),
                           (s_main_front, -wy - 0.02, wy + 0.02)):
            cornice(m, sd, u0, u1, 6.30, 6.84, dmax=0.26)
        for sd, u0, u1 in ((s_front, -wy - 0.02, ay1 + 0.02),
                           (s_left, ax0, ax1 + 0.02),
                           (sides(ax1, ay1)["right"], ax0 - 0.02, ax1 + 0.02)):
            cornice(m, sd, u0, u1, 4.18, atop - 0.02, dmax=0.20)

    with m.group("pilasters"):
        for uc in (-5.10, -3.10, -1.10):
            pilaster(m, s_right, uc, ptop - 0.02, eave, w=0.38, d=0.13)
        for uc in (-3.30, 3.30):
            pilaster(m, s_back, uc, ptop - 0.02, eave, w=0.38, d=0.13)
        for uc in (-5.10, -3.10):
            pilaster(m, s_left, uc, ptop - 0.02, eave, w=0.38, d=0.13)

    # ---- 转角隅石 ----
    with m.group("quoins"):
        for sx in (-1.0, 1.0):
            for sy in (-1.0, 1.0):
                quoins(m, wx_b if sx < 0 else mx1, wy, sx, sy,
                       [0.9, 1.9, 2.9, 3.9, 4.9, 5.9])
        for sx in (-1.0, 1.0):
            for sy in (-1.0, 1.0):
                if sx > 0:
                    quoins(m, ax1, wy, sx, sy, [0.9, 1.7, 2.5, 3.3])
                if sy > 0:
                    quoins(m, ax0, ay1, -1.0, 1.0, [0.9, 1.7, 2.5, 3.3])

    # ---- 落水管（背墙 2 根） ----
    with m.group("downpipes"):
        downpipe(m, s_back, -4.45, ptop, 6.10)
        downpipe(m, s_back, 4.45, ptop, 6.10)

    # ---- 附房石匾 + 主入口雨棚 ----
    with m.group("plaque"):
        m.add(*lbox(s_front, -0.95, 0.95, 3.62, 4.16, -0.06, 0.02), STONE)
    with m.group("canopies"):
        canopy(m, s_front, -1.20, 1.55, 3.62, 0.55, drop=0.34)
    return m


# =========================================================================== #
# 4. 原型 2：SN_HT_Workshop_Row（18 × 7 × 8.5，6000–7500 tri）
# =========================================================================== #

WR = {
    "target": (18.0, 7.0, 8.5),
    "base_x": 9.0, "base_y": 3.5,
    "wx": 8.4, "wy": 2.8,
    "plinth_top": 0.50, "eave": 5.98, "high": 8.26, "roof_t": 0.22,
    "bay_x": (-8.4, -2.8, 2.8, 8.4),
}


def build_workshop_row():
    C = WR
    m = Part()
    wx, wy = C["wx"], C["wy"]
    ptop, eave, high = C["plinth_top"], C["eave"], C["high"]
    x0, x1, x2, x3 = C["bay_x"]
    S = sides(wx, wy)
    s_front, s_back = S["front"], S["back"]
    s_right, s_left = S["right"], S["left"]

    # ---- 石基（18 × 7 底面） ----
    with m.group("stone_base"):
        m.add(*tb(-C["base_x"], C["base_x"], -C["base_y"], C["base_y"], 0.0, 0.20, 0.06), STONE)
        m.add(*tb(-8.96, 8.96, -3.46, 3.46, 0.18, 0.36, 0.03), STONE)
        m.add(*tb(-8.92, 8.92, -3.42, 3.42, 0.34, ptop, 0.02), STONE)

    # ---- 墙板：+Y 长墙（3 樘工坊门 + 高窗 + 2 风机位）、-Y 背墙、±X 山墙 ----
    right_open = [
        (-7.40, -3.80, 0.50, 4.30, 0.28, WOOD),    # 工坊门 A（3.6 宽）
        (-1.20, 1.20, 0.50, 3.60, 0.24, WOOD),     # 工坊门 B（2.4 宽）
        (4.10, 7.10, 0.50, 4.00, 0.26, WOOD),      # 工坊门 C（3.0 宽）
        (-6.30, -4.90, 4.75, 5.75, 0.16, GLASS),   # 门 A 上高窗
        (-0.70, 0.70, 4.00, 5.20, 0.16, GLASS),    # 门 B 上高窗
        (4.80, 6.40, 4.45, 5.65, 0.16, GLASS),     # 门 C 上高窗
        (-2.30, -1.85, 4.60, 5.60, 0.14, IRON),    # 百叶
    ]
    left_open = [
        (-7.60, -6.40, 1.40, 3.40, 0.16, GLASS),
        (-3.90, -2.70, 1.40, 3.40, 0.16, GLASS),
        (2.70, 3.90, 1.40, 3.40, 0.16, GLASS),
        (5.40, 6.60, 1.40, 3.40, 0.16, GLASS),
        (-1.40, 0.20, 5.00, 5.60, 0.14, IRON),     # 高位百叶
    ]
    front_open = [
        (-1.10, 1.10, 0.50, 3.70, 0.28, WOOD),     # 端头入口门
        (-2.70, -1.70, 1.50, 3.30, 0.16, GLASS),
        (1.70, 2.70, 1.50, 3.30, 0.16, GLASS),
        (-1.05, 1.05, 3.85, 4.35, 0.12, GLASS),    # 门上气窗
    ]
    back_open = [
        (-0.70, 0.70, 0.50, 3.10, 0.24, WOOD),     # 后服务门
        (-2.60, -1.70, 1.40, 3.20, 0.16, GLASS),
        (1.70, 2.60, 1.40, 3.20, 0.16, GLASS),
    ]
    with m.group("walls"):
        m.add_multi(*panel("y", wy, -1.0, -wx - 0.02, wx + 0.02, ptop, eave, 0.42, right_open))
        m.add_multi(*panel("y", -wy, 1.0, -wx - 0.02, wx + 0.02, ptop, eave, 0.42, left_open))
        m.add_multi(*panel("x", wx, -1.0, -wy - 0.02, wy + 0.02, ptop, eave, 0.42, front_open))
        m.add_multi(*panel("x", -wx, 1.0, -wy - 0.02, wy + 0.02, ptop, eave, 0.42, back_open))

    # ---- 3 个连续工坊 bay：大门 + 门框 + 上滑轨 + 门楣 ----
    with m.group("bay_doors"):
        for uc, w, v1, dep in ((-5.60, 3.60, 4.30, 0.28), (0.0, 2.40, 3.60, 0.24),
                               (5.60, 3.00, 4.00, 0.26)):
            door(m, s_right, uc, 0.50, v1, w, dep, double=True)
            # 门上滑轨（双轨）+ 3 吊架
            for dv in (0.05, 0.16):
                m.add(*lbox(s_right, uc - w / 2 - 0.35, uc + w / 2 + 0.35,
                            v1 + dv, v1 + dv + 0.07, -0.13, 0.02), IRON)
            for ux in (uc - w * 0.30, uc, uc + w * 0.30):
                m.add(*lbox(s_right, ux - 0.045, ux + 0.045, v1 + 0.04, v1 + 0.20,
                            -0.14, 0.02), IRON)
            # 门楣工字钢（灰/铁）
            m.add(*lbox(s_right, uc - w / 2 - 0.25, uc + w / 2 + 0.25, v1 + 0.22,
                        v1 + 0.46, -0.16, 0.02), IRON)
        door(m, s_front, 0.0, 0.50, 3.70, 2.20, 0.28, double=True)
        door(m, s_back, 0.0, 0.50, 3.10, 1.40, 0.24)
        steps(m, s_front, 0.0, 1.30, 0.0, ptop + 0.05, n=2, depth=0.40)

    # ---- 窗 / 百叶 ----
    with m.group("windows"):
        for uc, vc in ((-5.60, 5.25), (0.0, 4.60), (5.60, 5.05)):
            window(m, s_right, uc, vc, 1.40, 1.00, 0.16, sill=False, lintel=False,
                   bars=(True, False))
        for uc in (-7.00, -3.30, 3.30, 6.00):
            window(m, s_left, uc, 2.40, 1.20, 2.00, 0.16)
        window(m, s_front, -2.20, 2.40, 1.00, 1.80, 0.16)
        window(m, s_front, 2.20, 2.40, 1.00, 1.80, 0.16)
        window(m, s_front, 0.0, 4.10, 2.10, 0.50, 0.12, sill=False, lintel=False,
               bars=(True, False))
        for uc in (-2.15, 2.15):
            window(m, s_back, uc, 2.30, 0.90, 1.80, 0.16)

    # ---- 高位百叶（长墙打断 + 通风） ----
    with m.group("louvers"):
        louver(m, s_right, -2.075, 4.60, 5.60, 0.45, slats=6)
        louver(m, s_left, -0.60, 5.00, 5.60, 1.60)

    # ---- 墙面风机 ×2（需求必须项） ----
    with m.group("wall_fans"):
        fan_unit(m, s_right, -3.05, 5.05, r=0.52, depth=0.28)
        fan_unit(m, s_right, 3.05, 5.15, r=0.52, depth=0.28)
        fan_unit(m, s_left, 1.20, 4.60, r=0.42, depth=0.24)

    # ---- 铁雨棚 ×2（门 A / 门 C）+ 端头入口雨棚 ----
    with m.group("canopies"):
        canopy(m, s_right, -5.60, 2.30, 4.35, 0.55, drop=0.38)
        canopy(m, s_right, 5.60, 2.05, 4.10, 0.55, drop=0.36)
        canopy(m, s_front, 0.0, 1.65, 3.90, 0.50, drop=0.32)

    # ---- 锯齿采光顶：3 联（每跨 5.6 m：坡屋面 + 垂直玻璃天窗面 + 高边泛水） ----
    with m.group("sawtooth_roof"):
        for bx in (x0, x1, x2):
            bx1 = bx + (x3 - x0) / 3.0
            zt_lo = eave
            zt_hi = high
            pts = [(bx, zt_lo), (bx1, zt_hi), (bx1, zt_hi - C["roof_t"]),
                   (bx, zt_lo - C["roof_t"])]
            m.add(*prism_y(pts, -3.40, 3.40), IRON)
            # 坡面立缝 ×3
            for k in (0.25, 0.55, 0.85):
                x = bx + (bx1 - bx) * k
                z = zt_lo + (zt_hi - zt_lo) * k + 0.03
                m.add(*beam((x, -3.30, z), (x, 3.30, z), 0.06, 0.05), IRON)
            # 高边泛水/檐口压顶（顶面 = 包围盒 Z 上限）
            m.add(*box((bx1 - 0.30, -3.42, zt_hi - 0.04), (bx1 + 0.02, 3.42, 8.50)), IRON)
            # 低边檐沟（坡底）
            m.add(*prism_y([(bx - 0.02, zt_lo + 0.08), (bx + 0.14, zt_lo + 0.08),
                            (bx + 0.14, zt_lo - 0.02), (bx - 0.02, zt_lo - 0.02)],
                           -3.40, 3.40), IRON)
    with m.group("clerestory_glazing"):
        for k, bx in enumerate((x1, x2, x3)):
            half = 2.80 if k == 2 else 3.34
            # 垂直天窗面：玻璃板 + 2 竖梃 + 3 横挡
            m.add(*box((bx - 0.055, -half - 0.02, eave + 0.02),
                       (bx + 0.005, half + 0.02, high - 0.03)), GLASS)
            for sy in (-1.0, 1.0):
                m.add(*box((bx - 0.09, sy * half - 0.06, eave), (bx + 0.06,
                                                                 sy * half + 0.06, high)),
                      WOOD)
            for z in (eave + 0.06, eave + (high - eave) * 0.5, high - 0.06):
                m.add(*box((bx - 0.09, -half, z - 0.05), (bx + 0.06, half, z + 0.05)),
                      WOOD)
            for uc in (-half * 0.42, half * 0.42):
                m.add(*box((bx - 0.08, uc - 0.05, eave), (bx + 0.04, uc + 0.05, high)),
                      IRON)

    # ---- 外置楼梯 + 连廊猫道（沿 +Y 长墙） ----
    with m.group("external_stair"):
        # 楼梯：从地面到猫道 4.60，10 级踏步 + 2 斜梁 + 栏杆
        z_bot, z_top = 0.50, 4.55
        xs, xe = -8.05, -4.15
        y_str = 3.02
        n = 10
        for k in range(n):
            t = k / float(n - 1)
            x = xs + (xe - xs) * t
            z = z_bot + (z_top - z_bot) * t
            m.add(*box((x - 0.20, 2.94, z), (x + 0.20, 3.24, z + 0.07)), IRON)
        for sy in (-1.0, 1.0):
            m.add(*chamfer_beam((xs, y_str + sy * 0.13, z_bot),
                                (xe, y_str + sy * 0.13, z_top + 0.07), 0.06, 0.20, 0.015),
                  IRON)
        rail_pts = [(xs, 3.30, z_bot + 0.95), (xe, 3.30, z_top + 0.95)]
        for a_, b_ in ((rail_pts[0], rail_pts[1]),):
            m.add(*beam(a_, b_, 0.05, 0.05), IRON)
            m.add(*beam((a_[0], a_[1], a_[2] - 0.48), (b_[0], b_[1], b_[2] - 0.48),
                        0.045, 0.045), IRON)
        for k in range(4):
            t = k / 3.0
            x = xs + (xe - xs) * t
            z = z_bot + (z_top - z_bot) * t
            m.add(*box((x - 0.03, 3.27, z), (x + 0.03, 3.33, z + 0.98)), IRON)
    with m.group("catwalk"):
        m.add(*box((-4.15, 2.88, 4.47), (1.40, 3.40, 4.55)), IRON)
        for x in (-3.40, -1.60, 0.20, 1.25):
            m.add(*beam((x, 2.86, 4.46), (x, 3.42, 3.98), 0.06, 0.08), IRON)
        railing(m, [(-4.15, 3.36), (1.40, 3.36)], 4.55, height=1.05, post_step=0.85)
        # 猫道端部直爬梯到电气平台
        ladder(m, 1.30, 2.95, 3.30, 1.20, 4.45, rungs=9, axis="x")
    with m.group("pilasters"):
        for side, ucs in ((s_right, (-2.80, 2.80, -8.40, 8.40)),
                          (s_left, (-2.80, 2.80, -8.40, 8.40))):
            for uc in ucs:
                pilaster(m, side, uc, ptop - 0.02, eave, w=0.46, d=0.16)
        for side, u0, u1 in ((s_front, -wy - 0.02, wy + 0.02),):
            for uc in (-2.05, 2.05):
                pilaster(m, side, uc, ptop - 0.02, eave, w=0.40, d=0.14)
    with m.group("cornices"):
        string_band(m, s_right, -wx - 0.02, wx + 0.02, 5.30, 5.44, d=0.07)
        string_band(m, s_left, -wx - 0.02, wx + 0.02, 5.30, 5.44, d=0.07)
        cornice(m, s_front, -wy - 0.02, wy + 0.02, eave - 0.42, eave, dmax=0.24)
        cornice(m, s_back, -wy - 0.02, wy + 0.02, eave - 0.42, eave, dmax=0.24)
        cornice(m, s_right, -wx - 0.02, wx + 0.02, eave - 0.42, eave, dmax=0.22)
        cornice(m, s_left, -wx - 0.02, wx + 0.02, eave - 0.42, eave, dmax=0.22)
    with m.group("sign"):
        m.add(*lbox(s_front, -1.45, 1.45, 4.45, 5.05, -0.07, 0.02), WOOD)
    with m.group("downpipes"):
        downpipe(m, s_left, -8.30, ptop, eave - 0.10)
        downpipe(m, s_left, 8.30, ptop, eave - 0.10)
    with m.group("quoins"):
        for sx in (-1.0, 1.0):
            for sy in (-1.0, 1.0):
                quoins(m, wx, wy, sx, sy, [0.8, 1.7, 2.6, 3.5])
    with m.group("vents"):
        for bx, z in ((-8.30, eave + 0.05), (2.70, eave + 0.05)):
            vent_cowl(m, bx, -2.9, z, r=0.24)
    return m


# =========================================================================== #
# 5. 原型 3：SN_HT_Brick_Tenement（10 × 8 × 12，9000–12000 tri）
# =========================================================================== #

BT = {
    "target": (10.0, 8.0, 12.0),
    "base_x": 5.0, "base_y": 4.0,
    "wx_front": 4.4, "wx_back": -4.4, "wy": 3.2,
    "plinth_top": 0.55,
    "z1": 4.10, "z2": 7.10, "eave": 10.40,
    "roof_z": (10.38, 10.56), "parapet_z": (10.54, 11.00),
    "chimney_top": 12.0,
}


def build_brick_tenement():
    C = BT
    m = Part()
    wxf, wxb, wy = C["wx_front"], C["wx_back"], C["wy"]
    ptop, z1, z2, eave = C["plinth_top"], C["z1"], C["z2"], C["eave"]
    S = sides(wxf, wy)
    s_front, s_back = S["front"], S["back"]
    s_right, s_left = S["right"], S["left"]

    # ---- 石基（10 × 8 底面）+ 首层店面台阶 ----
    with m.group("stone_base"):
        m.add(*tb(-C["base_x"], C["base_x"], -C["base_y"], C["base_y"], 0.0, 0.24, 0.07), STONE)
        m.add(*tb(-4.96, 4.96, -3.96, 3.96, 0.22, 0.42, 0.03), STONE)
        m.add(*tb(-4.92, 4.92, -3.92, 3.92, 0.40, ptop, 0.02), STONE)

    # ---- 四面墙板（首层 / 二三层开洞） ----
    front_ground = [
        (-1.80, 1.80, 0.55, 3.40, 0.30, WOOD),     # 首层店面（封板 + 店门）
        (-3.05, -2.35, 1.10, 2.60, 0.16, GLASS),
    ]
    front_upper = [
        (-2.75, -1.65, 4.55, 6.25, 0.16, GLASS),
        (-0.55, 0.55, 4.55, 6.25, 0.16, GLASS),
        (1.65, 2.75, 4.55, 6.25, 0.16, GLASS),
        (-2.75, -1.65, 7.55, 9.25, 0.16, GLASS),
        (-0.55, 0.55, 7.55, 9.25, 0.16, GLASS),
        (1.65, 2.75, 7.55, 9.25, 0.16, GLASS),
        (-1.10, 1.10, 9.62, 10.18, 0.12, GLASS),   # 顶层小窗
    ]
    side_right_open = [
        (-3.40, -2.30, 1.20, 2.90, 0.16, GLASS),
        (-0.60, 0.50, 1.20, 2.90, 0.16, GLASS),
        (2.30, 3.40, 1.20, 2.90, 0.16, GLASS),
        (-3.30, -2.30, 4.55, 6.25, 0.16, GLASS),
        (0.10, 1.10, 4.55, 6.25, 0.16, GLASS),
        (-2.90, -1.90, 7.55, 9.25, 0.16, GLASS),
        (1.10, 2.10, 7.55, 9.25, 0.16, GLASS),
    ]
    side_left_open = [
        (-3.20, -2.20, 1.20, 2.90, 0.16, GLASS),
        (1.70, 2.70, 1.20, 2.90, 0.16, GLASS),
        (-2.80, -1.80, 4.55, 6.25, 0.16, GLASS),
        (1.20, 2.20, 4.55, 6.25, 0.16, GLASS),
        (-2.60, -1.60, 7.55, 9.25, 0.16, GLASS),
        (1.40, 2.40, 7.55, 9.25, 0.16, GLASS),
    ]
    back_open = [
        (-0.70, 0.70, 0.55, 2.95, 0.24, WOOD),     # 后服务门
        (-3.00, -2.00, 1.40, 2.90, 0.16, GLASS),
        (2.00, 3.00, 1.40, 2.90, 0.16, GLASS),
        (-2.85, -1.85, 4.55, 6.25, 0.16, GLASS),
        (1.65, 2.65, 4.55, 6.25, 0.16, GLASS),
        (-2.55, -1.55, 7.55, 9.25, 0.16, GLASS),
        (1.55, 2.55, 7.55, 9.25, 0.16, GLASS),
    ]
    with m.group("walls"):
        m.add_multi(*panel("x", wxf, -1.0, -wy - 0.02, wy + 0.02, ptop, z1, 0.42, front_ground))
        m.add_multi(*panel("x", wxf, -1.0, -wy - 0.02, wy + 0.02, z1, eave, 0.42, front_upper))
        m.add_multi(*panel("y", wy, -1.0, wxb - 0.02, wxf + 0.02, ptop, z1, 0.40,
                     side_right_open[:3]))
        m.add_multi(*panel("y", wy, -1.0, wxb - 0.02, wxf + 0.02, z1, z2, 0.40,
                     side_right_open[3:5]))
        m.add_multi(*panel("y", wy, -1.0, wxb - 0.02, wxf + 0.02, z2, eave, 0.40,
                     side_right_open[5:]))
        m.add_multi(*panel("y", -wy, 1.0, wxb - 0.02, wxf + 0.02, ptop, z1, 0.40,
                     side_left_open[:2]))
        m.add_multi(*panel("y", -wy, 1.0, wxb - 0.02, wxf + 0.02, z1, z2, 0.40,
                     side_left_open[2:4]))
        m.add_multi(*panel("y", -wy, 1.0, wxb - 0.02, wxf + 0.02, z2, eave, 0.40,
                     side_left_open[4:]))
        m.add_multi(*panel("x", wxb, 1.0, -wy - 0.02, wy + 0.02, ptop, z1, 0.42,
                     back_open[:3]))
        m.add_multi(*panel("x", wxb, 1.0, -wy - 0.02, wy + 0.02, z1, z2, 0.42,
                     back_open[3:5]))
        m.add_multi(*panel("x", wxb, 1.0, -wy - 0.02, wy + 0.02, z2, eave, 0.42,
                     back_open[5:]))

    # ---- 成列真凹窗洞：窗框 + 石窗台 + 石窗楣（上层带砖券） ----
    with m.group("windows"):
        for (u0, u1, v0, v1, _dep, _bm) in (front_upper[:3] + front_upper[3:6]):
            window(m, s_front, 0.5 * (u0 + u1), 0.5 * (v0 + v1), u1 - u0, v1 - v0, 0.16,
                   arch_rise=0.16 if v1 > 6.0 else 0.0)
        for uc in (-3.05 + 0.35,):
            window(m, s_front, uc, 1.85, 0.70, 1.50, 0.16)
        for (u0, u1, v0, v1, _dep, _bm) in side_right_open:
            window(m, s_right, 0.5 * (u0 + u1), 0.5 * (v0 + v1), u1 - u0, v1 - v0, 0.16)
        for (u0, u1, v0, v1, _dep, _bm) in side_left_open:
            window(m, s_left, 0.5 * (u0 + u1), 0.5 * (v0 + v1), u1 - u0, v1 - v0, 0.16)
        for (u0, u1, v0, v1, _dep, _bm) in back_open[1:]:
            window(m, s_back, 0.5 * (u0 + u1), 0.5 * (v0 + v1), u1 - u0, v1 - v0, 0.16)

    # ---- 首层小店：封板店面 + 店门 + 雨棚 + 空白店招 ----
    with m.group("shopfront"):
        # 开店门（店面凹口内右侧 1.0 宽）
        door(m, s_front, 1.15, 0.55, 3.30, 1.00, 0.30)
        # 封板：店面凹口内 6 条竖木板 + 横压条 + 石勒脚
        for k in range(6):
            u = -1.65 + k * 0.46
            m.add(*lbox(s_front, u, u + 0.42, 0.72, 3.22, 0.24, 0.30), WOOD)
        for vz in (1.20, 2.80):
            m.add(*lbox(s_front, -1.70, 1.62, vz - 0.06, vz + 0.06, 0.20, 0.26), IRON)
        m.add(*lbox(s_front, -1.80, 1.80, 0.55, 0.76, 0.14, 0.32), STONE)
        # 空白店招（木牌，无文字）
        m.add(*lbox(s_front, -1.85, 1.85, 3.55, 4.15, -0.10, 0.02), WOOD)
        m.add(*lbox(s_front, -1.95, -1.75, 3.50, 4.20, -0.12, 0.02), WOOD)
        m.add(*lbox(s_front, 1.75, 1.95, 3.50, 4.20, -0.12, 0.02), WOOD)
        m.add(*lbox(s_front, -1.95, 1.95, 4.08, 4.24, -0.12, 0.02), WOOD)
        steps(m, s_front, 1.15, 0.75, 0.0, ptop + 0.04, n=2, depth=0.40)
    with m.group("awning"):
        canopy(m, s_front, 0.0, 2.05, 3.52, 0.55, drop=0.42)

    # ---- 转角壁柱 + 隅石 + 层间石腰带 ----
    with m.group("corner_piers"):
        for sy in (-1.0, 1.0):
            uc = sy * (wy - 0.18)
            pilaster(m, s_front, uc, ptop - 0.02, eave - 0.10, w=0.62, d=0.17,
                     mat=BRICK)
            for k in range(3):
                m.add(*lvchamfer_box(s_front, uc - 0.36, uc + 0.36,
                                     ptop + 0.40 + k * 3.20, ptop + 0.80 + k * 3.20,
                                     -0.24, 0.02, 0.03), STONE)
        for sx in (-1.0, 1.0):
            for sy in (-1.0, 1.0):
                quoins(m, wxf if sx > 0 else wxb, wy, sx, sy,
                       [1.0, 2.1, 3.2, 4.3, 5.4, 6.5, 7.6, 8.7, 9.8, 10.4])
    with m.group("string_courses"):
        for (zz0, zz1) in ((z1 - 0.02, z1 + 0.16), (z2 - 0.02, z2 + 0.16)):
            string_band(m, s_front, -wy - 0.02, wy + 0.02, zz0, zz1, d=0.10)
            string_band(m, s_right, wxb - 0.02, wxf + 0.02, zz0, zz1, d=0.09)
            string_band(m, s_left, wxb - 0.02, wxf + 0.02, zz0, zz1, d=0.09)
            string_band(m, s_back, -wy - 0.02, wy + 0.02, zz0, zz1, d=0.09)

    # ---- 檐口 + 女儿墙 + 平屋面板 ----
    with m.group("cornice"):
        for sd, u0, u1 in ((s_front, -wy - 0.02, wy + 0.02),
                           (s_back, -wy - 0.02, wy + 0.02),
                           (s_right, wxb - 0.02, wxf + 0.02),
                           (s_left, wxb - 0.02, wxf + 0.02)):
            cornice(m, sd, u0, u1, eave - 0.46, eave, dmax=0.32)

    # ---- 檐下齿饰 / 二层窗前铁艺栏 / 首层地下室窗格栅（立面细节） ----
    with m.group("dentils"):
        for side, span, count in ((s_front, wy - 0.15, 12),
                                  (s_right, (wxf - wxb) / 2.0 - 0.25, 14),
                                  (s_left, (wxf - wxb) / 2.0 - 0.25, 14),
                                  (s_back, wy - 0.15, 12)):
            step = 2.0 * span / float(count - 1)
            for k in range(count):
                uc = -span + step * k
                m.add(*lbox(side, uc - 0.05, uc + 0.05, eave - 0.66, eave - 0.54,
                            -0.08, 0.02), STONE)
    with m.group("balconettes"):
        for uc in (-2.20, 0.0, 2.20):
            m.add(*lbox(s_front, uc - 0.78, uc + 0.78, 7.50, 7.58, -0.34, 0.02), STONE)
            for s_ in (-1.0, 1.0):
                m.add(*beam(lp(s_front, uc + s_ * 0.62, 7.40, 0.0),
                            lp(s_front, uc + s_ * 0.62, 7.48, -0.30), 0.06, 0.06), IRON)
            m.add(*lbox(s_front, uc - 0.76, uc + 0.76, 8.32, 8.38, -0.36, -0.30), IRON)
            for ux in (uc - 0.70, uc, uc + 0.70):
                m.add(*lbox(s_front, ux - 0.03, ux + 0.03, 7.56, 8.34, -0.36, -0.30), IRON)
    with m.group("basement_grilles"):
        for uc in (-1.45, 1.45):
            for (a, b, c_, d_) in ((uc - 0.45, uc + 0.45, 0.20, 0.26),
                                   (uc - 0.45, uc + 0.45, 0.72, 0.78),
                                   (uc - 0.45, uc - 0.39, 0.20, 0.78),
                                   (uc + 0.39, uc + 0.45, 0.20, 0.78)):
                m.add(*lbox(s_front, a, b, c_, d_, -0.10, 0.02), IRON)
            for k in range(4):
                ux = uc - 0.32 + k * 0.21
                m.add(*lbox(s_front, ux - 0.022, ux + 0.022, 0.20, 0.78, -0.12, -0.08),
                      IRON)

    with m.group("parapet"):
        m.add(*box((-4.62, -3.42, C["roof_z"][0]), (4.62, 3.42, C["roof_z"][1])), IRON)
        p0, p1 = C["parapet_z"]
        for (x0, x1, y0, y1) in ((4.42, 4.62, -3.42, 3.42), (-4.62, -4.42, -3.42, 3.42),
                                 (-4.42, 4.42, 3.22, 3.42), (-4.42, 4.42, -3.42, -3.22)):
            m.add(*box((x0, y0, p0), (x1, y1, p1)), BRICK)
            m.add(*tb(x0 - 0.03, x1 + 0.03, y0 - 0.03, y1 + 0.03, p1, p1 + 0.10, 0.03),
                  STONE)
        # 屋顶检修口
        m.add(*box((1.60, -2.10, C["roof_z"][1] - 0.02), (2.40, -1.30,
                                                          C["roof_z"][1] + 0.42)), WOOD)

    # ---- 多个砖烟囱（3 个，最高顶 12.00 = 包围盒最高点） ----
    with m.group("chimneys"):
        for (cx0, cy0, w, top) in ((-3.55, -2.35, 0.95, 12.00),
                                   (-0.35, 2.05, 0.85, 11.70),
                                   (2.55, -1.45, 1.00, 11.85)):
            brick_chimney(m, cx0, cx0 + w, cy0, cy0 + w,
                          C["roof_z"][1] - 0.12, top, pots=2)

    # ---- 后侧（+Y 侧后立面）外挂铁质逃生楼梯：3 平台 + 2 梯段 + 直爬梯 ----
    with m.group("fire_escape"):
        ys, ye_ = wy, wy + 0.74
        plat_z = (C["z1"] + 0.30, C["z2"] + 0.30, eave - 0.25)
        for pz in plat_z:
            m.add(*box((-1.30, ys, pz - 0.07), (1.30, ye_, pz)), IRON)
            for x in (-1.15, 0.0, 1.15):
                m.add(*beam((x, ys + 0.02, pz - 0.07), (x, ye_ - 0.05, pz - 0.55),
                            0.06, 0.07), IRON)
            railing(m, [(-1.30, ye_ - 0.03), (1.30, ye_ - 0.03)], pz,
                    height=1.05, post_step=0.65)
        # 2 段斜梯（平台之间）
        for k in range(2):
            za, zb = plat_z[k] + 0.02, plat_z[k + 1] - 0.02
            xa, xb = 1.15, 2.35
            n = 9
            for i in range(n):
                t = i / float(n - 1)
                m.add(*box((xa + (xb - xa) * t - 0.16, ys + 0.28,
                            za + (zb - za) * t),
                           (xa + (xb - xa) * t + 0.16, ys + 0.62,
                            za + (zb - za) * t + 0.06)), IRON)
            for sy in (0.30, 0.60):
                m.add(*chamfer_beam((xa, ys + sy, za), (xb, ys + sy, zb),
                                    0.05, 0.18, 0.012), IRON)
            m.add(*beam((xa, ye_ - 0.05, za + 0.95), (xb, ye_ - 0.05, zb + 0.95),
                        0.05, 0.05), IRON)
            for tt in (0.0, 0.5, 1.0):
                m.add(*box((xa + (xb - xa) * tt - 0.03, ys + 0.66,
                            za + (zb - za) * tt),
                           (xa + (xb - xa) * tt + 0.03, ys + 0.72,
                            za + (zb - za) * tt + 0.95)), IRON)
        # 底部直爬梯
        ladder(m, 0.0, ys + 0.30, ys + 0.60, 0.60, plat_z[0] - 0.05, rungs=9, axis="x")

    # ---- 门窗构件（店面门已在 shopfront；后门/上层门） ----
    with m.group("doors"):
        door(m, s_back, 0.0, 0.55, 2.95, 1.40, 0.24)
        door(m, s_right, -3.30, 0.55, 2.90, 1.10, 0.20)   # 侧门

    # ---- 落水管 / 烟囱帽 / 屋顶水塔 ----
    with m.group("downpipes"):
        downpipe(m, s_back, -3.80, ptop, eave - 0.20)
        downpipe(m, s_front, 3.05, ptop, eave - 0.20)
    return m


BUILDERS = {
    "boiler_house": build_boiler_house,
    "workshop_row": build_workshop_row,
    "brick_tenement": build_brick_tenement,
}


def build_all_geometry():
    """纯 Python：{SN_HT_<Name>_LOD0: Part}（dryrun_props.py / dryrun_prototypes_batch_b.py 入口）。"""
    _check_specs()
    return {"%s_LOD0" % spec["asset"]: BUILDERS[spec["kind"]]() for spec in PROTOTYPES}


# =========================================================================== #
# 5b. LOD1（批次 B 第二阶段）：三栋简化版 —— 同一份 LOD0 真源常量 +
#     只保留需求 §6 的轮廓识别点；删窗框/窗棂/窗台窗楣/隅石/落水管/次要管线，
#     百叶改整板、栏杆改连续实体板、屋面立缝减半。放工作台 y=225 一排。
# =========================================================================== #

LOD1_SPECS = [
    {
        "asset": "SN_HT_Boiler_House",
        "builder": "build_boiler_house_lod1",
        "target": (12.0, 10.0, 12.0),
        "cap": 2800,
        "location": (-45.0, 225.0, 0.0),
        "keep": ["石基", "错落双坡主屋面 + 平附房屋面", "12 m 高砖烟囱（3 段收分 + 石腰环 + 铁冠）",
                 "外露粗管（+Y 横管 + 附房前墙立管 + 烟囱立管）", "检修平台 + 连续栏板 + 爬梯",
                 "煤场围墙 + 铁门", "煤槽料斗", "石檐口（整条板）"],
        "cut": ["窗框/窗棂", "石窗台/窗楣", "隅石/壁柱柱头柱础", "落水管/檐沟", "屋面立缝（8→4）/脊部通风帽减半",
                "百叶斜片（改整块铁板）", "烟囱爬梯横档（14→7）", "除尘旋风筒细节", "门口石匾"],
        "silhouette": ["stone_base", "roof_main", "roof_annex", "chimney", "pipes", "platform",
                       "yard_wall"],
    },
    {
        "asset": "SN_HT_Workshop_Row",
        "builder": "build_workshop_row_lod1",
        "target": (18.0, 7.0, 8.5),
        "cap": 2800,
        "location": (0.0, 225.0, 0.0),
        "keep": ["3 联锯齿采光顶（坡面 + 高边泛水 + 低边檐沟）", "3 个连续 bay 门（3.6/2.4/3.0 三种宽）",
                 "3 面垂直玻璃天窗带（2 竖梃 + 2 横挡）", "墙面风机（筒体 + 轮毂）",
                 "2 道雨棚 + 端头入口雨棚", "外置铁楼梯（8 级 + 双斜梁 + 连续栏杆）",
                 "连廊猫道 + 连续栏板 + 端部爬梯", "石檐口（整条板）+ 端头招牌"],
        "cut": ["窗框/窗棂", "隅石", "壁柱柱头柱础（留柱身）", "落水管", "屋面立缝（每坡 3→1）",
                "百叶斜片（改整块铁板）", "铁中梃/护网细件", "檐沟/泛水细线脚"],
        "silhouette": ["stone_base", "sawtooth_roof", "clerestory_glazing", "bay_doors",
                       "wall_fans", "external_stair", "catwalk"],
    },
    {
        "asset": "SN_HT_Brick_Tenement",
        "builder": "build_brick_tenement_lod1",
        "target": (10.0, 8.0, 12.0),
        "cap": 4900,
        "location": (45.0, 225.0, 0.0),
        "keep": ["三层砖立面（首层/二层/三层墙板 + 2 道石腰带）", "主立面 6 个真凹窗 + 首层店面凹口 + 封板",
                 "店招 + 雨棚", "转角壁柱（去石箍）", "3 个砖烟囱（两段收身 + 石压顶）",
                 "外挂铁逃生楼梯（3 平台 + 1 段斜梯 + 连续栏板 + 底部爬梯）",
                 "平屋面 + 女儿墙 + 石檐口（整条板）", "侧/背窗列（各留 2–3 个真凹口）"],
        "cut": ["窗框/窗棂/石窗台/窗楣/砖券", "齿饰", "balconettes", "地下室格栅", "隅石",
                "落水管", "侧/背窗数量减半", "转角壁柱石箍", "店招边框/封板压条细件"],
        "silhouette": ["stone_base", "walls", "windows", "corner_piers", "fire_escape",
                       "chimneys", "shopfront", "parapet"],
    },
]

LOD1_BUILDERS = {
    "SN_HT_Boiler_House": "build_boiler_house_lod1",
    "SN_HT_Workshop_Row": "build_workshop_row_lod1",
    "SN_HT_Brick_Tenement": "build_brick_tenement_lod1",
}


def _lod1_window(m, side, uc, vc, w, h, depth, frame=True, sill=True):
    """LOD1 窗：洞口由 panel 真凹口给出，只留 2 竖框 + 上框 + 1 道石窗台（可关）。"""
    hw, hh = w / 2.0, h / 2.0
    if frame:
        for s_ in (-1.0, 1.0):
            ua = uc + s_ * (hw + 0.02)
            ub = uc + s_ * (hw - 0.08)
            m.add(*lbox(side, min(ua, ub), max(ua, ub), vc - hh, vc + hh,
                        -0.02, depth - 0.03), WOOD)
        m.add(*lbox(side, uc - hw + 0.03, uc + hw - 0.03, vc + hh - 0.08, vc + hh + 0.02,
                    -0.02, depth - 0.03), WOOD)
    if sill:
        m.add(*lbox(side, uc - hw - 0.10, uc + hw + 0.10, vc - hh - 0.10, vc - hh + 0.02,
                    -0.08, 0.02), STONE)


def _lod1_door(m, side, uc, v0, v1, w, depth, double=False):
    """LOD1 门：2 竖框 + 上框 + 门扇（单/双）+ 石门槛（去掉压条/拉手/雨棚细件）。"""
    hw = w / 2.0
    for s_ in (-1.0, 1.0):
        ua = uc + s_ * (hw + 0.03)
        ub = uc + s_ * (hw - 0.09)
        m.add(*lbox(side, min(ua, ub), max(ua, ub), v0, v1, -0.02, depth - 0.03), WOOD)
    m.add(*lbox(side, uc - hw + 0.04, uc + hw - 0.04, v1 - 0.10, v1 + 0.03,
                -0.02, depth - 0.03), WOOD)
    n = 2 if double else 1
    for k in range(n):
        if n == 1:
            u0, u1 = uc - hw + 0.05, uc + hw - 0.05
        elif k == 0:
            u0, u1 = uc - hw + 0.05, uc - 0.02
        else:
            u0, u1 = uc + 0.02, uc + hw - 0.05
        m.add(*lbox(side, u0, u1, v0 + 0.03, v1 - 0.08, depth - 0.09, depth - 0.03), WOOD)
    m.add(*lbox(side, uc - hw - 0.04, uc + hw + 0.04, v0 - 0.02, v0 + 0.05,
                -0.02, depth - 0.02), STONE)


def build_boiler_house_lod1():
    """SN_HT_Boiler_House LOD1：保留 烟囱 + 外露粗管 + 检修平台 + 错落屋顶。"""
    C = BH
    m = Part()
    wx_b, ax1, wy = C["wx_back"], C["annex_x1"], C["wy"]
    mx0, mx1, ax0, ay1 = C["main_x0"], C["main_x1"], C["annex_x0"], C["annex_y1"]
    ptop, eave, atop, ridge = (C["plinth_top"], C["main_eave"], C["annex_top"], C["ridge"])
    S = sides(ax1, wy)
    s_front, s_back, s_right, s_left = S["front"], S["back"], S["right"], S["left"]
    s_main_front = ("x", mx1, -1.0)
    s_annex_right = sides(ax1, ay1)["right"]

    with m.group("stone_base"):
        m.add(*tb(-6.0, 6.0, -5.0, 5.0, 0.0, 0.22, 0.10), STONE)
        m.add(*tb(-5.94, 5.94, -4.94, 4.94, 0.20, ptop, 0.04), STONE)

    right_open = [(-4.95, -3.65, 2.60, 5.10, 0.16, GLASS),
                  (-2.55, -1.25, 2.60, 5.10, 0.16, GLASS),
                  (0.55, 1.55, 3.60, 5.50, 0.16, IRON)]
    left_open = [(-4.55, -3.25, 2.70, 5.10, 0.16, GLASS),
                 (-0.55, 0.75, 3.30, 5.25, 0.16, IRON)]
    back_open = [(-0.75, 0.75, 0.60, 2.95, 0.24, WOOD),
                 (-3.30, -2.00, 2.70, 5.10, 0.16, GLASS)]
    annex_front_open = [(-2.35, -0.05, 0.55, 3.55, 0.28, WOOD),
                        (-4.35, -3.15, 1.40, 3.00, 0.16, GLASS)]
    annex_right_open = [(2.20, 3.40, 0.55, 2.70, 0.24, WOOD)]
    with m.group("walls"):
        m.add_multi(*panel("y", wy, -1.0, mx0 - 0.02, mx1, ptop, eave, 0.42, right_open))
        m.add_multi(*panel("y", -wy, 1.0, mx0 - 0.02, mx1, ptop, eave, 0.42, left_open))
        m.add_multi(*panel("x", wx_b, 1.0, -wy - 0.02, wy + 0.02, ptop, eave, 0.42, back_open))
        m.add_multi(*panel("x", mx1, -1.0, -wy - 0.02, wy + 0.02, ptop + 0.02, eave, 0.42, []))
        m.add_multi(*panel("x", ax1, -1.0, -wy - 0.02, ay1 + 0.02, ptop, atop, 0.40,
                           annex_front_open))
        m.add_multi(*panel("y", -wy, 1.0, ax0, ax1 + 0.02, ptop, atop, 0.40, []))
        m.add_multi(*panel("y", ay1, -1.0, ax0 - 0.02, ax1 + 0.02, ptop, atop, 0.40,
                           annex_right_open))

    with m.group("windows"):
        _lod1_window(m, s_right, -4.30, 3.85, 1.30, 2.50, 0.16)
        _lod1_window(m, s_right, -1.90, 3.85, 1.30, 2.50, 0.16)
        _lod1_window(m, s_left, -3.90, 3.90, 1.30, 2.40, 0.16)
        _lod1_window(m, s_back, -2.65, 3.90, 1.30, 2.40, 0.16)
        _lod1_window(m, s_front, -3.75, 2.20, 1.20, 1.60, 0.16)
        # 百叶改整块铁板（删斜片）
        m.add(*lbox(s_right, 0.60, 1.50, 3.65, 5.45, -0.06, 0.02), IRON)
        m.add(*lbox(s_left, -0.50, 0.70, 3.35, 5.20, -0.06, 0.02), IRON)

    with m.group("doors"):
        _lod1_door(m, s_front, -1.20, 0.55, 3.55, 2.30, 0.28, double=True)
        _lod1_door(m, s_back, 0.0, 0.60, 2.95, 1.50, 0.24)
        _lod1_door(m, s_annex_right, 2.90, 0.55, 2.70, 1.20, 0.24)
        steps(m, s_front, -1.20, 1.35, 0.0, ptop + 0.06, n=2, depth=0.42)

    # 主屋面：2 坡 + 脊瓦 + 每坡 2 道立缝 + 2 端山墙
    with m.group("roof_main"):
        for sy in (-1.0, 1.0):
            ye = sy * 5.0
            zt = ridge - abs(ye) * ((ridge - 6.78) / 5.0)
            pts = [(0.0, ridge - 0.22), (ye, zt - 0.22), (ye, zt - 0.06),
                   (ye - sy * 0.07, zt), (0.0, ridge)]
            m.add(*prism_x(pts, -6.0, 2.0), IRON)
        m.add(*box((-5.92, -0.34, ridge - 0.02), (1.95, 0.34, ridge + 0.16)), IRON)
        for sy in (-1.0, 1.0):
            for sx in (-4.2, 0.4):
                m.add(*beam((sx, sy * 4.55, ridge - 4.55 * ((ridge - 6.78) / 5.0) + 0.03),
                            (sx, sy * 0.25, ridge - 0.25 * ((ridge - 6.78) / 5.0) + 0.03),
                            0.075, 0.055), IRON)
        for x0, x1 in ((wx_b, wx_b + 0.42), (mx1 - 0.42, mx1)):
            m.add(*prism_x([(-4.70, 6.72), (4.70, 6.72), (4.70, 6.86),
                            (0.0, ridge - 0.01), (-4.70, 6.86)], x0, x1), BRICK)
        vent_cowl(m, -3.4, 0.0, ridge + 0.10, r=0.30)

    # 附房屋面：平顶 + 3 面女儿墙 + 简化除尘筒
    with m.group("roof_annex"):
        m.add(*box((ax0 - 0.02, -4.68, atop - 0.02), (ax1 + 0.02, ay1 + 0.02, atop + 0.20)),
              IRON)
        m.add(*box((ax1 - 0.06, -4.72, atop + 0.18), (ax1 + 0.06, ay1 + 0.04, atop + 0.52)),
              BRICK)
        m.add(*box((ax0 - 0.02, ay1 - 0.06, atop + 0.18), (ax1 + 0.02, ay1 + 0.06,
                                                          atop + 0.52)), BRICK)
        m.add(*box((ax0 - 0.02, -4.78, atop + 0.18), (ax1 + 0.02, -4.66, atop + 0.52)),
              BRICK)
        m.add(*box((ax1 - 0.10, -4.76, atop + 0.48), (ax1 + 0.10, ay1 + 0.08, atop + 0.58)),
              STONE)
        m.add(*rod((3.0, -2.6, atop + 0.18), (3.0, -2.6, atop + 1.30), 0.42, 10), IRON)
        m.add(*tb(2.50, 3.50, -3.10, -2.10, atop + 1.28, atop + 1.55, 0.12), IRON)

    # 烟囱（轮廓识别点 1）：3 段收分 + 2 石腰环 + 石压顶 + 铁冠 + 简化爬梯
    with m.group("chimney"):
        cx0, cx1, cy0, cy1 = C["chimney"]
        z1 = C["chimney_top"]
        m.add(*tb(cx0 - 0.12, cx1 + 0.12, cy0 - 0.12, cy1 + 0.12, ptop, 1.30, 0.04), STONE)
        zz = 1.30
        for k in range(3):
            a = 0.04 * k
            zz1 = 1.30 + 2.90 * (k + 1)
            m.add(*tb(cx0 - 0.10 + a, cx1 + 0.10 - a, cy0 - 0.10 + a, cy1 + 0.10 - a,
                      zz - 0.03, zz1, 0.03), BRICK)
            m.add(*tb(cx0 - 0.16 + a, cx1 + 0.16 - a, cy0 - 0.16 + a, cy1 + 0.16 - a,
                      zz1 - 0.10, zz1 + 0.02, 0.03), STONE)
            zz = zz1
        m.add(*tb(cx0 + 0.02, cx1 - 0.02, cy0 + 0.02, cy1 - 0.02, zz - 0.02, zz + 0.22,
                  0.04), STONE)
        cx, cy = 0.5 * (cx0 + cx1), 0.5 * (cy0 + cy1)
        m.add(*rod((cx, cy, zz + 0.20), (cx, cy, z1 - 0.18), 0.50, 8), IRON)
        m.add(*tb(cx - 0.62, cx + 0.62, cy - 0.62, cy + 0.62, z1 - 0.18, z1, 0.12), IRON)
        ladder(m, cx0 - 0.02, cy0 + 0.40, cy1 - 0.40, ptop + 0.30, zz - 0.30,
               rungs=5, axis="y")

    # 外露粗管（轮廓识别点 2）：保留 3 条主粗管（+Y 横管 / 附房前墙立管 / 烟囱立管）
    with m.group("pipes"):
        y_pipe = wy + 0.10
        pipe_run(m, [(-5.30, y_pipe, 5.95), (1.20, y_pipe, 5.95),
                     (1.20, y_pipe, 3.20), (2.60, y_pipe, 3.20)],
                 r=0.13, flanges=((1, 0.13),))
        x_pipe = ax1 + 0.13
        pipe_run(m, [(x_pipe, -2.75, 0.80), (x_pipe, -2.75, 4.30),
                     (x_pipe, -0.30, 4.30)], r=0.13, flanges=((1, 0.13),))
        pipe_run(m, [(5.27, 3.10, 5.10), (5.27, 3.10, 10.40)], r=0.12,
                 flanges=((0, 0.12),))
        for x in (-4.6, -2.2, 0.2):
            m.add(*box((x - 0.05, wy, 5.78), (x + 0.05, wy + 0.30, 6.02)), IRON)

    # 煤场围墙 + 铁门（3 竖栅 + 2 横档）
    with m.group("yard_wall"):
        m.add_multi(*panel("x", ax1, -1.0, 2.30, wy + 0.02, ptop, 2.55, 0.30, [],
                           mat_face=BRICK, mat_reveal=STONE, mat_inner=BRICK))
        m.add(*tb(ax1 - 0.34, ax1 + 0.02, 2.26, wy + 0.06, 2.55, 2.68, 0.03), STONE)
        for k in range(3):
            gy = 1.00 + k * 0.50
            m.add(*box((ax1 - 0.06, gy - 0.03, ptop), (ax1 + 0.02, gy + 0.03, 2.30)),
                  IRON)
        for gz in (1.00, 2.14):
            m.add(*box((ax1 - 0.06, 0.70, gz - 0.05), (ax1 + 0.02, 2.20, gz + 0.05)),
                  IRON)

    # 检修平台（轮廓识别点 3）：平台 + 三面连续实体栏板 + 简化爬梯
    with m.group("platform"):
        px0, px1 = 2.90, 4.90
        py0, py1 = wy - 0.70, wy + 0.14
        pz = 6.10
        m.add(*box((px0, py0, pz - 0.10), (px1, py1, pz)), IRON)
        for xx in (3.05, 3.95, 4.80):
            m.add(*beam((xx, 4.00, pz - 0.10), (xx, 4.94, 5.70), 0.06, 0.08), IRON)
        m.add(*box((px0 + 0.04, py1 - 0.06, pz), (px1 - 0.04, py1 + 0.02, pz + 1.05)),
              IRON)
        m.add(*box((px0 - 0.04, py0 + 0.04, pz), (px0 + 0.06, py1 - 0.04, pz + 1.05)),
              IRON)
        m.add(*box((px1 - 0.06, py0 + 0.04, pz), (px1 + 0.04, py1 - 0.04, pz + 1.05)),
              IRON)
        ladder(m, 4.35, 4.03, 4.51, 0.55, pz - 0.10, rungs=6, axis="x")

    with m.group("coal_chute"):
        m.add(*tb(-5.45, -4.45, wy - 0.02, 4.96, 0.60, 2.00, 0.06), IRON)
        m.add(*box((-5.50, 4.70, 1.98), (-4.40, 4.99, 2.06)), IRON)

    with m.group("cornices"):
        for sd, u0, u1 in ((s_right, mx0 - 0.02, mx1 + 0.02),
                           (s_left, mx0 - 0.02, mx1 + 0.02),
                           (s_back, -wy - 0.02, wy + 0.02),
                           (s_main_front, -wy - 0.02, wy + 0.02)):
            m.add(*lbox(sd, u0, u1, 6.30, 6.72, -0.24, 0.02), STONE)
        for sd, u0, u1 in ((s_front, -wy - 0.02, ay1 + 0.02),
                           (s_left, ax0, ax1 + 0.02),
                           (s_annex_right, ax0 - 0.02, ax1 + 0.02)):
            m.add(*lbox(sd, u0, u1, 4.18, atop - 0.02, -0.18, 0.02), STONE)

    with m.group("pilasters"):
        for uc in (-5.05,):
            pilaster(m, s_right, uc, ptop - 0.02, eave, w=0.40, d=0.14)

    with m.group("canopies"):
        canopy(m, s_front, -1.20, 1.55, 3.62, 0.55, drop=0.34)
    return m


def build_workshop_row_lod1():
    """SN_HT_Workshop_Row LOD1：保留 连续 bay 节奏 + 锯齿采光顶 + 外置楼梯/猫道。"""
    C = WR
    m = Part()
    wx, wy = C["wx"], C["wy"]
    ptop, eave, high = C["plinth_top"], C["eave"], C["high"]
    x0, x1, x2, x3 = C["bay_x"]
    S = sides(wx, wy)
    s_front, s_back, s_right, s_left = S["front"], S["back"], S["right"], S["left"]

    with m.group("stone_base"):
        m.add(*tb(-9.0, 9.0, -3.5, 3.5, 0.0, 0.20, 0.06), STONE)
        m.add(*tb(-8.96, 8.96, -3.46, 3.46, 0.18, ptop, 0.03), STONE)

    right_open = [(-7.40, -3.80, 0.50, 4.30, 0.28, WOOD),
                  (-1.20, 1.20, 0.50, 3.60, 0.24, WOOD),
                  (4.10, 7.10, 0.50, 4.00, 0.26, WOOD),
                  (-6.30, -4.90, 4.75, 5.75, 0.16, GLASS),
                  (4.80, 6.40, 4.45, 5.65, 0.16, GLASS)]
    left_open = [(-6.60, -5.40, 1.40, 3.40, 0.16, GLASS),
                 (-1.00, 0.60, 5.00, 5.60, 0.14, IRON)]
    front_open = [(-1.10, 1.10, 0.50, 3.70, 0.28, WOOD),
                  (-2.60, -1.70, 1.50, 3.30, 0.16, GLASS),
                  (1.70, 2.60, 1.50, 3.30, 0.16, GLASS)]
    back_open = [(-0.70, 0.70, 0.50, 3.10, 0.24, WOOD),
                 (-2.60, -1.70, 1.40, 3.20, 0.16, GLASS)]
    with m.group("walls"):
        m.add_multi(*panel("y", wy, -1.0, -wx - 0.02, wx + 0.02, ptop, eave, 0.42, right_open))
        m.add_multi(*panel("y", -wy, 1.0, -wx - 0.02, wx + 0.02, ptop, eave, 0.42, left_open))
        m.add_multi(*panel("x", wx, -1.0, -wy - 0.02, wy + 0.02, ptop, eave, 0.42, front_open))
        m.add_multi(*panel("x", -wx, 1.0, -wy - 0.02, wy + 0.02, ptop, eave, 0.42, back_open))

    with m.group("bay_doors"):
        for uc, w, v1, dep in ((-5.60, 3.60, 4.30, 0.28), (0.0, 2.40, 3.60, 0.24),
                               (5.60, 3.00, 4.00, 0.26)):
            _lod1_door(m, s_right, uc, 0.50, v1, w, dep, double=True)
            m.add(*lbox(s_right, uc - w / 2.0 - 0.25, uc + w / 2.0 + 0.25,
                        v1 + 0.06, v1 + 0.24, -0.12, 0.02), IRON)
        _lod1_door(m, s_front, 0.0, 0.50, 3.70, 2.20, 0.28, double=True)
        _lod1_door(m, s_back, 0.0, 0.50, 3.10, 1.40, 0.24)
        steps(m, s_front, 0.0, 1.30, 0.0, ptop + 0.05, n=2, depth=0.40)

    with m.group("windows"):
        _lod1_window(m, s_right, -5.60, 5.25, 1.40, 1.00, 0.16, frame=True, sill=False)
        _lod1_window(m, s_right, 5.60, 5.05, 1.40, 1.00, 0.16, frame=True, sill=False)
        _lod1_window(m, s_front, -2.20, 2.40, 1.00, 1.80, 0.16, frame=False)
        _lod1_window(m, s_front, 2.20, 2.40, 1.00, 1.80, 0.16, frame=False)
        # 高位百叶改整块铁板
        m.add(*lbox(s_left, -1.00, 0.60, 5.00, 5.60, -0.06, 0.02), IRON)

    # 3 联锯齿采光顶：坡面 + 高边泛水（顶 = 8.50）+ 低边檐沟 + 每坡 1 道立缝
    with m.group("sawtooth_roof"):
        for bx in (x0, x1, x2):
            bx1 = bx + (x3 - x0) / 3.0
            pts = [(bx, eave), (bx1, high), (bx1, high - C["roof_t"]),
                   (bx, eave - C["roof_t"])]
            m.add(*prism_y(pts, -3.40, 3.40), IRON)
            m.add(*box((bx1 - 0.30, -3.42, high - 0.04), (bx1 + 0.02, 3.42, 8.50)), IRON)
            m.add(*prism_y([(bx - 0.02, eave + 0.08), (bx + 0.14, eave + 0.08),
                            (bx + 0.14, eave - 0.02), (bx - 0.02, eave - 0.02)],
                           -3.40, 3.40), IRON)
            xm = bx + (bx1 - bx) * 0.55
            m.add(*beam((xm, -3.30, eave + (high - eave) * 0.55 + 0.03),
                        (xm, 3.30, eave + (high - eave) * 0.55 + 0.03), 0.06, 0.05), IRON)

    # 垂直玻璃天窗带（3 面）：玻璃 + 2 横挡 + 2 竖梃
    with m.group("clerestory_glazing"):
        for k, bx in enumerate((x1, x2, x3)):
            half = 2.80 if k == 2 else 3.34
            m.add(*box((bx - 0.055, -half - 0.02, eave + 0.02),
                       (bx + 0.005, half + 0.02, high - 0.03)), GLASS)
            m.add(*box((bx - 0.09, -half, eave + 0.10), (bx + 0.06, half, eave + 0.20)),
                  WOOD)
            for uc in (-half * 0.45, half * 0.45):
                m.add(*box((bx - 0.08, uc - 0.05, eave), (bx + 0.04, uc + 0.05, high)),
                      WOOD)

    with m.group("wall_fans"):
        for uc, vc, r in ((-3.05, 5.05, 0.50), (3.05, 5.15, 0.50)):
            m.add(*rod(lp(s_right, uc, vc, -0.02), lp(s_right, uc, vc, -0.24), r, 8),
                  IRON)

    with m.group("canopies"):
        for uc, hw, z0 in ((-5.60, 2.10, 4.35), (5.60, 1.95, 4.10)):
            pts = [(-0.02, z0), (-0.55, z0 - 0.36), (-0.55, z0 - 0.42), (-0.02, z0 - 0.08)]
            m.add(*lprism_u(s_right, uc - hw, uc + hw, pts), IRON)
            for s_ in (-1.0, 1.0):
                m.add(*beam(lp(s_right, uc + s_ * (hw - 0.2), z0 - 0.05, -0.04),
                            lp(s_right, uc + s_ * (hw - 0.2), z0 - 0.30, -0.51),
                            0.06, 0.06), IRON)
        m.add(*lprism_u(s_front, -1.65, 1.65,
                        [(-0.02, 3.90), (-0.50, 3.58), (-0.50, 3.52), (-0.02, 3.82)]),
              IRON)

    with m.group("external_stair"):
        z_bot, z_top = 0.50, 4.55
        xs, xe = -8.05, -4.15
        n = 7
        for k in range(n):
            t = k / float(n - 1)
            x = xs + (xe - xs) * t
            z = z_bot + (z_top - z_bot) * t
            m.add(*box((x - 0.20, 2.94, z), (x + 0.20, 3.24, z + 0.07)), IRON)
        for sy in (-1.0, 1.0):
            m.add(*chamfer_beam((xs, 3.02 + sy * 0.13, z_bot),
                                (xe, 3.02 + sy * 0.13, z_top + 0.07), 0.06, 0.20, 0.015),
                  IRON)
        m.add(*beam((xs, 3.30, z_bot + 0.95), (xe, 3.30, z_top + 0.95), 0.05, 0.05),
              IRON)

    with m.group("catwalk"):
        m.add(*box((-4.15, 2.88, 4.47), (1.40, 3.40, 4.55)), IRON)
        for x in (-3.40, -1.60, 0.20):
            m.add(*beam((x, 2.86, 4.46), (x, 3.42, 3.98), 0.06, 0.08), IRON)
        m.add(*box((-4.15, 3.34, 4.55), (1.40, 3.42, 5.55)), IRON)
        ladder(m, 1.30, 2.95, 3.30, 1.20, 4.45, rungs=4, axis="x")

    with m.group("pilasters"):
        for uc in (-2.80, 2.80):
            pilaster(m, s_right, uc, ptop - 0.02, eave, w=0.46, d=0.16)

    with m.group("cornices"):
        for side, u0, u1 in ((s_right, -wx - 0.02, wx + 0.02),
                             (s_left, -wx - 0.02, wx + 0.02),
                             (s_front, -wy - 0.02, wy + 0.02)):
            m.add(*lbox(side, u0, u1, eave - 0.36, eave, -0.22, 0.02), STONE)
        m.add(*lbox(s_front, -1.45, 1.45, 4.45, 5.05, -0.07, 0.02), WOOD)

    with m.group("vents"):
        vent_cowl(m, -8.30, -2.9, eave + 0.05, r=0.24)
    return m


def build_brick_tenement_lod1():
    """SN_HT_Brick_Tenement LOD1：保留 窄高街屋 + 3 烟囱 + 外挂逃生楼梯大轮廓。"""
    C = BT
    m = Part()
    wxf, wxb, wy = C["wx_front"], C["wx_back"], C["wy"]
    ptop, z1, z2, eave = C["plinth_top"], C["z1"], C["z2"], C["eave"]
    S = sides(wxf, wy)
    s_front, s_back, s_right, s_left = S["front"], S["back"], S["right"], S["left"]

    with m.group("stone_base"):
        m.add(*tb(-5.0, 5.0, -4.0, 4.0, 0.0, 0.24, 0.07), STONE)
        m.add(*tb(-4.96, 4.96, -3.96, 3.96, 0.22, ptop, 0.03), STONE)

    front_ground = [(-1.80, 1.80, 0.55, 3.40, 0.30, WOOD)]
    front_upper = [(-2.75, -1.65, 4.55, 6.25, 0.16, GLASS),
                   (-0.55, 0.55, 4.55, 6.25, 0.16, GLASS),
                   (1.65, 2.75, 4.55, 6.25, 0.16, GLASS),
                   (-2.75, -1.65, 7.55, 9.25, 0.16, GLASS),
                   (-0.55, 0.55, 7.55, 9.25, 0.16, GLASS),
                   (1.65, 2.75, 7.55, 9.25, 0.16, GLASS)]
    right_ground = [(-3.30, -2.30, 1.20, 2.90, 0.16, GLASS)]
    right_mid = [(-2.80, -1.80, 4.55, 6.25, 0.16, GLASS)]
    right_top = [(1.20, 2.20, 7.55, 9.25, 0.16, GLASS)]
    left_ground = [(-3.20, -2.20, 1.20, 2.90, 0.16, GLASS)]
    left_mid = [(1.40, 2.40, 4.55, 6.25, 0.16, GLASS)]
    back_ground = [(-0.70, 0.70, 0.55, 2.95, 0.24, WOOD)]
    back_mid = [(-2.85, -1.85, 4.55, 6.25, 0.16, GLASS)]
    back_top = [(1.55, 2.55, 7.55, 9.25, 0.16, GLASS)]
    with m.group("walls"):
        m.add_multi(*panel("x", wxf, -1.0, -wy - 0.02, wy + 0.02, ptop, z1, 0.42,
                           front_ground))
        m.add_multi(*panel("x", wxf, -1.0, -wy - 0.02, wy + 0.02, z1, eave, 0.42,
                           front_upper))
        m.add_multi(*panel("y", wy, -1.0, wxb - 0.02, wxf + 0.02, ptop, z1, 0.40,
                           right_ground))
        m.add_multi(*panel("y", wy, -1.0, wxb - 0.02, wxf + 0.02, z1, z2, 0.40,
                           right_mid))
        m.add_multi(*panel("y", wy, -1.0, wxb - 0.02, wxf + 0.02, z2, eave, 0.40,
                           right_top))
        m.add_multi(*panel("y", -wy, 1.0, wxb - 0.02, wxf + 0.02, ptop, z1, 0.40,
                           left_ground))
        m.add_multi(*panel("y", -wy, 1.0, wxb - 0.02, wxf + 0.02, z1, z2, 0.40,
                           left_mid))
        m.add_multi(*panel("y", -wy, 1.0, wxb - 0.02, wxf + 0.02, z2, eave, 0.40, []))
        m.add_multi(*panel("x", wxb, 1.0, -wy - 0.02, wy + 0.02, ptop, z1, 0.42,
                           back_ground))
        m.add_multi(*panel("x", wxb, 1.0, -wy - 0.02, wy + 0.02, z1, z2, 0.42,
                           back_mid))
        m.add_multi(*panel("x", wxb, 1.0, -wy - 0.02, wy + 0.02, z2, eave, 0.42,
                           back_top))

    # 主立面 6 个窗只留简化木框 + 石窗台（删窗棂/窗楣/砖券）
    with m.group("windows"):
        for (u0, u1, v0, v1, _dep, _bm) in front_upper:
            _lod1_window(m, s_front, 0.5 * (u0 + u1), 0.5 * (v0 + v1),
                         u1 - u0, v1 - v0, 0.16)
        _lod1_window(m, s_right, -2.80, 2.05, 1.00, 1.70, 0.16)
        _lod1_window(m, s_right, -2.30, 5.40, 1.00, 1.70, 0.16)
        _lod1_window(m, s_left, -2.70, 2.05, 1.00, 1.70, 0.16)
        _lod1_window(m, s_back, -2.35, 5.40, 1.00, 1.70, 0.16)

    # 首层小店：封板（4 条）+ 店门 + 空白店招 + 雨棚
    with m.group("shopfront"):
        for k in range(4):
            u = -1.65 + k * 0.80
            m.add(*lbox(s_front, u, u + 0.74, 0.72, 3.22, 0.24, 0.30), WOOD)
        m.add(*lbox(s_front, -1.80, 1.80, 0.55, 0.76, 0.14, 0.32), STONE)
        m.add(*lbox(s_front, -1.85, 1.85, 3.55, 4.15, -0.08, 0.02), WOOD)
        _lod1_door(m, s_front, 1.15, 0.55, 3.30, 1.00, 0.30)
        steps(m, s_front, 1.15, 0.75, 0.0, ptop + 0.04, n=2, depth=0.40)

    with m.group("awning"):
        m.add(*lprism_u(s_front, -2.05, 2.05,
                        [(-0.02, 3.52), (-0.55, 3.10), (-0.55, 3.04), (-0.02, 3.44)]),
              IRON)
        for s_ in (-1.0, 1.0):
            m.add(*beam(lp(s_front, s_ * 1.85, 3.46, -0.04),
                        lp(s_front, s_ * 1.85, 3.12, -0.51), 0.06, 0.06), IRON)

    # 转角壁柱（去石箍）+ 石腰带 + 檐口 + 女儿墙 + 平屋面
    with m.group("corner_piers"):
        for sy in (-1.0, 1.0):
            uc = sy * (wy - 0.18)
            pilaster(m, s_front, uc, ptop - 0.02, eave - 0.10, w=0.62, d=0.17, mat=BRICK)

    with m.group("string_courses"):
        for (zz0, zz1) in ((z1 - 0.02, z1 + 0.14), (z2 - 0.02, z2 + 0.14)):
            m.add(*lbox(s_front, -wy - 0.02, wy + 0.02, zz0, zz1, -0.10, 0.02), STONE)
            m.add(*lbox(s_right, wxb - 0.02, wxf + 0.02, zz0, zz1, -0.09, 0.02), STONE)
            m.add(*lbox(s_left, wxb - 0.02, wxf + 0.02, zz0, zz1, -0.09, 0.02), STONE)
            m.add(*lbox(s_back, -wy - 0.02, wy + 0.02, zz0, zz1, -0.09, 0.02), STONE)

    with m.group("cornice"):
        for side, u0, u1 in ((s_front, -wy - 0.02, wy + 0.02),
                             (s_back, -wy - 0.02, wy + 0.02),
                             (s_right, wxb - 0.02, wxf + 0.02),
                             (s_left, wxb - 0.02, wxf + 0.02)):
            m.add(*lbox(side, u0, u1, eave - 0.46, eave, -0.30, 0.02), STONE)

    with m.group("parapet"):
        p0, p1 = C["parapet_z"]
        m.add(*box((-4.62, -3.42, C["roof_z"][0]), (4.62, 3.42, C["roof_z"][1])), IRON)
        for (x0_, x1_, y0_, y1_) in ((4.42, 4.62, -3.42, 3.42), (-4.62, -4.42, -3.42, 3.42),
                                     (-4.42, 4.42, 3.22, 3.42),
                                     (-4.42, 4.42, -3.42, -3.22)):
            m.add(*box((x0_, y0_, p0), (x1_, y1_, p1)), BRICK)
            m.add(*box((x0_ - 0.03, y0_ - 0.03, p1), (x1_ + 0.03, y1_ + 0.03,
                                                     p1 + 0.10)), STONE)

    # 3 个砖烟囱（简化两段 + 石压顶 + 2 陶土帽；最高顶 12.00）
    with m.group("chimneys"):
        rz = C["roof_z"][1] - 0.12
        for (cx0, cy0, w, top) in ((-3.55, -2.35, 0.95, 12.00),
                                   (-0.35, 2.05, 0.85, 11.70),
                                   (2.55, -1.45, 1.00, 11.85)):
            mid = rz + (top - rz) * 0.55
            m.add(*tb(cx0, cx0 + w, cy0, cy0 + w, rz, mid, 0.02), BRICK)
            m.add(*tb(cx0 + 0.03, cx0 + w - 0.03, cy0 + 0.03, cy0 + w - 0.03,
                      mid - 0.02, top - 0.12, 0.02), BRICK)
            m.add(*tb(cx0 - 0.05, cx0 + w + 0.05, cy0 - 0.05, cy0 + w + 0.05,
                      top - 0.14, top, 0.03), STONE)
            for sx in (-0.02, 0.02):
                m.add(*rod((cx0 + w / 2.0 + sx, cy0 + w / 2.0, top - 0.14),
                           (cx0 + w / 2.0 + sx, cy0 + w / 2.0, top), 0.11, 8),
                      IRON)

    # 外挂铁逃生楼梯（大轮廓）：3 平台 + 1 段斜梯 + 连续栏板 + 底部爬梯
    with m.group("fire_escape"):
        ys, ye_ = wy, wy + 0.74
        plat_z = (C["z1"] + 0.30, C["z2"] + 0.30, eave - 0.25)
        for pz in plat_z:
            m.add(*box((-1.30, ys, pz - 0.07), (1.30, ye_, pz)), IRON)
            for x in (-1.10, 0.0, 1.10):
                m.add(*beam((x, ys + 0.02, pz - 0.07), (x, ye_ - 0.05, pz - 0.55),
                            0.06, 0.07), IRON)
            m.add(*box((-1.30, ye_ - 0.04, pz), (1.30, ye_ + 0.02, pz + 1.05)), IRON)
        za, zb = plat_z[1] + 0.02, plat_z[2] - 0.02
        xa, xb = 1.15, 2.35
        n = 8
        for i in range(n):
            t = i / float(n - 1)
            m.add(*box((xa + (xb - xa) * t - 0.16, ys + 0.28, za + (zb - za) * t),
                       (xa + (xb - xa) * t + 0.16, ys + 0.62,
                        za + (zb - za) * t + 0.06)), IRON)
        for sy in (0.30, 0.60):
            m.add(*chamfer_beam((xa, ys + sy, za), (xb, ys + sy, zb), 0.05, 0.18, 0.012),
                  IRON)
        m.add(*beam((xa, ye_ - 0.04, za + 0.95), (xb, ye_ - 0.04, zb + 0.95),
                    0.05, 0.05), IRON)
        ladder(m, 0.0, ys + 0.30, ys + 0.60, 0.60, plat_z[0] - 0.05, rungs=5, axis="x")

    with m.group("doors"):
        _lod1_door(m, s_back, 0.0, 0.55, 2.95, 1.40, 0.24)
        _lod1_door(m, s_right, -2.80, 0.55, 2.90, 1.10, 0.20)
    return m


def build_all_geometry_lod1():
    """纯 Python：{SN_HT_<Name>_LOD1: Part}（LOD1 干跑入口）。"""
    return {"%s_LOD1" % spec["asset"]: globals()[LOD1_BUILDERS[spec["asset"]]]()
            for spec in LOD1_SPECS}


# =========================================================================== #
# 5c. Blender 侧 LOD1：build / report / 预览（y=225；只碰 3 个 LOD1 对象）
# =========================================================================== #

_LOD1_RESULTS = {}
_LOD1_BASELINE = {}


def _lod1_names():
    return {"%s_LOD1" % s["asset"] for s in LOD1_SPECS}


def _lod1_cells(asset):
    for spec in PROTOTYPES:
        if spec["asset"] == asset:
            return spec["cells"]
    raise KeyError(asset)


def build_lod1():
    """只重建本批 3 个 LOD1（y=225 一排），不碰 LOD0 / A 批对象。"""
    import bpy
    collection = _ensure_collection()
    names = _lod1_names()

    # 先删旧 LOD1，再抓基线（保证基线不含本批 3 个对象，重跑稳定）
    for obj in list(collection.objects):
        if obj.name in names:
            old_mesh = obj.data
            bpy.data.objects.remove(obj, do_unlink=True)
            if old_mesh is not None and old_mesh.users == 0:
                bpy.data.meshes.remove(old_mesh)
    for stale in [me for me in bpy.data.meshes
                  if me.users == 0 and me.name.split("_mesh")[0] in names]:
        bpy.data.meshes.remove(stale)
    bpy.context.view_layer.update()

    _LOD1_BASELINE.clear()
    digest, count, rows = scene_digest(names)
    _LOD1_BASELINE.update({"digest": digest, "count": count, "rows": rows,
                           "collections": _collection_state(),
                           "objects_total": len(bpy.data.objects),
                           "lod0": _lod0_state()})

    built = []
    for spec in LOD1_SPECS:
        part = globals()[LOD1_BUILDERS[spec["asset"]]]()
        name = spec["asset"] + "_LOD1"
        obj = _make_object(name, part, spec["location"], collection, _grey_material)
        tex = _apply_cells(obj, _lod1_cells(spec["asset"]))
        _LOD1_RESULTS[name] = {"spec": spec, "object": obj, "part": part, "texture": tex}
        built.append((name, tri_count(part.faces)))
    bpy.context.view_layer.update()
    return built


def _lod0_state():
    """LOD0 三栋 + A 批 10 个对象的当前状态（用于 digest 之外的逐对象核对）。"""
    import bpy
    names = ["%s_LOD0" % s["asset"] for s in PROTOTYPES] + [
        "SN_HT_Warehouse_Long_LOD0", "SN_HT_Warehouse_Short_LOD0",
        "SN_HT_Harbor_Office_LOD0", "SN_HT_Cargo_Shed_LOD0", "SN_HT_Tavern_LOD0",
        "SN_HT_Warehouse_Long_LOD1", "SN_HT_Warehouse_Short_LOD1",
        "SN_HT_Harbor_Office_LOD1", "SN_HT_Cargo_Shed_LOD1", "SN_HT_Tavern_LOD1"]
    out = {}
    for n in names:
        o = bpy.data.objects.get(n)
        if o is None:
            out[n] = None
            continue
        mesh = o.data
        out[n] = {"tris": len(mesh.loop_triangles), "verts": len(mesh.vertices),
                  "geo": _geo_sig(o),
                  "location": [round(v, 4) for v in o.location],
                  "dims": [round(v, 4) for v in o.dimensions]}
    return out


def report_lod1():
    """LOD1 逐栋自检 + 与 LOD0 的 bbox/轴心对比 + 全场景 digest 回归。"""
    import bpy
    import json
    import os

    os.makedirs(OUT_DIR, exist_ok=True)
    mats = _load_materials()
    out = {"objects": {}, "comparisons": {}, "regression": {},
           "plan": [{"asset": s["asset"], "cap": s["cap"], "keep": s["keep"],
                     "cut": s["cut"], "silhouette": s["silhouette"]}
                    for s in LOD1_SPECS]}
    for spec in LOD1_SPECS:
        name = spec["asset"] + "_LOD1"
        entry = _LOD1_RESULTS.get(name)
        if entry is None:
            out["objects"][name] = {"missing": True}
            continue
        obj = entry["object"]
        tex = _apply_cells(obj, _lod1_cells(spec["asset"]))
        verify = tex.get("verify") or {}
        vchecks = verify.get("checks") or {}
        met = _mesh_metrics(obj)
        feats = feature_report(entry["part"])
        lod0 = bpy.data.objects.get(spec["asset"] + "_LOD0")
        lod0_met = _mesh_metrics(lod0) if lod0 else None
        ratio = (met["tris"] / float(lod0_met["tris"])) if lod0_met and lod0_met["tris"] else 99.0
        size_delta = [round(met["size"][i] - lod0_met["size"][i], 6) for i in range(3)] \
            if lod0_met else None
        bbox_delta = ([round(met["bbox"][0][i] - lod0_met["bbox"][0][i], 6) for i in range(3)] +
                      [round(met["bbox"][1][i] - lod0_met["bbox"][1][i], 6) for i in range(3)]) \
            if lod0_met else None
        target = spec["target"]
        missing_sil = [t for t in spec["silhouette"] if t not in feats]
        checks = {
            "tris_within_cap": met["tris"] <= spec["cap"],
            "tris_within_35pct_lod0": ratio <= 0.35 + 1e-9,
            "size_matches_target_0.02": all(
                abs(met["size"][i] - target[i]) <= 0.02 for i in range(3)),
            "bbox_matches_lod0_0.02": bool(lod0_met) and
                                      all(abs(d) <= 0.02 for d in size_delta) and
                                      all(abs(d) <= 0.02 for d in bbox_delta),
            "grounded_zmin_zero": abs(met["zmin"]) <= 1e-6,
            "pivot_ground_centre": abs(met["pivot_xy"][0]) <= 1e-6 and
                                   abs(met["pivot_xy"][1]) <= 1e-6,
            "material_slots_le_6": 0 < len(met["material_slots"]) <= MAX_MATERIAL_SLOTS,
            "palette_only": all(m in PALETTE for m in met["material_slots"] if m),
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
            "silhouette_features_present": not missing_sil,
        }
        checks["all_pass"] = all(checks.values())
        out["objects"][name] = {
            "asset": spec["asset"], "object": obj.name, "location": list(spec["location"]),
            "cap": spec["cap"], "target": list(target),
            "measured": met, "lod0_measured": lod0_met,
            "tri_ratio_vs_lod0": round(ratio, 5),
            "size_delta_vs_lod0": size_delta, "bbox_corner_delta_vs_lod0": bbox_delta,
            "silhouette_features": {t: {"faces": feats[t]["faces"],
                                        "tris": feats[t]["tris"],
                                        "bbox": feats[t]["bbox"]}
                                    for t in spec["silhouette"] if t in feats},
            "missing_silhouette": missing_sil,
            "keep": spec["keep"], "cut": spec["cut"],
            "uv": {"uv_layer": tex.get("uv_layer"), "uv_loops": tex.get("uv_loops"),
                   "uv_range_u": tex.get("uv_range_u"), "uv_range_v": tex.get("uv_range_v"),
                   "textured_slots": tex.get("textured_slots"),
                   "bound_images": verify.get("bound_images"),
                   "material_usage": verify.get("material_usage"),
                   "cells": _lod1_cells(spec["asset"])},
            "checks": checks,
        }

    # ---- 全场景 digest 回归（排除 3 个 LOD1）：258 → 261，非目标零改动 ----
    digest, count, rows = scene_digest(_lod1_names())
    before = {r["name"]: r for r in _LOD1_BASELINE.get("rows", [])}
    after = {r["name"]: r for r in rows}
    missing = sorted(set(before) - set(after))
    added = sorted(set(after) - set(before))
    modified = [n for n in sorted(set(before) & set(after))
                if json.dumps(before[n], sort_keys=True) != json.dumps(after[n], sort_keys=True)]
    lod0_now = _lod0_state()
    lod0_changed = [n for n, v in (_LOD1_BASELINE.get("lod0") or {}).items()
                    if lod0_now.get(n) != v]
    out["regression"] = {
        "excluded_from_digest": sorted(_lod1_names()),
        "baseline_count": _LOD1_BASELINE.get("count"), "after_count": count,
        "baseline_objects_total": _LOD1_BASELINE.get("objects_total"),
        "after_objects_total": len(bpy.data.objects),
        "digest_matches_baseline": _LOD1_BASELINE.get("digest") == digest,
        "missing_objects": missing, "added_objects": added, "modified_objects": modified,
        "collections_before": _LOD1_BASELINE.get("collections"),
        "collections_after": _collection_state(),
        "collections_delta": _collections_delta_lod1(),
        "collections_consistent": _collections_consistent_lod1(),
        "lod0_and_batch_a_changed": lod0_changed,
        "lod0_and_batch_a_state": lod0_now,
    }

    with open(os.path.join(OUT_DIR, "lod1_report.json"), "w", encoding="utf-8") as handle:
        json.dump(out, handle, ensure_ascii=False, indent=1)

    brief = {
        "tris": {k: (v["measured"]["tris"], v["cap"], v["tri_ratio_vs_lod0"])
                 for k, v in out["objects"].items() if "measured" in v},
        "bbox_delta": {k: v["size_delta_vs_lod0"] for k, v in out["objects"].items()
                       if "measured" in v},
        "all_pass": {k: v["checks"]["all_pass"] for k, v in out["objects"].items()
                     if "checks" in v},
        "missing_silhouette": {k: v["missing_silhouette"] for k, v in out["objects"].items()
                              if "measured" in v},
        "regression": {k: out["regression"][k] for k in
                       ("digest_matches_baseline", "baseline_count", "after_count",
                        "baseline_objects_total", "after_objects_total",
                        "missing_objects", "added_objects", "modified_objects",
                        "collections_consistent", "lod0_and_batch_a_changed")},
    }
    print("LOD1_PROTOTYPES_REPORT " + repr(brief))
    return out


def _collections_delta_lod1():
    before = _LOD1_BASELINE.get("collections") or {}
    after = _collection_state()
    return {n: {"before": before.get(n), "after": after.get(n)}
            for n in sorted(set(before) | set(after)) if before.get(n) != after.get(n)}


def _collections_consistent_lod1():
    """除 SN_Iron_Harbor_Architecture 增加 3 个 LOD1 外，集合结构不变。"""
    before = _LOD1_BASELINE.get("collections") or {}
    after = _collection_state()
    if set(after) != set(before):
        return False
    for name, a in after.items():
        b = before[name]
        if name == COLLECTION:
            if a["children"] != b["children"] or a["objects"] != b["objects"] + len(LOD1_SPECS):
                return False
        elif a != b:
            return False
    return True


def render_lod1_previews(assets=None):
    """EEVEE 1280×800：每栋 LOD1 3 视图 + LOD0/LOD1 同机位对比（临时平移 LOD1，渲染后还原）。"""
    import bpy
    bpy.context.view_layer.update()
    out_dir = SCREENSHOT_DIR
    os.makedirs(out_dir, exist_ok=True)
    scene = bpy.context.scene
    saved = {"engine": scene.render.engine,
             "res": (scene.render.resolution_x, scene.render.resolution_y,
                     scene.render.resolution_percentage),
             "filepath": scene.render.filepath, "camera": scene.camera}

    cam_data = bpy.data.cameras.new("TMP_LOD1P_CAM")
    cam = bpy.data.objects.new("TMP_LOD1P_CAM", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    lights = []
    for lname, energy, rot, color in (
            ("TMP_LOD1P_KEY", 2.6, (48.0, 0.0, 128.0), (1.0, 0.96, 0.90)),
            ("TMP_LOD1P_FILL", 0.55, (62.0, 0.0, 8.0), (0.80, 0.87, 1.0)),
            ("TMP_LOD1P_RIM", 0.9, (18.0, 0.0, 210.0), (0.92, 0.94, 1.0))):
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
            entry = _LOD1_RESULTS.get(spec["asset"] + "_LOD1")
            lod0 = bpy.data.objects.get(spec["asset"] + "_LOD0")
            if entry is None or lod0 is None:
                continue
            obj = entry["object"]
            _apply_cells(obj, _lod1_cells(spec["asset"]))
            obj.hide_render = False
            bpy.context.view_layer.update()
            lo, hi = _bbox_world([obj])
            centre = (lo + hi) * 0.5
            radius = max((hi - lo).length * 0.5, 1.0)
            for vtag in ("street_3q", "front_x", "roof"):
                files.append(_render_view([obj], centre, radius, vtag,
                                          "%s_LOD1" % spec["asset"], cam, cam_data,
                                          scene, out_dir))
            # ---- 同机位对比：LOD1 临时移到 LOD0 +X 侧，同框渲染后还原 ----
            lod0.hide_render = False
            width0 = lod0.dimensions.x if lod0.dimensions.x > 0 else abs(spec["target"][0])
            moved[obj] = tuple(obj.location)
            obj.location = (lod0.location.x + width0 + 3.0, lod0.location.y, 0.0)
            bpy.context.view_layer.update()
            lo, hi = _bbox_world([lod0, obj])
            centre = (lo + hi) * 0.5
            radius = max((hi - lo).length * 0.5, 1.0)
            for vtag in ("street_3q", "front_x", "roof"):
                files.append(_render_view([lod0, obj], centre, radius, vtag,
                                          "%s_LOD1_vs_LOD0" % spec["asset"], cam, cam_data,
                                          scene, out_dir))
            for o, loc in moved.items():
                o.location = loc
            moved.clear()
            obj.hide_render = True
            lod0.hide_render = True
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
    print("LOD1_PROTOTYPES_PREVIEW " + repr({"count": len(files),
                                             "files": [os.path.basename(f) for f in files]}))
    return files


# =========================================================================== #
# 6. 纯 Python 度量（dryrun 与 report 共用）
# =========================================================================== #

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
    xs = [v[0] for v in part.verts]
    ys = [v[1] for v in part.verts]
    zs = [v[2] for v in part.verts]
    boundary, nonman = edge_stats(part.faces)
    mats = []
    for _f, mat in part.faces:
        if mat not in mats:
            mats.append(mat)
    return {
        "tris": tri_count(part.faces), "verts": len(part.verts),
        "size": [round(max(xs) - min(xs), 6), round(max(ys) - min(ys), 6),
                 round(max(zs) - min(zs), 6)],
        "bbox": [[round(min(xs), 6), round(min(ys), 6), round(min(zs), 6)],
                 [round(max(xs), 6), round(max(ys), 6), round(max(zs), 6)]],
        "zmin": round(min(zs), 9),
        "pivot_xy": [round(0.5 * (min(xs) + max(xs)), 9),
                     round(0.5 * (min(ys) + max(ys)), 9)],
        "boundary_edges": boundary, "non_manifold_edges": nonman,
        "degenerate_faces": degenerate_faces(part.verts, part.faces),
        "materials": mats, "material_slots": len(mats),
    }


# =========================================================================== #
# 7. Blender 侧：材质 / 对象 / digest / 报告
# =========================================================================== #

_RESULTS = {}
_BASELINE = {}


def _load_file(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _load_materials():
    return _load_file(os.path.join(HERE, "sn_iron_harbor_materials.py"),
                      "sn_iron_harbor_materials")


def _ensure_collection():
    import bpy
    col = bpy.data.collections.get(COLLECTION)
    if col is None:
        col = bpy.data.collections.new(COLLECTION)
        bpy.context.scene.collection.children.link(col)
    return col


def _make_object(name, part, location, collection, grey_materials):
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
    import bpy
    mat = bpy.data.materials.get(name)
    if mat is not None:
        return mat
    tints = {BRICK: 0.345, PLASTER: 0.560, WOOD: 0.215, IRON: 0.120,
             STONE: 0.445, GLASS: 0.050}
    tint = tints.get(name, 0.5)
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (tint, tint, tint, 1.0)
    mat.diffuse_color = (tint, tint, tint, 1.0)
    return mat


def _apply_cells(obj, cells):
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


def _target_names():
    return {"%s_LOD0" % s["asset"] for s in PROTOTYPES}


def scene_digest(exclude_names=None):
    """除本批 3 个原型外的全场景指纹（与批次 A 的 digest 同 schema，便于横向对比）。"""
    import hashlib
    import json
    import bpy
    exclude = set(exclude_names or _target_names())
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
    """只重建本批 3 个原型 LOD0（y=200 一排），不碰其它对象。"""
    import bpy
    collection = _ensure_collection()
    names = _target_names()

    # 先删旧原型，再抓基线：保证基线集合基数不含本批 3 个对象（重跑也稳定）
    for obj in list(collection.objects):
        if obj.name in names:
            old_mesh = obj.data
            bpy.data.objects.remove(obj, do_unlink=True)
            if old_mesh is not None and old_mesh.users == 0:
                bpy.data.meshes.remove(old_mesh)
    for stale in [me for me in bpy.data.meshes
                  if me.users == 0 and me.name.split("_mesh")[0] in names]:
        bpy.data.meshes.remove(stale)
    bpy.context.view_layer.update()

    _BASELINE["digest"], _BASELINE["count"], _BASELINE["rows"] = scene_digest(names)
    _BASELINE["collections"] = _collection_state()
    _BASELINE["objects_total"] = len(bpy.data.objects)

    built = []
    for spec in PROTOTYPES:
        part = BUILDERS[spec["kind"]]()
        name = spec["asset"] + "_LOD0"
        obj = _make_object(name, part, spec["location"], collection, _grey_material)
        tex = _apply_cells(obj, spec["cells"])
        _RESULTS[name] = {"spec": spec, "object": obj, "part": part, "texture": tex}
        built.append((name, tri_count(part.faces)))
    bpy.context.view_layer.update()
    return built


def _mesh_metrics(obj):
    import bmesh
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


def _wall_breakup_evidence(spec):
    """>6 m 可见墙面打断统计（开口数 + 壁柱/腰带/雨棚/百叶等第二类打断）。"""
    if spec["kind"] == "boiler_house":
        return {
            "right_long_wall": {"span_m": 7.6, "openings": 5,
                                "second_breakup": "3 砖壁柱 + 石檐口 + 管支架 + 煤槽"},
            "left_long_wall": {"span_m": 7.6, "openings": 4,
                               "second_breakup": "2 砖壁柱 + 石檐口 + 灰斗"},
            "back_wall": {"span_m": 9.4, "openings": 4,
                          "second_breakup": "2 砖壁柱 + 落水管 + 石檐口"},
            "front_annex_wall": {"span_m": 5.2, "openings": 4,
                                 "second_breakup": "石匾 + 雨棚 + 石檐口"},
        }
    if spec["kind"] == "workshop_row":
        return {
            "right_long_wall": {"span_m": 16.8, "openings": 7,
                                "second_breakup": "4 砖壁柱 + 2 风机 + 2 雨棚 + 石腰带 + 猫道"},
            "left_long_wall": {"span_m": 16.8, "openings": 6,
                               "second_breakup": "4 砖壁柱 + 石腰带 + 落水管 + 高百叶"},
            "front_end_wall": {"span_m": 5.6, "openings": 4,
                               "second_breakup": "2 壁柱 + 石匾 + 雨棚 + 锯齿山墙"},
            "back_end_wall": {"span_m": 5.6, "openings": 3,
                              "second_breakup": "石檐口 + 隅石"},
        }
    return {
        "front_wall": {"span_m": 6.4, "openings": 9,
                       "second_breakup": "转角壁柱 + 2 道石腰带 + 店招 + 雨棚"},
        "right_wall": {"span_m": 8.8, "openings": 7,
                       "second_breakup": "2 道石腰带 + 外挂逃生楼梯 + 隅石"},
        "left_wall": {"span_m": 8.8, "openings": 6,
                      "second_breakup": "2 道石腰带 + 隅石 + 落水管"},
        "back_wall": {"span_m": 6.4, "openings": 7,
                      "second_breakup": "2 道石腰带 + 落水管"},
    }


def _collections_delta():
    before = _BASELINE.get("collections") or {}
    after = _collection_state()
    delta = {}
    for name in sorted(set(before) | set(after)):
        if before.get(name) != after.get(name):
            delta[name] = {"before": before.get(name), "after": after.get(name)}
    return delta


def _collections_consistent():
    """除 SN_Iron_Harbor_Architecture 增加 3 个原型外，集合结构必须与基线一致。"""
    before = _BASELINE.get("collections") or {}
    after = _collection_state()
    if set(after) != set(before):
        return False
    for name, a in after.items():
        b = before[name]
        if name == COLLECTION:
            if a["children"] != b["children"] or a["objects"] != b["objects"] + len(PROTOTYPES):
                return False
        elif a != b:
            return False
    return True


def report():
    import json
    import os
    import bpy

    os.makedirs(OUT_DIR, exist_ok=True)
    mats = _load_materials()
    out = {"objects": {}, "regression": {}, "variation": VARIATION,
           "required_features": REQUIRED_FEATURES}
    for spec in PROTOTYPES:
        name = spec["asset"] + "_LOD0"
        entry = _RESULTS.get(name)
        if entry is None:
            out["objects"][name] = {"missing": True}
            continue
        obj = entry["object"]
        tex = _apply_cells(obj, spec["cells"])
        verify = tex.get("verify") or {}
        vchecks = verify.get("checks") or {}
        met = _mesh_metrics(obj)
        features = feature_report(entry["part"])
        missing_features = [t for t in REQUIRED_FEATURES[spec["asset"]] if t not in features]
        bands = spec["tris_band"]
        checks = {
            "tris_in_target_band": bands[0] <= met["tris"] <= bands[1],
            "tris_within_hard_cap": met["tris"] <= spec["cap"],
            "size_matches_target_0.10": all(
                abs(met["size"][i] - spec["target"][i]) <= 0.10 for i in range(3)),
            "grounded_zmin_zero": abs(met["zmin"]) <= 1e-6,
            "pivot_ground_centre": abs(met["pivot_xy"][0]) <= 1e-6 and
                                   abs(met["pivot_xy"][1]) <= 1e-6,
            "material_slots_le_6": 0 < len(met["material_slots"]) <= MAX_MATERIAL_SLOTS,
            "palette_only": all(m in PALETTE for m in met["material_slots"] if m),
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
            "required_features_present": not missing_features,
            "at_least_two_silhouette_features": len(REQUIRED_FEATURES[spec["asset"]]) >= 2,
            "window_recess_ok": min(RECESS[spec["asset"]]["windows"]) >= 0.08,
            "door_recess_ok": min(RECESS[spec["asset"]]["doors"]) >= 0.12,
            "wall_breakup_ok": all(
                v["openings"] >= 1 and v["second_breakup"]
                for v in _wall_breakup_evidence(spec).values()),
        }
        checks["all_pass"] = all(checks.values())
        out["objects"][name] = {
            "asset": spec["asset"], "object": obj.name, "location": list(spec["location"]),
            "target": list(spec["target"]), "tris_band": list(bands), "cap": spec["cap"],
            "measured": met, "features": features, "missing_features": missing_features,
            "recess_m": RECESS[spec["asset"]],
            "wall_breakup": _wall_breakup_evidence(spec),
            "uv": {"uv_layer": tex.get("uv_layer"), "uv_loops": tex.get("uv_loops"),
                   "uv_range_u": tex.get("uv_range_u"), "uv_range_v": tex.get("uv_range_v"),
                   "textured_slots": tex.get("textured_slots"),
                   "bound_images": verify.get("bound_images"),
                   "material_usage": verify.get("material_usage"),
                   "cells": spec["cells"]},
            "checks": checks,
        }

    digest, count, rows = scene_digest()
    baseline_rows = {r["name"]: r for r in _BASELINE.get("rows", [])}
    after_rows = {r["name"]: r for r in rows}
    missing = sorted(set(baseline_rows) - set(after_rows))
    added = sorted(set(after_rows) - set(baseline_rows))
    modified = [n for n in sorted(set(baseline_rows) & set(after_rows))
                if json.dumps(baseline_rows[n], sort_keys=True) !=
                json.dumps(after_rows[n], sort_keys=True)]
    out["regression"] = {
        "excluded_from_digest": sorted(_target_names()),
        "baseline_count": _BASELINE.get("count"), "after_count": count,
        "baseline_objects_total": _BASELINE.get("objects_total"),
        "after_objects_total": len(bpy.data.objects),
        "digest_matches_baseline": _BASELINE.get("digest") == digest,
        "missing_objects": missing, "added_objects": added, "modified_objects": modified,
        "collections_before": _BASELINE.get("collections"),
        "collections_after": _collection_state(),
        "collections_delta": _collections_delta(),
        "collections_match": _collections_consistent(),
        "kit_objects_10": {
            n: {"tris": len(bpy.data.objects[n].data.loop_triangles),
                "location": [round(v, 3) for v in bpy.data.objects[n].location],
                "dims": [round(v, 3) for v in bpy.data.objects[n].dimensions]}
            for n in sorted(n_ for n_ in bpy.data.objects.keys()
                            if n_.startswith("SN_HT_") and
                            (n_.endswith("_LOD0") or n_.endswith("_LOD1")) and
                            n_ not in _target_names())},
    }

    with open(os.path.join(OUT_DIR, "prototypes_report.json"), "w", encoding="utf-8") as handle:
        json.dump(out, handle, ensure_ascii=False, indent=1)
    brief = {
        "tris": {k: (v["measured"]["tris"], v["tris_band"], v["cap"])
                 for k, v in out["objects"].items() if "measured" in v},
        "sizes": {k: (v["measured"]["size"], v["target"])
                  for k, v in out["objects"].items() if "measured" in v},
        "all_pass": {k: v["checks"]["all_pass"] for k, v in out["objects"].items()
                     if "checks" in v},
        "missing_features": {k: v.get("missing_features")
                             for k, v in out["objects"].items() if "measured" in v},
        "regression": {k: out["regression"][k] for k in
                       ("digest_matches_baseline", "baseline_count", "after_count",
                        "missing_objects", "added_objects", "modified_objects",
                        "collections_match")},
    }
    print("PROTOTYPES_REPORT " + repr(brief))
    return out


# =========================================================================== #
# 8. Blender 侧：预览渲染（每栋 3 视图 + 1 张三栋 lineup）
# =========================================================================== #

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


def _render_view(objs, centre, radius, vtag, name, cam, cam_data, scene, out_dir,
                 stem=None):
    import bpy
    from mathutils import Vector
    direction, lens, ctype = next((d, l, c) for (t, d, l, c) in _VIEWS if t == vtag)
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
    path = os.path.join(out_dir, "%s_1280x800.png" % (stem or ("%s_%s" % (name, vtag))))
    scene.render.filepath = path
    print("[prototypes-render] %s %s cam=%s type=%s" % (
        name, vtag, tuple(round(v, 2) for v in cam.location), cam_data.type))
    bpy.ops.render.render(write_still=True)
    return path


def render_previews(assets=None):
    """EEVEE 1280×800：每栋 3 视图 + 三栋 lineup；finally 还原相机/灯/世界/引擎/分辨率。"""
    import bpy
    bpy.context.view_layer.update()
    out_dir = SCREENSHOT_DIR
    os.makedirs(out_dir, exist_ok=True)
    scene = bpy.context.scene
    saved = {"engine": scene.render.engine,
             "res": (scene.render.resolution_x, scene.render.resolution_y,
                     scene.render.resolution_percentage),
             "filepath": scene.render.filepath, "camera": scene.camera}

    cam_data = bpy.data.cameras.new("TMP_PROTO_CAM")
    cam = bpy.data.objects.new("TMP_PROTO_CAM", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    lights = []
    for lname, energy, rot, color in (
            ("TMP_PROTO_KEY", 2.6, (48.0, 0.0, 128.0), (1.0, 0.96, 0.90)),
            ("TMP_PROTO_FILL", 0.55, (62.0, 0.0, 8.0), (0.80, 0.87, 1.0)),
            ("TMP_PROTO_RIM", 0.9, (18.0, 0.0, 210.0), (0.92, 0.94, 1.0))):
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

    wanted = set(assets) if assets else {s["asset"] for s in PROTOTYPES}
    hidden = {}
    for o in bpy.data.objects:
        if o.type == "MESH":
            hidden[o] = o.hide_render
            o.hide_render = True
    files = []
    try:
        for spec in PROTOTYPES:
            if spec["asset"] not in wanted:
                continue
            entry = _RESULTS.get(spec["asset"] + "_LOD0")
            if entry is None:
                continue
            obj = entry["object"]
            _apply_cells(obj, spec["cells"])
            obj.hide_render = False
            bpy.context.view_layer.update()
            lo, hi = _bbox_world([obj])
            centre = (lo + hi) * 0.5
            radius = max((hi - lo).length * 0.5, 1.0)
            for vtag in ("street_3q", "front_x", "roof"):
                files.append(_render_view([obj], centre, radius, vtag,
                                          "%s_LOD0" % spec["asset"], cam, cam_data, scene,
                                          out_dir))
            obj.hide_render = True
        # ---- 三栋并排 lineup ----
        lineup = [_RESULTS[s["asset"] + "_LOD0"]["object"] for s in PROTOTYPES
                  if s["asset"] in wanted and s["asset"] + "_LOD0" in _RESULTS]
        if len(lineup) == len(PROTOTYPES):
            for spec in PROTOTYPES:
                entry = _RESULTS[spec["asset"] + "_LOD0"]
                _apply_cells(entry["object"], spec["cells"])
                entry["object"].hide_render = False
            bpy.context.view_layer.update()
            lo, hi = _bbox_world(lineup)
            centre = (lo + hi) * 0.5
            radius = max((hi - lo).length * 0.5, 1.0)
            files.append(_render_view(lineup, centre, radius, "street_3q",
                                      "SN_HT_PROTOTYPES_LOD0_lineup", cam, cam_data,
                                      scene, out_dir,
                                      stem="SN_HT_PROTOTYPES_LOD0_lineup"))
            for o in lineup:
                o.hide_render = True
            bpy.context.view_layer.update()
    finally:
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
    print("PROTOTYPES_PREVIEW " + repr({"count": len(files),
                                        "files": [os.path.basename(f) for f in files]}))
    return files


if "bpy" in globals():
    print("sn_iron_harbor_prototypes_generator: call build_all() / report() / "
          "render_previews(assets=None); pure-python dryrun: build_all_geometry()")
