# -*- coding: utf-8 -*-
# @static-doc
# 作用：Steam Navigator 起重机类资产的共用低模几何部件库（纯 Python，不 import bpy）。
#
# 供 `sn_harbor_crane_generator.py` / `sn_mega_gantry_generator.py` /
# `sn_wooden_mast_crane_generator.py` / `sn_hand_jib_crane_generator.py` 复用：
# 桁架臂（lattice boom）、格构柱（lattice column）、梯子、栏杆、平台、车轮、
# 卷筒、滑轮、齿轮、钢缆、吊钩组、手摇绞车。所有基本体都是闭合壳体，
# 便于 `dryrun_cranes.py` 检查边界边 / 非流形边 / 退化面。
#
# 约定：1 unit = 1 m；+X 为前向（臂架伸出方向）、+Z 向上；材质名走调色板
# （SN_Metal / SN_Wood / SN_Wood_Dark / SN_Stone / SN_Brass / SN_Iron /
# SN_Iron_Red / SN_Canvas_Shade），不新增材质。
#
# 部件函数只把几何追加进调用方提供的 `Part`，不创建对象、不碰 bpy；
# 装配仍走 `ship_parts.assembly.build_collection()`。
# @end-static-doc

import math

from ship_parts.core import (
    Part,
    bar_between,
    box,
    frame_box,
    polyline_tube,
    taper_cyl,
    torus_z,
    vadd,
    vcross,
    vlen,
    vmul,
    vnorm,
    vsub,
)


# ---------------------------------------------------------------- 基础追加

def add_box(part, lo, hi, mat):
    """轴对齐长方体（闭合）。"""
    part.add(box(lo, hi), mat)


def add_bar(part, p0, p1, thickness, mat):
    """两点之间的方截面杆件（闭合）。"""
    part.add(bar_between(p0, p1, thickness), mat)


def add_cyl(part, p0, p1, r0, r1, mat, sides=8):
    """两端半径可不同的圆台（闭合，含封盖）。"""
    part.add(taper_cyl(p0, p1, r0, r1, sides), mat)


def add_tube(part, points, radii, mat, sides=4):
    """沿折线的圆管（钢缆 / 绳索 / 链条），每段独立闭合。"""
    part.add(polyline_tube(points, radii, sides), mat)


def add_frame_box(part, center, u, v, w, hu, hv, hw, mat):
    part.add(frame_box(center, u, v, w, hu, hv, hw), mat)


def axis_frame(direction):
    """给任意方向建立正交基 (u, v)，d 为归一化方向。"""
    d = vnorm(direction)
    ref = (0.0, 0.0, 1.0) if abs(d[2]) < 0.9 else (1.0, 0.0, 0.0)
    u = vnorm(vcross(ref, d))
    v = vnorm(vcross(d, u))
    return d, u, v


def _offset(p, u, v, hu, hv):
    return vadd(p, vadd(vmul(u, hu), vmul(v, hv)))


# ---------------------------------------------------------------- 桁架

def boom_parts(p0, p1, half_w, half_h, bays, mat, r_chord=0.085, r_brace=0.052,
               ring_every=2):
    """水平/斜向矩形截面桁架臂。

    返回 (chords, lattice, frames) 三个 `Part`：
    - chords：4 根贯通弦杆；
    - lattice：每节间 4 个面的斜腹杆；
    - frames：每 ring_every 个节间的横隔框（竖杆）。
    """
    chords, lattice, frames = Part(), Part(), Part()
    d, u, v = axis_frame(vsub(p1, p0))
    offs = ((half_w, half_h), (-half_w, half_h), (-half_w, -half_h), (half_w, -half_h))
    for hu, hv in offs:
        a = _offset(p0, u, v, hu, hv)
        b = _offset(p1, u, v, hu, hv)
        chords.add(taper_cyl(a, b, r_chord, r_chord, 4), mat)

    def at(t):
        c = vadd(p0, vmul(vsub(p1, p0), t))
        return {k: _offset(c, u, v, hu, hv) for k, (hu, hv) in zip(
            ("pp", "np", "nn", "pn"), offs)}

    def seg(a, b, target):
        target.add(bar_between(a, b, r_brace * 2.0), mat)

    for i in range(bays):
        t0, t1 = i / bays, (i + 1) / bays
        lo, hi = at(t0), at(t1)
        seg(lo["pp"], hi["pn"], lattice)   # +u 面
        seg(lo["np"], hi["nn"], lattice)   # -u 面
        seg(lo["pp"], hi["np"], lattice)   # +v 面
        seg(lo["nn"], hi["pn"], lattice)   # -v 面
        if ring_every and i % ring_every == 0:
            for a, b in (("pp", "np"), ("np", "nn"), ("nn", "pn"), ("pn", "pp")):
                frames.add(bar_between(lo[a], lo[b], r_brace * 2.0), mat)
    lo = at(0.0)
    for a, b in (("pp", "np"), ("np", "nn"), ("nn", "pn"), ("pn", "pp")):
        frames.add(bar_between(lo[a], lo[b], r_brace * 2.0), mat)
    hi = at(1.0)
    for a, b in (("pp", "np"), ("np", "nn"), ("nn", "pn"), ("pn", "pp")):
        frames.add(bar_between(hi[a], hi[b], r_brace * 2.0), mat)
    return chords, lattice, frames


def column_parts(p0, p1, half0, half1, levels, mat, r_chord=0.1, r_brace=0.06):
    """格构柱：4 根收分弦杆 + 每层水平框 + 每层 4 面斜撑。

    返回 (chords, rings, braces)。
    """
    chords, rings, braces = Part(), Part(), Part()
    d, u, v = axis_frame(vsub(p1, p0))
    corners = ((1, 1), (-1, 1), (-1, -1), (1, -1))

    def level_pts(t):
        base = vadd(p0, vmul(vsub(p1, p0), t))
        half = half0 + (half1 - half0) * t
        return [_offset(base, u, v, sx * half, sy * half) for sx, sy in corners]

    for a, b in zip(level_pts(0.0), level_pts(1.0)):
        chords.add(taper_cyl(a, b, r_chord, r_chord, 4), mat)

    for k in range(levels + 1):
        pts = level_pts(k / levels)
        for i in range(4):
            rings.add(bar_between(pts[i], pts[(i + 1) % 4], r_brace * 2.0), mat)
    for k in range(levels):
        lo, hi = level_pts(k / levels), level_pts((k + 1) / levels)
        for i in range(4):
            j = (i + 1) % 4
            braces.add(bar_between(lo[i], hi[j], r_brace * 2.0), mat)
    return chords, rings, braces


# ---------------------------------------------------------------- 附件

def ladder(part, p0, p1, width, mat, step=0.8):
    """沿 p0->p1 的直梯：两根梯柱 + 横档。"""
    d, u, _v = axis_frame(vsub(p1, p0))
    a = vadd(p0, vmul(u, -width * 0.5))
    b = vadd(p1, vmul(u, -width * 0.5))
    c = vadd(p0, vmul(u, width * 0.5))
    e = vadd(p1, vmul(u, width * 0.5))
    add_bar(part, a, b, 0.06, mat)
    add_bar(part, c, e, 0.06, mat)
    length = vlen(vsub(p1, p0))
    count = max(2, int(length / step))
    for i in range(count + 1):
        t = i / count
        add_bar(part, vadd(a, vmul(vsub(b, a), t)),
                vadd(c, vmul(vsub(e, c), t)), 0.045, mat)


def railing(part, points, height, mat, post_step=2.0):
    """沿折线的栏杆：立柱 + 上/中两道横杆。"""
    for i in range(len(points) - 1):
        a, b = points[i], points[i + 1]
        seg_len = vlen(vsub(b, a))
        count = max(1, int(seg_len / post_step))
        for k in range(count + 1):
            t = k / count
            base = vadd(a, vmul(vsub(b, a), t))
            add_bar(part, base, vadd(base, (0.0, 0.0, height)), 0.06, mat)
        for h in (height, height * 0.5):
            add_tube(part, [vadd(a, (0.0, 0.0, h)), vadd(b, (0.0, 0.0, h))],
                     [0.035, 0.035], mat, sides=4)


def platform(part, cx, cy, z, sx, sy, thickness, mat):
    add_box(part, (cx - sx * 0.5, cy - sy * 0.5, z),
            (cx + sx * 0.5, cy + sy * 0.5, z + thickness), mat)


def wheel(part, center, axis, radius, width, mat, sides=8):
    """车轮 / 卷轮：轮体 + 轮毂。"""
    d, _u, _v = axis_frame(axis)
    r0 = vsub(center, vmul(d, width * 0.5))
    r1 = vadd(center, vmul(d, width * 0.5))
    add_cyl(part, r0, r1, radius, radius, mat, sides)
    add_cyl(part, vsub(center, vmul(d, width * 0.7)),
            vadd(center, vmul(d, width * 0.7)), radius * 0.32, radius * 0.32,
            mat, 6)


def drum(part, center, axis, radius, length, mat, sides=10, flanges=True):
    """卷筒（钢缆盘）：筒身 + 两端法兰。"""
    d, _u, _v = axis_frame(axis)
    a = vsub(center, vmul(d, length * 0.5))
    b = vadd(center, vmul(d, length * 0.5))
    add_cyl(part, a, b, radius, radius, mat, sides)
    if flanges:
        add_cyl(part, vsub(a, vmul(d, 0.07)), vadd(a, vmul(d, 0.07)),
                radius * 1.18, radius * 1.18, mat, sides)
        add_cyl(part, vsub(b, vmul(d, 0.07)), vadd(b, vmul(d, 0.07)),
                radius * 1.18, radius * 1.18, mat, sides)


def sheave(part, center, axis, radius, thick, mat, sides=10):
    """滑轮：轮盘 + 贯穿轴。"""
    drum(part, center, axis, radius, thick, mat, sides, flanges=False)
    d, _u, _v = axis_frame(axis)
    add_cyl(part, vsub(center, vmul(d, thick * 0.9)),
            vadd(center, vmul(d, thick * 0.9)), radius * 0.18, radius * 0.18,
            mat, 6)


def gear(part, center, axis, radius, thick, teeth, mat):
    """齿轮：轮盘 + 周向轮齿（复杂传动的可读细节）。"""
    d, u, v = axis_frame(axis)
    a = vsub(center, vmul(d, thick * 0.5))
    b = vadd(center, vmul(d, thick * 0.5))
    add_cyl(part, a, b, radius, radius, mat, 12)
    tooth_h = radius * 0.16
    tooth_w = max(0.05, 2.0 * math.pi * radius / teeth * 0.5)
    for i in range(teeth):
        ang = 2.0 * math.pi * i / teeth
        radial = vnorm(vadd(vmul(u, math.cos(ang)), vmul(v, math.sin(ang))))
        tangent = vnorm(vcross(d, radial))
        pos = vadd(center, vmul(radial, radius + tooth_h * 0.35))
        add_frame_box(part, pos, radial, tangent, d,
                      tooth_h * 0.5, tooth_w * 0.5, thick * 0.5, mat)


def cable(part, points, radius, mat, sides=4):
    add_tube(part, points, [radius] * len(points), mat, sides)


def hook_block(part, top, block_mat, hook_mat, rope_mat=None, rope_top=None):
    """吊钩组：滑轮块 + 吊钩弯钩 + 可选短绳。

    top = 吊钩组挂点（绳索终点）；吊钩组整体挂在此点下方。
    """
    x, y, z = top
    # 滑轮块
    add_box(part, (x - 0.28, y - 0.16, z - 0.62), (x + 0.28, y + 0.16, z - 0.04),
            block_mat)
    sheave(part, (x, y, z - 0.33), (0.0, 1.0, 0.0), 0.20, 0.10, block_mat)
    # 吊钩弯钩（用折线圆管模拟弯钩轮廓）
    hook_pts = [
        (x, y, z - 0.62),
        (x + 0.10, y, z - 0.86),
        (x + 0.30, y, z - 0.98),
        (x + 0.42, y, z - 0.88),
        (x + 0.40, y, z - 0.72),
    ]
    add_tube(part, hook_pts, [0.075, 0.070, 0.065, 0.060, 0.052], hook_mat, 6)
    add_cyl(part, (x + 0.40, y, z - 0.72), (x + 0.34, y, z - 0.60),
            0.05, 0.035, hook_mat, 6)
    if rope_mat is not None and rope_top is not None:
        cable(part, [rope_top, (x, y, z - 0.04)], 0.035, rope_mat)


def hand_winch(part, center, axis, drum_radius, drum_length, gear_radius,
               teeth, mat_frame, mat_drum, mat_gear, crank=True):
    """手摇绞车：卷筒 + 齿轮 + 轴承座 + 摇柄（轴向按 axis 摆）。"""
    d, _u, v = axis_frame(axis)
    drum(part, center, axis, drum_radius, drum_length, mat_drum)
    for side in (-1.0, 1.0):
        p = vadd(center, vmul(d, side * drum_length * 0.62))
        add_box(part, (p[0] - 0.18, p[1] - 0.18, p[2] - drum_radius - 0.26),
                (p[0] + 0.18, p[1] + 0.18, p[2] - drum_radius * 0.15), mat_frame)
    gear(part, vadd(center, vmul(d, -drum_length * 0.62)), axis,
         gear_radius, 0.10, teeth, mat_gear)
    pawl = vadd(center, vadd(vmul(d, -drum_length * 0.62),
                             vmul(v, gear_radius * 0.9)))
    add_bar(part, pawl, vadd(pawl, (0.22, 0.0, 0.18)), 0.06, mat_frame)
    if crank:
        arm_base = vadd(center, vmul(d, drum_length * 0.62))
        arm_tip = vadd(arm_base, vmul(v, drum_radius * 1.5))
        add_bar(part, arm_base, arm_tip, 0.07, mat_frame)
        add_cyl(part, arm_tip, vadd(arm_tip, vmul(d, 0.30)), 0.045, 0.045,
                mat_frame, 6)


def timber_stack(part, cx, cy, z, length, count, radius, mat, along="x"):
    """甲板上的木料堆（圆木沿指定轴排开）。"""
    for i in range(count):
        off = (i - (count - 1) * 0.5) * radius * 2.05
        y = cy + (off if along == "x" else 0.0)
        x = cx + (0.0 if along == "x" else off)
        zz = z + ((i % 2) * radius * 0.9)
        if along == "x":
            add_cyl(part, (x - length * 0.5, y, zz), (x + length * 0.5, y, zz),
                    radius, radius, mat, 6)
        else:
            add_cyl(part, (x, y - length * 0.5, zz), (x, y + length * 0.5, zz),
                    radius, radius, mat, 6)
