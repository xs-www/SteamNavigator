# -*- coding: utf-8 -*-
# @static-doc
# 作用：Steam Navigator 船体帆索部件库 `rig_kit`（纯 Python，不 import bpy）——
# 把原先焊死在 3 艘船生成器里的桅杆 / 横桁 / 斜桁 / 帆杠 / 艏斜桁 / 帆面 / 索具
# 收敛成一套**参数化部件函数**，船型生成器只保留「布局」（桅位、后倾、帆角、锚点），
# 几何全部由本库组合；独立 `SN_Rig_*` 套件资产也从同一份函数导出，不维护第二套几何。
#
# ## 分层
# - `RigBuilder`：Part 适配器。包住任意船体 `Part` 与它的基本体模块（`prims`），
#   统一 `add(vf, material)` 与材质键（`wood / wood_dark / deck / metal / brass /
#   canvas / canvas_shade / iron`）。SF/PF 的 Part 是 `add(vf, mat)`；铁甲舰是
#   `add(verts, faces, mat)`（`legacy=True`），基本体各自保留，保证重构逐位一致。
# - 通用积木：`rope / ropes / spar / spar_jaws / block`。
# - 船型部件（sail 帆船 / steam 蒸汽船 / ironclad 铁甲舰）：`schooner_mast`,
#   `schooner_gaff_sail`, `schooner_headsails`, `schooner_standing_rigging`,
#   `schooner_running_rigging`, `steamer_mast`, `steamer_yard`, `steamer_bowsprit`,
#   `steamer_rigging`, `ironclad_masts`, `ironclad_rigging`。
#
# ## 几何不变量
# - 本库函数只接收「数值 + 材质键 + 布局字典」，不使用某艘船的模块级常量；
#   帆船 / 蒸汽船 / 铁甲舰三型各自的原构造顺序被原样保留，调用顺序 = 面顺序，
#   因此 3 艘船重构后逐对象顶点 / 面 digest 必须与基线完全一致
#   （见 `rig_kit_baseline.py`）。
# - 单位米、+X 船首、+Z 向上；帆面是单层曲面（双面材质），其余为闭合壳体。
#
# 用法：
# ```python
# import rig_kit, ship_parts.core as core
# part = core.Part()
# b = rig_kit.builder(part, core)
# rig_kit.schooner_mast(b, {"lower": 10.8, "top": 17.0, "gallant": 21.3, ...})
# ```
# @end-static-doc

import math


DEFAULT_MATERIALS = {
    "wood": "SN_Wood",
    "wood_dark": "SN_Wood_Dark",
    "deck": "SN_Wood_Deck",
    "metal": "SN_Metal",
    "brass": "SN_Brass",
    "canvas": "SN_Canvas",
    "canvas_shade": "SN_Canvas_Shade",
    "iron": "SN_Iron_Hull",
    "dark": "SN_Wood_Dark",
}

# 共享贴图材质（独立套件资产用；船体仍用旧纯色名，由批次 B 的迁移脚本在 GLB 前换贴图）
KIT_MATERIALS = {
    "wood": "SN_Tex_Wood",
    "wood_dark": "SN_Tex_Wood_Dark",
    "deck": "SN_Tex_Wood_Deck",
    "metal": "SN_Tex_Metal",
    "brass": "SN_Tex_Brass",
    "canvas": "SN_Tex_Canvas_Shade",
    "canvas_shade": "SN_Tex_Canvas_Shade",
    "iron": "SN_Tex_Iron",
    "dark": "SN_Tex_Wood_Dark",
}


class RigBuilder(object):
    """把 rig 部件追加到任意船体 `Part`；`prims` 提供基本体函数（taper_cyl / box / ...）。"""

    def __init__(self, part, prims, materials=None, legacy=False):
        self.part = part
        self.prims = prims
        self.materials = dict(DEFAULT_MATERIALS)
        if materials:
            self.materials.update(materials)
        self.legacy = legacy

    def mat(self, key):
        return self.materials[key]

    def add(self, verts_faces, material):
        if self.legacy:
            verts, faces = verts_faces
            self.part.add(verts, faces, material)
        else:
            self.part.add(verts_faces, material)


def builder(part, prims, materials=None, legacy=False):
    return RigBuilder(part, prims, materials=materials, legacy=legacy)


# ============================================================
# 通用积木
# ============================================================

def rope(b, p0, p1, radius=0.030, sides=4, material="wood_dark", taper=0.0):
    """两点之间的圆索（默认等径；taper 为末端半径收分）。"""
    b.add(b.prims.taper_cyl(p0, p1, radius, radius + taper, sides),
          b.mat(material))


def ropes(b, lines, radius=0.030, sides=4, material="wood_dark", taper=0.0):
    """批量索具：lines = [(p0, p1), ...]，按顺序追加。"""
    for p0, p1 in lines:
        rope(b, p0, p1, radius, sides, material, taper)


def spar(b, p0, p1, r0=0.10, r1=0.07, sides=6, material="wood_dark"):
    """任意方向的圆截面帆桁 / 斜桁。"""
    b.add(b.prims.taper_cyl(p0, p1, r0, r1, sides), b.mat(material))


def spar_jaws(b, z_center, half_x=0.22, half_y=0.24, half_z=0.10,
             material="wood_dark"):
    """斜桁 / 帆杠端部的桅杆夹钳（jaws）。"""
    b.add(b.prims.box((-half_x, -half_y, z_center - half_z),
                      (half_x, half_y, z_center + half_z)), b.mat(material))


def brass_band(b, center, radius, half_len=0.07, sides=6, material="brass"):
    """套在桁端的黄铜箍。"""
    x, y, z = center
    b.add(b.prims.taper_cyl((x - half_len, y, z), (x + half_len, y, z),
                            radius, radius, sides), b.mat(material))


def block(b, center, size=0.16, material="wood_dark", sheave="metal"):
    """索具滑车：木壳 + 金属滑轮。"""
    c = center
    h = size * 0.5
    b.add(b.prims.box((c[0] - h, c[1] - h * 0.55, c[2] - h),
                      (c[0] + h, c[1] + h * 0.55, c[2] + h)), b.mat(material))
    b.add(b.prims.taper_cyl((c[0], c[1] - h * 0.75, c[2]),
                            (c[0], c[1] + h * 0.75, c[2]),
                            size * 0.30, size * 0.30, 6), b.mat(sheave))


# ============================================================
# 帆面曲面（单层，双面材质）
# ============================================================

def _forward_horizontal(clew, tack):
    """帆面前缘的水平方向（与旧生成器逐位一致的 vnorm 计算）。"""
    dx = clew[0] - tack[0]
    dy = clew[1] - tack[1]
    dz = clew[2] - tack[2]
    if math.sqrt(dx * dx + dy * dy + dz * dz) <= 1e-6:
        return (1.0, 0.0, 0.0)
    vx, vz = dx, dz
    length = math.sqrt(vx * vx + vz * vz) or 1.0
    return (vx / length, 0.0, vz / length)


def quad_surface(tack, throat, peak, clew, camber, roach):
    """斜桁帆曲面：tack 前下 / throat 前上 / peak 后上 / clew 后下。"""
    fwd_h = _forward_horizontal(clew, tack)

    def surface(u, v):
        foot = (tack[0] + (clew[0] - tack[0]) * u,
                tack[1] + (clew[1] - tack[1]) * u,
                tack[2] + (clew[2] - tack[2]) * u)
        head = (throat[0] + (peak[0] - throat[0]) * u,
                throat[1] + (peak[1] - throat[1]) * u,
                throat[2] + (peak[2] - throat[2]) * u)
        p = (foot[0] + (head[0] - foot[0]) * v,
             foot[1] + (head[1] - foot[1]) * v,
             foot[2] + (head[2] - foot[2]) * v)
        aft = roach * (u ** 2) * math.sin(math.pi * v)
        p = (p[0] + fwd_h[0] * aft, p[1], p[2] + fwd_h[2] * aft)
        cam = camber * math.sin(math.pi * u) * math.sin(math.pi * (0.12 + 0.88 * v))
        return (p[0], p[1] + cam, p[2])

    return surface


def tri_surface(head, tack, clew, camber, roach):
    """三角帆曲面：head 顶点 / tack 前下 / clew 后下。"""
    fwd_h = _forward_horizontal(clew, tack)

    def surface(u, v):
        luff = (tack[0] + (head[0] - tack[0]) * v,
                tack[1] + (head[1] - tack[1]) * v,
                tack[2] + (head[2] - tack[2]) * v)
        leech = (clew[0] + (head[0] - clew[0]) * v,
                 clew[1] + (head[1] - clew[1]) * v,
                 clew[2] + (head[2] - clew[2]) * v)
        p = (luff[0] + (leech[0] - luff[0]) * u,
             luff[1] + (leech[1] - luff[1]) * u,
             luff[2] + (leech[2] - luff[2]) * u)
        aft = roach * (u ** 2) * math.sin(math.pi * v)
        p = (p[0] + fwd_h[0] * aft, p[1], p[2] + fwd_h[2] * aft)
        cam = camber * math.sin(math.pi * u) * math.sin(math.pi * v) * (1.0 - 0.30 * v)
        return (p[0], p[1] + cam, p[2])

    return surface


def square_surface(x_base, z_head, z_foot, half_head, half_foot, camber):
    """方帆曲面：u ∈ [-1, 1] 横向、v ∈ [0, 1] 从桁到帆脚。"""

    def surface(u, v):
        half = half_head + (half_foot - half_head) * v
        y = u * half
        z = z_head + (z_foot - z_head) * v + 0.13 * math.sin(
            math.pi * (u + 1.0) * 0.5) * (v ** 2)
        x = x_base + camber * math.sin(math.pi * (u + 1.0) * 0.5) * math.sin(
            math.pi * v * 0.92)
        return (x, y, z)

    return surface


def sail_seams(b, surface, u0, u1, n, v_values, dv=0.022, y_off=0.020,
               material="canvas_shade"):
    """帆缝 / 缩帆带：贴合曲面的窄条（u0..u1 映射到曲面 u 参数）。"""
    for vs in v_values:
        verts, faces = [], []
        for i in range(n):
            a = u0 + (u1 - u0) * i / float(n)
            c = u0 + (u1 - u0) * (i + 1) / float(n)
            p00 = surface(a, vs)
            p10 = surface(c, vs)
            p11 = surface(c, min(1.0, vs + dv))
            p01 = surface(a, min(1.0, vs + dv))
            base = len(verts)
            for p in (p00, p10, p11, p01):
                verts.append((p[0], p[1] + y_off, p[2]))
            faces.append((base, base + 1, base + 2, base + 3))
        b.add((verts, faces), b.mat(material))


def bolt_rope(b, points, radius=0.021, material="wood_dark", sides=4):
    """帆缘绳（luff / foot / head / leech）。"""
    b.add(b.prims.polyline_tube(points, [radius] * len(points), sides),
          b.mat(material))


def gaff_sail(b, tack, throat, peak, clew, camber, roach, nu=10, nv=8,
              seams=(0.16, 0.32, 0.48, 0.64, 0.80)):
    """斜桁帆：曲面 + 5 道帆缝 + 主缩帆带 + 4 条帆缘绳。"""
    surface = quad_surface(tack, throat, peak, clew, camber, roach)
    verts, faces = [], []
    for j in range(nv + 1):
        v = j / float(nv)
        for i in range(nu + 1):
            verts.append(surface(i / float(nu), v))
    for j in range(nv):
        for i in range(nu):
            a = j * (nu + 1) + i
            c = a + nu + 1
            faces.append((a, c, c + 1, a + 1))
    b.add((verts, faces), b.mat("canvas"))
    sail_seams(b, surface, 0.0, 1.0, nu, seams)
    sail_seams(b, surface, 0.0, 1.0, nu, (0.895,), dv=0.040, y_off=0.028)
    bolt_rope(b, [surface(0.0, k / 7.0) for k in range(8)])
    bolt_rope(b, [surface(k / 8.0, 0.0) for k in range(9)])
    bolt_rope(b, [surface(k / 8.0, 1.0) for k in range(9)])
    bolt_rope(b, [surface(1.0, k / 8.0) for k in range(9)])


def tri_sail(b, head, tack, clew, camber, roach, nu=8, nv=8,
             seams=(0.16, 0.32, 0.48, 0.64, 0.80)):
    """三角帆：曲面 + 帆缝 + 三条帆缘绳。"""
    surface = tri_surface(head, tack, clew, camber, roach)
    verts, faces = [], []
    for j in range(nv):
        v = j / float(nv)
        for i in range(nu + 1):
            verts.append(surface(i / float(nu), v))
    for j in range(nv - 1):
        for i in range(nu):
            a = j * (nu + 1) + i
            c = a + nu + 1
            faces.append((a, c, c + 1, a + 1))
    apex = len(verts)
    verts.append(surface(0.5, 1.0))
    last = (nv - 1) * (nu + 1)
    for i in range(nu):
        faces.append((last + i, last + i + 1, apex))
    b.add((verts, faces), b.mat("canvas"))
    sail_seams(b, surface, 0.0, 1.0, nu, seams)
    bolt_rope(b, [surface(0.0, k / 8.0) for k in range(9)])
    bolt_rope(b, [surface(k / 8.0, 0.0) for k in range(9)])
    bolt_rope(b, [surface(1.0, k / 8.0) for k in range(9)])


def square_sail(b, x_base, z_head, z_foot, half_head, half_foot, camber,
                nu=10, nv=6):
    """方帆：曲面 + 2 道帆缝 + 4 条帆缘绳。"""
    surface = square_surface(x_base, z_head, z_foot, half_head, half_foot, camber)
    verts, faces = [], []
    for j in range(nv + 1):
        v = j / float(nv)
        for i in range(nu + 1):
            u = -1.0 + 2.0 * i / nu
            verts.append(surface(u, v))
    for j in range(nv):
        for i in range(nu):
            a = j * (nu + 1) + i
            c = a + nu + 1
            faces.append((a, c, c + 1, a + 1))
    b.add((verts, faces), b.mat("canvas"))
    sail_seams(b, surface, -1.0, 1.0, nu, (0.30, 0.58), dv=0.028)
    bolt_rope(b, [surface(-1.0 + 2.0 * k / 8.0, 0.0) for k in range(9)])
    bolt_rope(b, [surface(-1.0 + 2.0 * k / 8.0, 1.0) for k in range(9)])
    bolt_rope(b, [surface(-1.0, k / 8.0) for k in range(9)])
    bolt_rope(b, [surface(1.0, k / 8.0) for k in range(9)])


# ============================================================
# 帆船（schooner）部件
# ============================================================

def schooner_mast(b, cfg, foot=-0.85):
    """帆船桅杆（局部坐标）：下桅 / 顶桅 / 上桅 + 桅帽 / 桅顶平台 / 横担 / 帆箍 / 顶珠。"""
    p = b.prims
    lower, top, gal = cfg["lower"], cfg["top"], cfg["gallant"]
    rl, rt, rg = cfg["r_lower"], cfg["r_top"], cfg["r_gal"]
    b.add(p.taper_cyl((0, 0, foot), (0, 0, lower), rl[0], rl[1], 8), b.mat("wood"))
    b.add(p.taper_cyl((0, 0, lower - 1.15), (0, 0, top - 0.95),
                      rt[0], rt[1], 8), b.mat("wood"))
    b.add(p.taper_cyl((0, 0, top - 1.30), (0, 0, gal), rg[0], rg[1], 6),
          b.mat("wood"))
    # 桅帽 / 顶桅帽
    b.add(p.box((-0.58, -0.30, lower - 0.13), (0.58, 0.30, lower + 0.13)),
          b.mat("wood_dark"))
    b.add(p.box((-0.46, -0.24, top - 0.12), (0.46, 0.24, top + 0.12)),
          b.mat("wood_dark"))
    # 桅顶平台（top）
    plat = [(-0.95, -0.82), (0.72, -0.82), (0.92, 0.0),
            (0.72, 0.82), (-0.95, 0.82)]
    b.add(p.prism_xy(plat, lower - 0.17, lower - 0.09), b.mat("wood_dark"))
    # 横担（crosstrees）
    b.add(p.box((-0.30, -1.45, top - 0.05), (0.30, 1.45, top + 0.09)),
          b.mat("wood_dark"))
    b.add(p.box((-0.18, -1.15, top + 0.09), (0.18, 1.15, top + 0.15)),
          b.mat("wood"))
    # 帆箍 / 铁箍
    n_hoops = 7
    for i in range(n_hoops):
        z = 1.00 + (lower - 2.00) * i / (n_hoops - 1)
        t = (z - foot) / (lower - foot)
        r = rl[0] + (rl[1] - rl[0]) * t + 0.035
        b.add(p.taper_cyl((0, 0, z - 0.035), (0, 0, z + 0.035), r, r, 8),
              b.mat("wood_dark"))
    # 顶桅箍
    for z in (top - 0.55, top - 1.05):
        b.add(p.taper_cyl((0, 0, z - 0.03), (0, 0, z + 0.03), rt[1] + 0.03,
                          rt[1] + 0.03, 8), b.mat("metal"))
    # 桅顶滑轮 / 顶珠
    b.add(p.taper_cyl((0, 0, gal - 0.12), (0, 0, gal + 0.06), 0.13, 0.10, 8),
          b.mat("wood_dark"))
    b.add(p.taper_cyl((0, 0, gal + 0.06), (0, 0, gal + 0.20), 0.075, 0.035, 8),
          b.mat("brass"))


def schooner_spars(b, gaff, boom, jaws_z, peak_band, clew_band, topsail=None,
                   jaws=(0.22, 0.24, 0.10), band_dx=(0.14, 0.02)):
    """帆船斜桁 + 帆杠（局部坐标，可带方顶帆桁）。

    gaff / boom：{"r0": r0, "r1": r1} 且端点来自 gaff["throat"]/["peak"]、
    boom["tack"]/["clew"]；顶端黄铜箍峰值半径由 `peak_band` / `clew_band` 给出。
    `jaws` = 夹钳半尺寸，`band_dx` = 黄铜箍两端沿 -X 的偏移。
    """
    p = b.prims
    b.add(p.taper_cyl(gaff["throat"], gaff["peak"], gaff["r0"], gaff["r1"], 6),
          b.mat("wood_dark"))
    b.add(p.taper_cyl(boom["tack"], boom["clew"], boom["r0"], boom["r1"], 6),
          b.mat("wood_dark"))
    for zc in jaws_z:
        b.add(p.box((-jaws[0], -jaws[1], zc - jaws[2]),
                    (jaws[0], jaws[1], zc + jaws[2])), b.mat("wood_dark"))
    for point, radius in ((gaff["peak"], peak_band), (boom["clew"], clew_band)):
        b.add(p.taper_cyl((point[0] + band_dx[0], 0.0, point[2] - 0.01),
                          (point[0] + band_dx[1], 0.0, point[2]),
                          radius + 0.02, radius + 0.02, 6), b.mat("brass"))
    if topsail:
        b.add(p.taper_cyl(
            (topsail["x"], -topsail["half_head"] - 0.30, topsail["z_head"] + 0.16),
            (topsail["x"], topsail["half_head"] + 0.30, topsail["z_head"] + 0.16),
            0.095, 0.095, 6), b.mat("wood_dark"))
        for ys in (-topsail["half_head"], topsail["half_head"]):
            b.add(p.taper_cyl((topsail["x"], ys - 0.06, topsail["z_head"] + 0.13),
                              (topsail["x"], ys + 0.06, topsail["z_head"] + 0.13),
                              0.13, 0.13, 6), b.mat("brass"))


def schooner_shroud_fan(b, top_pt, anchors, rows, top_offsets=(0.0, 0.0),
                        rung_width=0.055, rope_radius=0.034,
                        deadeye_radius=0.095, material="wood_dark"):
    """一侧下桅绳梯：锚点到桅顶的 4 根侧支索 + 横档 + 甲板眼板。"""
    p = b.prims
    for index, anchor in enumerate(anchors):
        offset = top_offsets[0] + (top_offsets[1] - top_offsets[0]) * (
            index / max(1, len(anchors) - 1))
        part_top = (top_pt[0] + offset, top_pt[1], top_pt[2])
        b.add(p.taper_cyl(part_top, anchor, rope_radius, rope_radius, 4),
              b.mat(material))
        b.add(p.taper_cyl((anchor[0], anchor[1] - deadeye_radius * 0.79,
                           anchor[2] + 0.03),
                          (anchor[0], anchor[1] + deadeye_radius * 0.79,
                           anchor[2] + 0.03),
                          deadeye_radius, deadeye_radius, 6), b.mat(material))
    for row in range(rows):
        t = 0.16 + 0.68 * row / float(max(1, rows - 1))
        a = (top_pt[0] + top_offsets[0] - 0.083, top_pt[1], top_pt[2])
        b_anchor = (top_pt[0] + top_offsets[1] + 0.083, top_pt[1], top_pt[2])
        start = (a[0] + (anchors[0][0] - a[0]) * t,
                 a[1] + (anchors[0][1] - a[1]) * t,
                 a[2] + (anchors[0][2] - a[2]) * t)
        end = (b_anchor[0] + (anchors[-1][0] - b_anchor[0]) * t,
               b_anchor[1] + (anchors[-1][1] - b_anchor[1]) * t,
               b_anchor[2] + (anchors[-1][2] - b_anchor[2]) * t)
        b.add(p.bar_between(start, end, rung_width * 2.0), b.mat(material))


def schooner_headsails(b, layout):
    """艏三角帆：大 jib（艏斜桁延伸杆 -> 前桅顶）+ fore staysail。"""
    mast_world = layout["mast_world"]
    jib_head = mast_world("Fore", layout["fore_top"] - 0.20)
    jib_tack = (layout["jibboom_tip"][0] - 0.10,
                0.0, layout["jibboom_tip"][2] - 0.10)
    jib_clew = (5.55, 0.0, 4.20)
    tri_sail(b, (jib_head[0], 0.10, jib_head[2]),
             (jib_tack[0], 0.10, jib_tack[2]),
             (jib_clew[0], 0.10, jib_clew[2]), 0.62, 0.34,
             nu=9, nv=9, seams=(0.16, 0.32, 0.48, 0.64, 0.80))
    stay_head = mast_world("Fore", layout["fore_lower"] - 0.55)
    stay_tack = (13.10, 0.0, 4.10)
    stay_clew = (8.25, 0.0, 4.00)
    tri_sail(b, (stay_head[0], 0.08, stay_head[2]),
             (stay_tack[0], 0.08, stay_tack[2]),
             (stay_clew[0], 0.08, stay_clew[2]), 0.40, 0.22,
             nu=7, nv=7, seams=(0.20, 0.40, 0.60, 0.80))


def schooner_standing_rigging(b, layout):
    """帆船静索：下桅绳梯 / 顶桅侧支索 + 绳梯 / 后支索 / 前后支索 / 艏斜桁拉索。"""
    p = b.prims
    masts = layout["masts"]
    mast_world = layout["mast_world"]
    deck_z_at = layout["deck_z_at"]
    half_beam_at = layout["half_beam_at"]
    deck_w_frac = layout["deck_w_frac"]

    def rope_line(a, c, radius):
        b.add(p.taper_cyl(a, c, radius, radius, 4), b.mat("wood_dark"))

    for key in ("Fore", "Main"):
        cfg = masts[key]
        lower = cfg["lower"]
        top = cfg["top"]
        gal = cfg["gallant"]
        mast_x = cfg["x"]
        for side in (1, -1):
            top_pt = mast_world(key, lower - 0.45)
            # 下桅侧支索（4 根 / 舷）+ 绳梯
            anchors = []
            for i in range(4):
                xx = mast_x - 1.02 + i * 0.68
                yy = deck_w_frac * half_beam_at(xx) + 0.34
                az = deck_z_at(xx) + 0.02
                anchor = (xx, side * yy, az)
                anchors.append(anchor)
                p_top = (top_pt[0] + (i - 1.5) * 0.055, side * 0.12, top_pt[2])
                rope_line(p_top, anchor, 0.034)
                b.add(p.taper_cyl((xx, side * (yy - 0.075), az + 0.03),
                                  (xx, side * (yy + 0.075), az + 0.03),
                                  0.095, 0.095, 6), b.mat("wood_dark"))
            for row in range(9):
                t = 0.16 + 0.68 * row / 8.0
                a = (top_pt[0] - 0.083, side * 0.12, top_pt[2])
                c = (top_pt[0] + 0.083, side * 0.12, top_pt[2])
                start = (a[0] + (anchors[0][0] - a[0]) * t,
                         a[1] + (anchors[0][1] - a[1]) * t,
                         a[2] + (anchors[0][2] - a[2]) * t)
                end = (c[0] + (anchors[3][0] - c[0]) * t,
                       c[1] + (anchors[3][1] - c[1]) * t,
                       c[2] + (anchors[3][2] - c[2]) * t)
                b.add(p.bar_between(start, end, 0.028), b.mat("wood_dark"))
            # 顶桅侧支索（3 根 / 舷）+ 绳梯
            top2 = mast_world(key, top - 0.35)
            for i in range(3):
                xx = mast_x - 0.72 + i * 0.72
                anchor = (xx, side * (0.62 + 0.10 * i),
                          deck_z_at(mast_x) + lower - 0.10)
                p_top = (top2[0], side * (0.10 + 0.06 * i), top2[2])
                rope_line(p_top, anchor, 0.028)
            for row in range(5):
                t = 0.18 + 0.58 * row / 4.0
                a = (top2[0], side * 0.10, top2[2])
                c = (mast_x - 0.72, side * 0.62,
                     deck_z_at(mast_x) + lower - 0.10)
                start = (a[0] + (c[0] - a[0]) * t, a[1] + (c[1] - a[1]) * t,
                         a[2] + (c[2] - a[2]) * t)
                d = (top2[0], side * 0.22, top2[2])
                e = (mast_x + 0.72, side * 0.82,
                     deck_z_at(mast_x) + lower - 0.10)
                end = (d[0] + (e[0] - d[0]) * t, d[1] + (e[1] - d[1]) * t,
                       d[2] + (e[2] - d[2]) * t)
                b.add(p.bar_between(start, end, 0.024), b.mat("wood_dark"))
            # 顶桅后支索（2 根 / 舷）
            top_back = mast_world(key, top - 0.55)
            for i, xx in enumerate((-9.60, -8.60)):
                yy = deck_w_frac * half_beam_at(xx) + 0.30
                anchor = (xx, side * yy, deck_z_at(xx) + 0.15)
                p_top = (top_back[0], side * (0.05 + 0.05 * i), top_back[2])
                rope_line(p_top, anchor, 0.024)
            # 上桅后支索（2 根 / 舷）
            back_top = mast_world(key, gal - 0.20)
            for i, xx in enumerate((-10.40, -9.40)):
                yy = deck_w_frac * half_beam_at(xx) + 0.25
                anchor = (xx, side * yy, deck_z_at(xx) + 0.10)
                p_top = (back_top[0], side * (0.05 + 0.05 * i), back_top[2])
                rope_line(p_top, anchor, 0.026)
    # 前后支索 / 艏支索
    fore_gal = mast_world("Fore", masts["Fore"]["gallant"] - 0.25)
    fore_top = mast_world("Fore", masts["Fore"]["top"] - 0.25)
    main_gal = mast_world("Main", masts["Main"]["gallant"] - 0.25)
    main_top = mast_world("Main", masts["Main"]["top"] - 0.30)
    stem_head = (12.44, 0.0, 3.30)
    jib_tip = (layout["jibboom_tip"][0], 0.0, layout["jibboom_tip"][2])
    fore_lower = mast_world("Fore", masts["Fore"]["lower"] - 0.30)
    main_lower = mast_world("Main", masts["Main"]["lower"] - 0.30)
    rope_line(fore_gal, stem_head, 0.044)
    rope_line(fore_top, jib_tip, 0.038)
    rope_line(main_gal, (layout["fore_x"], 0.0,
                         layout["fore_deck_z"] + 10.0), 0.044)
    rope_line(main_top, (layout["fore_x"], 0.0,
                         layout["fore_deck_z"] + 10.0), 0.038)
    rope_line(main_lower, fore_lower, 0.040)
    # 艏斜桁下拉索 / 系固索
    bow_tip = (layout["bowsprit_tip"][0], 0.0, layout["bowsprit_tip"][2])
    rope_line(jib_tip, (12.62, 0.0, 0.55), 0.032)
    rope_line(bow_tip, (12.62, 0.0, 0.55), 0.030)
    rope_line(fore_gal, bow_tip, 0.032)


def schooner_running_rigging(b, layout):
    """帆船动索：升降索 / 转帆索 / 帆脚索 / 吊索。"""
    p = b.prims
    masts = layout["masts"]
    mast_world = layout["mast_world"]
    mast_to_world = layout["mast_to_world"]
    deck_surface_z = layout["deck_surface_z"]
    sails = layout["sails"]
    topsails = layout["topsails"]
    fore_x = layout["fore_x"]

    def rope_line(a, c, radius=0.024):
        b.add(p.taper_cyl(a, c, radius, radius, 4), b.mat("wood_dark"))

    fore_sail = sails["Fore"]
    main_sail = sails["Main"]
    # 前桅斜桁帆：halyard / peak halyard / topping lift
    fore_mast_top = mast_world("Fore", masts["Fore"]["top"] + 0.10)
    fore_throat = mast_to_world("Fore", fore_sail["throat"])
    fore_peak = mast_to_world("Fore", fore_sail["peak"])
    fore_clew = mast_to_world("Fore", fore_sail["clew"])
    rope_line(fore_mast_top, fore_throat, 0.026)
    rope_line(fore_mast_top, fore_peak)
    rope_line(fore_mast_top, fore_clew)
    rope_line(fore_clew, (layout["main_x"] + 0.55, 0.55,
                          deck_surface_z(-1.2) + 0.30))
    rope_line(fore_throat, (fore_x + 1.10, 1.55,
                            deck_surface_z(fore_x + 1.1) + 0.35), 0.022)
    # 主桅大斜桁帆
    main_mast_top = mast_world("Main", masts["Main"]["top"] + 0.10)
    main_throat = mast_to_world("Main", main_sail["throat"])
    main_peak = mast_to_world("Main", main_sail["peak"])
    main_clew = mast_to_world("Main", main_sail["clew"])
    rope_line(main_mast_top, main_throat, 0.026)
    rope_line(main_mast_top, main_peak)
    rope_line(main_mast_top, main_clew)
    rope_line(main_clew, (-11.40, 0.60, deck_surface_z(-11.2) + 0.35))
    rope_line(main_throat, (-6.20, -1.35, deck_surface_z(-6.2) + 0.35), 0.022)
    # 方顶帆转帆索 / 升降索
    ts = topsails["Fore"]
    yard_l = mast_to_world("Fore", (ts["x"], -ts["half_head"] - 0.28,
                                    ts["z_head"] + 0.16))
    yard_r = mast_to_world("Fore", (ts["x"], ts["half_head"] + 0.28,
                                    ts["z_head"] + 0.16))
    rope_line(yard_l, (-10.90, -2.20, deck_surface_z(-10.8) + 0.45), 0.022)
    rope_line(yard_r, (-10.90, 2.20, deck_surface_z(-10.8) + 0.45), 0.022)
    rope_line(fore_mast_top, mast_to_world(
        "Fore", (ts["x"], 0.0, ts["z_head"] + 0.16)), 0.022)
    for point in (yard_l, yard_r):
        b.add(p.box((point[0] - 0.08, point[1] - 0.06, point[2] - 0.08),
                    (point[0] + 0.08, point[1] + 0.06, point[2] + 0.08)),
              b.mat("metal"))
    # 艏三角帆的帆脚索
    jib_clew = (5.55, 0.10, 4.20)
    rope_line(jib_clew, (7.20, 2.40, deck_surface_z(7.0) + 0.35), 0.022)
    rope_line(jib_clew, (7.20, -2.40, deck_surface_z(7.0) + 0.35), 0.022)
    # 主桅三角顶帆的帆脚索 / 升降索
    main_topsail = topsails["Main"]
    rope_line(mast_world("Main", main_topsail["head"][2] - 0.15),
              mast_world("Main", main_topsail["throat"][2]), 0.024)
    rope_line(mast_world("Main", main_topsail["peak"][2]),
              (-10.30, 1.85, deck_surface_z(-10.2) + 0.40), 0.022)


# ============================================================
# 蒸汽船（paddle steamer）部件
# ============================================================

def steamer_mast(b, spec):
    """蒸汽货轮桅杆：下桅 / 上桅 / 桅帽 / 2 道铁箍 / 桅顶桅冠。"""
    p = b.prims
    x, z0, z_low, z_top = spec["x"], spec["z0"], spec["z_low"], spec["z_top"]
    r_low = spec.get("r_low", (0.36, 0.22))
    r_top = spec.get("r_top", (0.17, 0.08))
    b.add(p.taper_cyl((x, 0, z0), (x, 0, z_low), r_low[0], r_low[1], 8),
          b.mat("wood"))
    b.add(p.taper_cyl((x, 0, z_low - 0.18), (x, 0, z_top),
                      r_top[0], r_top[1], 8), b.mat("wood"))
    b.add(p.box((x - 0.26, -0.30, z_low - 0.12),
                (x + 0.26, 0.30, z_low + 0.08)), b.mat("wood"))
    for frac in (0.30, 0.62):
        z = z0 + (z_low - z0) * frac
        r = r_low[0] + (r_low[1] - r_low[0]) * frac + 0.03
        b.add(p.taper_cyl((x, 0, z - 0.07), (x, 0, z + 0.07), r, r, 8),
              b.mat("metal"))
    b.add(p.taper_cyl((x, 0, z_top - 0.02), (x, 0, z_top + 0.18), 0.10, 0.04, 6),
          b.mat("metal"))


def steamer_yard(b, spec):
    """蒸汽货轮横桁 + 收帆卷：横桁 / 帆布卷 / 两端铁帽。"""
    p = b.prims
    z, width = spec["yard_z"], spec["yard_w"]
    x = spec["x"] + 0.30
    b.add(p.taper_cyl((x, -width * 0.5, z), (x, width * 0.5, z),
                      0.13, 0.10, 6), b.mat("wood"))
    b.add(p.taper_cyl((x - 0.08, -spec["sail_w"] * 0.5, z - 0.09),
                      (x - 0.08, spec["sail_w"] * 0.5, z - 0.09),
                      0.24, 0.24, 8), b.mat("deck"))
    for sy in (-1, 1):
        b.add(p.box((x - 0.08, sy * width * 0.5 - 0.07, z - 0.07),
                    (x + 0.10, sy * width * 0.5 + 0.07, z + 0.07)),
              b.mat("metal"))


def steamer_bowsprit(b, spec):
    """蒸汽货轮艏斜桁 + 绑扎铁箱 + 端部铁帽。"""
    p = b.prims
    b.add(p.taper_cyl((spec["x0"], 0, spec["z0"]), (spec["x1"], 0, spec["z1"]),
                      spec["r0"], spec["r1"], 8), b.mat("wood"))
    b.add(p.box(spec["gammon_lo"], spec["gammon_hi"]), b.mat("iron"))
    b.add(p.taper_cyl((spec["x1"], 0, spec["z1"] - 0.03),
                      (spec["x1"] - 0.35, 0, spec["z1"] - 0.03),
                      0.13, 0.13, 6), b.mat("metal"))


def steamer_rigging(b, layout):
    """蒸汽货轮索具：艏支索 / 桅间支索 / 侧支索 / 吊杆拉索。"""
    p = b.prims
    fore, main = layout["masts"][0], layout["masts"][1]
    anchors = layout["anchors"]
    lines = [
        ((fore["x"], 0.0, fore["z_top"] - 0.10), anchors["fore_head"]),
        ((fore["x"], 0.0, fore["z_top"] - 0.15),
         (main["x"], 0.0, main["z_top"] - 0.20)),
        (anchors["fore_head"], anchors["stem"]),
    ]
    for side in (1, -1):
        lines += [
            ((fore["x"], side * 0.22, fore["z_top"] - 0.70),
             (anchors["fore_shroud_a"][0], side * anchors["fore_shroud_a"][1],
              anchors["fore_shroud_a"][2])),
            ((fore["x"], side * 0.22, fore["z_top"] - 0.70),
             (anchors["fore_shroud_b"][0], side * anchors["fore_shroud_b"][1],
              anchors["fore_shroud_b"][2])),
            ((fore["x"] + 0.30, side * 3.40, fore["yard_z"]),
             (fore["x"], side * 0.10, fore["z_top"] - 0.05)),
            ((main["x"], side * 0.22, main["z_top"] - 0.70),
             (anchors["main_shroud_a"][0], side * anchors["main_shroud_a"][1],
              anchors["main_shroud_a"][2])),
            ((main["x"], side * 0.22, main["z_top"] - 0.70),
             (anchors["main_shroud_b"][0], side * anchors["main_shroud_b"][1],
              anchors["main_shroud_b"][2])),
            ((main["x"], side * 0.22, main["z_top"] - 0.20),
             (anchors["main_truck"][0], side * anchors["main_truck"][1],
              anchors["main_truck"][2])),
        ]
    for name, _hx, _hy, _hz, tx, ty, tz, _r0, _r1 in layout["booms"]:
        mast = fore if name == "Fore" else main
        for side in (1, -1):
            lines.append(((tx, side * ty, tz),
                          (mast["x"], side * 0.22, mast["z_top"] - 0.80)))
    for p0, p1 in lines:
        b.add(p.taper_cyl(p0, p1, layout.get("rope_radius", 0.038),
                          layout.get("rope_radius", 0.038), 4), b.mat("metal"))


# ============================================================
# 铁甲舰（ironclad）部件
# ============================================================

def ironclad_flag(b, x, y0, y1, z0, z1, seg=4, thickness=0.025):
    """沿 Y 飘的薄旗面：前后两张网格 + 四周边缘，闭合成薄板。"""
    top = [(x + 0.10 * math.sin((i / seg) * math.pi * 1.5),
            y0 + (y1 - y0) * i / seg, z1) for i in range(seg + 1)]
    bot = [(x + 0.06 * math.sin((i / seg) * math.pi * 1.5),
            y0 + (y1 - y0) * i / seg, z0) for i in range(seg + 1)]
    rows = [top, bot]
    mcols = seg + 1
    verts = []
    for row in rows:
        for px, py, pz in row:
            verts.append((px - thickness / 2.0, py, pz))
    for row in rows:
        for px, py, pz in row:
            verts.append((px + thickness / 2.0, py, pz))
    faces = []
    off = 2 * mcols
    for i in range(seg):
        faces.append((i, i + 1, mcols + i + 1, mcols + i))
        faces.append((off + mcols + i, off + mcols + i + 1, off + i + 1, off + i))
        faces.append((i, off + i, off + i + 1, i + 1))
        faces.append((mcols + i + 1, off + mcols + i + 1, off + mcols + i,
                      mcols + i))
    faces.append((0, mcols, off + mcols, off))
    faces.append((off + seg, off + mcols + seg, mcols + seg, seg))
    b.add((verts, faces), b.mat("canvas"))


def ironclad_masts(b, masts, layout):
    """铁甲舰三桅 + 横桁 + 收帆卷 + 艏斜桁承座 + 锚吊架（原构造顺序）。"""
    p = b.prims
    deck_z = layout["deck_z"]
    beam_deck = layout["beam_deck"]
    for spec in masts:
        x = spec["x"]
        b.add(p.taper_cyl((x, 0.0, deck_z), (x, 0.0, spec["lower_top"]),
                          0.40, 0.24, 8), b.mat("wood"))
        b.add(p.taper_cyl((x, 0.0, spec["lower_top"] - 0.3),
                          (x, 0.0, spec["top_top"]), 0.17, 0.085, 8),
              b.mat("wood"))
        b.add(p.translate(p.revolved(
            [(spec["top_top"] - 0.06, 0.10), (spec["top_top"] + 0.12, 0.10),
             (spec["top_top"] + 0.24, 0.0)], 8), x, 0.0, 0.0), b.mat("brass"))
        b.add(p.translate(p.revolved(
            [(spec["lower_top"] - 0.45, 0.30), (spec["lower_top"] - 0.30, 0.30)],
            8), x, 0.0, 0.0), b.mat("metal"))
        for z, half in spec["yards"]:
            b.add(p.taper_cyl((x, -half, z), (x, half, z), 0.075, 0.075, 8),
                  b.mat("wood"))
            b.add(p.taper_cyl((x, -half, z), (x, -half + 0.55, z),
                              0.11, 0.11, 8), b.mat("wood"))
            b.add(p.taper_cyl((x, half - 0.55, z), (x, half, z),
                              0.11, 0.11, 8), b.mat("wood"))
            b.add(p.taper_cyl((x, -0.66 * half, z - 0.26),
                              (x, 0.66 * half, z - 0.26),
                              0.20, 0.20, 8), b.mat("canvas"))
        if spec["top_top"] > 23.5:
            ironclad_flag(b, x, -0.02, 2.0, spec["top_top"] - 0.95,
                          spec["top_top"] - 0.50)
    # 艏斜桁承座
    bottom = [(24.2, -0.75, deck_z), (25.6, -0.75, deck_z),
              (25.6, 0.75, deck_z), (24.2, 0.75, deck_z)]
    top = [(24.6, -0.32, 6.0), (25.2, -0.32, 6.0),
           (25.2, 0.32, 6.0), (24.6, 0.32, 6.0)]
    b.add(p.hexa(bottom, top), b.mat("iron"))
    b.add(p.box((26.9, -0.30, 4.95), (27.9, 0.30, 7.05)), b.mat("iron"))
    b.add(p.box((24.4, -0.42, 5.9), (25.4, 0.42, 6.6)), b.mat("iron"))
    b.add(p.taper_cyl((25.0, 0.0, 6.2), (31.5, 0.0, 8.6), 0.30, 0.10, 8),
          b.mat("wood"))
    b.add(p.taper_cyl((27.5, 0.0, 7.45), (30.4, 0.0, 8.9), 0.14, 0.09, 6),
          b.mat("wood"))
    b.add(p.box((27.2, -0.24, 6.9), (27.9, 0.24, 7.7)), b.mat("metal"))
    # 锚吊架 + 吊链
    for s in (-1.0, 1.0):
        beam = beam_deck(23.0)
        ya, yb = sorted((s * (beam - 0.30), s * (beam + 0.35)))
        b.add(p.box((22.75, ya, 5.05), (23.25, yb, 5.35)), b.mat("wood"))
        b.add(p.taper_cyl((23.0, s * (beam - 0.10), 5.32),
                          (23.0, s * (beam - 0.10), 6.22), 0.045, 0.045, 5),
              b.mat("metal"))


def ironclad_rigging(b, masts, layout):
    """铁甲舰索具：前后支索 + 每桅 3 根/舷侧支索。"""
    p = b.prims
    beam_deck = layout["beam_deck"]
    fore, main, mizzen = masts[0], masts[1], masts[2]
    bow_tip = (31.5, 0.0, 8.6)
    fore_top = (fore["x"], 0.0, fore["top_top"])
    main_top = (main["x"], 0.0, main["top_top"])
    mizzen_top = (mizzen["x"], 0.0, mizzen["top_top"])
    lines = [
        (bow_tip, fore_top), (fore_top, main_top), (main_top, mizzen_top),
        (mizzen_top, (-27.5, 0.0, 5.4)),
        ((25.5, 0.0, 6.0), (fore["x"], 0.0, fore["top_top"] - 1.2)),
        ((24.5, 0.0, 5.6), (fore["x"], 0.0, fore["top_top"] - 3.0)),
    ]
    for spec in masts:
        x = spec["x"]
        beam = beam_deck(x)
        for s in (-1.0, 1.0):
            for dx in (-1.6, 0.0, 1.6):
                top = (x, 0.0, spec["lower_top"] - 0.35)
                foot = (x + dx, s * (beam - 0.10), 5.48)
                lines.append((top, foot))
    for p0, p1 in lines:
        b.add(p.taper_cyl(p0, p1, 0.032, 0.032, 4), b.mat("metal"))
