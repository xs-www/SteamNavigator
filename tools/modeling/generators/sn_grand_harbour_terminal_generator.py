# -*- coding: utf-8 -*-
# @static-doc
# 作用：大型港口航站楼 SN_Grand_Harbour_Terminal 的参数化生成器（纯 Python 几何 +
# Blender 装配入口）。参照铁港参考图的中央钟楼、三拱门廊、铜绿屋面、连续拱廊与
# 海堤广场，生成 132 m 宽 × 72 m 深 × 56.5 m 高的单件地标建筑。
#
# 契约：
# - 1 unit = 1 m；+X 为正面（港池/固定机位方向），+Y 为建筑长轴，+Z 向上。
# - 根节点 SN_GHT_Root 在平台中心地面 (z=0)；所有几何在根局部坐标中生成。
# - 15 个 mesh：Quay_Base / Quay_Stairs / Quay_Balustrade / Plaza_Furniture /
#   Central_Block / Central_Entrance / Portico / Wings / Wing_Arcades /
#   Wing_Windows / Pavilions / Roofs / Tower / Tower_Clock / Details；
#   Blender 侧另加 SN_GHT_Sign（黄铜文字铭牌，纯几何干跑不计入）。
# - 材质全部为共享贴图 SN_Tex_*（含新增 SN_Tex_Copper_Green），由
#   sn_shared_materials.apply_collection(space="root") 统一写节点与 UV。
#
# 用法：
# - Blender 内：`import runpy; runpy.run_path(<本文件>, run_name="__main__")`
# - 纯 Python 干跑：`python tools/modeling/generators/dryrun_grand_harbour_terminal.py`
# @end-static-doc

import math
import os
import sys
import hashlib


def _generator_dir():
    candidates = []
    f = globals().get("__file__")
    if f:
        candidates.append(os.path.dirname(os.path.abspath(f)))
    try:
        import bpy
        fp = getattr(bpy.data, "filepath", "") if getattr(bpy, "data", None) is not None else ""
        if fp:
            d = os.path.dirname(os.path.abspath(fp))
            for _ in range(8):
                cand = os.path.join(d, "tools", "modeling", "generators")
                if os.path.isdir(os.path.join(cand, "ship_parts")):
                    candidates.append(cand)
                    break
                parent = os.path.dirname(d)
                if parent == d:
                    break
                d = parent
    except Exception:
        pass
    candidates.append(os.path.join(os.path.abspath(os.getcwd()),
                                   "tools", "modeling", "generators"))
    for d in candidates:
        if os.path.isdir(os.path.join(d, "ship_parts")):
            return d
    return os.path.abspath(os.path.dirname(candidates[0] if candidates else "."))


GENERATOR_DIR = _generator_dir()
if GENERATOR_DIR not in sys.path:
    sys.path.insert(0, GENERATOR_DIR)

import weapon_kit as wk  # noqa: E402
from ship_parts.core import (  # noqa: E402
    Part,
    bar_between,
    box,
    frame_box,
    hexa,
    prism_xy,
    prism_xz,
    revolved,
    taper_cyl,
    torus_z,
    vadd,
    vcross,
    vlen,
    vmul,
    vnorm,
    vsub,
)

# --------------------------------------------------------------------------- #
# 资产契约
# --------------------------------------------------------------------------- #

ASSET = "SN_Grand_Harbour_Terminal"
COLLECTION = "SN_GHT_Grand_Harbour_Terminal_Prototype"
PREFIX = "SN_GHT_"
ROOT_NAME = "SN_GHT_Root"
CATEGORY = "architecture"
TARGET_SIZE = (72.5, 133.7, 56.7)          # X 进深 × Y 面宽 × Z 高
TRI_BUDGET = 90000
TRI_FLOOR = 45000
WORKBENCH_POS = (0.0, -330.0, 0.0)
SIGN_TRI_ALLOWANCE = 6000

MAT_STONE = "SN_Tex_Stone"
MAT_COPPER = "SN_Tex_Copper_Green"
MAT_IRON = "SN_Tex_Iron"
MAT_IRON_RED = "SN_Tex_Iron_Red"
MAT_WOOD = "SN_Tex_Wood"
MAT_WOOD_DARK = "SN_Tex_Wood_Dark"
MAT_BRASS = "SN_Tex_Brass"
MAT_GLASS = "SN_Tex_Glass_Dark"
MAT_CANVAS = "SN_Tex_Canvas_Shade"
MAT_METAL = "SN_Tex_Metal"

MATERIAL_WHITELIST = frozenset({
    MAT_STONE, MAT_COPPER, MAT_IRON, MAT_IRON_RED, MAT_WOOD, MAT_WOOD_DARK,
    MAT_BRASS, MAT_GLASS, MAT_CANVAS, MAT_METAL,
})

# ---- 平台 / 广场 ---- #
PLAT_X0, PLAT_X1 = -36.0, 36.0
PLAT_Y = 66.0
PLAT_TOP = 2.4
STAIR_X0, STAIR_X1 = 28.0, 36.0
STAIR_HALF_Y = 12.0
STAIR_STEPS = 6
STAIR_RISE = PLAT_TOP / STAIR_STEPS
STAIR_TREAD = (STAIR_X1 - STAIR_X0) / STAIR_STEPS

# ---- 主体 ---- #
FLOOR_Z = 3.2
CENTRAL_Y = 21.0
CENTRAL_X0, CENTRAL_X1 = -18.0, 10.0
CENTRAL_FRONT = 10.0
CENTRAL_BACK = -18.0
CENTRAL_TOP = 23.0
WING_Y0, WING_Y1 = 21.0, 52.0
WING_BACK = -16.0
WING_LOWER_FRONT = 8.2
WING_UPPER_FRONT = 9.4
WING_SCREEN_FRONT = 10.2
WING_LOWER_TOP = 10.0
WING_UPPER_BOT = 10.8
WING_TOP = 16.0
WING_ROOF_EAVE = 17.0
WING_ROOF_RIDGE = 21.0
PAV_Y0, PAV_Y1 = 52.0, 66.0
PAV_X0, PAV_X1 = -16.0, 11.0
PAV_TOP = 19.0
PAV_ROOF_EAVE = 20.2
PAV_ROOF_RIDGE = 23.5
CENTRAL_ROOF_EAVE = 23.0
CENTRAL_ROOF_RIDGE = 28.5

# ---- 中央拱门 / 门廊 ---- #
ARCH_HALF_U = 7.5          # 中央大拱半宽 15 m
ARCH_SPRING = 10.4
ARCH_CROWN = ARCH_SPRING + ARCH_HALF_U
ARCH_TOP = 18.9
SIDE_ARCH_HALF = 2.5
SIDE_ARCH_SPRING = 7.0
SIDE_ARCH_CROWN = SIDE_ARCH_SPRING + SIDE_ARCH_HALF
SIDE_ARCH_Y = 16.0
PORTICO_COL_X = 15.8
PORTICO_COL_Y = (-19.8, -10.2, 10.2, 19.8)
PORTICO_ENTAB_Z = (20.5, 23.5)
PORTICO_FRONT_X = 18.0
PORTICO_BAL_Z = (23.5, 24.6)

# ---- 塔楼 ---- #
TOWER_CX = -4.0
TOWER_HALF = 8.0
TOWER_BASE_Z = (24.0, 27.5)
TOWER_BODY_Z = (27.5, 40.5)
TOWER_CLOCK_Z = 37.0
TOWER_CORNICE_Z = (40.5, 41.8)
TOWER_DRUM_Z = (41.8, 43.2)
TOWER_DOME_Z = (43.2, 49.5)
TOWER_LANTERN_Z = (49.5, 54.0)
FLAG_TOP = 56.5

# ---- 广场细部 ---- #
LAMP_POSITIONS = [
    (29.5, -55.0), (29.5, -38.0), (29.5, -20.0), (29.5, 20.0),
    (29.5, 38.0), (29.5, 55.0), (23.0, -9.5), (23.0, 9.5),
]
FLAG_POSITIONS = [
    (30.0, -62.5), (30.0, 62.5), (-30.0, -62.5), (-30.0, 62.5),
]
BOLLARD_YS = (-58.0, -46.0, -34.0, -22.0, 22.0, 34.0, 46.0, 58.0)


# --------------------------------------------------------------------------- #
# 基本几何助手（全部闭合壳体）
# --------------------------------------------------------------------------- #

def _box(part, lo, hi, mat):
    part.add(box(lo, hi), mat)


def _panel(part, axis, a0, a1, u0, u1, v0, v1, mat):
    """轴向板：axis=0 → X 向厚度；axis=1 → Y 向厚度。"""
    if axis == 0:
        _box(part, (a0, u0, v0), (a1, u1, v1), mat)
    elif axis == 1:
        _box(part, (u0, a0, v0), (u1, a1, v1), mat)
    else:
        _box(part, (u0, v0, a0), (u1, v1, a1), mat)


def _cyl(part, p0, p1, r0, r1, mat, sides=8):
    if vlen(vsub(p1, p0)) < 1e-9:
        return
    part.add(taper_cyl(p0, p1, r0, r1, sides), mat)


def _bar(part, p0, p1, thickness, mat):
    if vlen(vsub(p1, p0)) < 1e-9:
        return
    part.add(bar_between(p0, p1, thickness), mat)


def _slab(part, a, b, width_axis, width, thickness, mat):
    d = vnorm(vsub(b, a))
    u = vnorm(width_axis)
    w = vnorm(vcross(u, d))
    center = vmul(vadd(a, b), 0.5)
    part.add(frame_box(center, u, d, w, width * 0.5,
                       vlen(vsub(a, b)) * 0.5, thickness * 0.5), mat)


def _prism_axis(poly, a0, a1, axis):
    """在局部平面 (u,v) 上的简单多边形，沿 axis 挤出为闭合棱柱。"""
    n = len(poly)
    if axis == 0:
        verts = [(a0, u, v) for (u, v) in poly] + [(a1, u, v) for (u, v) in poly]
    elif axis == 1:
        verts = [(u, a0, v) for (u, v) in poly] + [(u, a1, v) for (u, v) in poly]
    else:
        verts = [(u, v, a0) for (u, v) in poly] + [(u, v, a1) for (u, v) in poly]
    faces = [tuple(range(n))[::-1], tuple(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, n + j, n + i))
    return verts, faces


def _add_prism_axis(part, poly, a0, a1, axis, mat):
    part.add(_prism_axis(poly, a0, a1, axis), mat)


def _circle(cu, cv, r, seg, start=0.0, end=2.0 * math.pi):
    # 整圆不重复首点；部分圆弧保留两端点
    full = abs((end - start) - 2.0 * math.pi) < 1e-9
    count = seg if full else seg + 1
    return [(cu + r * math.cos(start + (end - start) * i / seg),
             cv + r * math.sin(start + (end - start) * i / seg))
            for i in range(count)]


def _annulus(cu, cv, r_in, r_out, seg, start=0.0, end=2.0 * math.pi):
    outer = _circle(cu, cv, r_out, seg, start, end)
    inner = _circle(cu, cv, r_in, seg, start, end)
    return outer + list(reversed(inner))


def _ring_axis(part, axis, a0, a1, cu, cv, r_in, r_out, mat, seg=16):
    _add_prism_axis(part, _annulus(cu, cv, r_in, r_out, seg), a0, a1, axis, mat)


def _arch_ring_axis(part, axis, a0, a1, cu, spring, r_in, r_out, mat, seg=14):
    outer = [(cu + r_out * math.cos(math.pi * i / seg),
              spring + r_out * math.sin(math.pi * i / seg)) for i in range(seg + 1)]
    inner = [(cu + r_in * math.cos(math.pi * i / seg),
              spring + r_in * math.sin(math.pi * i / seg)) for i in range(seg + 1)]
    _add_prism_axis(part, outer + list(reversed(inner)), a0, a1, axis, mat)


def _arch_lunette_axis(part, axis, a0, a1, cu, spring, r, top_v, side, mat, seg=8):
    """方洞上角、半圆拱外的填石（side=-1 左 / +1 右）。"""
    pts = []
    for k in range(seg + 1):
        ang = 0.5 * math.pi * k / seg
        pts.append((cu + side * r * math.cos(ang), spring + r * math.sin(ang)))
    pts.append((cu, top_v))
    pts.append((cu + side * r, top_v))
    _add_prism_axis(part, pts, a0, a1, axis, mat)


def _arched_glass_poly(cu, sill, spring, r):
    pts = [(cu - r, sill), (cu + r, sill)]
    for k in range(0, 13):
        ang = math.pi * k / 12.0
        pts.append((cu + r * math.cos(ang), spring + r * math.sin(ang)))
    return pts


def _solid_shell(part, verts, faces, offset, mat):
    """开放曲面 + 法向偏移壳体：曲面边界自动补侧壁，生成闭合薄壳。"""
    n = len(verts)
    ox, oy, oz = offset
    all_verts = list(verts) + [(x + ox, y + oy, z + oz) for (x, y, z) in verts]
    all_faces = [tuple(f) for f in faces]
    all_faces += [tuple(reversed([i + n for i in f])) for f in faces]
    edge_count = {}
    for f in faces:
        for i in range(len(f)):
            a, b = f[i], f[(i + 1) % len(f)]
            key = (a, b) if a < b else (b, a)
            edge_count[key] = edge_count.get(key, 0) + 1
    for (a, b), count in edge_count.items():
        if count == 1:
            all_faces.append((a, b, b + n, a + n))
        elif count > 2:
            raise RuntimeError("non-manifold open surface edge %s count=%d" % ((a, b), count))
    part.add((all_verts, all_faces), mat)


def _hip_roof(part, x0, x1, y0, y1, eave, ridge, hip, thickness, mat):
    """四坡屋面：屋脊沿 Y，hip 为两端收进距离。"""
    xc = (x0 + x1) * 0.5
    e0 = (x0, y0, eave)
    e1 = (x1, y0, eave)
    e2 = (x1, y1, eave)
    e3 = (x0, y1, eave)
    r0 = (xc, y0 + hip, ridge)
    r1 = (xc, y1 - hip, ridge)
    verts = [e0, e1, e2, e3, r0, r1]
    faces = [(0, 1, 5, 4), (2, 3, 4, 5), (0, 4, 3), (1, 2, 5)]
    _solid_shell(part, verts, faces, (0.0, 0.0, -thickness), mat)


def _gable_roof(part, x0, x1, y0, y1, eave, ridge, thickness, roof_mat, gable_mat):
    """双坡屋面（山墙面为石/铜实体），用于老虎窗。"""
    ym = (y0 + y1) * 0.5
    verts = [(x0, y0, eave), (x1, y0, eave), (x1, y1, eave), (x0, y1, eave),
             (x0, ym, ridge), (x1, ym, ridge)]
    faces = [(0, 1, 5, 4), (2, 3, 4, 5)]
    _solid_shell(part, verts, faces, (0.0, 0.0, -thickness), roof_mat)
    # 两端山墙
    for x in (x0, x1):
        _add_prism_axis(part, [(y0, eave), (y1, eave), (ym, ridge)], x, x + 0.02,
                        0, gable_mat)


def _hip_roof_ribs(part, x0, x1, y0, y1, eave, ridge, hip, mat, step=2.6):
    xc = (x0 + x1) * 0.5
    # 前后大坡面的顺坡铜条
    y = y0 + hip + 1.0
    while y <= y1 - hip - 1.0 + 1e-6:
        for (ex, side) in ((x0, -1.0), (x1, 1.0)):
            p0 = (ex + side * 0.22, y, eave + 0.06)
            p1 = (xc + side * 0.22, y, ridge + 0.06)
            _bar(part, p0, p1, 0.10, mat)
        y += step
    # 两端山墙坡面的斜脊铜条
    for (yy, ry) in ((y0, y0 + hip), (y1, y1 - hip)):
        for (ex, rr) in ((x0, (xc, ry, ridge)), (x1, (xc, ry, ridge))):
            _bar(part, (ex, yy, eave + 0.06), rr, 0.12, mat)
    # 屋脊压顶
    _slab(part, (xc, y0 + hip, ridge + 0.08), (xc, y1 - hip, ridge + 0.08),
          (1.0, 0.0, 0.0), 0.35, 0.16, mat)


def _ridge_cresting(part, x, y0, y1, z, mat, step=1.6):
    _bar(part, (x, y0, z + 0.1), (x, y1, z + 0.1), 0.18, mat)
    n = max(1, int((y1 - y0) / step))
    for i in range(n + 1):
        y = y0 + (y1 - y0) * i / n
        _cyl(part, (x, y, z + 0.12), (x, y, z + 0.55), 0.09, 0.012, mat, 4)


def _cornice(part, x0, x1, y0, y1, z0, z1, out, mat):
    """三层退台檐口；四周环绕（按用户要求不排齿饰）。"""
    h = z1 - z0
    tiers = ((0.00, 0.38, 0.38), (0.38, 0.70, 0.70), (0.70, 1.00, 1.00))
    for (t0, t1, f) in tiers:
        o = out * f
        za = z0 + h * t0
        zb = z0 + h * t1
        _box(part, (x0 - o, y0 - o, za), (x1 + o, y0 + 0.08, zb), mat)
        _box(part, (x0 - o, y1 - 0.08, za), (x1 + o, y1 + o, zb), mat)
        _box(part, (x0 - o, y0 - o, za), (x0 + 0.08, y1 + o, zb), mat)
        _box(part, (x1 - 0.08, y0 - o, za), (x1 + o, y1 + o, zb), mat)


def _string_course(part, x0, x1, y0, y1, z0, z1, out, mat):
    _box(part, (x0 - out, y0 - out, z0), (x1 + out, y0 + 0.05, z1), mat)
    _box(part, (x0 - out, y1 - 0.05, z0), (x1 + out, y1 + out, z1), mat)
    _box(part, (x0 - out, y0 - out, z0), (x0 + 0.05, y1 + out, z1), mat)
    _box(part, (x1 - 0.05, y0 - out, z0), (x1 + out, y1 + out, z1), mat)


def _quoin_stack(part, cx, cy, sx, sy, z0, z1, mat, count=11):
    for i in range(count):
        za = z0 + (z1 - z0) * i / count
        zb = z0 + (z1 - z0) * (i + 1) / count
        long = 1.15 if i % 2 == 0 else 0.72
        px = cx + sx * 0.13
        py = cy + sy * 0.13
        x0, x1 = sorted((px, cx - sx * long))
        y0, y1 = sorted((py, cy - sy * long))
        _box(part, (x0, y0, za + 0.015), (x1, y1, zb - 0.015), mat)


def _pilaster(part, axis, plane, sign, uc, z0, z1, width, depth, mat):
    if axis == 0:
        _box(part, (plane, uc - width * 0.5, z0), (plane + sign * depth, uc + width * 0.5, z1), mat)
        _box(part, (plane, uc - width * 0.62, z0 - 0.18), (plane + sign * depth * 1.35,
              uc + width * 0.62, z0 + 0.18), mat)
        _box(part, (plane, uc - width * 0.62, z1 - 0.18), (plane + sign * depth * 1.35,
              uc + width * 0.62, z1 + 0.18), mat)
    else:
        _box(part, (uc - width * 0.5, plane, z0), (uc + width * 0.5, plane + sign * depth, z1), mat)
        _box(part, (uc - width * 0.62, plane, z0 - 0.18), (uc + width * 0.62,
              plane + sign * depth * 1.35, z0 + 0.18), mat)
        _box(part, (uc - width * 0.62, plane, z1 - 0.18), (uc + width * 0.62,
              plane + sign * depth * 1.35, z1 + 0.18), mat)


def _rect_window(part, axis, plane, sign, cu, cv, w, h, glass=MAT_GLASS,
                 frame=MAT_WOOD_DARK, sill_mat=MAT_STONE, mullions=1,
                 sill=True, pediment=False):
    # 玻璃 / 凹底
    _panel(part, axis, plane + sign * 0.015, plane + sign * 0.06,
           cu - w * 0.5, cu + w * 0.5, cv - h * 0.5, cv + h * 0.5, glass)
    d0, d1 = plane + sign * 0.04, plane + sign * 0.20
    # 四边框
    _panel(part, axis, d0, d1, cu - w * 0.5 - 0.14, cu + w * 0.5 + 0.14,
           cv + h * 0.5 - 0.06, cv + h * 0.5 + 0.14, frame)
    _panel(part, axis, d0, d1, cu - w * 0.5 - 0.14, cu + w * 0.5 + 0.14,
           cv - h * 0.5 - 0.14, cv - h * 0.5 + 0.06, frame)
    _panel(part, axis, d0, d1, cu - w * 0.5 - 0.14, cu - w * 0.5 + 0.06,
           cv - h * 0.5, cv + h * 0.5, frame)
    _panel(part, axis, d0, d1, cu + w * 0.5 - 0.06, cu + w * 0.5 + 0.14,
           cv - h * 0.5, cv + h * 0.5, frame)
    # 窗棂
    for k in range(mullions):
        off = (k - (mullions - 1) * 0.5) * (w / (mullions + 1.0))
        _panel(part, axis, plane + sign * 0.06, plane + sign * 0.11,
               cu + off - 0.035, cu + off + 0.035, cv - h * 0.5, cv + h * 0.5, frame)
    _panel(part, axis, plane + sign * 0.06, plane + sign * 0.11,
           cu - w * 0.5, cu + w * 0.5, cv + h * 0.12 - 0.035,
           cv + h * 0.12 + 0.035, frame)
    # 窗台 / 窗楣
    if sill:
        _panel(part, axis, plane, plane + sign * 0.30, cu - w * 0.5 - 0.25,
               cu + w * 0.5 + 0.25, cv - h * 0.5 - 0.20, cv - h * 0.5 - 0.02, sill_mat)
    _panel(part, axis, plane, plane + sign * 0.22, cu - w * 0.5 - 0.22,
           cu + w * 0.5 + 0.22, cv + h * 0.5 + 0.02, cv + h * 0.5 + 0.22, sill_mat)
    if pediment:
        _add_prism_axis(part, [(cu - w * 0.5 - 0.35, cv + h * 0.5 + 0.22),
                               (cu + w * 0.5 + 0.35, cv + h * 0.5 + 0.22),
                               (cu, cv + h * 0.5 + 1.15)],
                        plane + sign * 0.02, plane + sign * 0.28, axis, sill_mat)


def _arched_window(part, axis, plane, sign, cu, sill, spring, r, glass=MAT_GLASS,
                   frame=MAT_STONE, mullions=1, balcony=False):
    _add_prism_axis(part, _arched_glass_poly(cu, sill, spring, r),
                    plane + sign * 0.01, plane + sign * 0.06, axis, glass)
    _arch_ring_axis(part, axis, plane + sign * 0.04, plane + sign * 0.24,
                    cu, spring, r, r + 0.28, frame, 14)
    # 侧框 / 窗台 / 拱心石
    _panel(part, axis, plane, plane + sign * 0.24, cu - r - 0.30, cu - r + 0.02,
           sill, spring, frame)
    _panel(part, axis, plane, plane + sign * 0.24, cu + r - 0.02, cu + r + 0.30,
           sill, spring, frame)
    _panel(part, axis, plane, plane + sign * 0.38, cu - r - 0.35, cu + r + 0.35,
           sill - 0.22, sill - 0.02, frame)
    _panel(part, axis, plane, plane + sign * 0.38, cu - 0.24, cu + 0.24,
           spring + r - 0.02, spring + r + 0.42, frame)
    for k in range(mullions):
        off = (k - (mullions - 1) * 0.5) * (2.0 * r / (mullions + 1.0))
        _panel(part, axis, plane + sign * 0.05, plane + sign * 0.11,
               cu + off - 0.035, cu + off + 0.035, sill, spring + r * 0.55, MAT_IRON)
    if balcony:
        _balcony_front(part, axis, plane, sign, cu, sill, r)


def _balcony_front(part, axis, plane, sign, cu, z, half_w):
    # 小阳台：石板 + 3 道横杆 + 5 根立柱
    if axis == 0:
        _box(part, (plane, cu - half_w, z - 0.20), (plane + sign * 1.0, cu + half_w, z - 0.06), MAT_STONE)
        for s in (-1, 1):
            _box(part, (plane + sign * 0.04, cu + s * half_w - 0.04, z),
                 (plane + sign * 0.98, cu + s * half_w + 0.04, z + 1.0), MAT_IRON)
        for zz in (z + 0.18, z + 0.58, z + 0.94):
            _box(part, (plane + sign * 0.90, cu - half_w, zz),
                 (plane + sign * 0.98, cu + half_w, zz + 0.08), MAT_IRON)
        for k in range(5):
            u = cu - half_w + 2.0 * half_w * k / 4.0
            _box(part, (plane + sign * 0.92, u - 0.03, z), (plane + sign * 0.98, u + 0.03, z + 1.0), MAT_IRON)
    else:
        _box(part, (cu - half_w, plane, z - 0.20), (cu + half_w, plane + sign * 1.0, z - 0.06), MAT_STONE)
        for s in (-1, 1):
            _box(part, (cu + s * half_w - 0.04, plane + sign * 0.04, z),
                 (cu + s * half_w + 0.04, plane + sign * 0.98, z + 1.0), MAT_IRON)
        for zz in (z + 0.18, z + 0.58, z + 0.94):
            _box(part, (cu - half_w, plane + sign * 0.90, zz),
                 (cu + half_w, plane + sign * 0.98, zz + 0.08), MAT_IRON)
        for k in range(5):
            u = cu - half_w + 2.0 * half_w * k / 4.0
            _box(part, (u - 0.03, plane + sign * 0.92, z), (u + 0.03, plane + sign * 0.98, z + 1.0), MAT_IRON)


# --------------------------------------------------------------------------- #
# 平台 / 广场
# --------------------------------------------------------------------------- #

def _build_quay_base():
    m = Part()
    # 主平台 + 两侧码头肩台（中间留出大台阶）
    _box(m, (PLAT_X0, -PLAT_Y, 0.0), (STAIR_X0, PLAT_Y, PLAT_TOP), MAT_STONE)
    for sy in (-1.0, 1.0):
        y0, y1 = sorted((sy * STAIR_HALF_Y, sy * PLAT_Y))
        _box(m, (STAIR_X0, y0, 0.0), (PLAT_X1, y1, PLAT_TOP), MAT_STONE)
    # 三级压顶 / 潮痕线
    _box(m, (PLAT_X0 - 0.15, -PLAT_Y - 0.15, PLAT_TOP - 0.18),
         (PLAT_X1 + 0.15, PLAT_Y + 0.15, PLAT_TOP), MAT_STONE)
    _box(m, (PLAT_X0 - 0.10, -PLAT_Y - 0.10, 1.15),
         (PLAT_X1 + 0.10, PLAT_Y + 0.10, 1.38), MAT_STONE)
    _box(m, (PLAT_X0 - 0.08, -PLAT_Y - 0.08, 0.42),
         (PLAT_X1 + 0.08, PLAT_Y + 0.08, 0.58), MAT_STONE)
    # 前海堤面竖向石缝节奏（浅浮雕带）
    for k in range(23):
        y = -PLAT_Y + 2.0 + k * 5.8
        if abs(y) < STAIR_HALF_Y + 1.0:
            continue
        _box(m, (PLAT_X1 + 0.02, y - 0.10, 0.15), (PLAT_X1 + 0.16, y + 0.10, 1.35), MAT_STONE)
    # 后侧压顶
    _box(m, (PLAT_X0 - 0.15, -PLAT_Y - 0.15, PLAT_TOP - 0.16),
         (PLAT_X0 + 0.15, PLAT_Y + 0.15, PLAT_TOP), MAT_STONE)
    return m


def _build_quay_stairs():
    m = Part()
    for i in range(STAIR_STEPS):
        x0 = STAIR_X1 - (i + 1) * STAIR_TREAD
        x1 = STAIR_X1 - i * STAIR_TREAD
        top = (i + 1) * STAIR_RISE
        _box(m, (x0, -STAIR_HALF_Y, 0.0), (x1, STAIR_HALF_Y, top), MAT_STONE)
        # 踏面前沿石条
        _box(m, (x0, -STAIR_HALF_Y, top - 0.06), (x0 + 0.18, STAIR_HALF_Y, top + 0.02), MAT_STONE)
    # 两侧梯颊墙
    for sy in (-1.0, 1.0):
        y0, y1 = sorted((sy * STAIR_HALF_Y, sy * (STAIR_HALF_Y + 1.4)))
        _box(m, (STAIR_X0, y0, 0.0), (STAIR_X1 + 0.2, y1, PLAT_TOP + 0.18), MAT_STONE)
        _box(m, (STAIR_X0 - 0.2, y0 - 0.12, PLAT_TOP + 0.18),
             (STAIR_X1 + 0.3, y1 + 0.12, PLAT_TOP + 0.36), MAT_STONE)
    return m


def _build_quay_balustrade():
    m = Part()
    # 正面两段石栏杆（让开中央大台阶）
    for sy in (-1.0, 1.0):
        y0, y1 = sorted((sy * (STAIR_HALF_Y + 1.8), sy * (PLAT_Y - 0.6)))
        _balustrade_line(m, (0.0, y0), (0.0, y1), PLAT_TOP, 1.05, MAT_STONE, axis_x=PLAT_X1 - 0.7)
    # 侧边栏杆（沿 X 方向）
    for sy in (-1.0, 1.0):
        _balustrade_line(m, (PLAT_X0 + 0.7, sy * (PLAT_Y - 0.7)),
                         (PLAT_X1 - 0.7, sy * (PLAT_Y - 0.7)), PLAT_TOP, 1.05, MAT_STONE)
    # 平台后沿低石墙
    _box(m, (PLAT_X0 + 0.2, -PLAT_Y + 0.2, PLAT_TOP), (PLAT_X0 + 0.8, PLAT_Y - 0.2, PLAT_TOP + 0.75), MAT_STONE)
    # 台阶两侧石栏柱 + 球饰
    for sy in (-1.0, 1.0):
        for x in (STAIR_X0 + 0.4, STAIR_X1 - 0.4):
            _box(m, (x - 0.55, sy * (STAIR_HALF_Y + 1.4) - 0.55, PLAT_TOP + 0.18),
                 (x + 0.55, sy * (STAIR_HALF_Y + 1.4) + 0.55, PLAT_TOP + 1.9), MAT_STONE)
            _urn(m, x, sy * (STAIR_HALF_Y + 1.4), PLAT_TOP + 1.9, 0.55, MAT_STONE)
    return m


def _balustrade_line(part, p0, p1, z, height, mat, axis_x=None):
    """斜/直段石栏杆：下枋 + 宝瓶柱 + 上枋 + 柱墩。p0/p1 为 (x,y)。"""
    x0, y0 = p0
    x1, y1 = p1
    length = math.hypot(x1 - x0, y1 - y0)
    if length < 1e-6:
        return
    dx, dy = (x1 - x0) / length, (y1 - y0) / length
    _slab(part, (x0, y0, z + 0.02), (x1, y1, z + 0.02), (0.0, 0.0, 1.0), 0.30, 0.26, mat)
    _slab(part, (x0, y0, z + height - 0.16), (x1, y1, z + height - 0.16), (0.0, 0.0, 1.0), 0.38, 0.20, mat)
    n = max(1, int(length / 1.15))
    for i in range(n + 1):
        t = i / n
        cx, cy = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
        _add_baluster(part, cx, cy, z + 0.24, height - 0.44, mat)
    n_post = max(1, int(length / 6.5))
    for i in range(n_post + 1):
        t = i / n_post
        cx, cy = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
        _box(part, (cx - 0.42, cy - 0.42, z), (cx + 0.42, cy + 0.42, z + height + 0.12), mat)
        _box(part, (cx - 0.50, cy - 0.50, z + height + 0.12),
             (cx + 0.50, cy + 0.50, z + height + 0.28), mat)


def _add_baluster(part, cx, cy, z, height, mat):
    profile = [(0.00, 0.14), (0.10, 0.17), (0.18, 0.09), (0.42, 0.15),
               (0.55, 0.10), (0.68, 0.07)]
    verts, faces = revolved([(zz * height / 0.68, rr) for zz, rr in profile], 6)
    verts = [(x + cx, y + cy, zz + z) for (x, y, zz) in verts]
    part.add((verts, faces), mat)


def _build_plaza_furniture():
    m = Part()
    for (x, y) in LAMP_POSITIONS:
        _lamp_post(m, x, y, PLAT_TOP)
    for (x, y) in FLAG_POSITIONS:
        _flag_pole(m, x, y, PLAT_TOP, 17.0, 4.8, 3.0, MAT_IRON_RED if y < 0 else MAT_CANVAS)
    for y in BOLLARD_YS:
        _bollard(m, PLAT_X1 - 0.7, y, PLAT_TOP)
        _bollard(m, PLAT_X1 - 1.8, y, PLAT_TOP)
    # 长凳
    for sy in (-1.0, 1.0):
        for x in (18.0, 25.0):
            _bench(m, x, sy * 28.0, PLAT_TOP)
    # 前海堤系船环
    for y in (-48.0, -32.0, -16.0, 16.0, 32.0, 48.0):
        _mooring_ring(m, PLAT_X1 + 0.02, y, 1.1)
    # 平台四角石瓮
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            _box(m, (PLAT_X0 + 0.4 + sx * 0.0, sy * (PLAT_Y - 1.2) - 0.7, PLAT_TOP),
                 (PLAT_X0 + 1.8, sy * (PLAT_Y - 1.2) + 0.7, PLAT_TOP + 0.9), MAT_STONE)
            _urn(m, PLAT_X0 + 1.1, sy * (PLAT_Y - 1.2), PLAT_TOP + 0.9, 1.15, MAT_STONE)
    return m


def _lamp_post(part, x, y, z):
    _box(part, (x - 0.42, y - 0.42, z), (x + 0.42, y + 0.42, z + 0.25), MAT_IRON)
    _cyl(part, (x, y, z + 0.25), (x, y, z + 0.55), 0.32, 0.24, MAT_IRON, 8)
    _cyl(part, (x, y, z + 0.55), (x, y, z + 4.15), 0.15, 0.11, MAT_IRON, 8)
    for zz in (z + 1.2, z + 2.2, z + 3.2):
        _ring_axis(part, 2, zz, zz + 0.10, x, y, 0.14, 0.19, MAT_BRASS, 8)
    # 灯笼
    _box(part, (x - 0.38, y - 0.38, z + 4.05), (x + 0.38, y + 0.38, z + 4.18), MAT_BRASS)
    _box(part, (x - 0.30, y - 0.30, z + 4.18), (x + 0.30, y + 0.30, z + 4.82), MAT_GLASS)
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            _box(part, (x + sx * 0.28 - 0.035, y + sy * 0.28 - 0.035, z + 4.18),
                 (x + sx * 0.28 + 0.035, y + sy * 0.28 + 0.035, z + 4.82), MAT_IRON)
    _box(part, (x - 0.40, y - 0.40, z + 4.82), (x + 0.40, y + 0.40, z + 4.96), MAT_BRASS)
    _cyl(part, (x, y, z + 4.96), (x, y, z + 5.30), 0.24, 0.02, MAT_BRASS, 6)


def _bollard(part, x, y, z):
    _cyl(part, (x, y, z), (x, y, z + 0.10), 0.36, 0.36, MAT_IRON, 8)
    _cyl(part, (x, y, z + 0.10), (x, y, z + 0.82), 0.26, 0.22, MAT_IRON, 8)
    _cyl(part, (x, y, z + 0.82), (x, y, z + 0.96), 0.34, 0.30, MAT_IRON, 8)
    _cyl(part, (x, y, z + 0.96), (x, y, z + 1.02), 0.16, 0.10, MAT_BRASS, 6)


def _mooring_ring(part, x, y, z):
    _box(part, (x - 0.06, y - 0.45, z - 0.45), (x + 0.10, y + 0.45, z + 0.45), MAT_IRON)
    # 用 16 段圆环近似
    verts = []
    faces = []
    seg, tube = 12, 4
    for i in range(seg):
        a = 2.0 * math.pi * i / seg
        cu, cv = math.cos(a), math.sin(a)
        for k in range(tube):
            b = 2.0 * math.pi * k / tube
            rr = 0.30 + 0.055 * math.cos(b)
            verts.append((x + 0.12 + 0.055 * math.sin(b),
                          y + rr * cu, z + rr * cv))
    for i in range(seg):
        i2 = (i + 1) % seg
        for k in range(tube):
            k2 = (k + 1) % tube
            faces.append((i * tube + k, i2 * tube + k, i2 * tube + k2, i * tube + k2))
    part.add((verts, faces), MAT_IRON)


def _bench(part, x, y, z):
    _box(part, (x - 1.7, y - 0.35, z), (x + 1.7, y + 0.35, z + 0.12), MAT_WOOD)
    _box(part, (x - 1.7, y - 0.35, z + 0.12), (x + 1.7, y + 0.35, z + 0.16), MAT_WOOD_DARK)
    for sx in (-1.0, 1.0):
        _box(part, (x + sx * 1.35 - 0.12, y - 0.35, z), (x + sx * 1.35 + 0.12, y + 0.35, z + 0.52), MAT_IRON)
    _box(part, (x - 1.7, y - 0.10, z + 0.52), (x + 1.7, y + 0.10, z + 1.05), MAT_WOOD)
    _box(part, (x - 1.7, y - 0.16, z + 1.05), (x + 1.7, y + 0.16, z + 1.15), MAT_WOOD_DARK)


def _urn(part, x, y, z, scale, mat):
    profile = [(0.00, 0.30), (0.10, 0.34), (0.16, 0.22), (0.30, 0.18),
               (0.52, 0.34), (0.72, 0.36), (0.86, 0.20), (0.94, 0.28), (1.00, 0.30)]
    verts, faces = revolved([(zz * scale, rr * scale) for zz, rr in profile], 8)
    verts = [(vx + x, vy + y, vz + z) for (vx, vy, vz) in verts]
    part.add((verts, faces), mat)


def _flag_pole(part, x, y, z, pole_h, flag_w, flag_h, flag_mat):
    _box(part, (x - 0.55, y - 0.55, z), (x + 0.55, y + 0.55, z + 0.55), MAT_STONE)
    _cyl(part, (x, y, z + 0.55), (x, y, z + pole_h), 0.09, 0.055, MAT_IRON, 8)
    _cyl(part, (x, y, z + pole_h), (x, y, z + pole_h + 0.35), 0.16, 0.02, MAT_BRASS, 6)
    _flag(part, (x, y, z + pole_h - 0.35), flag_w, flag_h, (1.0, 0.0, 0.0), flag_mat)


def _flag(part, anchor, width, height, direction, mat):
    ax, ay, az = anchor
    dx, dy, dz = direction
    nx, ny, nz = 0.0, 1.0, 0.0
    nu, nv = 7, 3
    verts = []
    faces = []
    for j in range(nv + 1):
        for i in range(nu + 1):
            u = width * i / nu
            v = -height * j / nv
            wave = 0.34 * math.sin(2.4 * math.pi * i / nu + 0.7) * (j / nv) ** 0.7
            verts.append((ax + dx * u + nx * wave,
                          ay + dy * u + ny * wave,
                          az + v + 0.10 * math.sin(1.9 * math.pi * i / nu) * (j / nv)))
    for j in range(nv):
        for i in range(nu):
            a = j * (nu + 1) + i
            b = a + 1
            c = a + nu + 2
            d = a + nu + 1
            faces.append((a, b, c, d))
    _solid_shell(part, verts, faces, (0.0, -0.03, 0.0), mat)


# --------------------------------------------------------------------------- #
# 中央主楼
# --------------------------------------------------------------------------- #

def _build_central_block():
    m = Part()
    # 后部实体：中央门厅位置留空（x=1.15 之后让给 8 m 深玻璃门厅）
    _box(m, (CENTRAL_BACK, -CENTRAL_Y, FLOOR_Z), (2.2, -8.6, CENTRAL_TOP), MAT_STONE)
    _box(m, (CENTRAL_BACK, 8.6, FLOOR_Z), (2.2, CENTRAL_Y, CENTRAL_TOP), MAT_STONE)
    _box(m, (CENTRAL_BACK, -8.6, FLOOR_Z), (1.15, 8.6, CENTRAL_TOP), MAT_STONE)
    # 后部实体前脸只到 2.2 / 1.15，中央入口保持 8 m 深空腹
    # 基座 / 楼层线
    _box(m, (CENTRAL_BACK, -CENTRAL_Y, PLAT_TOP), (CENTRAL_FRONT, CENTRAL_Y, FLOOR_Z), MAT_STONE)
    _box(m, (CENTRAL_BACK - 0.15, -CENTRAL_Y - 0.15, FLOOR_Z),
         (CENTRAL_FRONT + 0.15, CENTRAL_Y + 0.15, FLOOR_Z + 0.32), MAT_STONE)
    # 前墙（中央拱洞两侧 + 顶部）
    for side in (-1.0, 1.0):
        y0, y1 = sorted((side * ARCH_HALF_U, side * CENTRAL_Y))
        _box(m, (9.2, y0, FLOOR_Z), (CENTRAL_FRONT, y1, CENTRAL_TOP), MAT_STONE)
    _box(m, (9.2, -ARCH_HALF_U, ARCH_TOP), (CENTRAL_FRONT, ARCH_HALF_U, CENTRAL_TOP), MAT_STONE)
    # 拱肩填石
    for side in (-1.0, 1.0):
        _arch_lunette_axis(m, 0, 9.2, CENTRAL_FRONT, 0.0, ARCH_SPRING,
                           ARCH_HALF_U, ARCH_TOP, side, MAT_STONE, 10)
    # 前墙开口两侧的壁柱
    for side in (-1.0, 1.0):
        _pilaster(m, 0, CENTRAL_FRONT, 1.0, side * (ARCH_HALF_U + 0.7),
                  FLOOR_Z, PORTICO_ENTAB_Z[0], 1.3, 0.55, MAT_STONE)
    # 中央拱券
    _arch_ring_axis(m, 0, CENTRAL_FRONT, CENTRAL_FRONT + 0.75, 0.0,
                    ARCH_SPRING, ARCH_HALF_U, ARCH_HALF_U + 0.95, MAT_STONE, 18)
    _box(m, (CENTRAL_FRONT, -0.42, ARCH_CROWN - 0.10),
         (CENTRAL_FRONT + 0.86, 0.42, ARCH_CROWN + 0.95), MAT_STONE)
    for side in (-1.0, 1.0):
        _box(m, (CENTRAL_FRONT, side * (ARCH_HALF_U - 0.05) - 0.30,
                 ARCH_SPRING - 0.65), (CENTRAL_FRONT + 0.55,
                 side * (ARCH_HALF_U - 0.05) + 0.30, ARCH_SPRING + 0.25), MAT_STONE)
        _box(m, (CENTRAL_FRONT, side * (ARCH_HALF_U + 0.15) - 0.55,
                 ARCH_SPRING - 0.55), (CENTRAL_FRONT + 0.35,
                 side * (ARCH_HALF_U + 0.15) + 0.55, ARCH_SPRING + 0.18), MAT_STONE)
    # 侧拱窗（假凹窗，环 + 玻璃 + 窗台）
    for side in (-1.0, 1.0):
        _arched_window(m, 0, CENTRAL_FRONT, 1.0, side * SIDE_ARCH_Y,
                       FLOOR_Z, SIDE_ARCH_SPRING, SIDE_ARCH_HALF,
                       frame=MAT_STONE, mullions=2, balcony=False)
        # 侧拱上方圆窗
        _ring_axis(m, 0, CENTRAL_FRONT, CENTRAL_FRONT + 0.34,
                   side * SIDE_ARCH_Y, 14.0, 1.05, 1.35, MAT_STONE, 16)
        m.add(_prism_axis(_circle(side * SIDE_ARCH_Y, 14.0, 1.05, 16),
                          CENTRAL_FRONT + 0.02, CENTRAL_FRONT + 0.07, 0), MAT_GLASS)
        _box(m, (CENTRAL_FRONT, side * SIDE_ARCH_Y - 0.08, 13.9),
             (CENTRAL_FRONT + 0.40, side * SIDE_ARCH_Y + 0.08, 14.1), MAT_IRON)
        _box(m, (CENTRAL_FRONT, side * SIDE_ARCH_Y - 1.05, 13.9),
             (CENTRAL_FRONT + 0.40, side * SIDE_ARCH_Y + 1.05, 14.1), MAT_IRON)
    # 前墙顶部檐口
    _cornice(m, 9.2, CENTRAL_FRONT, -CENTRAL_Y, CENTRAL_Y, 20.8, CENTRAL_TOP, 0.55, MAT_STONE)
    # 用户反馈竖向隅石像锯齿：中央主楼也不再排隅石，所有转角保持平直
    # 背面窗列
    for sy in (-1.0, 1.0):
        for k in range(5):
            y = -14.0 + k * 7.0
            _rect_window(m, 0, CENTRAL_BACK, -1.0, y, 8.2, 2.0, 3.2, mullions=2)
            _rect_window(m, 0, CENTRAL_BACK, -1.0, y, 15.0, 2.0, 3.0, mullions=2)
    # 背面基座门
    _box(m, (CENTRAL_BACK - 0.25, -2.4, FLOOR_Z), (CENTRAL_BACK + 0.05, 2.4, FLOOR_Z + 4.6), MAT_WOOD_DARK)
    _box(m, (CENTRAL_BACK - 0.35, -2.8, FLOOR_Z + 4.6), (CENTRAL_BACK + 0.05, 2.8, FLOOR_Z + 5.0), MAT_STONE)
    return m


def _build_central_entrance():
    m = Part()
    # 8 m 深的门厅：两侧墙 + 顶棚 + 大玻璃墙 + 双扇门
    _box(m, (1.2, -8.6, FLOOR_Z), (9.2, -7.4, 19.2), MAT_STONE)
    _box(m, (1.2, 7.4, FLOOR_Z), (9.2, 8.6, 19.2), MAT_STONE)
    _box(m, (1.2, -8.6, FLOOR_Z), (9.2, 8.6, FLOOR_Z + 0.22), MAT_STONE)
    _box(m, (1.2, -8.6, 18.6), (9.2, 8.6, 19.2), MAT_STONE)
    # 玻璃幕墙
    _box(m, (1.22, -7.4, FLOOR_Z), (1.30, 7.4, 18.6), MAT_GLASS)
    # 竖向黄铜/铁窗棂
    for k in range(11):
        y = -7.0 + k * 1.4
        _box(m, (1.30, y - 0.045, FLOOR_Z), (1.38, y + 0.045, 18.6), MAT_BRASS)
    for zz in (8.0, 11.5, 15.0):
        _box(m, (1.30, -7.4, zz - 0.04), (1.38, 7.4, zz + 0.04), MAT_BRASS)
    # 中央玫瑰窗铁艺
    _ring_axis(m, 0, 1.30, 1.42, 0.0, 13.4, 3.0, 3.22, MAT_BRASS, 20)
    for k in range(8):
        a = 2.0 * math.pi * k / 8.0
        _bar(m, (1.36, 0.0, 13.4),
             (1.36, 3.0 * math.cos(a), 13.4 + 3.0 * math.sin(a)), 0.08, MAT_BRASS)
    # 下部双扇木门 + 门框
    _box(m, (1.30, -3.4, FLOOR_Z), (1.42, 3.4, 8.0), MAT_WOOD)
    for y in (-3.4, 0.0, 3.4):
        _box(m, (1.38, y - 0.10, FLOOR_Z), (1.50, y + 0.10, 8.0), MAT_IRON)
    for zz in (5.2, 7.8):
        _box(m, (1.38, -3.4, zz - 0.08), (1.50, 3.4, zz + 0.08), MAT_BRASS)
    for y in (-1.8, 1.8):
        _cyl(m, (1.50, y, 5.2), (1.64, y, 5.2), 0.10, 0.10, MAT_BRASS, 8)
    # 门厅地面
    _box(m, (1.2, -7.4, FLOOR_Z), (9.2, 7.4, FLOOR_Z + 0.05), MAT_STONE)
    # 门厅侧壁壁柱
    for sy in (-1.0, 1.0):
        for x in (2.2, 5.0, 7.8):
            _box(m, (x - 0.28, sy * 7.4 - (0.0 if sy > 0 else 0.34),
                     FLOOR_Z), (x + 0.28,
                     sy * 7.4 + (0.34 if sy > 0 else 0.0), 18.4), MAT_STONE)
    return m


# --------------------------------------------------------------------------- #
# 门廊 / 巨柱
# --------------------------------------------------------------------------- #

def _build_portico():
    m = Part()
    # 台基与台阶
    _box(m, (CENTRAL_FRONT, -CENTRAL_Y, PLAT_TOP), (19.7, CENTRAL_Y, FLOOR_Z), MAT_STONE)
    _box(m, (19.7, -CENTRAL_Y, PLAT_TOP), (20.5, CENTRAL_Y, PLAT_TOP + 0.40), MAT_STONE)
    _box(m, (20.5, -CENTRAL_Y, PLAT_TOP), (21.3, CENTRAL_Y, PLAT_TOP + 0.18), MAT_STONE)
    # 巨柱
    for y in PORTICO_COL_Y:
        _box(m, (PORTICO_COL_X - 1.42, y - 1.42, FLOOR_Z),
             (PORTICO_COL_X + 1.42, y + 1.42, FLOOR_Z + 1.10), MAT_STONE)
        _box(m, (PORTICO_COL_X - 1.22, y - 1.22, FLOOR_Z + 1.10),
             (PORTICO_COL_X + 1.22, y + 1.22, FLOOR_Z + 1.32), MAT_STONE)
        _cyl(m, (PORTICO_COL_X, y, FLOOR_Z + 1.32),
             (PORTICO_COL_X, y, PORTICO_ENTAB_Z[0] - 1.10), 1.02, 0.92, MAT_STONE, 16)
        _cyl(m, (PORTICO_COL_X, y, PORTICO_ENTAB_Z[0] - 1.10),
             (PORTICO_COL_X, y, PORTICO_ENTAB_Z[0] - 0.55), 0.92, 1.05, MAT_STONE, 16)
        _box(m, (PORTICO_COL_X - 1.42, y - 1.42, PORTICO_ENTAB_Z[0] - 0.55),
             (PORTICO_COL_X + 1.42, y + 1.42, PORTICO_ENTAB_Z[0]), MAT_STONE)
        _ring_axis(m, 2, FLOOR_Z + 1.36, FLOOR_Z + 1.50,
                   PORTICO_COL_X, y, 0.90, 1.06, MAT_BRASS, 16)
        _ring_axis(m, 2, PORTICO_ENTAB_Z[0] - 0.48, PORTICO_ENTAB_Z[0] - 0.34,
                   PORTICO_COL_X, y, 0.92, 1.06, MAT_BRASS, 16)
    # 门廊顶棚与梁
    _box(m, (CENTRAL_FRONT, -CENTRAL_Y, PORTICO_ENTAB_Z[0] - 0.35),
         (PORTICO_FRONT_X, CENTRAL_Y, PORTICO_ENTAB_Z[0]), MAT_STONE)
    for k in range(9):
        y = -CENTRAL_Y + 2.0 + k * 5.0
        _box(m, (CENTRAL_FRONT, y - 0.18, PORTICO_ENTAB_Z[0] - 0.55),
             (PORTICO_FRONT_X - 0.2, y + 0.18, PORTICO_ENTAB_Z[0] - 0.34), MAT_IRON)
    # 檐部三带
    _box(m, (CENTRAL_FRONT, -CENTRAL_Y - 0.45, PORTICO_ENTAB_Z[0]),
         (PORTICO_FRONT_X, CENTRAL_Y + 0.45, PORTICO_ENTAB_Z[0] + 0.80), MAT_STONE)
    _box(m, (CENTRAL_FRONT, -CENTRAL_Y - 0.45, PORTICO_ENTAB_Z[0] + 0.80),
         (PORTICO_FRONT_X + 0.10, CENTRAL_Y + 0.45, PORTICO_ENTAB_Z[0] + 1.95), MAT_STONE)
    _cornice(m, CENTRAL_FRONT, PORTICO_FRONT_X + 0.10, -CENTRAL_Y - 0.45,
             CENTRAL_Y + 0.45, PORTICO_ENTAB_Z[0] + 1.95, PORTICO_ENTAB_Z[1],
             0.55, MAT_STONE)
    # 铭牌底衬（黄铜字在其前方；下沿让出檐下齿饰）
    _box(m, (PORTICO_FRONT_X + 0.02, -12.2, PORTICO_ENTAB_Z[0] + 0.50),
         (PORTICO_FRONT_X + 0.11, 12.2, PORTICO_ENTAB_Z[0] + 1.92), MAT_IRON)
    _string_course(m, PORTICO_FRONT_X - 0.05, PORTICO_FRONT_X + 0.10,
                   -12.6, 12.6, PORTICO_ENTAB_Z[0] + 0.45,
                   PORTICO_ENTAB_Z[0] + 0.55, 0.10, MAT_STONE)
    _string_course(m, PORTICO_FRONT_X - 0.05, PORTICO_FRONT_X + 0.10,
                   -12.6, 12.6, PORTICO_ENTAB_Z[0] + 1.92,
                   PORTICO_ENTAB_Z[0] + 2.02, 0.10, MAT_STONE)
    # 顶部石栏板 + 瓮
    _box(m, (PORTICO_FRONT_X - 0.35, -CENTRAL_Y, PORTICO_BAL_Z[0]),
         (PORTICO_FRONT_X + 0.05, CENTRAL_Y, PORTICO_BAL_Z[1]), MAT_STONE)
    for k in range(9):
        y = -CENTRAL_Y + 2.4 + k * 4.6
        _box(m, (PORTICO_FRONT_X - 0.42, y - 1.45, PORTICO_BAL_Z[0] + 0.30),
             (PORTICO_FRONT_X + 0.12, y + 1.45, PORTICO_BAL_Z[0] + 1.02), MAT_STONE)
        _box(m, (PORTICO_FRONT_X - 0.50, y - 1.55, PORTICO_BAL_Z[1] - 0.12),
             (PORTICO_FRONT_X + 0.16, y + 1.55, PORTICO_BAL_Z[1] + 0.12), MAT_STONE)
    for y in (-18.0, -9.0, 0.0, 9.0, 18.0):
        _urn(m, PORTICO_FRONT_X - 0.15, y, PORTICO_BAL_Z[1] + 0.12, 0.85, MAT_STONE)
    return m


# --------------------------------------------------------------------------- #
# 两翼
# --------------------------------------------------------------------------- #

def _build_wings():
    m = Part()
    for side in (-1.0, 1.0):
        y0, y1 = sorted((side * WING_Y0, side * WING_Y1))
        # 后部下层体量
        _box(m, (WING_BACK, y0, PLAT_TOP), (WING_LOWER_FRONT, y1, WING_LOWER_TOP), MAT_STONE)
        # 上层体量
        _box(m, (WING_BACK, y0, WING_UPPER_BOT), (WING_UPPER_FRONT, y1, WING_TOP), MAT_STONE)
        # 拱廊顶横带
        _box(m, (WING_LOWER_FRONT - 0.2, y0, WING_LOWER_TOP),
             (WING_SCREEN_FRONT + 0.35, y1, WING_UPPER_BOT), MAT_STONE)
        # 基座 / 层线 / 檐口
        _box(m, (WING_BACK - 0.1, y0 - 0.1, PLAT_TOP),
             (WING_SCREEN_FRONT + 0.35, y1 + 0.1, FLOOR_Z), MAT_STONE)
        _string_course(m, WING_BACK, WING_SCREEN_FRONT + 0.1, y0, y1,
                       WING_UPPER_BOT - 0.28, WING_UPPER_BOT, 0.20, MAT_STONE)
        _cornice(m, WING_BACK, WING_UPPER_FRONT, y0, y1, WING_TOP, WING_ROOF_EAVE,
                 0.55, MAT_STONE)
        # 用户反馈转角隅石远看像锯齿：两翼与端亭的竖向隅石不再排，保留平直转角
        # 背面窗
        for k in range(5):
            y = y0 + (y1 - y0) * (k + 0.5) / 5.0
            _rect_window(m, 0, WING_BACK, -1.0, y, 6.8, 1.8, 2.6, mullions=1)
            _rect_window(m, 0, WING_BACK, -1.0, y, 13.2, 1.8, 2.6, mullions=1)
        # 上层壁柱
        for k in range(7):
            y = y0 + (y1 - y0) * k / 6.0
            _pilaster(m, 0, WING_UPPER_FRONT, 1.0, y, WING_UPPER_BOT, WING_TOP, 0.65, 0.30, MAT_STONE)
        # 上层窗
        for k in range(6):
            y = y0 + (y1 - y0) * (k + 0.5) / 6.0
            _rect_window(m, 0, WING_UPPER_FRONT, 1.0, y, 13.25, 2.2, 2.9,
                         mullions=2, pediment=(k % 2 == 0))
        # 拱廊上方石栏板
        _box(m, (WING_SCREEN_FRONT + 0.05, y0, WING_UPPER_BOT),
             (WING_SCREEN_FRONT + 0.40, y1, WING_UPPER_BOT + 0.55), MAT_STONE)
        for k in range(6):
            y = y0 + (y1 - y0) * (k + 0.5) / 6.0
            _box(m, (WING_SCREEN_FRONT + 0.07, y - 2.0, WING_UPPER_BOT + 0.12),
                 (WING_SCREEN_FRONT + 0.36, y + 2.0, WING_UPPER_BOT + 0.44), MAT_STONE)
    return m


def _build_wing_arcades():
    m = Part()
    for side in (-1.0, 1.0):
        y0, y1 = sorted((side * WING_Y0, side * WING_Y1))
        # 7 根墩柱
        ys = [y0 + (y1 - y0) * k / 6.0 for k in range(7)]
        for y in ys:
            _box(m, (WING_LOWER_FRONT - 0.05, y - 0.52, FLOOR_Z),
                 (WING_SCREEN_FRONT, y + 0.52, WING_LOWER_TOP), MAT_STONE)
            _box(m, (WING_LOWER_FRONT - 0.15, y - 0.68, FLOOR_Z),
                 (WING_SCREEN_FRONT + 0.10, y + 0.68, FLOOR_Z + 0.55), MAT_STONE)
            _box(m, (WING_LOWER_FRONT - 0.15, y - 0.68, WING_LOWER_TOP - 0.45),
                 (WING_SCREEN_FRONT + 0.10, y + 0.68, WING_LOWER_TOP), MAT_STONE)
        # 6 个拱洞
        for k in range(6):
            yc = (ys[k] + ys[k + 1]) * 0.5
            half = (ys[k + 1] - ys[k]) * 0.5 - 0.52
            spring = 6.6
            _arch_ring_axis(m, 0, WING_SCREEN_FRONT, WING_SCREEN_FRONT + 0.42,
                            yc, spring, half, half + 0.28, MAT_STONE, 12)
            _arch_lunette_axis(m, 0, WING_LOWER_FRONT - 0.05, WING_SCREEN_FRONT,
                               yc, spring, half, WING_LOWER_TOP,
                               -1.0, MAT_STONE, 8)
            _arch_lunette_axis(m, 0, WING_LOWER_FRONT - 0.05, WING_SCREEN_FRONT,
                               yc, spring, half, WING_LOWER_TOP,
                               1.0, MAT_STONE, 8)
            # 拱心石
            _box(m, (WING_SCREEN_FRONT, yc - 0.24, spring + half - 0.02),
                 (WING_SCREEN_FRONT + 0.50, yc + 0.24, spring + half + 0.44), MAT_STONE)
            # 后墙玻璃 / 木门
            _box(m, (WING_LOWER_FRONT + 0.02, yc - half + 0.15, FLOOR_Z + 0.3),
                 (WING_LOWER_FRONT + 0.08, yc + half - 0.15, WING_LOWER_TOP - 0.6), MAT_GLASS)
            for yy in (yc - half + 0.15, yc + half - 0.15):
                _box(m, (WING_LOWER_FRONT + 0.02, yy - 0.10, FLOOR_Z + 0.2),
                     (WING_LOWER_FRONT + 0.16, yy + 0.10, WING_LOWER_TOP - 0.4), MAT_WOOD_DARK)
            if k % 2 == 0:
                _box(m, (WING_LOWER_FRONT + 0.09, yc - 1.0, FLOOR_Z + 0.3),
                     (WING_LOWER_FRONT + 0.16, yc + 1.0, FLOOR_Z + 4.2), MAT_WOOD)
                _box(m, (WING_LOWER_FRONT + 0.16, yc - 1.0, FLOOR_Z + 4.0),
                     (WING_LOWER_FRONT + 0.22, yc + 1.0, FLOOR_Z + 4.2), MAT_BRASS)
            else:
                for zz in (FLOOR_Z + 1.4, FLOOR_Z + 3.2, FLOOR_Z + 5.0):
                    _box(m, (WING_LOWER_FRONT + 0.04, yc - half + 0.15, zz - 0.05),
                         (WING_LOWER_FRONT + 0.12, yc + half - 0.15, zz + 0.05), MAT_IRON)
    return m


def _build_wing_windows():
    # 两翼上层窗已在 _build_wings 里生成；本对象放拱廊内灯具与端墙细节
    m = Part()
    for side in (-1.0, 1.0):
        y0, y1 = sorted((side * WING_Y0, side * WING_Y1))
        for k in range(6):
            y = y0 + (y1 - y0) * (k + 0.5) / 6.0
            _box(m, (WING_SCREEN_FRONT + 0.15, y - 0.16, 6.6),
                 (WING_SCREEN_FRONT + 0.55, y + 0.16, 6.9), MAT_IRON)
            _cyl(m, (WING_SCREEN_FRONT + 0.42, y, 6.5),
                 (WING_SCREEN_FRONT + 0.42, y, 5.3), 0.20, 0.14, MAT_BRASS, 6)
            _cyl(m, (WING_SCREEN_FRONT + 0.42, y, 5.3),
                 (WING_SCREEN_FRONT + 0.42, y, 5.0), 0.30, 0.10, MAT_GLASS, 6)
    return m


# --------------------------------------------------------------------------- #
# 端部亭阁
# --------------------------------------------------------------------------- #

def _build_pavilions():
    m = Part()
    for side in (-1.0, 1.0):
        y0, y1 = sorted((side * PAV_Y0, side * PAV_Y1))
        # 体量
        _box(m, (PAV_X0, y0, PLAT_TOP), (PAV_X1, y1, PAV_TOP), MAT_STONE)
        _box(m, (PAV_X0 - 0.15, y0 - 0.15, PLAT_TOP),
             (PAV_X1 + 0.15, y1 + 0.15, FLOOR_Z), MAT_STONE)
        # 转角保持平直（用户要求去掉竖向隅石“锯齿”）
        # 外侧山墙窗（±Y 端面，四向完整度）
        outer_y = y1 if side > 0 else y0
        outer_sign = 1.0 if side > 0 else -1.0
        for wx in (-11.0, -2.5, 6.0):
            _rect_window(m, 1, outer_y, outer_sign, wx, 7.0, 2.2, 3.2,
                         mullions=2)
            _rect_window(m, 1, outer_y, outer_sign, wx, 13.4, 2.2, 2.8,
                         mullions=2, pediment=True)
        # 正立面两扇高拱窗 + 圆窗
        for yc in (y0 + 4.0, y1 - 4.0):
            _arched_window(m, 0, PAV_X1, 1.0, yc, FLOOR_Z + 0.8, 10.2, 2.35,
                           frame=MAT_STONE, mullions=2, balcony=True)
        _ring_axis(m, 0, PAV_X1 - 0.02, PAV_X1 + 0.32, (y0 + y1) * 0.5, 15.0,
                   1.35, 1.70, MAT_STONE, 18)
        m.add(_prism_axis(_circle((y0 + y1) * 0.5, 15.0, 1.35, 18),
                          PAV_X1 + 0.01, PAV_X1 + 0.06, 0), MAT_GLASS)
        for k in range(4):
            a = 2.0 * math.pi * k / 4.0 + 0.4
            _bar(m, (PAV_X1 + 0.05, (y0 + y1) * 0.5, 15.0),
                 (PAV_X1 + 0.05, (y0 + y1) * 0.5 + 1.35 * math.cos(a),
                  15.0 + 1.35 * math.sin(a)), 0.08, MAT_BRASS)
        # 层线 / 檐口
        _cornice(m, PAV_X0, PAV_X1, y0, y1, PAV_TOP, PAV_ROOF_EAVE, 0.85, MAT_STONE)
        # 山花
        _add_prism_axis(m, [(y0 + 0.4, PAV_ROOF_EAVE), (y1 - 0.4, PAV_ROOF_EAVE),
                           ((y0 + y1) * 0.5, PAV_ROOF_EAVE + 2.45)],
                        PAV_X1 - 0.9, PAV_X1 + 0.25, 0, MAT_STONE)
        _add_prism_axis(m, [(y0 + 1.0, PAV_ROOF_EAVE + 0.15),
                            (y1 - 1.0, PAV_ROOF_EAVE + 0.15),
                            ((y0 + y1) * 0.5, PAV_ROOF_EAVE + 2.05)],
                        PAV_X1 + 0.26, PAV_X1 + 0.30, 0, MAT_IRON)
        _ring_axis(m, 0, PAV_X1 + 0.28, PAV_X1 + 0.40,
                   (y0 + y1) * 0.5, PAV_ROOF_EAVE + 1.18, 0.48, 0.66, MAT_BRASS, 14)
        # 亭阁四角石瓮
        for yy in (y0 + 0.8, y1 - 0.8):
            _urn(m, PAV_X1 - 0.4, yy, PAV_ROOF_EAVE + 0.1, 0.85, MAT_STONE)
        # 背面 / 外侧窗
        for k in range(3):
            yy = y0 + (y1 - y0) * (k + 0.5) / 3.0
            _rect_window(m, 0, PAV_X0, -1.0, yy, 8.6, 2.0, 3.2, mullions=2)
            _rect_window(m, 0, PAV_X0, -1.0, yy, 14.4, 2.0, 2.6, mullions=1)
    return m


# --------------------------------------------------------------------------- #
# 屋面 / 塔楼
# --------------------------------------------------------------------------- #

def _build_roofs():
    m = Part()
    # 中央大屋面
    _hip_roof(m, CENTRAL_X0, CENTRAL_FRONT, -CENTRAL_Y, CENTRAL_Y,
              CENTRAL_ROOF_EAVE, CENTRAL_ROOF_RIDGE, 7.5, 0.42, MAT_COPPER)
    _hip_roof_ribs(m, CENTRAL_X0, CENTRAL_FRONT, -CENTRAL_Y, CENTRAL_Y,
                   CENTRAL_ROOF_EAVE, CENTRAL_ROOF_RIDGE, 7.5, MAT_IRON, 2.6)
    _ridge_cresting(m, TOWER_CX, -CENTRAL_Y + 7.5, -8.8,
                    CENTRAL_ROOF_RIDGE, MAT_IRON, 1.5)
    _ridge_cresting(m, TOWER_CX, 8.8, CENTRAL_Y - 7.5,
                    CENTRAL_ROOF_RIDGE, MAT_IRON, 1.5)
    # 中央屋面老虎窗（正面 3 个）
    for y in (-12.0, 0.0, 12.0):
        _dormer(m, 4.2, y, 25.15, 2.8, 2.0, 2.0)
    # 两翼屋面
    for side in (-1.0, 1.0):
        y0, y1 = sorted((side * WING_Y0, side * WING_Y1))
        _hip_roof(m, WING_BACK, WING_UPPER_FRONT, y0, y1,
                  WING_ROOF_EAVE, WING_ROOF_RIDGE, 6.0, 0.38, MAT_COPPER)
        _hip_roof_ribs(m, WING_BACK, WING_UPPER_FRONT, y0, y1,
                       WING_ROOF_EAVE, WING_ROOF_RIDGE, 6.0, MAT_IRON, 2.8)
        _ridge_cresting(m, (WING_BACK + WING_UPPER_FRONT) * 0.5,
                        y0 + 6.0, y1 - 6.0, WING_ROOF_RIDGE, MAT_IRON, 1.8)
        for y in (y0 + 9.0, y0 + 21.0):
            _dormer(m, 3.8, y, 18.2, 2.4, 1.8, 1.8)
    # 亭阁屋面
    for side in (-1.0, 1.0):
        y0, y1 = sorted((side * PAV_Y0, side * PAV_Y1))
        _hip_roof(m, PAV_X0, PAV_X1, y0, y1, PAV_ROOF_EAVE, PAV_ROOF_RIDGE,
                  4.0, 0.40, MAT_COPPER)
        _hip_roof_ribs(m, PAV_X0, PAV_X1, y0, y1, PAV_ROOF_EAVE,
                       PAV_ROOF_RIDGE, 4.0, MAT_IRON, 2.4)
        _ridge_cresting(m, (PAV_X0 + PAV_X1) * 0.5, y0 + 4.0, y1 - 4.0,
                        PAV_ROOF_RIDGE, MAT_IRON, 1.5)
        _pavilion_cupola(m, (PAV_X0 + PAV_X1) * 0.5, side * (PAV_Y0 + PAV_Y1) * 0.5,
                         PAV_ROOF_RIDGE)
    # 烟囱
    for (x, y) in ((-12.0, -15.0), (-12.0, 15.0), (5.5, -16.5), (5.5, 16.5)):
        _chimney(m, x, y, CENTRAL_ROOF_RIDGE - 2.2, CENTRAL_ROOF_RIDGE + 3.2, 1.0)
    for side in (-1.0, 1.0):
        for y in (26.0, 47.0):
            _chimney(m, -10.0, y, WING_ROOF_RIDGE - 1.6, WING_ROOF_RIDGE + 2.8, 0.8)
    return m


def _dormer(part, x_front, y, base_z, width, height, depth):
    x0 = x_front - depth
    _box(part, (x0, y - width * 0.5, base_z), (x_front, y + width * 0.5, base_z + height), MAT_STONE)
    _box(part, (x_front + 0.01, y - width * 0.5 + 0.22, base_z + 0.35),
         (x_front + 0.08, y + width * 0.5 - 0.22, base_z + height - 0.15), MAT_GLASS)
    for yy in (y - width * 0.5 + 0.22, y + width * 0.5 - 0.22):
        _box(part, (x_front + 0.01, yy - 0.08, base_z + 0.25),
             (x_front + 0.14, yy + 0.08, base_z + height - 0.05), MAT_WOOD_DARK)
    _box(part, (x_front + 0.01, y - 0.04, base_z + 0.3),
         (x_front + 0.14, y + 0.04, base_z + height - 0.1), MAT_WOOD_DARK)
    _box(part, (x_front, y - width * 0.6, base_z + height - 0.1),
         (x_front + 0.18, y + width * 0.6, base_z + height + 0.10), MAT_STONE)
    _gable_roof(part, x0 - 0.3, x_front + 0.3, y - width * 0.65, y + width * 0.65,
                base_z + height, base_z + height + 1.0, 0.16, MAT_COPPER, MAT_STONE)


def _chimney(part, x, y, z0, z1, half):
    _box(part, (x - half, y - half, z0), (x + half, y + half, z1), MAT_STONE)
    for f in (0.3, 0.6, 0.85):
        z = z0 + (z1 - z0) * f
        _box(part, (x - half - 0.08, y - half - 0.08, z - 0.08),
             (x + half + 0.08, y + half + 0.08, z + 0.08), MAT_STONE)
    _box(part, (x - half - 0.16, y - half - 0.16, z1 - 0.18),
         (x + half + 0.16, y + half + 0.16, z1), MAT_STONE)
    _box(part, (x - half * 0.55, y - half * 0.55, z1 - 0.02),
         (x + half * 0.55, y + half * 0.55, z1 + 0.10), MAT_IRON)
    _box(part, (x - half * 0.35, y - half * 0.35, z1 + 0.10),
         (x + half * 0.35, y + half * 0.35, z1 + 0.28), MAT_IRON_RED)


def _pavilion_cupola(part, cx, cy, base_z):
    _cyl(part, (cx, cy, base_z - 0.3), (cx, cy, base_z + 1.1), 2.45, 2.30, MAT_STONE, 8)
    _cyl(part, (cx, cy, base_z + 1.1), (cx, cy, base_z + 1.3), 2.65, 2.45, MAT_STONE, 8)
    # 8 根小柱
    for k in range(8):
        a = 2.0 * math.pi * k / 8.0
        px, py = cx + 2.05 * math.cos(a), cy + 2.05 * math.sin(a)
        _cyl(part, (px, py, base_z + 1.3), (px, py, base_z + 3.1), 0.16, 0.13, MAT_STONE, 6)
    _cyl(part, (cx, cy, base_z + 1.3), (cx, cy, base_z + 3.1), 1.80, 1.80, MAT_GLASS, 12)
    _cyl(part, (cx, cy, base_z + 3.1), (cx, cy, base_z + 3.35), 2.25, 2.25, MAT_STONE, 8)
    verts, faces = revolved([(0.0, 2.15), (0.5, 2.0), (1.3, 1.65), (2.0, 1.0), (2.35, 0.25)], 12)
    verts = [(vx + cx, vy + cy, vz + base_z + 3.35) for (vx, vy, vz) in verts]
    part.add((verts, faces), MAT_COPPER)
    _cyl(part, (cx, cy, base_z + 5.6), (cx, cy, base_z + 6.0), 0.18, 0.02, MAT_BRASS, 6)
    _flag_pole(part, cx, cy, base_z + 5.95, 4.2, 3.0, 1.8, MAT_IRON_RED)


def _build_tower_body(part):
    cx = TOWER_CX
    # 基座
    _box(part, (cx - TOWER_HALF - 1.2, -TOWER_HALF - 1.2, TOWER_BASE_Z[0]),
         (cx + TOWER_HALF + 1.2, TOWER_HALF + 1.2, TOWER_BASE_Z[1]), MAT_STONE)
    _string_course(part, cx - TOWER_HALF - 1.25, cx + TOWER_HALF + 1.25,
                   -TOWER_HALF - 1.25, TOWER_HALF + 1.25,
                   TOWER_BASE_Z[1] - 0.30, TOWER_BASE_Z[1], 0.18, MAT_STONE)
    # 塔身
    _box(part, (cx - TOWER_HALF, -TOWER_HALF, TOWER_BODY_Z[0]),
         (cx + TOWER_HALF, TOWER_HALF, TOWER_BODY_Z[1]), MAT_STONE)
    # 四角壁柱
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            px = cx + sx * TOWER_HALF
            py = sy * TOWER_HALF
            _box(part, (px - sx * 0.6, py - sy * 0.6, TOWER_BODY_Z[0]),
                 (px + sx * 0.15, py + sy * 0.15, TOWER_BODY_Z[1]), MAT_STONE)
    # 层线（只保留塔身下沿一道，避免横穿钟盘与百叶拱）
    _string_course(part, cx - TOWER_HALF - 0.18, cx + TOWER_HALF + 0.18,
                   -TOWER_HALF - 0.18, TOWER_HALF + 0.18, 28.0, 28.28, 0.18, MAT_STONE)
    # 四面高拱百叶洞
    for axis, plane, sign in ((0, cx + TOWER_HALF, 1.0), (0, cx - TOWER_HALF, -1.0),
                              (1, TOWER_HALF, 1.0), (1, -TOWER_HALF, -1.0)):
        center_u = 0.0
        _arched_window(part, axis, plane, sign, center_u, 29.4, 31.6, 1.7,
                       frame=MAT_STONE, mullions=0)
        for k in range(7):
            zz = 29.8 + k * 0.55
            if axis == 0:
                _box(part, (plane + sign * 0.02, center_u - 1.55, zz - 0.05),
                     (plane + sign * 0.10, center_u + 1.55, zz + 0.05), MAT_IRON)
            else:
                _box(part, (center_u - 1.55, plane + sign * 0.02, zz - 0.05),
                     (center_u + 1.55, plane + sign * 0.10, zz + 0.05), MAT_IRON)
    # 檐口
    _cornice(part, cx - TOWER_HALF, cx + TOWER_HALF, -TOWER_HALF, TOWER_HALF,
             TOWER_CORNICE_Z[0], TOWER_CORNICE_Z[1], 0.95, MAT_STONE)
    # 四角小尖塔
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            px, py = cx + sx * (TOWER_HALF - 0.1), sy * (TOWER_HALF - 0.1)
            _box(part, (px - 0.45, py - 0.45, TOWER_CORNICE_Z[1]),
                 (px + 0.45, py + 0.45, TOWER_CORNICE_Z[1] + 1.4), MAT_STONE)
            _cyl(part, (px, py, TOWER_CORNICE_Z[1] + 1.4),
                 (px, py, TOWER_CORNICE_Z[1] + 2.6), 0.38, 0.02, MAT_STONE, 4)
    # 鼓座（石鼓 + 两道线脚；高处的开口留给穹顶肋与铜面读层次）
    _cyl(part, (cx, 0.0, TOWER_DRUM_Z[0]), (cx, 0.0, TOWER_DRUM_Z[1]),
         8.05, 7.85, MAT_STONE, 16)
    _ring_axis(part, 2, TOWER_DRUM_Z[0] + 0.28, TOWER_DRUM_Z[0] + 0.42,
               cx, 0.0, 7.75, 8.15, MAT_STONE, 16)
    _ring_axis(part, 2, TOWER_DRUM_Z[1] - 0.42, TOWER_DRUM_Z[1] - 0.28,
               cx, 0.0, 7.60, 8.10, MAT_STONE, 16)
    # 铜穹顶
    profile = [(0.00, 8.05), (0.55, 7.95), (1.4, 7.55), (2.6, 6.80),
               (3.8, 5.65), (4.9, 4.25), (5.7, 2.70), (6.1, 1.10), (6.3, 0.30)]
    verts, faces = revolved(profile, 16)
    verts = [(vx + cx, vy, vz + TOWER_DOME_Z[0]) for (vx, vy, vz) in verts]
    part.add((verts, faces), MAT_COPPER)
    # 穹顶肋
    for k in range(16):
        a = 2.0 * math.pi * k / 16.0
        pts = []
        for (zz, rr) in profile:
            pts.append((cx + (rr + 0.06) * math.cos(a),
                        (rr + 0.06) * math.sin(a), TOWER_DOME_Z[0] + zz))
        for i in range(len(pts) - 1):
            _bar(part, pts[i], pts[i + 1], 0.12, MAT_IRON)
    # 顶部铜球 / 尖顶
    _cyl(part, (cx, 0.0, TOWER_DOME_Z[0] + 6.2), (cx, 0.0, TOWER_DOME_Z[0] + 6.5),
         0.55, 0.55, MAT_BRASS, 10)
    # 灯亭
    _cyl(part, (cx, 0.0, TOWER_LANTERN_Z[0]), (cx, 0.0, TOWER_LANTERN_Z[0] + 0.55),
         2.45, 2.15, MAT_STONE, 8)
    for k in range(8):
        a = 2.0 * math.pi * k / 8.0
        px, py = cx + 1.95 * math.cos(a), 1.95 * math.sin(a)
        _cyl(part, (px, py, TOWER_LANTERN_Z[0] + 0.55),
             (px, py, TOWER_LANTERN_Z[0] + 2.55), 0.16, 0.13, MAT_STONE, 6)
    _cyl(part, (cx, 0.0, TOWER_LANTERN_Z[0] + 0.55),
         (cx, 0.0, TOWER_LANTERN_Z[0] + 2.55), 1.70, 1.70, MAT_GLASS, 12)
    _cyl(part, (cx, 0.0, TOWER_LANTERN_Z[0] + 2.55),
         (cx, 0.0, TOWER_LANTERN_Z[0] + 2.80), 2.35, 2.35, MAT_STONE, 8)
    verts, faces = revolved([(0.0, 2.30), (0.5, 2.10), (1.3, 1.65), (2.0, 1.0),
                             (2.55, 0.30)], 12)
    verts = [(vx + cx, vy, vz + TOWER_LANTERN_Z[0] + 2.80) for (vx, vy, vz) in verts]
    part.add((verts, faces), MAT_COPPER)
    _cyl(part, (cx, 0.0, TOWER_LANTERN_Z[0] + 5.35),
         (cx, 0.0, FLAG_TOP - 2.5), 0.16, 0.05, MAT_IRON, 6)
    _flag_pole(part, cx, 0.0, FLAG_TOP - 2.7, 2.5, 5.0, 2.6, MAT_IRON_RED)


def _clock_face(part, axis, plane, sign, cu, cv, r):
    # 盘面
    _add_prism_axis(part, _circle(cu, cv, r, 20),
                    plane + sign * 0.02, plane + sign * 0.14, axis, MAT_CANVAS)
    _ring_axis(part, axis, plane + sign * 0.10, plane + sign * 0.22,
               cu, cv, r, r + 0.22, MAT_IRON, 20)
    # 12 个黄铜刻度
    for k in range(12):
        a = 2.0 * math.pi * k / 12.0
        u = cu + (r - 0.30) * math.sin(a)
        v = cv + (r - 0.30) * math.cos(a)
        if axis == 0:
            p0, p1 = (plane + sign * 0.15, u, v), (plane + sign * 0.23, u, v)
        else:
            p0, p1 = (u, plane + sign * 0.15, v), (u, plane + sign * 0.23, v)
        _cyl(part, p0, p1, 0.075, 0.075, MAT_BRASS, 6)
    # 时针 / 分针
    for (angle, length, thick) in ((math.radians(-38.0), r * 0.58, 0.13),
                                   (math.radians(52.0), r * 0.86, 0.08)):
        dx = math.sin(angle) * length
        dy = math.cos(angle) * length
        if axis == 0:
            p0 = (plane + sign * 0.26, cu, cv)
            p1 = (plane + sign * 0.26, cu + dx, cv + dy)
        else:
            p0 = (cu, plane + sign * 0.26, cv)
            p1 = (cu + dx, plane + sign * 0.26, cv + dy)
        _bar(part, p0, p1, thick, MAT_IRON)
    # 中心轴帽
    if axis == 0:
        _cyl(part, (plane + sign * 0.22, cu, cv), (plane + sign * 0.34, cu, cv),
             0.12, 0.12, MAT_BRASS, 8)
    else:
        _cyl(part, (cu, plane + sign * 0.22, cv), (cu, plane + sign * 0.34, cv),
             0.12, 0.12, MAT_BRASS, 8)


# --------------------------------------------------------------------------- #
# 塔楼钟盘
# --------------------------------------------------------------------------- #

def _build_tower():
    m = Part()
    _build_tower_body(m)
    return m


def _build_tower_clock():
    m = Part()
    for axis, plane, sign in ((0, TOWER_CX + TOWER_HALF, 1.0),
                              (0, TOWER_CX - TOWER_HALF, -1.0),
                              (1, TOWER_HALF, 1.0),
                              (1, -TOWER_HALF, -1.0)):
        _clock_face(m, axis, plane, sign, 0.0, TOWER_CLOCK_Z, 2.25)
    return m


# --------------------------------------------------------------------------- #
# 广场细节（灯 / 旗 / 长凳 / 系船环）已在上方
# --------------------------------------------------------------------------- #

def _build_details():
    m = Part()
    # 中央主楼壁灯
    for y in (-13.3, 13.3):
        _wall_lamp(m, CENTRAL_FRONT + 0.15, y, 7.0)
    for y in (-18.0, 18.0):
        _wall_lamp(m, CENTRAL_FRONT + 0.15, y, 16.0)
    # 亭阁壁灯
    for side in (-1.0, 1.0):
        for y in (56.0, 62.0):
            _wall_lamp(m, PAV_X1 + 0.15, side * y, 8.0)
    # 落水管（中央主楼两角 + 两翼端部）
    for sy in (-1.0, 1.0):
        _downpipe(m, CENTRAL_FRONT + 0.02, sy * (CENTRAL_Y - 0.8), FLOOR_Z, 20.4)
    for side in (-1.0, 1.0):
        for y in (WING_Y0 + 0.8, WING_Y1 - 0.8):
            _downpipe(m, WING_UPPER_FRONT + 0.02, side * y, WING_UPPER_BOT, 16.0)
    return m


def _wall_lamp(part, x, y, z):
    _box(part, (x - 0.20, y - 0.20, z - 0.20), (x + 0.20, y + 0.20, z + 0.20), MAT_IRON)
    _cyl(part, (x + 0.15, y, z), (x + 1.05, y, z + 0.25), 0.10, 0.10, MAT_IRON, 6)
    _box(part, (x + 0.95, y - 0.28, z + 0.12), (x + 1.35, y + 0.28, z + 0.74), MAT_GLASS)
    for sy in (-1.0, 1.0):
        _box(part, (x + 0.94, y + sy * 0.26 - 0.04, z + 0.10),
             (x + 1.36, y + sy * 0.26 + 0.04, z + 0.76), MAT_IRON)
    _box(part, (x + 0.92, y - 0.30, z + 0.70), (x + 1.38, y + 0.30, z + 0.80), MAT_IRON)
    _cyl(part, (x + 1.15, y, z + 0.80), (x + 1.15, y, z + 1.00), 0.20, 0.02, MAT_BRASS, 6)


def _downpipe(part, x, y, z0, z1):
    _cyl(part, (x, y, z0), (x, y, z1), 0.075, 0.075, MAT_IRON, 8)
    for z in (z0 + 1.2, z0 + 3.2, z0 + 5.2):
        _box(part, (x - 0.10, y - 0.16, z - 0.05), (x + 0.10, y + 0.16, z + 0.05), MAT_IRON)
    _box(part, (x - 0.18, y - 0.18, z0 - 0.05), (x + 0.18, y + 0.18, z0 + 0.20), MAT_IRON)


# --------------------------------------------------------------------------- #
# 组装
# --------------------------------------------------------------------------- #

def build_geometry():
    """返回 {mesh_name: (Part, parent_key)}；父级全部挂根空物体。"""
    parts = {
        PREFIX + "Quay_Base": (_build_quay_base(), "ROOT"),
        PREFIX + "Quay_Stairs": (_build_quay_stairs(), "ROOT"),
        PREFIX + "Quay_Balustrade": (_build_quay_balustrade(), "ROOT"),
        PREFIX + "Plaza_Furniture": (_build_plaza_furniture(), "ROOT"),
        PREFIX + "Central_Block": (_build_central_block(), "ROOT"),
        PREFIX + "Central_Entrance": (_build_central_entrance(), "ROOT"),
        PREFIX + "Portico": (_build_portico(), "ROOT"),
        PREFIX + "Wings": (_build_wings(), "ROOT"),
        PREFIX + "Wing_Arcades": (_build_wing_arcades(), "ROOT"),
        PREFIX + "Wing_Windows": (_build_wing_windows(), "ROOT"),
        PREFIX + "Pavilions": (_build_pavilions(), "ROOT"),
        PREFIX + "Roofs": (_build_roofs(), "ROOT"),
        PREFIX + "Tower": (_build_tower(), "ROOT"),
        PREFIX + "Tower_Clock": (_build_tower_clock(), "ROOT"),
        PREFIX + "Details": (_build_details(), "ROOT"),
    }
    return parts


# --------------------------------------------------------------------------- #
# 纯 Python 报告
# --------------------------------------------------------------------------- #

def _part_health(part):
    """返回 (边界边, 非流形边, 退化面, 孤立点)。"""
    edge_count = {}
    used = set()
    for face, _mat in part.faces:
        if len(set(face)) != len(face):
            continue
        for i in range(len(face)):
            a, b = face[i], face[(i + 1) % len(face)]
            used.add(a)
            used.add(b)
            key = (a, b) if a < b else (b, a)
            edge_count[key] = edge_count.get(key, 0) + 1
    boundary = sum(1 for c in edge_count.values() if c == 1)
    nonmanifold = sum(1 for c in edge_count.values() if c > 2)
    degenerate = 0
    for face, _mat in part.faces:
        if len(set(face)) != len(face):
            degenerate += 1
            continue
        # 用 Newell 法向面积判断退化
        nx = ny = nz = 0.0
        for i in range(len(face)):
            x0, y0, z0 = part.verts[face[i]]
            x1, y1, z1 = part.verts[face[(i + 1) % len(face)]]
            nx += (y0 - y1) * (z0 + z1)
            ny += (z0 - z1) * (x0 + x1)
            nz += (x0 - x1) * (y0 + y1)
        if math.sqrt(nx * nx + ny * ny + nz * nz) < 1e-8:
            degenerate += 1
    loose = len(part.verts) - len(used)
    return boundary, nonmanifold, degenerate, loose


def geometry_report():
    parts = {name: part for name, (part, _p) in build_geometry().items()
             if len(part.verts) > 0}
    tri = 0
    bmin = [1e18] * 3
    bmax = [-1e18] * 3
    mats = set()
    failures = []
    per_object = {}
    for name, part in parts.items():
        p_tri = sum(max(1, len(f) - 2) for f, _m in part.faces)
        tri += p_tri
        mats.update(m for _f, m in part.faces)
        for v in part.verts:
            for i in range(3):
                bmin[i] = min(bmin[i], v[i])
                bmax[i] = max(bmax[i], v[i])
        boundary, nonmanifold, degenerate, loose = _part_health(part)
        per_object[name] = {
            "verts": len(part.verts),
            "faces": len(part.faces),
            "tris": p_tri,
            "boundary_edges": boundary,
            "non_manifold_edges": nonmanifold,
            "degenerate_faces": degenerate,
            "loose_verts": loose,
            "materials": sorted({m for _f, m in part.faces}),
        }
        if boundary or nonmanifold or degenerate or loose:
            failures.append("%s: boundary=%d nonmanifold=%d degenerate=%d loose=%d" % (
                name, boundary, nonmanifold, degenerate, loose))
    size = tuple(round(bmax[i] - bmin[i], 3) for i in range(3))
    bad_mats = sorted(mats - MATERIAL_WHITELIST)
    if bad_mats:
        failures.append("materials outside whitelist: %s" % ", ".join(bad_mats))
    if not (-0.05 <= bmin[2] <= 0.05):
        failures.append("zmin %.3f != 0" % bmin[2])
    for i, target in enumerate(TARGET_SIZE):
        if abs(size[i] - target) > 0.65:
            failures.append("size[%s] %.3f != %.3f" % ("XYZ"[i], size[i], target))
    if tri > TRI_BUDGET - SIGN_TRI_ALLOWANCE:
        failures.append("geometry tris %d too high for budget %d (sign allowance %d)" % (
            tri, TRI_BUDGET, SIGN_TRI_ALLOWANCE))
    if tri < TRI_FLOOR:
        failures.append("geometry tris %d below floor %d" % (tri, TRI_FLOOR))
    return {
        "asset": ASSET,
        "objects": len(parts),
        "tris": tri,
        "size": size,
        "bbox_min": [round(v, 3) for v in bmin],
        "bbox_max": [round(v, 3) for v in bmax],
        "materials": sorted(mats),
        "per_object": per_object,
        "failures": failures,
        "ok": not failures,
    }


# --------------------------------------------------------------------------- #
# Blender 装配
# --------------------------------------------------------------------------- #

SIGN_TEXT = "HARBOUR TERMINAL"
SIGN_SIZE = 1.45
SIGN_BASE = (PORTICO_FRONT_X + 0.16, 0.0, 21.55)

# 大型建筑的大面如果按共享贴图的 2 m tile 平铺，石块/铜板会形成明显的规则
# 重复。这里对**本资产**做后处理：把 UV 周期乘 0.45–0.6（tile 变 3.3–4.9 m，
# 石块/铜板更大、重复频率更低）+ 每对象确定性偏移，既保留共享贴图，又不改
# 其它资产的材质规范。注意 UV 小于 1 才是“放大纹理”；大于 1 会把贴图压小。
UV_OBJECT_SCALE = {
    PREFIX + "Quay_Base": 0.45,
    PREFIX + "Quay_Stairs": 0.45,
    PREFIX + "Quay_Balustrade": 0.85,
    PREFIX + "Plaza_Furniture": 1.0,
    PREFIX + "Central_Block": 0.45,
    PREFIX + "Central_Entrance": 0.60,
    PREFIX + "Portico": 0.55,
    PREFIX + "Wings": 0.45,
    PREFIX + "Wing_Arcades": 0.55,
    PREFIX + "Wing_Windows": 1.0,
    PREFIX + "Pavilions": 0.45,
    PREFIX + "Roofs": 0.50,
    PREFIX + "Tower": 0.48,
    PREFIX + "Tower_Clock": 1.0,
    PREFIX + "Details": 1.0,
    PREFIX + "Sign": 1.0,
}
UV_SCALE_MATERIALS = frozenset({MAT_STONE, MAT_COPPER})


def _build_sign(collection, root):
    import bpy
    import bmesh
    from mathutils import Matrix, Vector

    cu = bpy.data.curves.new(PREFIX + "Sign_Curve", "FONT")
    cu.body = SIGN_TEXT
    cu.size = SIGN_SIZE
    cu.extrude = 0.06
    cu.offset = 0.015
    cu.space_character = 1.10
    cu.resolution_u = 5
    cu.align_x = "CENTER"
    cu.align_y = "CENTER"
    tmp = bpy.data.objects.new(PREFIX + "Sign_Tmp", cu)
    collection.objects.link(tmp)
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(tmp.evaluated_get(dg))
    bpy.data.objects.remove(tmp, do_unlink=True)
    bpy.data.curves.remove(cu)
    me.name = PREFIX + "Sign"
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.dissolve_degenerate(bm, dist=1e-5, edges=bm.edges)
    zero = [f for f in bm.faces if f.calc_area() < 1e-7]
    if zero:
        bmesh.ops.delete(bm, geom=zero, context="FACES")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    me.update()
    # 字体平面 XY，法线 +Z → 主立面前向 +X，文字左→右沿 +Y（右手系）
    rot = Matrix(((0.0, 0.0, 1.0),
                  (1.0, 0.0, 0.0),
                  (0.0, 1.0, 0.0)))
    base = Vector(SIGN_BASE)
    for v in me.vertices:
        v.co = rot @ v.co + base
    mat = bpy.data.materials.get(MAT_BRASS)
    if mat is None:
        import sn_shared_materials as sm
        sm.build_materials()
        mat = bpy.data.materials.get(MAT_BRASS)
    me.materials.append(mat)
    for poly in me.polygons:
        poly.material_index = 0
        poly.use_smooth = False
    ob = bpy.data.objects.new(PREFIX + "Sign", me)
    collection.objects.link(ob)
    ob.parent = root
    bpy.context.view_layer.update()
    return ob


def _retune_terminal_uvs(collection):
    """本资产专用的 UV 去重复：放大石/铜的周期 + 每对象确定性偏移。

    共享材质本身保持 2 m tile；只在航站楼这套 mesh 的 UVMap 上做后处理，
    因此不会影响其它资产。返回逐对象 {scale, offset} 报告。
    """
    report = {}
    for ob in collection.objects:
        if ob.type != "MESH":
            continue
        uv = ob.data.uv_layers.get("UVMap")
        if uv is None:
            continue
        digest = hashlib.sha256(ob.name.encode("utf-8")).digest()
        base = UV_OBJECT_SCALE.get(ob.name, 1.0)
        # 每个对象再带 ±10% 的周期差异，避免相邻体量完全同频
        variation = 0.90 + 0.20 * (digest[2] / 255.0)
        off = (digest[0] / 255.0 * 0.75, digest[1] / 255.0 * 0.75)
        slots = [m.name if m else "" for m in ob.data.materials]
        for poly in ob.data.polygons:
            mat = slots[poly.material_index] if poly.material_index < len(slots) else ""
            scale = base * variation if mat in UV_SCALE_MATERIALS else 1.0
            for li in range(poly.loop_start, poly.loop_start + poly.loop_total):
                u, v = uv.data[li].uv
                uv.data[li].uv = (u * scale + off[0], v * scale + off[1])
        report[ob.name] = {
            "scale": round(base * variation, 4),
            "offset": [round(off[0], 4), round(off[1], 4)],
        }
    collection.update_tag()
    return report


def build_all():
    import importlib
    import json
    import bpy

    import sn_shared_materials as sm
    import ship_parts.assembly as assembly

    # 活体 Blender 会缓存纯 Python 模块，重建前强制刷新
    importlib.reload(sm)
    importlib.reload(assembly)

    parts = {k: v for k, v in build_geometry().items() if len(v[0].verts) > 0}
    palette = sm.palette_linear()
    cfg = assembly.BuildConfig(
        collection=COLLECTION,
        prefix=PREFIX,
        root_name=ROOT_NAME,
        workbench_pos=WORKBENCH_POS,
        material_colors=palette,
        material_reuse=palette,
        root_props={
            "asset": ASSET,
            "version": "1.0",
            "units": "m",
            "category": CATEGORY,
            "front": "+X",
            "up": "+Z",
            "datum": "platform centre on ground z=0; front +X",
            "width_y": TARGET_SIZE[1],
            "depth_x": TARGET_SIZE[0],
            "height": TARGET_SIZE[2],
            "tri_budget": TRI_BUDGET,
            "style": "victorian harbour terminal / clock tower / copper roofs",
            "sign_text": SIGN_TEXT,
        },
        text_material=MAT_BRASS,
        report_title="Grand Harbour Terminal",
        tri_budget=TRI_BUDGET,
        root_size=6.0,
    )
    col = assembly.build_collection(parts, cfg)
    root = bpy.data.objects[ROOT_NAME]
    sign = _build_sign(col, root)
    tex = sm.apply_collection(col, space="root", root=root)
    uv_retune = _retune_terminal_uvs(col)
    verified = sm.verify_collection(col)
    info = assembly.report(cfg, verbose=False)
    sign_tris = sum(max(1, len(p.vertices) - 2) for p in sign.data.polygons)
    report = {
        "asset": ASSET,
        "collection": COLLECTION,
        "root": ROOT_NAME,
        "objects": info["objects"],
        "meshes": info["meshes"],
        "empties": info["empties"],
        "tris": info["tris"],
        "sign_node": sign.name,
        "sign_tris": sign_tris,
        "bbox": info["bbox"],
        "bbox_min": info["bbox_min"],
        "bbox_max": info["bbox_max"],
        "materials": info["materials"],
        "textures": {
            "textured": tex["textured"],
            "failures": tex["failures"],
            "materials": tex["materials"],
        },
        "uv_retune": uv_retune,
        "verify": verified,
        "per_object": {
            ob.name: {
                "tris": sum(max(1, len(p.vertices) - 2) for p in ob.data.polygons),
                "verts": len(ob.data.vertices),
                "materials": [m.name for m in ob.data.materials if m],
            }
            for ob in col.objects if ob.type == "MESH"
        },
    }
    print("GRAND_TERMINAL_BUILD_REPORT " + json.dumps(report, ensure_ascii=False))
    if not verified.get("ok"):
        raise RuntimeError("shared material verification failed: %r" % verified)
    return report


# --------------------------------------------------------------------------- #
# 入口
# --------------------------------------------------------------------------- #

if __name__ == "__main__":
    if "bpy" in sys.modules:
        build_all()
    else:
        rep = geometry_report()
        print("GRAND_TERMINAL_GEOMETRY %r" % rep)
        if not rep["ok"]:
            for f in rep["failures"]:
                print("FAIL", f)
            sys.exit(1)
