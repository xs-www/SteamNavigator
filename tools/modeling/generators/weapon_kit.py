# -*- coding: utf-8 -*-
# @static-doc
# 作用：Steam Navigator 舰载武器资产的共用低模几何部件库（纯 Python，不 import bpy）。
#
# 供 `sn_weapon_batch1_generator.py` 复用：炮管 / 炮口箍 / 耳轴 / 摇架 / 炮座、
# 俯仰弧齿、手轮、辐条轮、铆钉排、地脚螺栓、蒸汽管、弹斗、炮弹、炮架滑轨等。
# 所有基本体都是闭合壳体，便于 `dryrun_weapon_batch1.py` 检查边界边 / 非流形边 /
# 退化面；几何只追加进调用方提供的 `Part`，不创建对象、不碰 bpy。
#
# 约定：1 unit = 1 m；+X 为炮口方向、+Z 向上、+Y 为左舷；材质名走共享贴图材质
# （`SN_Tex_*`，见 `sn_weapon_materials.py`），不新增材质。
# @end-static-doc

import math

from ship_parts.core import (
    Part,
    bar_between,
    box,
    frame_box,
    hexa,
    polyline_tube,
    taper_cyl,
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


def add_plate(part, x0, x1, y0, y1, z0, z1, mat):
    add_box(part, (x0, y0, z0), (x1, y1, z1), mat)


def add_cyl(part, p0, p1, r0, r1, mat, sides=8):
    """任意轴向圆台（闭合，含封盖）。"""
    if vlen(vsub(p1, p0)) < 1e-9:
        return
    part.add(taper_cyl(p0, p1, r0, r1, sides), mat)


def add_bar(part, p0, p1, thickness, mat):
    if vlen(vsub(p1, p0)) < 1e-9:
        return
    part.add(bar_between(p0, p1, thickness), mat)


def add_tube(part, points, radii, mat, sides=4):
    part.add(polyline_tube(points, radii, sides), mat)


def add_frustum(part, z0, z1, half0, half1, mat, center=(0.0, 0.0)):
    """矩形截面的四棱台（弹斗 / 漏斗 / 收分罩）。"""
    cx, cy = center
    bottom = [(cx - half0, cy - half0, z0), (cx + half0, cy - half0, z0),
              (cx + half0, cy + half0, z0), (cx - half0, cy + half0, z0)]
    top = [(cx - half1, cy - half1, z1), (cx + half1, cy - half1, z1),
           (cx + half1, cy + half1, z1), (cx - half1, cy + half1, z1)]
    part.add(hexa(bottom, top), mat)


# ---------------------------------------------------------------- 紧固件

def add_rivet(part, center, axis, r, h, mat, sides=6):
    d = vnorm(axis)
    add_cyl(part, vsub(center, vmul(d, h * 0.5)),
            vadd(center, vmul(d, h * 0.5)), r, r, mat, sides)


def rivet_row(part, p0, p1, count, axis, r, h, mat, sides=6):
    """沿 p0→p1 排一列铆钉。"""
    if count <= 0:
        return
    for i in range(count):
        t = (i + 0.5) / count
        p = vadd(p0, vmul(vsub(p1, p0), t))
        add_rivet(part, p, axis, r, h, mat, sides)


def add_bolt(part, center, r, h, mat, axis=(0.0, 0.0, 1.0), sides=6):
    add_rivet(part, center, axis, r, h, mat, sides)


def bolt_square(part, x, y, z, r, h, mat, inset=0.0):
    """四角地脚螺栓（z 为板顶面）。"""
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            add_bolt(part, (x + sx * inset, y + sy * inset, z + h * 0.5),
                     r, h, mat)


def bolt_circle(part, center, radius, count, r, h, mat, axis=(0.0, 0.0, 1.0)):
    d = vnorm(axis)
    ref = (0.0, 0.0, 1.0) if abs(d[2]) < 0.9 else (1.0, 0.0, 0.0)
    u = vnorm(vcross(ref, d))
    v = vnorm(vcross(d, u))
    for i in range(count):
        a = 2.0 * math.pi * i / count
        p = vadd(center, vadd(vmul(u, radius * math.cos(a)),
                              vmul(v, radius * math.sin(a))))
        add_rivet(part, p, d, r, h, mat)


# ---------------------------------------------------------------- 炮管 / 炮座

def barrel_x(part, x0, x1, z, r0, r1, mat, sides=10, rings=(),
             muzzle=None, y=0.0):
    """沿 +X 的炮管：主锥体 + 加强箍 + 炮口箍。

    rings: [(x, r, width), ...] 加强箍；muzzle: (r, width) 炮口箍。
    """
    add_cyl(part, (x0, y, z), (x1, y, z), r0, r1, mat, sides)
    for x, r, width in rings:
        add_cyl(part, (x - width * 0.5, y, z), (x + width * 0.5, y, z),
                r, r, mat, max(6, sides))
    if muzzle is not None:
        r, width = muzzle
        add_cyl(part, (x1 - width, y, z), (x1, y, z), r, r, mat, sides)


def trunnion(part, x, z, length, r, mat, y=0.0, sides=8):
    """沿 Y 的耳轴。"""
    add_cyl(part, (x, y - length * 0.5, z), (x, y + length * 0.5, z),
            r, r, mat, sides)


def cheek_pair(part, x0, x1, y_out, thickness, z0, z1, mat, y_center=0.0):
    """左右两片炮架颊板（沿 Y 向外，可整体偏移到 y_center）。"""
    for sy in (-1.0, 1.0):
        y0 = y_center + sy * y_out - thickness * 0.5
        y1 = y_center + sy * y_out + thickness * 0.5
        add_box(part, (x0, min(y0, y1), z0), (x1, max(y0, y1), z1), mat)


def deck_plate(part, x0, x1, y0, y1, z0, z1, mat, bolts=4, bolt_r=0.055,
               bolt_h=0.07, inset=0.12):
    add_box(part, (x0, y0, z0), (x1, y1, z1), mat)
    if bolts:
        cx, cy = (x0 + x1) * 0.5, (y0 + y1) * 0.5
        hx = (x1 - x0) * 0.5 - inset
        hy = (y1 - y0) * 0.5 - inset
        for sx in (-1.0, 1.0):
            for sy in (-1.0, 1.0):
                add_bolt(part, (cx + sx * hx, cy + sy * hy, z1 + bolt_h * 0.5),
                         bolt_r, bolt_h, mat)


def elevation_arc(part, cx, cz, radius, y, start_deg, end_deg, count,
                  tooth_len, tooth_w, thick, mat):
    """俯仰弧齿：在 XZ 平面沿圆弧排一列小方块。"""
    if count <= 0:
        return
    for i in range(count):
        t = i / (count - 1) if count > 1 else 0.0
        ang = math.radians(start_deg + (end_deg - start_deg) * t)
        radial = (math.cos(ang), 0.0, math.sin(ang))
        tangent = (-math.sin(ang), 0.0, math.cos(ang))
        pos = (cx + radius * math.cos(ang), y, cz + radius * math.sin(ang))
        part.add(frame_box(pos, radial, tangent, (0.0, 1.0, 0.0),
                           tooth_len * 0.5, tooth_w * 0.5, thick * 0.5), mat)


def add_torus(part, center, axis, big_r, tube_r, mat, seg=12, tube=4):
    """任意轴向圆环（手轮轮缘 / 止退环）。"""
    d = vnorm(axis)
    ref = (0.0, 0.0, 1.0) if abs(d[2]) < 0.9 else (1.0, 0.0, 0.0)
    u = vnorm(vcross(ref, d))
    v = vnorm(vcross(d, u))
    verts = []
    for i in range(seg):
        a = 2.0 * math.pi * i / seg
        radial = vadd(vmul(u, math.cos(a)), vmul(v, math.sin(a)))
        for k in range(tube):
            b = 2.0 * math.pi * k / tube
            rr = big_r + tube_r * math.cos(b)
            p = vadd(center, vadd(vmul(radial, rr),
                                  vmul(d, tube_r * math.sin(b))))
            verts.append(p)
    faces = []
    for i in range(seg):
        i2 = (i + 1) % seg
        for k in range(tube):
            k2 = (k + 1) % tube
            faces.append((i * tube + k, i2 * tube + k,
                          i2 * tube + k2, i * tube + k2))
    part.add((verts, faces), mat)


def handwheel(part, center, axis, radius, mat, rim_r=0.035, spokes=4,
              hub_r=0.07, hub_len=0.12):
    """手轮：圆环轮缘 + 辐条 + 轮毂。"""
    d = vnorm(axis)
    ref = (0.0, 0.0, 1.0) if abs(d[2]) < 0.9 else (1.0, 0.0, 0.0)
    u = vnorm(vcross(ref, d))
    v = vnorm(vcross(d, u))
    add_torus(part, center, d, radius, rim_r, mat, seg=10, tube=4)
    add_cyl(part, vsub(center, vmul(d, hub_len * 0.5)),
            vadd(center, vmul(d, hub_len * 0.5)), hub_r, hub_r, mat, 8)
    for i in range(spokes):
        a = 2.0 * math.pi * i / spokes
        p = vadd(center, vadd(vmul(u, radius * math.cos(a)),
                              vmul(v, radius * math.sin(a))))
        add_bar(part, center, p, rim_r * 1.3, mat)


def spoked_wheel(part, center, axis, radius, width, mat, spokes=6,
                 rim_r=0.06):
    """辐条轮（炮车轮 / 飞轮）：轮缘 + 辐条 + 轮毂。"""
    d = vnorm(axis)
    ref = (0.0, 0.0, 1.0) if abs(d[2]) < 0.9 else (1.0, 0.0, 0.0)
    u = vnorm(vcross(ref, d))
    v = vnorm(vcross(d, u))
    add_torus(part, center, d, radius, rim_r, mat, seg=12, tube=4)
    add_cyl(part, vsub(center, vmul(d, width * 0.5)),
            vadd(center, vmul(d, width * 0.5)), radius * 0.18,
            radius * 0.18, mat, 8)
    for i in range(spokes):
        a = 2.0 * math.pi * i / spokes
        p = vadd(center, vadd(vmul(u, radius * math.cos(a)),
                              vmul(v, radius * math.sin(a))))
        add_bar(part, center, p, rim_r * 1.1, mat)


# ---------------------------------------------------------------- 管线 / 弹药

def steam_pipe(part, points, r, mat, flanges=True, sides=6):
    add_tube(part, points, [r] * len(points), mat, sides)
    if not flanges:
        return
    for i in range(1, len(points) - 1):
        d = vnorm(vsub(points[i + 1], points[i - 1]))
        add_cyl(part, vsub(points[i], vmul(d, 0.035)),
                vadd(points[i], vmul(d, 0.035)), r * 1.8, r * 1.8, mat, 8)


def shell(part, base, length, r, mat, axis=(0.0, 0.0, 1.0)):
    """炮弹 / 药包：圆柱弹体 + 收口弹头。"""
    d = vnorm(axis)
    p0 = base
    p1 = vadd(base, vmul(d, length - r * 1.2))
    p2 = vadd(base, vmul(d, length))
    add_cyl(part, p0, p1, r, r, mat, 8)
    add_cyl(part, p1, p2, r, r * 0.35, mat, 8)


def rope_loop(part, center, axis, radius, tube_r, mat):
    add_torus(part, center, axis, radius, tube_r, mat, seg=10, tube=4)


def ladder(part, p0, p1, width, mat, step=0.38, rail_r=0.035, rung_r=0.025):
    """直梯：两根梯柱 + 横档，p0→p1 方向。"""
    d = vnorm(vsub(p1, p0))
    ref = (0.0, 0.0, 1.0) if abs(d[2]) < 0.9 else (1.0, 0.0, 0.0)
    u = vnorm(vcross(ref, d))
    a = vadd(p0, vmul(u, width * 0.5))
    b = vadd(p1, vmul(u, width * 0.5))
    c = vsub(p0, vmul(u, width * 0.5))
    e = vsub(p1, vmul(u, width * 0.5))
    add_cyl(part, a, b, rail_r, rail_r, mat, 6)
    add_cyl(part, c, e, rail_r, rail_r, mat, 6)
    count = max(2, int(vlen(vsub(p1, p0)) / step))
    for i in range(count + 1):
        t = i / count
        add_cyl(part, vadd(a, vmul(vsub(b, a), t)),
                vadd(c, vmul(vsub(e, c), t)), rung_r, rung_r, mat, 6)


def railing(part, points, height, mat, post_step=1.0, bar_r=0.035):
    """沿折线的栏杆：立柱 + 上/中两道横杆。"""
    for i in range(len(points) - 1):
        a, b = points[i], points[i + 1]
        length = vlen(vsub(b, a))
        count = max(1, int(length / post_step))
        for k in range(count + 1):
            t = k / count
            base = vadd(a, vmul(vsub(b, a), t))
            add_cyl(part, base, vadd(base, (0.0, 0.0, height)), bar_r, bar_r,
                    mat, 6)
        for h in (height, height * 0.55):
            add_cyl(part, vadd(a, (0.0, 0.0, h)),
                    vadd(b, (0.0, 0.0, h)), bar_r, bar_r, mat, 6)


# ---------------------------------------------------------------- 变换

def transform(part, rot_y_deg=0.0, offset=(0.0, 0.0, 0.0)):
    """绕 Y 轴旋转（俯仰）后平移；返回新的 Part（材质保留）。"""
    ang = math.radians(rot_y_deg)
    ca, sa = math.cos(ang), math.sin(ang)
    out = Part()
    out.recalc = part.recalc
    out.verts = []
    for x, y, z in part.verts:
        xr = x * ca + z * sa
        zr = -x * sa + z * ca
        out.verts.append((xr + offset[0], y + offset[1], zr + offset[2]))
    out.faces = list(part.faces)
    return out
