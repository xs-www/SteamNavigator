# -*- coding: utf-8 -*-
"""Steam Navigator — SN_Schooner_Fame 1795 双桅纵帆船参数化生成脚本。

工单
----
tools/modeling/briefs/sn_schooner_fame.json
集合：SN_Schooner_Fame_Prototype（新增，不触碰既有对象）
轴心：船体中部水线（z = 0），+X = 船首，+Z = 向上，1 unit = 1 m
预算：<= 18000 tri
材质：SN_Hull_Black / SN_Ochre / SN_Wood / SN_Wood_Dark / SN_Wood_Deck /
      SN_Canvas / SN_Canvas_Shade / SN_Metal / SN_Brass /
      SN_Flag_Red / SN_Flag_White / SN_Flag_Blue

设计要点
--------
参考 1795 年 Salem 双桅纵帆船 Fame 的绘画：
- 黑色船身 + 赭黄色上舷带/舷墙 + 黑色压条与压顶；低矮而修长的 24.4 m 船体；
- 双桅后倾：前桅斜桁帆 + 方顶帆，主桅大斜桁帆 + 三角顶帆；
- 艏斜桁 + 艏三角帆（jib + fore staysail）；
- 完整索具：舷侧绳梯（shrouds + ratlines）、支索、转帆索、吊索、帆缘绳；
- 艉部弧形艉廊 + 双灯 + FAME 铭牌；主桅顶红白长旒（用户要求不要星条旗）；
- 甲板属具：双舱口格栅、绞盘、起锚机、舵轮、罗经柜、锚、钟、木桶、盘绳。

约定
----
- 几何函数是纯 Python（不 import bpy），可用 dryrun_schooner_fame.py 离线校验。
- 公共部件（甲板属具 / 艏斜桁 / 艏饰 / 艉廊 / Blender 装配层）在
  tools/modeling/generators/ship_parts/；本文件只保留船型参数与船型强相关几何
  （hull/deck/bulwark/wales/keel/channels/桅帆/索具/锚架）。
- Blender 侧只做集合 / 材质 / 空物体层级 / 父级 / 文字铭牌；装配走
  ship_parts.assembly.build_collection()。
- 桅杆 Pivot：前桅 / 主桅；桅杆、斜桁、帆等局部坐标，绕 Y 轴旋转后倾。
- 其它对象（船体、索具、甲板件、长旒）用世界坐标，父级为根空物体。

用法
----
Blender 内：import runpy; runpy.run_path(<本文件>, run_name="__main__")
纯 Python 干跑：python tools/modeling/generators/dryrun_schooner_fame.py
"""

import math
import os
import sys


def _find_generator_dir():
    """定位 tools/modeling/generators（dryrun / Blender MCP / Text Editor 通用）。"""
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
    for d in candidates:
        if os.path.isdir(os.path.join(d, "ship_parts")):
            return d
    d = os.path.abspath(os.getcwd())
    for _ in range(6):
        cand = os.path.join(d, "tools", "modeling", "generators")
        if os.path.isdir(os.path.join(cand, "ship_parts")):
            return cand
        d = os.path.dirname(d)
    return None


_GEN_DIR = _find_generator_dir()
if _GEN_DIR and _GEN_DIR not in sys.path:
    sys.path.insert(0, _GEN_DIR)

from ship_parts.core import (  # noqa: E402
    Part, vadd, vsub, vmul, vcross, vlen, vnorm, lerp, lerp3,
    box, hexa, translate, rotate_y, merge, ring, taper_cyl, polyline_tube,
    frame_box, bar_between, ring_band, prism_xz, prism_xy, revolved, torus_x,
    torus_z, mirror_part, merge_parts,
)
from ship_parts.palette import (  # noqa: E402
    MAT_WOOD, MAT_WOOD_DARK, MAT_WOOD_DECK, MAT_CANVAS, MAT_CANVAS_SHADE,
    MAT_METAL, MAT_BRASS, MAT_FLAG_RED, MAT_FLAG_WHITE, MAT_FLAG_BLUE,
)
from ship_parts import deck as deck_kit, bow as bow_kit, stern as stern_kit, assembly  # noqa: E402

import rig_kit  # noqa: E402
from ship_parts import core as _rig_core  # noqa: E402

# ============================================================
# 参数区
# ============================================================

COLLECTION = "SN_Schooner_Fame_Prototype"
PREFIX = "SN_SF_"
ROOT_NAME = "SN_SF_Root"

# 工作台摆位（导出 GLB 时根节点临时归零，见 export_schooner_fame_glb.py）
WORKBENCH_POS = (0.0, -70.0, 0.0)

# 材质：名称 -> (线性 base color, roughness, metallic)
COLORS = {
    "SN_Hull_Black":  ((0.017, 0.015, 0.014), 0.55, 0.10),
    "SN_Ochre":       ((0.430, 0.230, 0.052), 0.62, 0.00),
    "SN_Canvas_Shade": ((0.400, 0.360, 0.285), 0.92, 0.00),
    "SN_Flag_Red":    ((0.310, 0.022, 0.018), 0.72, 0.00),
}
# 复用工作台既有材质（不存在时才按下面数值新建）
REUSE_COLORS = {
    "SN_Wood":      ((0.200, 0.088, 0.035), 0.70, 0.00),
    "SN_Wood_Dark": ((0.042, 0.019, 0.008), 0.64, 0.00),
    "SN_Wood_Deck": ((0.300, 0.165, 0.072), 0.76, 0.00),
    "SN_Canvas":    ((0.660, 0.620, 0.520), 0.92, 0.00),
    "SN_Metal":     ((0.140, 0.150, 0.170), 0.36, 0.90),
    "SN_Brass":     ((0.420, 0.270, 0.075), 0.28, 0.85),
    "SN_Flag_Blue": ((0.012, 0.035, 0.120), 0.75, 0.00),
    "SN_Flag_White": ((0.800, 0.800, 0.800), 0.70, 0.00),
}
# 公共材质名来自 ship_parts.palette；船体主色仍由本船定义
MAT_HULL = "SN_Hull_Black"
MAT_OCHRE = "SN_Ochre"
MAT_DECK = MAT_WOOD_DECK

# 横剖面站：(x, 半宽 w, 甲板高 dz, 龙骨底 kz)；x 升序（-12.0 艉 -> +12.4 艏）
# 船体 LOA 24.4 m，水线 z = 0，吃水约 2.5 m；艉板宽 4.7 m，艏柱收窄。
STATIONS = [
    (-12.00, 2.35, 3.00, -1.55),
    (-11.80, 2.62, 2.97, -1.80),
    (-11.30, 2.86, 2.92, -2.05),
    (-10.40, 3.02, 2.86, -2.25),
    (-9.20, 3.12, 2.80, -2.38),
    (-7.60, 3.16, 2.74, -2.45),
    (-5.60, 3.16, 2.68, -2.48),
    (-3.20, 3.10, 2.63, -2.50),
    (-0.60, 3.02, 2.59, -2.50),
    (1.80, 2.92, 2.57, -2.48),
    (4.20, 2.78, 2.57, -2.40),
    (6.40, 2.58, 2.60, -2.22),
    (8.20, 2.30, 2.66, -1.95),
    (9.60, 1.96, 2.74, -1.58),
    (10.80, 1.55, 2.84, -1.10),
    (11.60, 1.05, 2.96, -0.55),
    (12.10, 0.55, 3.10, 0.05),
    (12.40, 0.16, 3.24, 0.75),
]

# 横剖面轮廓：(相对半宽, 相对吃水深度)，从龙骨中心到甲板边缘
# 圆舭 + 最大宽度在约 62% 深度 + 轻微内倾（tumblehome）
PROFILE = [
    (0.000, 0.000), (0.360, 0.008), (0.600, 0.035), (0.780, 0.090),
    (0.900, 0.180), (0.970, 0.320), (1.000, 0.500), (1.000, 0.660),
    (0.985, 0.800), (0.940, 0.910), (0.860, 1.000),
]

DECK_W_FRAC = 0.860       # 甲板 / 舷墙所在的相对半宽（与 PROFILE 末端一致）
DECK_CAMBER = 0.095       # 甲板拱高
BULWARK_H = 0.78          # 舷墙高
BULWARK_OUT = 0.030       # 舷墙外偏移
BULWARK_IN = 0.075        # 舷墙内偏移
CAP_T = 0.070             # 舷墙压顶厚
OCHRE_BAND = 1.02         # 赭黄上舷带高度（自甲板边向下）
QD_H = 0.22               # 艉楼甲板抬高
QD_END = -7.40            # 艉楼前端 x

# 桅杆：x / 后倾角(deg，负=桅顶向艉) / 下桅高 / 顶桅高 / 上桅高（相对甲板）
MASTS = {
    "Fore": dict(x=4.60, rake=-2.5, lower=10.2, top=16.2, gallant=20.4,
                 r_lower=(0.340, 0.230), r_top=(0.205, 0.115), r_gal=(0.090, 0.038)),
    "Main": dict(x=-1.80, rake=-3.2, lower=10.8, top=17.0, gallant=21.3,
                 r_lower=(0.375, 0.245), r_top=(0.220, 0.122), r_gal=(0.095, 0.040)),
}

# 艏斜桁 / 艏三角帆
BOWSPRIT = dict(root=(12.20, 0.0, 3.20), tip=(18.20, 0.0, 6.35),
                r0=0.240, r1=0.135)
JIBBOOM = dict(root=(17.05, 0.0, 5.85), tip=(20.60, 0.0, 7.55),
               r0=0.130, r1=0.055)

# 红白长旒（星条旗已按用户要求移除；build_flag_world 保留但不装配）
FLAG = dict(hoist_z=17.0, height=2.05, fly=3.70, y=0.52, wave=0.26)
PENNANT = dict(z=21.20, length=5.60, height=0.34, y=-0.10, wave=0.30)

# 甲板属具位置
HATCH_FORE = dict(x=6.80, z=0.0, sx=1.90, sy=1.60)
HATCH_MAIN = dict(x=0.10, z=0.0, sx=2.30, sy=2.00)
SKYLIGHT = dict(x=-4.90, z=0.0, sx=1.70, sy=1.20)
CAPSTAN = dict(x=2.60, z=0.0, r=0.42, h=0.78)
WINDLASS = dict(x=8.90, z=0.0, width=2.30)
WHEEL = dict(x=-9.60, z=0.0, R=0.62, r=0.055)
BINNACLE = dict(x=-8.55, z=0.0)
BELL = dict(x=3.20, z=0.0)


# ============================================================
# 站 / 剖面查询
# ============================================================

def interp_station(x):
    xs = [s[0] for s in STATIONS]
    if x <= xs[0]:
        return STATIONS[0][1:]
    if x >= xs[-1]:
        return STATIONS[-1][1:]
    for i in range(len(xs) - 1):
        if xs[i] <= x <= xs[i + 1]:
            t = (x - xs[i]) / (xs[i + 1] - xs[i])
            return tuple(STATIONS[i][k] + t * (STATIONS[i + 1][k] - STATIONS[i][k])
                         for k in (1, 2, 3))
    return STATIONS[-1][1:]


def deck_z_at(x):
    return interp_station(x)[1]


def half_beam_at(x):
    return interp_station(x)[0]


def deck_surface_z(x):
    return deck_z_at(x) + 0.02


def stations_in(x0, x1):
    out = [x0]
    for st in STATIONS:
        if x0 + 1e-6 < st[0] < x1 - 1e-6:
            out.append(st[0])
    out.append(x1)
    return sorted(set(out))


def hull_profile_fraction(x, z):
    """给定 x 与高度 z，返回所在剖面轮廓的（相对半宽, 相对深度）。"""
    w, dz, kz = interp_station(x)
    if dz - kz < 1e-6:
        return DECK_W_FRAC, 1.0
    fz = (z - kz) / (dz - kz)
    fz = max(0.0, min(1.0, fz))
    for i in range(len(PROFILE) - 1):
        fy0, fz0 = PROFILE[i]
        fy1, fz1 = PROFILE[i + 1]
        if fz0 <= fz <= fz1:
            t = (fz - fz0) / (fz1 - fz0) if fz1 - fz0 > 1e-9 else 0.0
            return fy0 + t * (fy1 - fy0), fz
    return PROFILE[-1][0], fz


def hull_y_at(x, z):
    """船体舷侧表面在世界坐标 y 上的半宽（> 0）。"""
    fy, _fz = hull_profile_fraction(x, z)
    return fy * half_beam_at(x)


def hull_surface_point(x, z, side=1):
    """船体舷侧点 + 水平外法线（用于腰板 / 通道 / 舷窗）。"""
    y = hull_y_at(x, z)
    y0 = hull_y_at(x, z + 0.02)
    y1 = hull_y_at(x, z - 0.02)
    n = vnorm((0.0, side, (y0 - y1) / 0.04 if abs(y0 - y1) > 1e-9 else 0.0))
    return (x, side * y, z), n


def deck_loop_points(xs):
    """甲板边缘闭合环：左舷 x0->x1，再右舷 x1->x0，并带甲板拱高。"""
    loop = []
    for x in xs:
        loop.append((x, DECK_W_FRAC * half_beam_at(x),
                     deck_surface_z(x) + DECK_CAMBER))
    for x in reversed(xs):
        loop.append((x, -DECK_W_FRAC * half_beam_at(x),
                     deck_surface_z(x) + DECK_CAMBER))
    return loop


def loop_normals(loop):
    n = len(loop)
    cx = sum(p[0] for p in loop) / n
    cy = sum(p[1] for p in loop) / n
    out = []
    for k in range(n):
        tx = loop[(k + 1) % n][0] - loop[k - 1][0]
        ty = loop[(k + 1) % n][1] - loop[k - 1][1]
        nx, ny = -ty, tx
        L = math.hypot(nx, ny) or 1.0
        nx, ny = nx / L, ny / L
        if nx * (loop[k][0] - cx) + ny * (loop[k][1] - cy) < 0:
            nx, ny = -nx, -ny
        out.append((nx, ny))
    return out


def band_loop(loop, normals, height, out_off, in_off, material, z0=None):
    """沿闭合环生成带状闭合体；z0=None 时以每点的 z 为底。"""
    verts = []
    for (x, y, z), (nx, ny) in zip(loop, normals):
        zb = z if z0 is None else z0
        zt = zb + height
        verts.extend([
            (x + nx * out_off, y + ny * out_off, zb),
            (x + nx * out_off, y + ny * out_off, zt),
            (x + nx * in_off, y + ny * in_off, zb),
            (x + nx * in_off, y + ny * in_off, zt),
        ])
    n = len(loop)
    faces = []
    for k in range(n):
        k2 = (k + 1) % n
        a, b = k * 4, k2 * 4
        faces.append((a, b, b + 1, a + 1))          # 外侧
        faces.append((a + 3, a + 2, b + 2, b + 3))  # 内侧
        faces.append((a + 1, b + 1, b + 3, a + 3))  # 顶面
        faces.append((a, a + 2, b + 2, b))          # 底面
    part = Part()
    part.add((verts, faces), material)
    return part


def railing_run(p0, p1, z, height=0.85, spacing=1.45, material=MAT_METAL,
                post=0.045, rails=True):
    """两点之间的直线栏杆：立柱 + 两道通长横杆。"""
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]
    L = math.hypot(dx, dy)
    part = Part()
    if L < 1e-6:
        return part
    u = (dx / L, dy / L, 0.0)
    v = (-u[1], u[0], 0.0)
    n = max(1, int(round(L / spacing)))
    for i in range(n + 1):
        t = i / n
        c = (p0[0] + dx * t, p0[1] + dy * t, z + height * 0.5)
        part.add(frame_box(c, u, v, (0.0, 0.0, 1.0), post, post, height * 0.5),
                 material)
    if rails:
        for hz in (height * 0.52, height * 0.98):
            c = ((p0[0] + p1[0]) * 0.5, (p0[1] + p1[1]) * 0.5, z + hz)
            part.add(frame_box(c, u, v, (0.0, 0.0, 1.0), L * 0.5, 0.021,
                               0.021), material)
    return part


# ============================================================
# 船体 / 甲板 / 舷墙 / 龙骨 / 艏柱 / 舵 / 艉廊
# ============================================================

def _hull_material_at(x, z):
    """黑船身 + 赭黄上舷带：分界跟随甲板边线（即跟随舷弧）。"""
    return MAT_OCHRE if z >= deck_z_at(x) - OCHRE_BAND else MAT_HULL


def build_hull():
    """闭合船体：18 个横剖面站放样；黑船身 + 赭黄上舷带。"""
    part = Part()
    rings = []
    for x, w, dz, kz in STATIONS:
        pts = [(x, fy * w, kz + fz * (dz - kz)) for (fy, fz) in PROFILE]
        # 镜像必须包含甲板边缘点（pts[1:]），否则右舷会少一层列板
        rings.append(pts + [(x, -y, z) for (x, y, z) in reversed(pts[1:])])
    nr = len(rings[0])
    verts, idx = [], []
    for ring_pts in rings:
        idx.append(len(verts))
        verts.extend(ring_pts)
    faces = []
    for i in range(len(rings) - 1):
        a, b = idx[i], idx[i + 1]
        for j in range(nr):
            j2 = (j + 1) % nr
            faces.append((a + j, a + j2, b + j2, b + j))
    # 艏 / 艉封板：以环心做三角扇，避免共线点造成退化三角形
    for ring_index, flip in ((idx[0], True), (idx[-1], False)):
        cx = sum(verts[ring_index + k][0] for k in range(nr)) / nr
        cy = sum(verts[ring_index + k][1] for k in range(nr)) / nr
        cz = sum(verts[ring_index + k][2] for k in range(nr)) / nr
        center = len(verts)
        verts.append((cx, cy, cz))
        for j in range(nr):
            j2 = (j + 1) % nr
            if flip:
                faces.append((center, ring_index + j2, ring_index + j))
            else:
                faces.append((center, ring_index + j, ring_index + j2))
    part.verts = verts
    for f in faces:
        cx = sum(verts[i][0] for i in f) / len(f)
        cz = sum(verts[i][2] for i in f) / len(f)
        part.faces.append((f, _hull_material_at(cx, cz)))
    return part


def build_wales():
    """黑/赭分界处的黑色腰板 + 上缘一道细黑压条（贴合船体曲面）。"""
    xs = stations_in(-11.85, 12.05)
    part = Part()
    for side in (1, -1):
        for z_off, h, out in ((-OCHRE_BAND, 0.105, 0.040),
                              (0.00, 0.055, 0.030)):
            verts = []
            for x in xs:
                zc = deck_z_at(x) + z_off
                yo = hull_y_at(x, zc) + out
                yi = yo - 0.050
                verts.extend([(x, side * yo, zc - h * 0.5),
                              (x, side * yo, zc + h * 0.5),
                              (x, side * yi, zc + h * 0.5),
                              (x, side * yi, zc - h * 0.5)])
            faces = []
            n = len(xs)
            for i in range(n - 1):
                a, b = i * 4, (i + 1) * 4
                faces.append((a, b, b + 1, a + 1))
                faces.append((a + 1, b + 1, b + 2, a + 2))
                faces.append((a + 2, b + 2, b + 3, a + 3))
                faces.append((a + 3, b + 3, b, a))
            faces.append((0, 1, 2, 3))
            a = (n - 1) * 4
            faces.append((a, a + 1, a + 2, a + 3))
            part.add((verts, faces), MAT_HULL)
    return part


def build_deck():
    """主甲板：沿站生成带拱度的木甲板，横向 12 条板材交替深浅。"""
    xs = stations_in(-11.95, 12.30)
    ny = 12
    verts = []
    for x in xs:
        wd = DECK_W_FRAC * half_beam_at(x)
        z0 = deck_surface_z(x)
        for k in range(ny + 1):
            t = -1.0 + 2.0 * k / ny
            verts.append((x, t * wd, z0 + DECK_CAMBER * (1.0 - t * t)))
    part = Part()
    part.verts = verts
    for i in range(len(xs) - 1):
        for k in range(ny):
            a = i * (ny + 1) + k
            b = (i + 1) * (ny + 1) + k
            mat = MAT_DECK if k % 2 == 0 else MAT_WOOD
            part.faces.append(((a, b, b + 1, a + 1), mat))
    part.recalc = False
    return part


def build_quarterdeck():
    """艉楼甲板（抬高 0.22 m）+ 前挡板 + 两级台阶。"""
    xs = stations_in(-11.95, QD_END)
    ny = 10
    verts = []
    for x in xs:
        wd = DECK_W_FRAC * half_beam_at(x)
        z0 = deck_surface_z(x) + QD_H
        for k in range(ny + 1):
            t = -1.0 + 2.0 * k / ny
            verts.append((x, t * wd, z0 + DECK_CAMBER * 0.85 * (1.0 - t * t)))
    part = Part()
    part.verts = verts
    for i in range(len(xs) - 1):
        for k in range(ny):
            a = i * (ny + 1) + k
            b = (i + 1) * (ny + 1) + k
            mat = MAT_DECK if k % 2 == 0 else MAT_WOOD
            part.faces.append(((a, b, b + 1, a + 1), mat))
    part.recalc = False
    # 前挡板
    wd = DECK_W_FRAC * half_beam_at(QD_END)
    z0 = deck_surface_z(QD_END)
    part.add(box((QD_END - 0.09, -wd, z0 - 0.02),
                 (QD_END + 0.09, wd, z0 + QD_H + 0.02)), MAT_WOOD_DARK)
    # 台阶
    for i in range(2):
        part.add(box((QD_END + 0.10 + i * 0.34, -0.85, z0 - 0.02),
                     (QD_END + 0.42 + i * 0.34, 0.85,
                      z0 + QD_H * (1.0 - i * 0.5))), MAT_WOOD)
    return part


def build_bulwark():
    """赭黄舷墙 + 黑色压顶（沿甲板边缘闭合环）。"""
    xs = stations_in(-11.98, 12.38)
    loop = deck_loop_points(xs)
    normals = loop_normals(loop)
    part = Part()
    part.merge(band_loop(loop, normals, BULWARK_H, BULWARK_OUT, -BULWARK_IN,
                         MAT_OCHRE))
    cap = band_loop(loop, normals, CAP_T, BULWARK_OUT + 0.025,
                    -BULWARK_IN - 0.015, MAT_HULL)
    for i, v in enumerate(cap.verts):
        v = list(v)
        v[2] += BULWARK_H - 0.012
        cap.verts[i] = tuple(v)
    part.merge(cap)
    return part


FIGUREHEAD_CFG = dict(
    scroll_root=(12.42, 0.0, 3.18), scroll_tip=(13.10, 0.0, 3.42),
    scroll_tip2=(13.02, 0.0, 3.40), scroll_end=(13.30, 0.0, 3.30),
    bust_lo=(12.58, -0.15, 2.86), bust_hi=(12.94, 0.15, 3.12),
    head_center=(12.80, 0.0, 3.10),
    eye_x=(12.92, 12.95), eye_z=(3.17, 3.21), eye_ys=(-0.055, 0.055),
    ochre_mat=MAT_OCHRE, hull_mat=MAT_HULL,
)


def build_figurehead():
    """艏柱顶的雕刻艏饰：黄铜卷饰 + 赭黄胸像 + 深色眼点（部件库 bow.figurehead）。"""
    part = Part()
    bow_kit.figurehead(part, FIGUREHEAD_CFG, brass_mat=MAT_BRASS)
    return part


def build_ladders():
    """两舷上艉楼的短梯：斜梁 + 4 道横档（部件库 deck.ladder）。"""
    part = Part()
    z0 = deck_surface_z(QD_END + 0.95) + DECK_CAMBER * 0.85
    z1 = deck_surface_z(QD_END) + QD_H + DECK_CAMBER * 0.85
    for side in (1, -1):
        p0 = (QD_END + 0.95, side * 1.42, z0)
        p1 = (QD_END + 0.06, side * 1.42, z1)
        deck_kit.ladder(part, p0, p1, 1.42)
    return part


def build_keel_stem_rudder():
    """龙骨 / 艏柱 / 艉柱 / 舵 / 舵铁 / 舵柄。"""
    part = Part()
    # 龙骨
    part.add(box((-11.90, -0.13, -2.74), (11.80, 0.13, -2.46)), MAT_HULL)
    # 艏柱（弧形 XZ 截面）
    stem_poly = [(11.45, -2.55), (12.10, -1.90), (12.50, 0.50), (12.58, 3.15),
                 (12.38, 3.15), (12.30, 0.50), (11.92, -1.90), (11.75, -2.55)]
    part.add(prism_xz(stem_poly, -0.10, 0.10), MAT_HULL)
    # 艉柱（上段收进艉廊内，避免与中央艉窗玻璃共面形成竖条）
    part.add(box((-12.32, -0.11, -2.62), (-12.05, 0.11, 2.95)), MAT_HULL)
    part.add(box((-12.46, -0.10, -2.62), (-12.32, 0.10, 1.95)), MAT_HULL)
    # 舵
    part.add(box((-12.78, -0.09, -2.38), (-12.45, 0.09, 2.28)), MAT_HULL)
    part.add(box((-12.82, -0.06, -2.10), (-12.74, 0.06, 2.10)), MAT_HULL)
    # 舵铁
    for zc in (-1.55, -0.10, 1.45):
        part.add(box((-12.70, -0.145, zc - 0.06), (-12.48, 0.145, zc + 0.06)),
                 MAT_METAL)
    # 舵头 / 舵柄（艉楼甲板；舵头完全收进艉廊内，避免与艉板共面）
    part.add(box((-12.30, -0.07, 2.28), (-12.06, 0.07, 2.86)), MAT_METAL)
    part.add(box((-12.28, -0.60, 2.68), (-11.55, 0.60, 2.82)), MAT_WOOD_DARK)
    return part


def build_stern_gallery():
    """艉部弧形艉廊 + 3 扇艉窗 + 黑色檐口 + 双灯（部件库 stern.stern_gallery）。"""
    part = Part()
    stern_kit.stern_gallery(part, -12.00, -12.34, MAT_OCHRE, MAT_HULL)
    return part


def build_bowsprit():
    """艏斜桁 + 艏斜桁延伸杆 + 系固铁箍（部件库 bow.bowsprit）。"""
    part = Part()
    bow_kit.bowsprit(part, BOWSPRIT, JIBBOOM, wood_mat=MAT_WOOD,
                     metal_mat=MAT_METAL)
    return part


def build_bow_fittings():
    """艏部：锚架 / 猫头梁 / 锚 / 锚链 / 系缆桩。"""
    part = Part()
    for side in (1, -1):
        # 猫头梁
        part.add(box((10.50, side * 1.70, 2.78), (11.35, side * 2.42, 2.94)),
                 MAT_WOOD_DARK)
        part.add(box((10.55, side * 2.34, 2.76), (10.78, side * 2.56, 2.98)),
                 MAT_METAL)
        # 锚（收起贴舷）
        ax = 10.85
        part.add(box((ax, side * 2.22, 1.55), (ax + 0.11, side * 2.46, 2.86)),
                 MAT_METAL)
        part.add(box((ax - 0.55, side * 2.28, 2.25), (ax + 0.55, side * 2.40, 2.38)),
                 MAT_METAL)
        for sgn in (-1, 1):
            part.add(box((ax + sgn * 0.38, side * 2.20, 1.76),
                         (ax + sgn * 0.56, side * 2.48, 2.28)), MAT_METAL)
            part.add(box((ax + sgn * 0.30, side * 2.18, 1.48),
                         (ax + sgn * 0.56, side * 2.50, 1.78)), MAT_METAL)
        # 锚链（几段短链）
        for i in range(5):
            xx = 10.55 - i * 0.20
            zz = 2.92 - i * 0.16
            part.add(box((xx, side * 2.16, zz), (xx + 0.13, side * 2.28, zz + 0.18)),
                     MAT_METAL)
        # 系缆桩
        part.add(taper_cyl((10.10, side * 1.42, 2.72), (10.10, side * 1.42, 3.06),
                           0.075, 0.075, 8), MAT_WOOD_DARK)
        part.add(taper_cyl((10.10, side * 1.42, 3.02), (10.10, side * 1.42, 3.10),
                           0.13, 0.10, 8), MAT_WOOD_DARK)
    return part


def build_channels():
    """桅杆两侧的侧支索平台（channels）+ 铁链板。"""
    part = Part()
    for key, cfg in MASTS.items():
        x0 = cfg["x"]
        zc = deck_z_at(x0 + 0.4)
        for side in (1, -1):
            y = DECK_W_FRAC * half_beam_at(x0) + 0.28
            part.add(box((x0 - 1.30, side * (y - 0.22), zc - 0.10),
                         (x0 + 1.30, side * (y + 0.06), zc + 0.02)),
                     MAT_WOOD_DARK)
            for i in range(4):
                xx = x0 - 1.10 + i * 0.72
                yy = hull_y_at(xx, zc - 0.45) + 0.02
                part.add(box((xx - 0.035, side * yy, zc - 0.62),
                             (xx + 0.035, side * (y + 0.02), zc - 0.02)),
                         MAT_METAL)
    return part


# ============================================================
# 桅杆 / 帆 / 索具（世界坐标辅助）
# ============================================================

FORE_X = MASTS["Fore"]["x"]
MAIN_X = MASTS["Main"]["x"]
FORE_DECK_Z = deck_z_at(FORE_X)
MAIN_DECK_Z = deck_z_at(MAIN_X)


def mast_pivot_world(key):
    cfg = MASTS[key]
    return (cfg["x"], 0.0, (FORE_DECK_Z if key == "Fore" else MAIN_DECK_Z))


def mast_world(key, z_local, y=0.0):
    """桅杆局部 z -> 世界坐标（含后倾角）。"""
    cfg = MASTS[key]
    px, _py, pz = mast_pivot_world(key)
    a = math.radians(cfg["rake"])
    return (px + z_local * math.sin(a), y, pz + z_local * math.cos(a))


def mast_to_world(key, p):
    """桅杆局部坐标 (x,y,z) -> 世界坐标（含后倾角）。"""
    cfg = MASTS[key]
    px, _py, pz = mast_pivot_world(key)
    a = math.radians(cfg["rake"])
    return (px + p[0] * math.cos(a) + p[2] * math.sin(a),
            p[1],
            pz - p[0] * math.sin(a) + p[2] * math.cos(a))


def build_masts_local():
    """两根桅杆（局部坐标，父级 Pivot 负责后倾）；几何来自 rig_kit.schooner_mast。"""
    parts = {}
    for key, cfg in MASTS.items():
        part = Part()
        b = rig_kit.builder(part, _rig_core)
        rig_kit.schooner_mast(b, cfg)
        parts[key] = part
    return parts


def build_mast_pennant_staff():
    """主桅顶的长旒挂杆（仅作局部结构，不再生成旗杆段对象）。"""
    part = Part()
    p = mast_world("Main", MASTS["Main"]["top"] + 1.0)
    q = mast_world("Main", MASTS["Main"]["top"] + 2.4)
    part.add(taper_cyl(p, q, 0.045, 0.025, 6), MAT_WOOD_DARK)
    return part


# ============================================================
# 帆面
# ============================================================

# ============================================================
# 桁 / 帆（桅杆局部坐标）
# ============================================================

FORE_SAIL = dict(tack=(0.0, 0.09, 1.55), throat=(0.0, 0.09, 8.55),
                 peak=(-5.15, 0.09, 11.35), clew=(-4.55, 0.09, 1.98))
MAIN_SAIL = dict(tack=(0.0, 0.10, 1.55), throat=(0.0, 0.10, 9.45),
                 peak=(-8.05, 0.10, 12.75), clew=(-8.90, 0.10, 2.12))
FORE_TOPSAIL = dict(x=0.58, z_head=14.85, z_foot=11.55,
                    half_head=3.10, half_foot=2.72, camber=0.72)
MAIN_TOPSAIL = dict(throat=(0.0, 0.10, 9.50), peak=(-8.05, 0.10, 12.75),
                    head=(0.0, 0.10, 17.00))


def build_spars_local():
    """桅杆局部坐标的斜桁 / 帆桁 / 方顶帆桁（几何来自 rig_kit.schooner_spars）。"""
    parts = {}
    fore_gaff = dict(
        throat=(FORE_SAIL["throat"][0], 0.0, FORE_SAIL["throat"][2]),
        peak=(FORE_SAIL["peak"][0], 0.0, FORE_SAIL["peak"][2]),
        r0=0.075, r1=0.052)
    fore_boom = dict(
        tack=(FORE_SAIL["tack"][0], 0.0, FORE_SAIL["tack"][2]),
        clew=(FORE_SAIL["clew"][0], 0.0, FORE_SAIL["clew"][2]),
        r0=0.090, r1=0.060)
    main_gaff = dict(
        throat=(MAIN_SAIL["throat"][0], 0.0, MAIN_SAIL["throat"][2]),
        peak=(MAIN_SAIL["peak"][0], 0.0, MAIN_SAIL["peak"][2]),
        r0=0.085, r1=0.058)
    main_boom = dict(
        tack=(MAIN_SAIL["tack"][0], 0.0, MAIN_SAIL["tack"][2]),
        clew=(MAIN_SAIL["clew"][0], 0.0, MAIN_SAIL["clew"][2]),
        r0=0.100, r1=0.065)
    specs = {
        "Fore": dict(gaff=fore_gaff, boom=fore_boom,
                     jaws_z=(FORE_SAIL["tack"][2], FORE_SAIL["throat"][2]),
                     peak_band=0.060, clew_band=0.070, topsail=FORE_TOPSAIL,
                     jaws=(0.22, 0.24, 0.10), band_dx=(0.14, 0.02)),
        "Main": dict(gaff=main_gaff, boom=main_boom,
                     jaws_z=(MAIN_SAIL["tack"][2], MAIN_SAIL["throat"][2]),
                     peak_band=0.066, clew_band=0.075, topsail=None,
                     jaws=(0.24, 0.25, 0.11), band_dx=(0.15, 0.02)),
    }
    for key, spec in specs.items():
        part = Part()
        b = rig_kit.builder(part, _rig_core)
        rig_kit.schooner_spars(b, spec["gaff"], spec["boom"], spec["jaws_z"],
                               spec["peak_band"], spec["clew_band"],
                               topsail=spec["topsail"], jaws=spec["jaws"],
                               band_dx=spec["band_dx"])
        parts[key] = part
    return parts


def build_sails_local():
    """桅杆局部坐标的帆（几何来自 rig_kit 的 gaff_sail / square_sail / tri_sail）。"""
    parts = {}
    # 前桅斜桁帆 + 方顶帆
    part = Part()
    b = rig_kit.builder(part, _rig_core)
    rig_kit.gaff_sail(b, FORE_SAIL["tack"], FORE_SAIL["throat"],
                      FORE_SAIL["peak"], FORE_SAIL["clew"], 0.60, 0.42)
    ts = FORE_TOPSAIL
    rig_kit.square_sail(b, ts["x"], ts["z_head"], ts["z_foot"],
                        ts["half_head"], ts["half_foot"], ts["camber"])
    parts["Fore"] = part
    # 主桅大斜桁帆 + 三角顶帆
    part = Part()
    b = rig_kit.builder(part, _rig_core)
    rig_kit.gaff_sail(b, MAIN_SAIL["tack"], MAIN_SAIL["throat"],
                      MAIN_SAIL["peak"], MAIN_SAIL["clew"], 0.76, 0.48)
    mt = MAIN_TOPSAIL
    rig_kit.tri_sail(b, mt["head"], mt["throat"], mt["peak"], 0.50, 0.26)
    parts["Main"] = part
    return parts


def build_headsails_world():
    """艏三角帆：大 jib（艏斜桁延伸杆 -> 前桅顶）+ fore staysail（rig_kit）。"""
    part = Part()
    b = rig_kit.builder(part, _rig_core)
    rig_kit.schooner_headsails(b, {
        "mast_world": mast_world,
        "fore_top": MASTS["Fore"]["top"],
        "fore_lower": MASTS["Fore"]["lower"],
        "jibboom_tip": JIBBOOM["tip"],
    })
    return part


# ============================================================
# 索具（世界坐标）
# ============================================================

def build_standing_rigging_world():
    """帆船静索（几何来自 rig_kit.schooner_standing_rigging）。"""
    part = Part()
    b = rig_kit.builder(part, _rig_core)
    rig_kit.schooner_standing_rigging(b, {
        "masts": MASTS,
        "mast_world": mast_world,
        "deck_z_at": deck_z_at,
        "half_beam_at": half_beam_at,
        "deck_w_frac": DECK_W_FRAC,
        "jibboom_tip": JIBBOOM["tip"],
        "bowsprit_tip": BOWSPRIT["tip"],
        "fore_x": FORE_X,
        "fore_deck_z": FORE_DECK_Z,
    })
    return part


def build_running_rigging_world():
    """帆船动索（几何来自 rig_kit.schooner_running_rigging）。"""
    part = Part()
    b = rig_kit.builder(part, _rig_core)
    rig_kit.schooner_running_rigging(b, {
        "masts": MASTS,
        "mast_world": mast_world,
        "mast_to_world": mast_to_world,
        "deck_surface_z": deck_surface_z,
        "sails": {"Fore": FORE_SAIL, "Main": MAIN_SAIL},
        "topsails": {"Fore": FORE_TOPSAIL, "Main": MAIN_TOPSAIL},
        "fore_x": FORE_X,
        "main_x": MAIN_X,
    })
    return part


# ============================================================
# 甲板属具
# ============================================================

def _hatch(part, d):
    x, sx, sy = d["x"], d["sx"], d["sy"]
    z = deck_surface_z(x) + DECK_CAMBER * 0.85
    # 暗色舱口内衬
    part.add(box((x - sx * 0.5, -sy * 0.5, z - 0.30),
                 (x + sx * 0.5, sy * 0.5, z - 0.26)), MAT_HULL)
    # 围板
    t = 0.11
    part.add(box((x - sx * 0.5 - t, -sy * 0.5 - t, z),
                 (x - sx * 0.5, sy * 0.5 + t, z + 0.17)), MAT_WOOD_DARK)
    part.add(box((x + sx * 0.5, -sy * 0.5 - t, z),
                 (x + sx * 0.5 + t, sy * 0.5 + t, z + 0.17)), MAT_WOOD_DARK)
    part.add(box((x - sx * 0.5, -sy * 0.5 - t, z),
                 (x + sx * 0.5, -sy * 0.5, z + 0.17)), MAT_WOOD_DARK)
    part.add(box((x - sx * 0.5, sy * 0.5, z),
                 (x + sx * 0.5, sy * 0.5 + t, z + 0.17)), MAT_WOOD_DARK)
    # 格栅
    for i in range(5):
        xx = x - sx * 0.5 + 0.16 + (sx - 0.32) * i / 4.0
        part.add(box((xx - 0.028, -sy * 0.5 + 0.04, z + 0.06),
                     (xx + 0.028, sy * 0.5 - 0.04, z + 0.13)), MAT_WOOD)
    for j in range(3):
        yy = -sy * 0.5 + 0.18 + (sy - 0.36) * j / 2.0
        part.add(box((x - sx * 0.5 + 0.04, yy - 0.028, z + 0.13),
                     (x + sx * 0.5 - 0.04, yy + 0.028, z + 0.19)), MAT_WOOD)


def build_hatches():
    part = Part()
    for d in (HATCH_FORE, HATCH_MAIN):
        deck_kit.hatch(part, d["x"], d["sx"], d["sy"],
                       deck_surface_z(d["x"]) + DECK_CAMBER * 0.85, MAT_HULL)
    return part


def build_skylight():
    part = Part()
    x = SKYLIGHT["x"]
    z = deck_surface_z(x) + DECK_CAMBER * 0.85
    deck_kit.skylight(part, x, z, glass_mat=MAT_FLAG_BLUE)
    return part


def build_capstan_windlass():
    part = Part()
    x = CAPSTAN["x"]
    z = deck_surface_z(x) + DECK_CAMBER * 0.85
    deck_kit.capstan(part, x, z)
    xw = WINDLASS["x"]
    zw = deck_surface_z(xw) + DECK_CAMBER * 0.85
    deck_kit.windlass(part, xw, zw)
    return part


def build_wheel_binnacle():
    part = Part()
    x = WHEEL["x"]
    z = deck_surface_z(x) + QD_H
    deck_kit.wheel(part, x, z, WHEEL["R"], WHEEL["r"])
    xb = BINNACLE["x"]
    zb = deck_surface_z(xb) + QD_H
    deck_kit.binnacle(part, xb, zb)
    return part


def build_fife_rails():
    """桅脚前的缆桩栏（fife rail）+ 系索桩（部件库 deck.fife_rail）。"""
    part = Part()
    for key in ("Fore", "Main"):
        x = MASTS[key]["x"] - 0.95
        z = deck_surface_z(x) + DECK_CAMBER * 0.85
        deck_kit.fife_rail(part, x, z)
    return part


def build_deck_details():
    part = Part()
    x = BELL["x"]
    z = deck_surface_z(x) + DECK_CAMBER * 0.85
    deck_kit.bell(part, x, z)
    for bx, by in ((-5.85, 1.55), (1.45, -1.72)):
        bz = deck_surface_z(bx) + DECK_CAMBER * 0.85
        deck_kit.barrel(part, bx, by, bz)
    for cx, cy in ((-3.55, -1.95), (6.35, 1.92)):
        cz = deck_surface_z(cx) + DECK_CAMBER * 0.7
        deck_kit.rope_coil(part, cx, cy, cz)
    for bx, by in ((8.55, 1.42), (8.55, -1.42), (-6.95, 1.62), (-6.95, -1.62)):
        bz = deck_surface_z(bx) + DECK_CAMBER * 0.85
        deck_kit.bollard(part, bx, by, bz)
    for bx, by in ((5.30, -1.65), (5.30, 1.65)):
        bz = deck_surface_z(bx) + DECK_CAMBER * 0.85
        deck_kit.bucket(part, bx, by, bz)
    return part


# ============================================================
# 旗帜 / 长旒
# ============================================================

def build_flag_world():
    part = Part()
    m = mast_world("Main", FLAG["hoist_z"])
    x0, y0, z0 = m[0], m[1] + FLAG["y"], m[2]
    fly, height = FLAG["fly"], FLAG["height"]
    nu, nv = 12, 15

    def surface(u, v):
        x = x0 - u * fly
        z = z0 - v * height - 0.12 * u * math.sin(math.pi * v)
        y = y0 + FLAG["wave"] * math.sin(u * 5.2 + v * 1.4) * (0.30 + 0.70 * u)
        return (x, y, z)

    verts = []
    for j in range(nv + 1):
        v = j / float(nv)
        for i in range(nu + 1):
            verts.append(surface(i / float(nu), v))
    for j in range(nv):
        for i in range(nu):
            a = j * (nu + 1) + i
            b = a + nu + 1
            u = (i + 0.5) / nu
            v = (j + 0.5) / nv
            if u < 0.40 and v < 0.47:
                mat = MAT_FLAG_BLUE
            else:
                mat = MAT_FLAG_RED if j % 2 == 0 else MAT_FLAG_WHITE
            part.faces.append(((a, b, b + 1, a + 1), mat))
    part.verts = verts
    part.recalc = False
    # 15 颗星（5 × 3 的小菱形）
    star_v = []
    for j in range(3):
        for i in range(5):
            cu = 0.045 + 0.078 * i
            cv = 0.085 + 0.135 * j
            du, dv = 0.020, 0.036
            p0 = surface(cu - du, cv)
            p1 = surface(cu, cv - dv)
            p2 = surface(cu + du, cv)
            p3 = surface(cu, cv + dv)
            base = len(part.verts) + len(star_v)
            for p in (p0, p1, p2, p3):
                star_v.append((p[0], p[1] - 0.008, p[2]))
            part.faces.append(((base, base + 1, base + 2), MAT_FLAG_WHITE))
            part.faces.append(((base, base + 2, base + 3), MAT_FLAG_WHITE))
    part.verts.extend(star_v)
    # 旗索
    part.add(taper_cyl(surface(0.0, 0.0), surface(0.0, 1.0), 0.016, 0.016, 4),
             MAT_WOOD_DARK)
    return part


def build_pennant_world():
    part = Part()
    m = mast_world("Main", PENNANT["z"])
    x0, y0, z0 = m[0], m[1] + PENNANT["y"], m[2]
    length = PENNANT["length"]
    height = PENNANT["height"]
    nu, nv = 12, 2

    def surface(u, v):
        h = height * (1.0 - 0.86 * u)
        x = x0 - u * length
        z = z0 - height * 0.5 - v * h
        y = y0 + PENNANT["wave"] * math.sin(u * 6.0 + v * 2.0) * (0.20 + 0.80 * u)
        return (x, y, z)

    verts = []
    for j in range(nv + 1):
        v = j / float(nv)
        for i in range(nu + 1):
            verts.append(surface(i / float(nu), v))
    part.verts = verts
    for j in range(nv):
        for i in range(nu):
            a = j * (nu + 1) + i
            b = a + nu + 1
            mat = MAT_FLAG_RED if j == 0 else MAT_FLAG_WHITE
            part.faces.append(((a, b, b + 1, a + 1), mat))
    part.recalc = False
    part.add(taper_cyl(surface(0.0, 0.0), surface(0.0, 1.0), 0.014, 0.014, 4),
             MAT_WOOD_DARK)
    return part


# ============================================================
# 装配
# ============================================================

NAME_PLATES = {
    "SN_SF_Nameplate": dict(
        text="FAME", size=0.30, base=(-12.40, 0.0, 2.84),
        matrix=((0, 0, -1), (-1, 0, 0), (0, 1, 0))),
}


def build_all_geometry():
    """返回 {对象名: (Part, 父级键)}；父级键 = ROOT / FORE / MAIN。"""
    parts = {}

    def add(name, part, parent="ROOT"):
        parts[name] = (part, parent)

    add("SN_SF_Hull", build_hull())
    add("SN_SF_Deck", build_deck())
    add("SN_SF_Quarterdeck", build_quarterdeck())
    add("SN_SF_Bulwark", build_bulwark())
    add("SN_SF_Wales", build_wales())
    add("SN_SF_Keel_Stem_Rudder", build_keel_stem_rudder())
    add("SN_SF_Figurehead", build_figurehead())
    add("SN_SF_Stern_Gallery", build_stern_gallery())
    add("SN_SF_Bowsprit", build_bowsprit())
    add("SN_SF_Bow_Fittings", build_bow_fittings())
    add("SN_SF_Channels", build_channels())

    masts = build_masts_local()
    add("SN_SF_Mast_Fore", masts["Fore"], "FORE")
    add("SN_SF_Mast_Main", masts["Main"], "MAIN")
    spars = build_spars_local()
    add("SN_SF_Spars_Fore", spars["Fore"], "FORE")
    add("SN_SF_Spars_Main", spars["Main"], "MAIN")
    sails = build_sails_local()
    # 港口样片机位在 Godot +Z 侧（= Blender -Y 右舷），帆腹朝右舷才能在游戏里看到
    # 饱满的凸面；因此帆 / 艏三角帆 / 动索统一镜像到 -Y 侧。
    add("SN_SF_Sails_Fore", mirror_part(sails["Fore"]), "FORE")
    add("SN_SF_Sails_Main", mirror_part(sails["Main"]), "MAIN")
    add("SN_SF_Headsails", mirror_part(build_headsails_world()))

    add("SN_SF_Rigging_Standing", build_standing_rigging_world())
    add("SN_SF_Rigging_Running", mirror_part(build_running_rigging_world()))
    # 星条旗已按用户要求移除；旗杆小段也不再需要

    add("SN_SF_Hatches", build_hatches())
    add("SN_SF_Skylight", build_skylight())
    add("SN_SF_Capstan_Windlass", build_capstan_windlass())
    add("SN_SF_Wheel_Binnacle", build_wheel_binnacle())
    add("SN_SF_Fife_Rails", build_fife_rails())
    add("SN_SF_Ladders", build_ladders())
    add("SN_SF_Deck_Details", build_deck_details())
    add("SN_SF_Pennant", build_pennant_world())
    # 用户要求不要星条旗：不再生成 SN_SF_Flag（build_flag_world 保留但未装配）
    return parts


# ============================================================
# Blender 侧：交给 ship_parts.assembly
# ============================================================

def build_config(origin=WORKBENCH_POS):
    """把本船的集合/摆位/材质/Pivot/铭牌收敛成一份 BuildConfig。"""
    from ship_parts.assembly import BuildConfig, PivotSpec
    return BuildConfig(
        collection=COLLECTION,
        prefix=PREFIX,
        root_name=ROOT_NAME,
        workbench_pos=origin,
        material_colors=COLORS,
        material_reuse=REUSE_COLORS,
        root_props={
            "asset": "SN_Schooner_Fame",
            "version": "1.0",
            "units": "metres",
            "pivot": "waterline, centre of hull",
            "forward_axis": "+X",
            "style": "low-poly flat-shaded 1795 Salem two-masted schooner",
            "tri_budget": 18000,
        },
        pivots=[
            PivotSpec("FORE", PREFIX + "Mast_Fore_Pivot",
                      mast_pivot_world("Fore"),
                      (0.0, math.radians(MASTS["Fore"]["rake"]), 0.0), 1.2),
            PivotSpec("MAIN", PREFIX + "Mast_Main_Pivot",
                      mast_pivot_world("Main"),
                      (0.0, math.radians(MASTS["Main"]["rake"]), 0.0), 1.2),
        ],
        origins={"ROOT": (0.0, 0.0, 0.0),
                 "FORE": (0.0, 0.0, 0.0),
                 "MAIN": (0.0, 0.0, 0.0)},
        name_plates=NAME_PLATES,
        text_material=MAT_BRASS,
        report_title="SN_Schooner_Fame",
        tri_budget=18000,
        root_size=3.0,
    )


def build_all(origin=WORKBENCH_POS):
    """在 Blender 中重建整船（幂等）。origin = 根空物体的工作台摆位。"""
    return assembly.build_collection(build_all_geometry(), build_config(origin))


def report(verbose=True):
    """只读统计：对象 / 三角面 / 包围盒 / 材质 / 命名。"""
    return assembly.report(build_config(), verbose=verbose)
if __name__ == "__main__":
    build_all()




