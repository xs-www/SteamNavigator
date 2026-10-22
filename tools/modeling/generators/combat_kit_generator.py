# -*- coding: utf-8 -*-
# @static-doc
# 作用：`combat_kit` 敌舰套件（M2-1）的参数化生成器（纯 Python 几何 + Blender 装配入口）——
# 4 艘敌舰共用一套「船体骨架」放样/甲板/舷墙/龙骨/艏艉构件，按敌舰类型挂不同上层建筑、
# 桅帆 / 烟囱与武备安装点；几何复用现有船体的站表放样思路与 `rig_kit` / `ship_parts`
# 部件库，不维护第二套帆索几何。
#
# ## 资产（阶段 2 需要 3 类敌人；本批 4 艘 × 3 类，含 2 艘 Light）
# | 资产 | 敌人类别 | 轮廓 | 预算 | 武器 socket | 炮门 socket |
# | --- | --- | --- | ---: | ---: | ---: |
# | `SN_Enemy_Pirate_Sloop` | Light | 单桅纵帆、黑船身 + 锈红舷带、22.5 m | 5200 | 3 | 0 |
# | `SN_Enemy_Merchant_Armed` | Medium | 双桅横帆武装商船、34 m 宽体 + 艉楼 | 7200 | 6 | 0 |
# | `SN_Enemy_Ironclad_Raider` | Heavy | 低干舷铁甲舰变体、单烟囱 + 中央炮房、44 m | 7600 | 4 | 8 |
# | `SN_Enemy_Gunboat` | Light | 小型蒸汽炮艇、艏部装甲炮盾 + 单烟囱、16 m | 2600 | 3 | 0 |
#
# ## 复用边界（M2-1 工单）
# - 船体骨架：沿用现有船体的「横剖面站 + 剖面轮廓」放样（与 `SN_Schooner_Fame` /
#   `SN_Ironclad` 同一套数学），不新造船型语言；
# - 帆索：桅杆 / 斜桁 / 帆面 / 索具全部走 `rig_kit`（M0-4 部件库）；
# - 甲板属具：舱口 / 绞盘 / 舵轮 / 罗经柜 / 锚 / 木桶 / 系缆桩 / 短梯全部走
#   `ship_parts.deck`；艏斜桁 / 艏部分件走 `ship_parts.bow` / 自带实现；
# - 武备：**不烘炮**。甲板炮位按 `weapon-assembly@2`（`hull-sockets@1`）给空节点，
#   铁甲舰变体的舷侧炮门按 `hull-gunports@1` 给空节点，复用现成
#   `SN_Weapon_CasemateGun` 模块（M0-6）。
#
# ## 坐标 / 轴心 / 命名
# - 单位米，+X 船首、+Z 向上；根 = 水线中心（x=0 船中、z=0 水线），吃水为负 z；
# - `SN_<PFX>_` 对象前缀 + `SN_<PFX>_Root` 根空物体；BLEND 内 socket 名带资产前缀，
#   GLB 后处理归一化为 `SN_Socket_Weapon_*` / `SN_Socket_GunPort_*`；
# - 材质只用 10 张 `SN_Tex_*` 共享贴图；UV 由 `sn_shared_materials.apply_collection(space="root")` 写。
#
# ## 纯 Python 接口（供 dryrun / socket 脚本 / GLB 验收复用）
# - `SHIPS[asset]`：`hull` / `masts` / `builder` / `tri_budget` / `bbox` / `enemy_class`；
# - `WEAPON_SOCKETS[asset]`：甲板炮位规格（含实测期望 `deck_z`，由船体站表解析计算）；
# - `GUN_PORTS[asset]`：舷侧炮门规格（`gun_port_pose()` 从同一个船体站表推导）；
# - `build_all_geometry(asset)` / `build_config(asset)` / `build_all(asset)`。
#
# ## 用法
# - Blender 内：`import runpy; runpy.run_path(<本文件>, run_name="__main__")` 或
#   `import combat_kit_generator as ck; ck.build_all("SN_Enemy_Pirate_Sloop")`
# - 纯 Python 干跑：`python tools/modeling/generators/dryrun_combat_kit.py`
# @end-static-doc

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

from ship_parts.core import (  # noqa: E402
    Part, vadd, vsub, vmul, vcross, vlen, vnorm, lerp, lerp3,
    box, hexa, translate, rotate_y, merge, ring, taper_cyl, polyline_tube,
    frame_box, bar_between, ring_band, prism_xz, prism_xy, revolved,
    torus_x, torus_z, mirror_part, merge_parts,
)
from ship_parts import deck as deck_kit  # noqa: E402
from ship_parts import assembly  # noqa: E402
import rig_kit  # noqa: E402

# ============================================================
# 材质（新资产只用 SN_Tex_* 共享贴图）
# ============================================================

WOOD = "SN_Tex_Wood"
DARK = "SN_Tex_Wood_Dark"
DECK = "SN_Tex_Wood_Deck"
METAL = "SN_Tex_Metal"
BRASS = "SN_Tex_Brass"
IRON = "SN_Tex_Iron"
RED = "SN_Tex_Iron_Red"
CANVAS = "SN_Tex_Canvas_Shade"
GLASS = "SN_Tex_Glass_Dark"

ALLOWED_MATERIALS = {WOOD, DARK, DECK, METAL, BRASS, IRON, RED, CANVAS, GLASS}

# 只在材质不存在时的回退色（线性 RGB, roughness, metallic）；正常由
# `sn_shared_materials.build_materials()` 提供贴图材质。
MATERIAL_FALLBACK = {
    METAL: ((0.130, 0.140, 0.170), 0.36, 0.90),
    IRON: ((0.060, 0.065, 0.075), 0.52, 0.62),
    RED: ((0.150, 0.040, 0.025), 0.55, 0.50),
    WOOD: ((0.110, 0.050, 0.020), 0.70, 0.00),
    DARK: ((0.020, 0.010, 0.006), 0.64, 0.00),
    DECK: ((0.190, 0.100, 0.045), 0.76, 0.00),
    BRASS: ((0.420, 0.270, 0.075), 0.28, 0.85),
    CANVAS: ((0.360, 0.330, 0.270), 0.92, 0.00),
    GLASS: ((0.020, 0.030, 0.040), 0.20, 0.30),
}

SOCKET_SPEC = "hull-sockets@1"
GUN_PORT_SPEC = "hull-gunports@1"
COMBAT_KIT_SPEC = "enemy-ships@1"


# ============================================================
# 船体骨架：横剖面站 + 剖面轮廓（与现有船体同一套放样数学）
# ============================================================

class HullSpec(object):
    """船体骨架：`stations` = [(x, 半宽 w, 甲板高 dz, 龙骨底 kz)]（x 升序）。"""

    def __init__(self, stations, profile, deck_w_frac=0.86, deck_camber=0.09,
                 bulwark_h=0.72, bulwark_out=0.030, bulwark_in=0.075,
                 cap_t=0.070):
        self.stations = [tuple(float(v) for v in st) for st in stations]
        self.profile = [tuple(float(v) for v in p) for p in profile]
        self.deck_w_frac = float(deck_w_frac)
        self.deck_camber = float(deck_camber)
        self.bulwark_h = float(bulwark_h)
        self.bulwark_out = float(bulwark_out)
        self.bulwark_in = float(bulwark_in)
        self.cap_t = float(cap_t)
        xs = [st[0] for st in self.stations]
        if xs != sorted(xs) or len(set(xs)) != len(xs):
            raise ValueError("stations x 必须严格升序：%r" % (xs,))

    # ---- 站表查询（纯解析 / 线性插值）------------------------------------
    def interp(self, x):
        sts = self.stations
        if x <= sts[0][0]:
            return sts[0][1:]
        if x >= sts[-1][0]:
            return sts[-1][1:]
        for i in range(len(sts) - 1):
            if sts[i][0] <= x <= sts[i + 1][0]:
                t = (x - sts[i][0]) / (sts[i + 1][0] - sts[i][0])
                return tuple(sts[i][k] + t * (sts[i + 1][k] - sts[i][k])
                             for k in (1, 2, 3))
        return sts[-1][1:]

    def deck_z_at(self, x):
        return self.interp(x)[1]

    def half_beam_at(self, x):
        return self.interp(x)[0]

    def keel_z_at(self, x):
        return self.interp(x)[2]

    def deck_surface_z(self, x):
        return self.deck_z_at(x) + 0.02

    def deck_top(self, x, y):
        """甲板顶面（含拱度）在局部 (x, y) 的高度。"""
        wd = self.deck_w_frac * self.half_beam_at(x)
        t = 0.0 if wd <= 1e-9 else max(-1.0, min(1.0, y / wd))
        return self.deck_surface_z(x) + self.deck_camber * (1.0 - t * t)

    def stations_in(self, x0, x1):
        out = [x0]
        for st in self.stations:
            if x0 + 1e-6 < st[0] < x1 - 1e-6:
                out.append(st[0])
        out.append(x1)
        return sorted(set(out))

    def profile_fraction(self, x, z):
        w, dz, kz = self.interp(x)
        if dz - kz < 1e-6:
            return self.deck_w_frac, 1.0
        fz = max(0.0, min(1.0, (z - kz) / (dz - kz)))
        prof = self.profile
        for i in range(len(prof) - 1):
            fy0, fz0 = prof[i]
            fy1, fz1 = prof[i + 1]
            if fz0 <= fz <= fz1:
                t = (fz - fz0) / (fz1 - fz0) if fz1 - fz0 > 1e-9 else 0.0
                return fy0 + t * (fy1 - fy0), fz
        return prof[-1][0], fz

    def hull_y_at(self, x, z):
        """解析近似：舷侧表面半宽（>0）。"""
        fy, _fz = self.profile_fraction(x, z)
        return fy * self.half_beam_at(x)

    def section_points(self, x):
        """一个横剖面站的右侧轮廓点 [(y, z)]（从龙骨中点到甲板边）。"""
        w, dz, kz = self.interp(x)
        return [(fy * w, kz + fz * (dz - kz)) for (fy, fz) in self.profile]

    def hull_surface_y(self, x, z):
        """**放样网格实际表面**半宽：站间按顶点线性插值（炮门框 / 装甲带贴壳用）。"""
        sts = self.stations
        index = 0
        for k in range(len(sts) - 1):
            if sts[k][0] <= x <= sts[k + 1][0]:
                index = k
                break
        x0, x1 = sts[index][0], sts[index + 1][0]
        t = (x - x0) / (x1 - x0) if x1 > x0 else 0.0
        rows = []
        for (y0, z0), (y1, z1) in zip(self.section_points(x0),
                                      self.section_points(x1)):
            y = y0 * (1.0 - t) + y1 * t
            zz = z0 * (1.0 - t) + z1 * t
            if y >= 0.0:
                rows.append((zz, y))
        rows.sort()
        if z <= rows[0][0]:
            return rows[0][1]
        if z >= rows[-1][0]:
            return rows[-1][1]
        for (za, ya), (zb, yb) in zip(rows, rows[1:]):
            if za <= z <= zb:
                u = (z - za) / (zb - za) if zb > za else 0.0
                return ya * (1.0 - u) + yb * u
        return rows[-1][1]


# ============================================================
# 几何工具
# ============================================================

def tri_count(part):
    return sum(max(0, len(f) - 2) for f, _m in part.faces)


def loop_normals(loop):
    n = len(loop)
    cx = sum(p[0] for p in loop) / n
    cy = sum(p[1] for p in loop) / n
    out = []
    for k in range(n):
        tx = loop[(k + 1) % n][0] - loop[k - 1][0]
        ty = loop[(k + 1) % n][1] - loop[k - 1][1]
        nx, ny = -ty, tx
        length = math.hypot(nx, ny) or 1.0
        nx, ny = nx / length, ny / length
        if nx * (loop[k][0] - cx) + ny * (loop[k][1] - cy) < 0:
            nx, ny = -nx, -ny
        out.append((nx, ny))
    return out


def band_loop(loop, normals, height, out_off, in_off, material, z0=None):
    """沿闭合环生成闭合带状体（舷墙 / 压顶）。"""
    verts = []
    for (x, y, z), (nx, ny) in zip(loop, normals):
        zb = z if z0 is None else z0
        zt = zb + height
        verts.extend([
            (x + nx * out_off, y + ny * out_off, zb),
            (x + nx * out_off, y + ny * out_off, zt),
            (x + nx * out_off + nx * in_off, y + ny * out_off + ny * in_off, zb),
            (x + nx * out_off + nx * in_off, y + ny * out_off + ny * in_off, zt),
        ])
    n = len(loop)
    faces = []
    for k in range(n):
        k2 = (k + 1) % n
        a, b = k * 4, k2 * 4
        faces.append((a, b, b + 1, a + 1))
        faces.append((a + 3, a + 2, b + 2, b + 3))
        faces.append((a + 1, b + 1, b + 3, a + 3))
        faces.append((a, a + 2, b + 2, b))
    part = Part()
    part.add((verts, faces), material)
    return part


def deck_edge_loop(hull, xs, dz=0.0):
    loop = []
    for x in xs:
        loop.append((x, hull.deck_w_frac * hull.half_beam_at(x),
                     hull.deck_surface_z(x) + hull.deck_camber + dz))
    for x in reversed(xs):
        loop.append((x, -hull.deck_w_frac * hull.half_beam_at(x),
                     hull.deck_surface_z(x) + hull.deck_camber + dz))
    return loop


def build_hull(hull, material_at):
    """闭合船体放样：站表 + 剖面轮廓；首尾用环心三角扇封盖。"""
    rings = []
    for x, w, dz, kz in hull.stations:
        pts = [(x, fy * w, kz + fz * (dz - kz)) for (fy, fz) in hull.profile]
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
    part = Part()
    part.verts = verts
    for f in faces:
        cx = sum(verts[i][0] for i in f) / len(f)
        cz = sum(verts[i][2] for i in f) / len(f)
        part.faces.append((f, material_at(cx, cz)))
    return part


def build_deck(hull, mat_a, mat_b, x0=None, x1=None, ny=12, z_off=0.0):
    """带拱度的木/铁甲板：沿站生成，横向板材交替深浅（单层曲面，边界边允许）。"""
    xs = hull.stations_in(x0 if x0 is not None else hull.stations[0][0],
                          x1 if x1 is not None else hull.stations[-1][0])
    verts = []
    for x in xs:
        wd = hull.deck_w_frac * hull.half_beam_at(x)
        z0 = hull.deck_surface_z(x) + z_off
        for k in range(ny + 1):
            t = -1.0 + 2.0 * k / ny
            verts.append((x, t * wd, z0 + hull.deck_camber * (1.0 - t * t)))
    part = Part()
    part.verts = verts
    for i in range(len(xs) - 1):
        for k in range(ny):
            a = i * (ny + 1) + k
            b = (i + 1) * (ny + 1) + k
            part.faces.append(((a, b, b + 1, a + 1),
                               mat_a if k % 2 == 0 else mat_b))
    part.recalc = False
    return part


def build_raised_deck(hull, x_end, rise, mat_a, mat_b, x0=None, ny=10):
    """艉楼 / 后甲板：抬高 rise 的甲板面 + 前挡板 + 两级台阶。"""
    xs = hull.stations_in(x0 if x0 is not None else hull.stations[0][0], x_end)
    verts = []
    for x in xs:
        wd = hull.deck_w_frac * hull.half_beam_at(x)
        z0 = hull.deck_surface_z(x) + rise
        for k in range(ny + 1):
            t = -1.0 + 2.0 * k / ny
            verts.append((x, t * wd,
                          z0 + hull.deck_camber * 0.85 * (1.0 - t * t)))
    part = Part()
    part.verts = verts
    for i in range(len(xs) - 1):
        for k in range(ny):
            a = i * (ny + 1) + k
            b = (i + 1) * (ny + 1) + k
            part.faces.append(((a, b, b + 1, a + 1),
                               mat_a if k % 2 == 0 else mat_b))
    part.recalc = False
    wd = hull.deck_w_frac * hull.half_beam_at(x_end)
    z0 = hull.deck_surface_z(x_end)
    part.add(box((x_end - 0.09, -wd, z0 - 0.02),
                 (x_end + 0.09, wd, z0 + rise + 0.02)), DARK)
    for i in range(2):
        part.add(box((x_end + 0.10 + i * 0.34, -0.9, z0 - 0.02),
                     (x_end + 0.42 + i * 0.34, 0.9,
                      z0 + rise * (1.0 - i * 0.5))), WOOD)
    return part


def build_bulwark(hull, band_mat, cap_mat, xs=None):
    xs = xs or hull.stations_in(hull.stations[0][0] + 0.05,
                                hull.stations[-1][0] - 0.05)
    loop = deck_edge_loop(hull, xs)
    normals = loop_normals(loop)
    part = Part()
    part.merge(band_loop(loop, normals, hull.bulwark_h, hull.bulwark_out,
                         -hull.bulwark_in, band_mat))
    cap = band_loop(loop, normals, hull.cap_t,
                    hull.bulwark_out + 0.025, -hull.bulwark_in - 0.015, cap_mat)
    for i, v in enumerate(cap.verts):
        cap.verts[i] = (v[0], v[1], v[2] + hull.bulwark_h - 0.012)
    part.merge(cap)
    return part


def build_side_bands(hull, bands, mat):
    """贴着舷侧、随甲板舷弧起伏的腰板 / 压条带。

    bands = [(z_off, height, out)]；z_off 相对甲板边线（负值在甲板下）。
    """
    xs = hull.stations_in(hull.stations[0][0] + 0.15,
                          hull.stations[-1][0] - 0.15)
    part = Part()
    for z_off, height, out in bands:
        for side in (1, -1):
            verts = []
            for x in xs:
                zc = hull.deck_z_at(x) + z_off
                yo = hull.hull_y_at(x, zc) + out
                yi = yo - 0.05
                verts.extend([
                    (x, side * yo, zc - height * 0.5),
                    (x, side * yo, zc + height * 0.5),
                    (x, side * yi, zc + height * 0.5),
                    (x, side * yi, zc - height * 0.5),
                ])
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
            part.add((verts, faces), mat)
    return part


def build_keel_stem_rudder(hull, hull_mat, metal_mat, bow_prism=None,
                           rudder_z0=None, prop=None):
    """龙骨 / 艏柱 / 艉柱 / 舵 / 舵铁；可选螺旋桨（蒸汽舰）。"""
    part = Part()
    x0 = hull.stations[0][0]
    x1 = hull.stations[-1][0]
    keel_z = min(st[3] for st in hull.stations) - 0.12
    part.add(box((x0 + 0.30, -0.13, keel_z - 0.10),
                 (x1 - 0.35, 0.13, keel_z + 0.16)), hull_mat)
    if bow_prism is not None:
        poly, y = bow_prism
        part.add(prism_xz(poly, -y, y), hull_mat)
    # 艉柱 / 舵 / 舵铁
    z0 = -1.30 if rudder_z0 is None else rudder_z0
    z1 = hull.deck_z_at(x0) - 0.45
    part.add(box((x0 - 0.36, -0.12, z0), (x0 - 0.04, 0.12, z1)), hull_mat)
    part.add(box((x0 - 0.66, -0.08, z0 + 0.10), (x0 - 0.36, 0.08, z1 - 0.05)),
             hull_mat)
    for zc in (z0 + 0.20, 0.5 * (z0 + z1), z1 - 0.25):
        part.add(box((x0 - 0.52, -0.145, zc - 0.05),
                     (x0 - 0.30, 0.145, zc + 0.05)), metal_mat)
    if prop is not None:
        # prop = (桨毂 x, 桨毂 z, 叶半径)；三叶螺旋桨 + 轴
        px, pz, r = prop
        part.add(taper_cyl((px, 0.0, pz), (px - 0.30, 0.0, pz),
                           0.16, 0.12, 8), BRASS)
        part.add(box((px + 0.10, -0.10, pz - 0.10),
                     (px + 0.75, 0.10, pz + 0.10)), metal_mat)
        for k in range(3):
            a = k * 2.0 * math.pi / 3.0 + math.pi / 6.0
            uy, uz = math.cos(a), math.sin(a)
            vy, vz = -math.sin(a), math.cos(a)
            corners = []
            for rr, ww in ((0.14, -0.06), (0.14, 0.06),
                           (r, 0.05), (r, -0.05)):
                corners.append((rr * uy + ww * vy, pz + rr * uz + ww * vz))
            bottom = [(px - 0.33, yy, zz) for yy, zz in corners]
            top = [(px - 0.27, yy, zz) for yy, zz in corners]
            part.add(hexa(bottom, top), metal_mat)
    return part


def build_transom(part, hull_mat, glass_mat, brass_mat, x, y_half, z0, z1,
                  windows=3, nameplate=False):
    """艉板 + 压顶 + 艉窗 + 黄铜窗框（可选铭牌位置）。"""
    part.add(box((x - 0.02, -y_half, z0), (x + 0.42, y_half, z1)), hull_mat)
    part.add(box((x - 0.05, -y_half - 0.05, z1), (x + 0.45, y_half + 0.05,
                                                 z1 + 0.12)), hull_mat)
    span = (2.0 * y_half) / windows
    for i in range(windows):
        cy = -y_half + span * (i + 0.5)
        part.add(box((x - 0.05, cy - 0.30, z0 + 0.22),
                     (x + 0.02, cy + 0.30, z1 - 0.22)), glass_mat)
        part.add(box((x - 0.07, cy - 0.36, z0 + 0.16),
                     (x - 0.01, cy - 0.30, z1 - 0.16)), brass_mat)
        part.add(box((x - 0.07, cy + 0.30, z0 + 0.16),
                     (x - 0.01, cy + 0.36, z1 - 0.16)), brass_mat)
        part.add(box((x - 0.07, cy - 0.36, z1 - 0.22),
                     (x - 0.01, cy + 0.36, z1 - 0.16)), brass_mat)
        part.add(box((x - 0.07, cy - 0.36, z0 + 0.16),
                     (x - 0.01, cy + 0.36, z0 + 0.22)), brass_mat)
    if nameplate:
        part.add(box((x - 0.06, -0.55, z0 + 0.08), (x + 0.01, 0.55,
                                                   z0 + 0.18)), brass_mat)


def build_bowsprit(part, root, tip, jib_root, jib_tip, wood_mat, metal_mat,
                   gammon_x):
    """艏斜桁 + 延伸杆 + 三道铁箍 + 艏柱系固箱。"""
    part.add(taper_cyl(root, tip, 0.22, 0.12, 8), wood_mat)
    part.add(taper_cyl(jib_root, jib_tip, 0.12, 0.05, 6), wood_mat)
    axis = vnorm(vsub(tip, root))
    for t in (0.18, 0.38, 0.58):
        p = lerp3(root, tip, t)
        r = 0.22 + (0.12 - 0.22) * t + 0.03
        part.add(taper_cyl(vadd(p, vmul(axis, -0.06)),
                           vadd(p, vmul(axis, 0.06)), r, r, 8), metal_mat)
    part.add(box((gammon_x - 0.20, -0.20, root[2] - 0.16),
                 (gammon_x + 0.22, 0.20, root[2] + 0.16)), metal_mat)


def build_bow_fittings(part, hull, metal_mat, wood_mat, extra_x=0.0):
    """艏部猫头梁 / 锚 / 锚链 / 系缆桩（两舷镜像）。"""
    x = hull.stations[-1][0] - 1.4 + extra_x
    deckz = hull.deck_surface_z(x) + hull.deck_camber * 0.85
    beam = hull.deck_w_frac * hull.half_beam_at(x)
    for side in (1, -1):
        part.add(box((x - 0.35, side * (beam - 0.35), deckz - 0.04),
                     (x + 0.35, side * (beam + 0.30), deckz + 0.12)),
                 wood_mat)
        part.add(box((x, side * (beam - 0.10) - 0.10, deckz + 0.05),
                     (x + 0.14, side * (beam - 0.10) + 0.10, deckz + 1.30)),
                 metal_mat)
        part.add(box((x - 0.40, side * (beam - 0.16) - 0.08,
                      deckz + 1.00),
                     (x + 0.55, side * (beam - 0.16) + 0.08, deckz + 1.14)),
                 metal_mat)
        for sgn in (-1, 1):
            part.add(taper_cyl(
                (x + sgn * 0.30, side * (beam - 0.10), deckz + 0.30),
                (x + sgn * 0.52, side * (beam - 0.02), deckz - 0.05),
                0.09, 0.055, 6), metal_mat)
        part.add(taper_cyl((x - 0.9, side * (beam - 0.55), deckz - 0.02),
                           (x - 0.9, side * (beam - 0.55), deckz + 0.34),
                           0.07, 0.07, 8), wood_mat)


def build_flag(part, x, y0, y1, z0, z1, material, seg=4, thickness=0.025):
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
    part.add((verts, faces), material)


def build_pennant(part, x, y, z, length, height, material, thickness=0.020):
    """细长旒旗（沿 -X 飘、尾端收尖）。"""
    seg = 4
    rows = []
    for k in range(2):
        zz = z - height * 0.5 if k == 0 else z + height * 0.5
        row = []
        for i in range(seg + 1):
            t = i / float(seg)
            h = height * (1.0 - 0.92 * t)
            row.append((x - length * t, y + 0.06 * math.sin(t * 5.0), zz
                        if k == 0 else zz + (h - height) * 0.5))
        rows.append(row)
    verts = []
    for row in rows:
        for px, py, pz in row:
            verts.append((px - thickness * 0.5, py, pz))
    for row in rows:
        for px, py, pz in row:
            verts.append((px + thickness * 0.5, py, pz))
    mcols = seg + 1
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
    part.add((verts, faces), material)


def build_smokestack(part, spec, metal_mat, brass_mat, iron_mat):
    """后倾烟囱：分级收分 + 黄铜箍 + 顶圈 + 基座 + 蒸汽管。"""
    x = spec["x"]
    z0, z1 = spec["z0"], spec["z1"]
    lean = spec.get("lean", 0.0)
    levels = [(z0, spec["r0"]), (z0 + 0.55 * (z1 - z0), spec["r0"] * 0.86),
              (z1 - 0.25, spec["r1"] * 1.06), (z1, spec["r1"])]
    verts = []
    for z, r in levels:
        cx = x + lean * (z - z0) / (z1 - z0)
        verts.extend(ring(8, r, r, z, cx=cx))
    faces = []
    for k in range(len(levels) - 1):
        base, nxt = k * 8, (k + 1) * 8
        for i in range(8):
            j = (i + 1) % 8
            faces.append((base + i, base + j, nxt + j, nxt + i))
    for i in range(1, 7):
        faces.append((0, i + 1, i))
        top = (len(levels) - 1) * 8
        faces.append((top, top + i, top + i + 1))
    part.add((verts, faces), metal_mat)
    for z in (z0 + 0.9, z0 + 0.55 * (z1 - z0)):
        t = (z - z0) / (z1 - z0)
        cx = x + lean * t
        r = (spec["r0"] + (spec["r1"] - spec["r0"]) * t) + 0.04
        part.add(translate(revolved([(z - 0.09, r), (z + 0.09, r)], 8),
                           cx, 0.0, 0.0), brass_mat)
    cx_top = x + lean
    part.add(translate(revolved([(z1 - 0.09, spec["r1"] + 0.09),
                                 (z1 + 0.06, spec["r1"] + 0.09)], 8),
                       cx_top, 0.0, 0.0), brass_mat)
    part.add(box((x - spec["base_hw"], -spec["base_hw"], z0 - 0.55),
                 (x + spec["base_hw"], spec["base_hw"], z0 - 0.05)), iron_mat)


# ============================================================
# 帆索辅助：船型布局 -> rig_kit 世界坐标
# ============================================================

from ship_parts import core as _core  # noqa: E402


def mast_transform(masts):
    """返回 (mast_world, mast_to_world, mast_pivot_world)；masts[key] 含 x / rake / deck_z。"""

    def pivot(key):
        cfg = masts[key]
        return (cfg["x"], 0.0, cfg["deck_z"])

    def world(key, z_local, y=0.0):
        cfg = masts[key]
        px, _py, pz = pivot(key)
        a = math.radians(cfg["rake"])
        return (px + z_local * math.sin(a), y, pz + z_local * math.cos(a))

    def to_world(key, p):
        cfg = masts[key]
        px, _py, pz = pivot(key)
        a = math.radians(cfg["rake"])
        return (px + p[0] * math.cos(a) + p[2] * math.sin(a),
                p[1],
                pz - p[0] * math.sin(a) + p[2] * math.cos(a))

    return world, to_world, pivot


def build_mast_part(masts, key):
    part = Part()
    b = rig_kit.builder(part, _core, materials=rig_kit.KIT_MATERIALS)
    rig_kit.schooner_mast(b, masts[key])
    return part


def build_gaff_spars(masts, key, sail, topsail=None):
    """帆船斜桁 + 帆杠（局部坐标）。"""
    part = Part()
    gaff = dict(throat=(sail["throat"][0], 0.0, sail["throat"][2]),
                peak=(sail["peak"][0], 0.0, sail["peak"][2]),
                r0=0.075, r1=0.052)
    boom = dict(tack=(sail["tack"][0], 0.0, sail["tack"][2]),
                clew=(sail["clew"][0], 0.0, sail["clew"][2]),
                r0=0.095, r1=0.062)
    b = rig_kit.builder(part, _core, materials=rig_kit.KIT_MATERIALS)
    rig_kit.schooner_spars(b, gaff, boom, (sail["tack"][2], sail["throat"][2]),
                           0.062, 0.072, topsail=topsail,
                           jaws=(0.22, 0.24, 0.10), band_dx=(0.14, 0.02))
    return part


def build_gaff_sail(part, sail, camber, roach, topsail=None):
    b = rig_kit.builder(part, _core, materials=rig_kit.KIT_MATERIALS)
    rig_kit.gaff_sail(b, sail["tack"], sail["throat"], sail["peak"],
                      sail["clew"], camber, roach)
    if topsail:
        rig_kit.square_sail(b, topsail["x"], topsail["z_head"],
                            topsail["z_foot"], topsail["half_head"],
                            topsail["half_foot"], topsail["camber"])


def build_square_rig_local(part, lower, top, sails):
    """横帆局部几何：横桁 / 桅帽横担（帆面在独立的 Sails 部件里生成）。"""
    b = rig_kit.builder(part, _core, materials=rig_kit.KIT_MATERIALS)
    for spec in sails:
        yard_z = spec["z_head"] + 0.10
        half = spec["half_head"] + 0.42
        b.add(_core.taper_cyl((spec["x"] + 0.06, -half, yard_z),
                              (spec["x"] + 0.06, half, yard_z),
                              0.105, 0.085, 6), b.mat("wood"))
        for side in (-1, 1):
            b.add(_core.taper_cyl((spec["x"] + 0.06, side * half - 0.10, yard_z),
                                  (spec["x"] + 0.06, side * half + 0.22, yard_z),
                                  0.13, 0.13, 6), b.mat("metal"))
    # 桅顶 / 桅帽横担
    for z in (lower - 0.25, top - 0.20):
        b.add(_core.box((-0.30, -1.55, z), (0.30, 1.55, z + 0.16)),
              b.mat("wood_dark"))


def build_shroud_rig(part, masts, keys, hull, rows=7, row_offsets=(-1.20, -0.42,
                                                                   0.42, 1.20)):
    """侧支索 + 绳梯（每桅两侧 / 世界坐标）。"""
    world, _to, _pivot = mast_transform(masts)
    b = rig_kit.builder(part, _core, materials=rig_kit.KIT_MATERIALS)
    for key in keys:
        cfg = masts[key]
        x = cfg["x"]
        top_pt = world(key, cfg["lower"] - 0.45)
        for side in (1, -1):
            anchors = []
            for dx in row_offsets:
                xx = x + dx
                yy = hull.deck_w_frac * hull.half_beam_at(xx) + 0.32
                zz = hull.deck_surface_z(xx) + 0.02
                anchors.append((xx, side * yy, zz))
            rig_kit.schooner_shroud_fan(b, top_pt, anchors, rows,
                                        top_offsets=(-0.06, 0.06))
    return part


def build_stays(part, lines, radius=0.034):
    """世界坐标支索 / 后支索 / 吊索（统一用暗色索）。"""
    b = rig_kit.builder(part, _core, materials=rig_kit.KIT_MATERIALS)
    for p0, p1 in lines:
        b.add(_core.taper_cyl(p0, p1, radius, radius, 4), b.mat("wood_dark"))
    return part


# ============================================================
# 1. 海盗单桅（Light，单桅纵帆）
# ============================================================

SLOOP_HULL = HullSpec(
    stations=[
        (-11.20, 2.42, 2.86, -1.42),
        (-11.00, 2.66, 2.83, -1.66),
        (-10.50, 2.90, 2.79, -1.92),
        (-9.60, 3.05, 2.72, -2.12),
        (-8.50, 3.13, 2.65, -2.26),
        (-7.00, 3.16, 2.57, -2.34),
        (-5.20, 3.12, 2.51, -2.38),
        (-3.20, 3.02, 2.47, -2.38),
        (-1.00, 2.88, 2.45, -2.34),
        (1.20, 2.72, 2.45, -2.27),
        (3.40, 2.55, 2.47, -2.14),
        (5.60, 2.36, 2.53, -1.94),
        (7.60, 2.10, 2.61, -1.66),
        (9.20, 1.78, 2.71, -1.32),
        (10.30, 1.38, 2.83, -0.92),
        (11.00, 0.82, 2.97, -0.40),
        (11.30, 0.34, 3.10, 0.22),
    ],
    profile=[(0.00, 0.00), (0.36, 0.01), (0.60, 0.04), (0.78, 0.11),
             (0.90, 0.21), (0.97, 0.35), (1.00, 0.53), (1.00, 0.68),
             (0.985, 0.81), (0.94, 0.92), (0.86, 1.00)],
    deck_w_frac=0.86, deck_camber=0.09, bulwark_h=0.72, cap_t=0.065,
)

SLOOP_MASTS = {
    "Main": dict(x=0.80, deck_z=2.45, rake=-3.20, lower=9.40, top=15.20,
                 gallant=18.60, r_lower=(0.300, 0.200),
                 r_top=(0.180, 0.100), r_gal=(0.080, 0.036)),
}
SLOOP_SAIL = dict(tack=(0.00, 0.10, 1.40), throat=(0.00, 0.10, 8.10),
                  peak=(-4.30, 0.10, 10.40), clew=(-3.90, 0.10, 1.80))
SLOOP_TOPSAIL = dict(x=0.45, z_head=13.10, z_foot=10.30,
                     half_head=2.10, half_foot=1.85, camber=0.55)
SLOOP_BOWSPRIT = dict(root=(11.05, 0.0, 2.92), tip=(15.30, 0.0, 4.55),
                      jib_root=(14.10, 0.0, 4.20), jib_tip=(17.20, 0.0, 5.35))
SLOOP_POOP = dict(x_end=-7.60, rise=0.20)


def sloop_deck_top(x, y):
    z = SLOOP_HULL.deck_top(x, y)
    if x <= SLOOP_POOP["x_end"]:
        z += SLOOP_POOP["rise"] + 0.0
    return z


def _sloop_parts():
    h = SLOOP_HULL
    prefix = "SN_ES_"
    parts = {}

    def add(name, part, parent="ROOT"):
        parts[prefix + name] = (part, parent)

    def hull_mat(x, z):
        return RED if z >= h.deck_z_at(x) - 0.78 else DARK

    add("Hull", build_hull(h, hull_mat))
    add("Deck", build_deck(h, DECK, WOOD))
    add("Poop_Deck", build_raised_deck(h, SLOOP_POOP["x_end"],
                                       SLOOP_POOP["rise"], DECK, WOOD))
    add("Bulwark", build_bulwark(h, RED, DARK))
    add("Wales", build_side_bands(h, [(-0.78, 0.10, 0.040),
                                      (0.00, 0.055, 0.030)], DARK))

    keel = Part()
    stem = ([(11.00, -2.44), (11.28, -1.60), (11.38, 0.40), (11.38, 3.08),
             (11.18, 3.08), (11.16, 0.40), (11.02, -1.60)], 0.10)
    keel.merge(build_keel_stem_rudder(h, DARK, METAL, bow_prism=stem,
                                      rudder_z0=-1.25))
    add("Keel_Stem_Rudder", keel)

    transom = Part()
    build_transom(transom, DARK, GLASS, BRASS, -11.28, 2.05, 1.58, 3.20,
                  windows=3, nameplate=True)
    add("Transom", transom)

    bow = Part()
    build_bowsprit(bow, SLOOP_BOWSPRIT["root"], SLOOP_BOWSPRIT["tip"],
                   SLOOP_BOWSPRIT["jib_root"], SLOOP_BOWSPRIT["jib_tip"],
                   WOOD, METAL, 11.24)
    build_bow_fittings(bow, h, METAL, DARK)
    add("Bow_Fittings", bow)

    # ---- 桅 / 桁 / 帆（局部坐标，父级 Pivot）--------------------------
    add("Mast", build_mast_part(SLOOP_MASTS, "Main"), "MAIN")
    add("Spars", build_gaff_spars(SLOOP_MASTS, "Main", SLOOP_SAIL,
                                  topsail=SLOOP_TOPSAIL), "MAIN")
    sails = Part()
    build_gaff_sail(sails, SLOOP_SAIL, 0.62, 0.42, topsail=SLOOP_TOPSAIL)
    add("Sails", sails, "MAIN")

    # ---- 索具 / 艏三角帆（世界坐标）-----------------------------------
    world, _to, _pivot = mast_transform(SLOOP_MASTS)
    rig = build_shroud_rig(Part(), SLOOP_MASTS, ["Main"], h, rows=7)
    top = world("Main", SLOOP_MASTS["Main"]["top"] - 0.25)
    gal = world("Main", SLOOP_MASTS["Main"]["gallant"] - 0.15)
    lower = world("Main", SLOOP_MASTS["Main"]["lower"] - 0.30)
    rig_lines = [
        (gal, (11.30, 0.0, 3.05)),
        (top, (13.60, 0.0, 4.35)),
        (lower, (17.10, 0.0, 5.30)),
        (top, (-10.95, 0.0, 3.30)),
        (top, (-11.10, 0.0, 5.35)),
        (top, (-11.10, 0.0, 5.20)),
    ]
    build_stays(rig, rig_lines, 0.032)
    # 动索：斜桁吊索 / 帆脚索
    mw = world
    m2w = _to
    peak = m2w("Main", SLOOP_SAIL["peak"])
    clew = m2w("Main", SLOOP_SAIL["clew"])
    throat = m2w("Main", SLOOP_SAIL["throat"])
    build_stays(rig, [(mw("Main", 14.9), peak), (mw("Main", 15.6), throat),
                      (clew, (-9.20, 0.70, 2.90)), (clew, (-9.20, -0.70, 2.90)),
                      (throat, (-0.20, 0.60, 2.90))], 0.022)
    add("Rigging", rig)

    heads = Part()
    b = rig_kit.builder(heads, _core, materials=rig_kit.KIT_MATERIALS)
    head = world("Main", SLOOP_MASTS["Main"]["top"] - 0.20)
    rig_kit.tri_sail(b, (head[0], 0.10, head[2]),
                     (SLOOP_BOWSPRIT["jib_tip"][0] - 0.05, 0.10,
                      SLOOP_BOWSPRIT["jib_tip"][2] - 0.05),
                     (5.90, 0.10, 3.35), 0.55, 0.30, nu=9, nv=9)
    rig_kit.tri_sail(b, (lower[0], 0.08, lower[2]),
                     (12.55, 0.0, 3.15), (8.20, 0.08, 3.05), 0.38, 0.22,
                     nu=7, nv=7)
    add("Headsails", heads)

    # ---- 甲板属具 ----------------------------------------------------
    fit = Part()
    z = h.deck_top(5.40, 0.0)
    deck_kit.hatch(fit, 5.40, 1.80, 1.45, z, hull_mat=DARK, wood_mat=WOOD,
                   dark_mat=DARK)
    z = h.deck_top(-5.20, 0.0)
    deck_kit.hatch(fit, -5.20, 1.60, 1.30, z, hull_mat=DARK, wood_mat=WOOD,
                   dark_mat=DARK)
    deck_kit.capstan(fit, 2.05, h.deck_top(2.05, 0.0), dark_mat=DARK,
                     wood_mat=WOOD)
    deck_kit.windlass(fit, 3.55, h.deck_top(3.55, 0.0), dark_mat=DARK,
                      wood_mat=WOOD)
    zq = sloop_deck_top(-9.40, 0.0) + 0.02
    deck_kit.wheel(fit, -9.40, zq, 0.58, 0.050, dark_mat=DARK, wood_mat=WOOD)
    deck_kit.binnacle(fit, -8.55, sloop_deck_top(-8.55, 0.0), dark_mat=DARK,
                      wood_mat=WOOD, brass_mat=BRASS)
    deck_kit.fife_rail(fit, -0.15, h.deck_top(-0.15, 0.0), dark_mat=DARK,
                       wood_mat=WOOD)
    deck_kit.bell(fit, 2.60, h.deck_top(2.60, 0.0), dark_mat=DARK,
                  brass_mat=BRASS)
    for bx, by in ((-6.30, 1.75), (-6.30, -1.75), (8.70, 1.30), (8.70, -1.30),
                   (-9.90, 1.55), (-9.90, -1.55)):
        deck_kit.bollard(fit, bx, by, sloop_deck_top(bx, by) + 0.01,
                         dark_mat=DARK)
    for bx, by in ((-6.95, 1.95), (7.30, -1.55)):
        deck_kit.barrel(fit, bx, by, h.deck_top(bx, by), wood_mat=WOOD,
                        metal_mat=METAL)
    deck_kit.rope_coil(fit, 4.65, 1.10, h.deck_top(4.65, 1.10) + 0.02,
                       dark_mat=DARK)
    deck_kit.ladder(fit, (SLOOP_POOP["x_end"] + 0.95, 1.20,
                          h.deck_top(-6.65, 0.0) + 0.02),
                    (SLOOP_POOP["x_end"] + 0.06, 1.20,
                     sloop_deck_top(-7.54, 0.0) + 0.02), 0.9,
                    dark_mat=DARK, wood_mat=WOOD)
    add("Deck_Fittings", fit)

    # ---- 旗 / 旒 -----------------------------------------------------
    flag = Part()
    flag.add(taper_cyl((-11.20, 0.0, 3.20), (-11.20, 0.0, 6.10),
                       0.06, 0.035, 6), WOOD)
    build_flag(flag, -11.24, 0.0, 2.20, 4.55, 5.85, DARK)
    mast_z = SLOOP_MASTS["Main"]["gallant"]
    mtop = world("Main", mast_z)
    flag.add(taper_cyl(mtop, (mtop[0], 0.0, mtop[2] + 0.55), 0.045, 0.025, 6),
             WOOD)
    build_pennant(flag, mtop[0], -0.10, mtop[2] + 0.35, 4.40, 0.42, RED)
    add("Flags", flag)
    return parts


def sloop_config():
    world, _to, pivot = mast_transform(SLOOP_MASTS)
    return dict(
        asset="SN_Enemy_Pirate_Sloop",
        collection="SN_Enemy_Pirate_Sloop_Prototype",
        prefix="SN_ES_",
        root="SN_ES_Root",
        workbench=(-55.0, -110.0, 0.0),
        tri_budget=9000,
        enemy_class="Light",
        enemy_archetype="pirate_sloop",
        style="low-poly flat-shaded single-mast pirate sloop",
        pivots=[assembly.PivotSpec(
            "MAIN", "SN_ES_Mast_Pivot", pivot("Main"),
            (0.0, math.radians(SLOOP_MASTS["Main"]["rake"]), 0.0), 1.2)],
        bbox=(29.10, 6.35, 24.20),
        bbox_tol=(0.80, 0.40, 0.80),
        deck_top=sloop_deck_top,
    )


# ============================================================
# 2. 武装商船（Medium，双桅横帆）
# ============================================================

MERCHANT_HULL = HullSpec(
    stations=[
        (-16.80, 3.60, 3.95, -2.10),
        (-16.20, 3.95, 3.90, -2.50),
        (-15.20, 4.25, 3.82, -2.80),
        (-13.80, 4.45, 3.74, -3.00),
        (-12.00, 4.58, 3.66, -3.15),
        (-10.00, 4.66, 3.58, -3.20),
        (-7.50, 4.70, 3.50, -3.20),
        (-5.00, 4.68, 3.44, -3.15),
        (-2.50, 4.62, 3.38, -3.05),
        (0.00, 4.55, 3.34, -2.95),
        (2.50, 4.45, 3.32, -2.82),
        (5.00, 4.30, 3.34, -2.65),
        (7.50, 4.10, 3.38, -2.45),
        (10.00, 3.80, 3.46, -2.20),
        (12.50, 3.40, 3.56, -1.90),
        (14.50, 2.90, 3.68, -1.55),
        (16.00, 2.20, 3.82, -1.10),
        (17.00, 1.30, 3.95, -0.55),
        (17.20, 0.55, 4.05, 0.00),
    ],
    profile=[(0.00, 0.00), (0.30, 0.02), (0.55, 0.05), (0.72, 0.10),
             (0.85, 0.20), (0.94, 0.34), (1.00, 0.50), (1.00, 0.66),
             (0.99, 0.80), (0.96, 0.90), (0.90, 1.00)],
    deck_w_frac=0.90, deck_camber=0.10, bulwark_h=0.80, cap_t=0.075,
)

MERCHANT_MASTS = {
    "Fore": dict(x=10.00, deck_z=3.46, rake=-2.00, lower=10.20, top=16.40,
                 gallant=20.60, r_lower=(0.340, 0.230),
                 r_top=(0.200, 0.110), r_gal=(0.090, 0.038)),
    "Main": dict(x=-3.00, deck_z=3.37, rake=-2.60, lower=11.00, top=17.40,
                 gallant=21.80, r_lower=(0.370, 0.245),
                 r_top=(0.215, 0.120), r_gal=(0.095, 0.040)),
}
MERCHANT_SAILS = {
    "Fore": [
        dict(x=0.62, z_foot=2.45, z_head=9.35, half_foot=3.40, half_head=3.10,
             camber=0.55),
        dict(x=0.58, z_foot=10.55, z_head=15.55, half_foot=2.80, half_head=2.15,
             camber=0.50),
    ],
    "Main": [
        dict(x=0.66, z_foot=2.45, z_head=10.10, half_foot=3.55, half_head=3.25,
             camber=0.58),
        dict(x=0.60, z_foot=11.30, z_head=16.55, half_foot=2.95, half_head=2.25,
             camber=0.52),
    ],
}
MERCHANT_BOWSPRIT = dict(root=(17.05, 0.0, 3.95), tip=(21.40, 0.0, 5.25),
                         jib_root=(20.20, 0.0, 4.95),
                         jib_tip=(23.30, 0.0, 5.85))
MERCHANT_POOP = dict(x_end=-10.50, rise=0.28)


def merchant_deck_top(x, y):
    z = MERCHANT_HULL.deck_top(x, y)
    if x <= MERCHANT_POOP["x_end"]:
        z += MERCHANT_POOP["rise"]
    return z


def _merchant_parts():
    h = MERCHANT_HULL
    prefix = "SN_EM_"
    parts = {}

    def add(name, part, parent="ROOT"):
        parts[prefix + name] = (part, parent)

    def hull_mat(x, z):
        if z >= h.deck_z_at(x) - 0.62:
            return DARK
        if z <= h.keel_z_at(x) + 1.05:
            return RED
        return WOOD

    add("Hull", build_hull(h, hull_mat))
    add("Deck", build_deck(h, DECK, WOOD))
    add("Poop_Deck", build_raised_deck(h, MERCHANT_POOP["x_end"],
                                       MERCHANT_POOP["rise"], DECK, WOOD))
    add("Bulwark", build_bulwark(h, DARK, DARK))
    add("Wales", build_side_bands(h, [(-0.62, 0.12, 0.045),
                                      (-1.10, 0.07, 0.035),
                                      (0.00, 0.06, 0.030)], DARK))

    keel = Part()
    stem = ([(16.90, -2.10), (17.16, -1.20), (17.26, 0.60), (17.26, 4.05),
             (17.06, 4.05), (17.02, 0.60), (16.92, -1.20)], 0.11)
    keel.merge(build_keel_stem_rudder(h, DARK, METAL, bow_prism=stem,
                                      rudder_z0=-1.60))
    add("Keel_Stem_Rudder", keel)

    transom = Part()
    build_transom(transom, DARK, GLASS, BRASS, -16.88, 2.95, 2.55, 4.34,
                  windows=3, nameplate=True)
    add("Transom", transom)

    bow = Part()
    build_bowsprit(bow, MERCHANT_BOWSPRIT["root"], MERCHANT_BOWSPRIT["tip"],
                   MERCHANT_BOWSPRIT["jib_root"], MERCHANT_BOWSPRIT["jib_tip"],
                   WOOD, METAL, 17.18)
    build_bow_fittings(bow, h, METAL, DARK)
    add("Bow_Fittings", bow)

    # ---- 双桅横帆 ----------------------------------------------------
    for key in ("Fore", "Main"):
        add("Mast_%s" % key, build_mast_part(MERCHANT_MASTS, key), key.upper())
        spar = Part()
        build_square_rig_local(spar, MERCHANT_MASTS[key]["lower"],
                               MERCHANT_MASTS[key]["top"], MERCHANT_SAILS[key])
        add("Spars_%s" % key, spar, key.upper())
        leaves = Part()
        b = rig_kit.builder(leaves, _core, materials=rig_kit.KIT_MATERIALS)
        for spec in MERCHANT_SAILS[key]:
            rig_kit.square_sail(b, spec["x"], spec["z_head"], spec["z_foot"],
                                spec["half_head"], spec["half_foot"],
                                spec["camber"])
        add("Sails_%s" % key, leaves, key.upper())

    world, _to, _pivot = mast_transform(MERCHANT_MASTS)
    rig = build_shroud_rig(Part(), MERCHANT_MASTS, ["Fore", "Main"], h, rows=7)
    fore_top = world("Fore", MERCHANT_MASTS["Fore"]["top"] - 0.25)
    main_top = world("Main", MERCHANT_MASTS["Main"]["top"] - 0.25)
    fore_gal = world("Fore", MERCHANT_MASTS["Fore"]["gallant"] - 0.15)
    main_gal = world("Main", MERCHANT_MASTS["Main"]["gallant"] - 0.15)
    fore_low = world("Fore", MERCHANT_MASTS["Fore"]["lower"] - 0.30)
    rig_lines = [
        (fore_gal, (17.24, 0.0, 4.10)),
        (fore_top, (21.30, 0.0, 5.20)),
        (fore_low, (23.20, 0.0, 5.80)),
        (main_gal, fore_low),
        (main_top, fore_top),
        (main_gal, (-16.70, 0.0, 4.30)),
        (main_top, (-16.70, 0.0, 4.60)),
        (fore_top, (-16.80, 0.0, 5.40)),
    ]
    build_stays(rig, rig_lines, 0.034)
    # 转帆索 / 动索
    for key in ("Fore", "Main"):
        cfg = MERCHANT_MASTS[key]
        for spec in MERCHANT_SAILS[key]:
            half = spec["half_head"] + 0.42
            zz = cfg["deck_z"] + spec["z_head"] + 0.10
            left = (cfg["x"] + 0.06, -half, zz)
            right = (cfg["x"] + 0.06, half, zz)
            build_stays(rig, [
                (left, (cfg["x"] - 2.40, -3.10,
                        h.deck_surface_z(cfg["x"] - 2.4) + 0.40)),
                (right, (cfg["x"] - 2.40, 3.10,
                         h.deck_surface_z(cfg["x"] - 2.4) + 0.40)),
            ], 0.022)
    add("Rigging", rig)

    heads = Part()
    b = rig_kit.builder(heads, _core, materials=rig_kit.KIT_MATERIALS)
    rig_kit.tri_sail(b, (fore_top[0], 0.10, fore_top[2]),
                     (MERCHANT_BOWSPRIT["jib_tip"][0] - 0.05, 0.10,
                      MERCHANT_BOWSPRIT["jib_tip"][2] - 0.05),
                     (10.20, 0.10, 4.60), 0.60, 0.32, nu=9, nv=9)
    rig_kit.tri_sail(b, (fore_low[0], 0.08, fore_low[2]),
                     (18.40, 0.0, 4.25), (13.00, 0.08, 4.30), 0.40, 0.24,
                     nu=7, nv=7)
    add("Headsails", heads)

    # ---- 甲板属具 ----------------------------------------------------
    fit = Part()
    z = h.deck_top(2.50, 0.0)
    deck_kit.hatch(fit, 2.50, 3.20, 2.40, z, hull_mat=DARK, wood_mat=WOOD,
                   dark_mat=DARK)
    z = h.deck_top(-6.00, 0.0)
    deck_kit.hatch(fit, -6.00, 2.80, 2.20, z, hull_mat=DARK, wood_mat=WOOD,
                   dark_mat=DARK)
    deck_kit.capstan(fit, 12.30, h.deck_top(12.30, 0.0), dark_mat=DARK,
                     wood_mat=WOOD)
    zq = merchant_deck_top(-14.20, 0.0) + 0.02
    deck_kit.wheel(fit, -14.20, zq, 0.66, 0.055, dark_mat=DARK, wood_mat=WOOD)
    deck_kit.binnacle(fit, -13.30, merchant_deck_top(-13.30, 0.0),
                      dark_mat=DARK, wood_mat=WOOD, brass_mat=BRASS)
    deck_kit.fife_rail(fit, 8.95, h.deck_top(8.95, 0.0), dark_mat=DARK,
                       wood_mat=WOOD)
    deck_kit.fife_rail(fit, -4.05, h.deck_top(-4.05, 0.0), dark_mat=DARK,
                       wood_mat=WOOD)
    deck_kit.bell(fit, 12.90, h.deck_top(12.90, 0.0), dark_mat=DARK,
                  brass_mat=BRASS)
    for bx, by in ((12.00, 2.40), (12.00, -2.40), (-9.00, 3.20),
                   (-9.00, -3.20), (15.40, 1.60), (15.40, -1.60),
                   (-15.60, 2.20), (-15.60, -2.20)):
        deck_kit.bollard(fit, bx, by, merchant_deck_top(bx, by) + 0.01,
                         dark_mat=DARK)
    for bx, by in ((-11.40, 2.60), (8.20, 2.20), (8.20, -2.20)):
        deck_kit.barrel(fit, bx, by, merchant_deck_top(bx, by), wood_mat=WOOD,
                        metal_mat=METAL)
    for cx, cy in ((4.60, -1.80), (-8.20, 1.90)):
        deck_kit.rope_coil(fit, cx, cy, h.deck_top(cx, cy) + 0.02,
                           dark_mat=DARK)
    deck_kit.ladder(fit, (MERCHANT_POOP["x_end"] + 0.95, 1.60,
                          h.deck_top(-9.55, 0.0) + 0.02),
                    (MERCHANT_POOP["x_end"] + 0.06, 1.60,
                     merchant_deck_top(-10.44, 0.0) + 0.02), 1.1,
                    dark_mat=DARK, wood_mat=WOOD)
    add("Deck_Fittings", fit)

    flag = Part()
    flag.add(taper_cyl((-16.90, 0.0, 4.34), (-16.90, 0.0, 7.60),
                       0.065, 0.038, 6), WOOD)
    build_flag(flag, -16.94, 0.0, 2.60, 5.35, 6.95, CANVAS)
    mtop = world("Fore", MERCHANT_MASTS["Fore"]["gallant"])
    flag.add(taper_cyl(mtop, (mtop[0], 0.0, mtop[2] + 0.55), 0.045, 0.025, 6),
             WOOD)
    build_pennant(flag, mtop[0], -0.10, mtop[2] + 0.35, 3.60, 0.38, RED)
    add("Flags", flag)
    return parts


def merchant_config():
    _world, _to, pivot = mast_transform(MERCHANT_MASTS)
    return dict(
        asset="SN_Enemy_Merchant_Armed",
        collection="SN_Enemy_Merchant_Armed_Prototype",
        prefix="SN_EM_",
        root="SN_EM_Root",
        workbench=(10.0, -110.0, 0.0),
        tri_budget=12000,
        enemy_class="Medium",
        enemy_archetype="armed_merchantman",
        style="low-poly flat-shaded two-mast square-rigged armed merchantman",
        pivots=[assembly.PivotSpec(
            "FORE", "SN_EM_Mast_Fore_Pivot", pivot("Fore"),
            (0.0, math.radians(MERCHANT_MASTS["Fore"]["rake"]), 0.0), 1.2),
            assembly.PivotSpec(
            "MAIN", "SN_EM_Mast_Main_Pivot", pivot("Main"),
            (0.0, math.radians(MERCHANT_MASTS["Main"]["rake"]), 0.0), 1.2)],
        bbox=(40.80, 9.40, 28.80),
        bbox_tol=(0.80, 0.50, 0.80),
        deck_top=merchant_deck_top,
    )


# ============================================================
# 3. 铁甲舰变体（Heavy，低干舷 / 单烟囱 / 中央炮房 + 舷侧炮门）
# ============================================================

RAIDER_HULL = HullSpec(
    stations=[
        (-20.00, 4.55, 3.58, -2.55),
        (-18.50, 5.05, 3.60, -3.05),
        (-17.00, 5.45, 3.62, -3.30),
        (-15.00, 5.85, 3.63, -3.42),
        (-12.50, 6.15, 3.64, -3.50),
        (-10.00, 6.35, 3.65, -3.52),
        (-7.50, 6.48, 3.65, -3.52),
        (-5.00, 6.55, 3.66, -3.52),
        (-2.50, 6.58, 3.66, -3.52),
        (0.00, 6.58, 3.66, -3.52),
        (3.00, 6.54, 3.66, -3.50),
        (6.00, 6.45, 3.66, -3.46),
        (9.00, 6.28, 3.66, -3.38),
        (12.00, 6.02, 3.67, -3.24),
        (15.00, 5.65, 3.68, -3.02),
        (17.50, 5.10, 3.70, -2.70),
        (19.50, 4.40, 3.74, -2.25),
        (20.80, 3.40, 3.80, -1.70),
        (21.60, 2.05, 3.92, -1.05),
        (22.00, 0.90, 4.05, -0.35),
    ],
    profile=[(0.00, 0.00), (0.45, 0.012), (0.82, 0.05), (0.98, 0.14),
             (1.04, 0.30), (1.06, 0.50), (1.05, 0.66), (1.02, 0.82),
             (0.995, 0.93), (0.99, 1.00)],
    deck_w_frac=0.99, deck_camber=0.06, bulwark_h=0.55, cap_t=0.090,
    bulwark_out=0.040, bulwark_in=0.090,
)

RAIDER_MAST = dict(x=13.20, deck_z=3.67, z0=3.66, z_low=12.00, z_top=16.60,
                   r_low=(0.320, 0.200), r_top=(0.140, 0.060))
RAIDER_FUNNEL = dict(x=-3.00, z0=6.00, z1=12.20, r0=0.85, r1=0.62,
                     lean=-0.55, base_hw=1.05)
RAIDER_GUN_X = [-10.0, -3.5, 3.0, 9.5]
RAIDER_GUN_Z0, RAIDER_GUN_Z1 = 1.30, 3.25
RAIDER_PORT_W, RAIDER_PORT_H = 2.05, 1.95
RAIDER_TOE_OUT = 0.20
RAIDER_RISE = 0.030


def raider_deck_top(x, y):
    return RAIDER_HULL.deck_top(x, y)


def raider_gun_bore(side):
    dx, dy, dz = RAIDER_TOE_OUT, float(side) * 0.977, RAIDER_RISE
    length = math.sqrt(dx * dx + dy * dy + dz * dz)
    return (dx / length, dy / length, dz / length)


def raider_gun_port_pose(x, side):
    """炮门平面中心 / 炮膛轴线——炮门 socket 与炮门框几何共用的挂载基准。"""
    h = RAIDER_HULL
    z_mid = 0.5 * (RAIDER_GUN_Z0 + RAIDER_GUN_Z1)
    y = h.hull_surface_y(x, z_mid)
    dx, dy, dz = raider_gun_bore(side)
    return {
        "x": float(x),
        "side": int(side),
        "center": (float(x), float(side * y), z_mid),
        "bore": (dx, dy, dz),
        "rot_z_deg": math.degrees(math.atan2(dy, dx)),
        "rot_y_deg": -math.degrees(math.asin(dz)),
        "z_mid": z_mid,
        "port_w": RAIDER_PORT_W,
        "port_h": RAIDER_PORT_H,
        "sill_z": RAIDER_GUN_Z0,
        "deck_z": h.deck_z_at(x),
    }


def _raider_gun_ports_part():
    """舷侧 8 个空炮门：炮门框 + 深色炮口板 + 上翻门盖（炮管由 casemate 模块供给）。"""
    h = RAIDER_HULL
    part = Part()
    frame = 0.18
    port_half = RAIDER_PORT_W * 0.5
    z_lo, z_hi = RAIDER_GUN_Z0, RAIDER_GUN_Z1

    for x in RAIDER_GUN_X:
        for s in (-1.0, 1.0):
            def corner(xx, zz, off):
                return (xx, s * (h.hull_surface_y(xx, zz) + off), zz)

            def slab(x_lo, x_hi, za, zb, off_in, off_out, material):
                bottom = [corner(x_lo, za, off_in), corner(x_hi, za, off_in),
                          corner(x_hi, za, off_out), corner(x_lo, za, off_out)]
                top = [corner(x_lo, zb, off_in), corner(x_hi, zb, off_in),
                       corner(x_hi, zb, off_out), corner(x_lo, zb, off_out)]
                part.add(hexa(bottom, top), material)

            slab(x - port_half - frame, x + port_half + frame,
                 z_hi, z_hi + frame, 0.0, 0.12, METAL)
            slab(x - port_half - frame, x + port_half + frame,
                 z_lo - frame, z_lo, 0.0, 0.12, METAL)
            slab(x - port_half - frame, x - port_half, z_lo, z_hi,
                 0.0, 0.12, METAL)
            slab(x + port_half, x + port_half + frame, z_lo, z_hi,
                 0.0, 0.12, METAL)
            slab(x - port_half, x + port_half, z_lo, z_hi, -0.05, 0.06, DARK)
            # 上翻炮门盖（内缘贴壳面，外缘外挑 + 抬起）
            lid_half = RAIDER_PORT_W * 0.5 + 0.10
            zin0, zin1 = z_hi + frame - 0.02, z_hi + frame + 0.08
            zout0, zout1 = z_hi + frame + 0.52, z_hi + frame + 0.62
            yin0_l = h.hull_surface_y(x - lid_half, zin0)
            yin0_r = h.hull_surface_y(x + lid_half, zin0)
            yin1_l = h.hull_surface_y(x - lid_half, zin1)
            yin1_r = h.hull_surface_y(x + lid_half, zin1)
            bottom = [(x - lid_half, s * yin0_l, zin0),
                      (x + lid_half, s * yin0_r, zin0),
                      (x + lid_half, s * (yin0_r + 0.62), zout0),
                      (x - lid_half, s * (yin0_l + 0.62), zout0)]
            top = [(x - lid_half, s * yin1_l, zin1),
                   (x + lid_half, s * yin1_r, zin1),
                   (x + lid_half, s * (yin1_r + 0.62), zout1),
                   (x - lid_half, s * (yin1_l + 0.62), zout1)]
            part.add(hexa(bottom, top), IRON)
    return part


def _raider_parts():
    h = RAIDER_HULL
    prefix = "SN_ER_"
    parts = {}

    def add(name, part, parent="ROOT"):
        parts[prefix + name] = (part, parent)

    def hull_mat(x, z):
        return RED if z <= h.keel_z_at(x) + 1.15 else IRON

    add("Hull", build_hull(h, hull_mat))
    add("Deck", build_deck(h, IRON, METAL, ny=10))
    add("Bulwark", build_bulwark(h, IRON, METAL))

    # 装甲带 + 板缝 + 上船壳列板线
    belt = Part()
    z0, z1 = -0.90, 1.30
    off = 0.34
    for k in range(len(h.stations) - 1):
        x0s, x1s = h.stations[k][0], h.stations[k + 1][0]
        for s in (-1.0, 1.0):
            bottom = [(x0s, s * h.hull_y_at(x0s, z0), z0),
                      (x1s, s * h.hull_y_at(x1s, z0), z0),
                      (x1s, s * (h.hull_y_at(x1s, z0) + off), z0),
                      (x0s, s * (h.hull_y_at(x0s, z0) + off), z0)]
            top = [(x0s, s * h.hull_y_at(x0s, z1), z1),
                   (x1s, s * h.hull_y_at(x1s, z1), z1),
                   (x1s, s * (h.hull_y_at(x1s, z1) + off), z1),
                   (x0s, s * (h.hull_y_at(x0s, z1) + off), z1)]
            belt.add(hexa(bottom, top), IRON)
    for st in h.stations[1:-1]:
        x = st[0]
        for s in (-1.0, 1.0):
            y = h.hull_y_at(x, 0.2)
            belt.add(box((x - 0.06, s * y, z0), (x + 0.06, s * (y + off + 0.06),
                                                 z1)), METAL)
    # 装甲带上缘黄铜压条
    for s in (-1.0, 1.0):
        xs = h.stations_in(h.stations[0][0] + 0.4, h.stations[-1][0] - 0.4)
        verts = []
        for x in xs:
            y = h.hull_y_at(x, z1) + off - 0.05
            verts.extend([(x, s * y, z1 - 0.02), (x, s * y, z1 + 0.08),
                          (x, s * (y + 0.16), z1 + 0.08),
                          (x, s * (y + 0.16), z1 - 0.02)])
        faces = []
        for i in range(len(xs) - 1):
            a, b = i * 4, (i + 1) * 4
            faces.extend([(a, b, b + 1, a + 1), (a + 1, b + 1, b + 2, a + 2),
                          (a + 2, b + 2, b + 3, a + 3), (a + 3, b + 3, b, a)])
        faces.extend([(0, 1, 2, 3),
                      ((len(xs) - 1) * 4, (len(xs) - 1) * 4 + 1,
                       (len(xs) - 1) * 4 + 2, (len(xs) - 1) * 4 + 3)])
        belt.add((verts, faces), BRASS)
    # 上船壳竖向板缝
    for st in h.stations[2:-1]:
        x = st[0]
        for s in (-1.0, 1.0):
            y = h.hull_y_at(x, 2.6)
            belt.add(box((x - 0.05, s * y, 1.34), (x + 0.05, s * (y + 0.05),
                                                   3.52)), METAL)
    add("Armor_Belt", belt)

    keel = Part()
    stem = ([(21.55, -1.05), (21.90, -0.50), (22.10, 0.80), (22.10, 4.02),
             (21.88, 4.02), (21.86, 0.80), (21.62, -0.50)], 0.11)
    keel.merge(build_keel_stem_rudder(h, IRON, METAL, bow_prism=stem,
                                      rudder_z0=-1.55,
                                      prop=(-20.90, -1.95, 1.00)))
    # 撞角（水下前伸楔形）
    ram_bottom = [(21.60, -1.30, -1.70), (21.60, 1.30, -1.70),
                  (21.60, 1.30, 0.55), (21.60, -1.30, 0.55)]
    ram_top = [(23.60, -0.28, -1.08), (23.60, 0.28, -1.08),
               (23.60, 0.28, 0.12), (23.60, -0.28, 0.12)]
    keel.add(hexa(ram_bottom, ram_top), METAL)
    add("Keel_Stem_Rudder", keel)

    transom = Part()
    build_transom(transom, IRON, GLASS, BRASS, -20.30, 3.35, 1.75, 3.72,
                  windows=3, nameplate=True)
    add("Transom", transom)

    # ---- 中央装甲炮房 / 指挥塔 / 烟囱 / 通风筒 ------------------------
    sup = Part()
    deckz = h.deck_z_at(0.0)
    bottom = [(-8.00, -3.65, deckz), (8.00, -3.65, deckz),
              (8.00, 3.65, deckz), (-8.00, 3.65, deckz)]
    top = [(-7.20, -2.95, deckz + 2.39), (7.20, -2.95, deckz + 2.39),
           (7.20, 2.95, deckz + 2.39), (-7.20, 2.95, deckz + 2.39)]
    sup.add(hexa(bottom, top), IRON)
    roof_z = deckz + 2.39
    # 斜壁竖向装甲肋
    for x in (-6.40, -4.20, -2.00, 0.20, 2.40, 4.60, 6.40):
        for s in (-1.0, 1.0):
            pts = []
            for zz in (deckz + 0.06, roof_z - 0.04):
                t = (zz - deckz) / (roof_z - deckz)
                y_wall = s * (3.65 + (2.95 - 3.65) * t)
                pts.append((x + 0.07, y_wall + s * 0.07, zz))
                pts.append((x - 0.07, y_wall + s * 0.07, zz))
                pts.append((x - 0.07, y_wall, zz))
                pts.append((x + 0.07, y_wall, zz))
            bottom_pts = [pts[0], pts[1], pts[2], pts[3]]
            top_pts = [pts[4], pts[5], pts[6], pts[7]]
            sup.add(hexa(bottom_pts, top_pts), METAL)
    # 炮房顶盖黄铜压条 + 栏杆
    for s in (-1.0, 1.0):
        sup.add(box((-7.20, s * 2.95 - 0.05, roof_z - 0.06),
                    (7.20, s * 2.95 + 0.05, roof_z + 0.02)), BRASS)
        sup.add(box((-7.20, s * 3.65 - 0.06, deckz),
                    (7.20, s * 3.65 + 0.06, deckz + 0.18)), BRASS)
    sup.add(box((-7.25, -3.00, roof_z - 0.06), (7.25, 3.00, roof_z + 0.02)),
            IRON)
    for px, py in ((-6.9, -2.70), (6.9, -2.70), (6.9, 2.70), (-6.9, 2.70),
                   (0.0, -2.70), (0.0, 2.70), (-6.9, 0.0), (6.9, 0.0)):
        sup.add(box((px - 0.05, py - 0.05, roof_z), (px + 0.05, py + 0.05,
                                                     roof_z + 0.85)), METAL)
    for s in (-1.0, 1.0):
        sup.add(box((-6.95, s * 2.70 - 0.05, roof_z + 0.80),
                    (6.95, s * 2.70 + 0.05, roof_z + 0.92)), METAL)
        sup.add(box((-6.95, s * 2.70 - 0.05, roof_z + 0.40),
                    (6.95, s * 2.70 + 0.05, roof_z + 0.50)), BRASS)
    sup.add(box((-6.95, -2.75, roof_z + 0.80), (-6.90, 2.75, roof_z + 0.92)),
            METAL)
    sup.add(box((6.90, -2.75, roof_z + 0.80), (6.95, 2.75, roof_z + 0.92)),
            METAL)
    # 指挥塔（炮房前方）
    sup.add(translate(revolved([(deckz, 1.15), (deckz + 1.85, 1.05),
                                (deckz + 1.95, 1.10)], 10), 9.80, 0.0, 0.0),
            IRON)
    for k in range(4):
        a = math.pi / 4.0 + k * math.pi / 2.0
        cx = 9.80 + 1.08 * math.cos(a)
        cy = 1.08 * math.sin(a)
        sup.add(box((cx - 0.24, cy - 0.06, deckz + 1.35),
                    (cx + 0.24, cy + 0.06, deckz + 1.65)), DARK)
    sup.add(translate(revolved([(deckz + 1.92, 1.18), (deckz + 2.02, 1.18)], 10),
                      9.80, 0.0, 0.0), BRASS)
    # 烟囱（单烟囱 = 铁甲舰变体识别特征）
    build_smokestack(sup, RAIDER_FUNNEL, METAL, BRASS, IRON)
    # 炮房顶通风筒 + 天窗
    for x in (4.60, -6.20):
        sup.add(translate(revolved([(roof_z, 0.30), (roof_z + 1.05, 0.24)], 8),
                          x, 0.0, 0.0), METAL)
        sup.add(translate(box((-0.26, -0.26, roof_z + 1.02),
                              (0.26, 0.26, roof_z + 1.30)), x, 0.0, 0.0), METAL)
    sup.add(box((-1.10, -1.10, roof_z), (1.10, 1.10, roof_z + 0.22)), BRASS)
    sup.add(box((-1.00, -1.00, roof_z + 0.22), (1.00, 1.00, roof_z + 0.26)),
            DARK)
    # 艏部甲板木板平台（避开 x=13 的 Heavy 炮位射线净空）
    sup.add(box((14.40, -1.80, deckz), (16.00, 1.80, deckz + 0.20)), WOOD)
    add("Superstructure", sup)

    # 舷侧炮门（空）
    add("Gun_Ports", _raider_gun_ports_part())

    # ---- 单桅（蒸汽桅）+ 横桁 + 收帆 + 索具 ---------------------------
    mast = Part()
    b = rig_kit.builder(mast, _core, materials=rig_kit.KIT_MATERIALS)
    rig_kit.steamer_mast(b, RAIDER_MAST)
    for yard_z, half in ((12.80, 3.20), (15.50, 2.20)):
        x = RAIDER_MAST["x"] + 0.30
        b.add(_core.taper_cyl((x, -half, yard_z), (x, half, yard_z),
                              0.115, 0.090, 6), b.mat("wood"))
        b.add(_core.taper_cyl((x - 0.08, -0.66 * half, yard_z - 0.20),
                              (x - 0.08, 0.66 * half, yard_z - 0.20),
                              0.18, 0.18, 8), b.mat("canvas_shade"))
        for s in (-1, 1):
            b.add(_core.taper_cyl((x, s * half - 0.10, yard_z),
                                  (x, s * half + 0.22, yard_z),
                                  0.14, 0.14, 6), b.mat("metal"))
    add("Mast", mast)

    rig = Part()
    bx = rig_kit.builder(rig, _core, materials=rig_kit.KIT_MATERIALS)
    top = (RAIDER_MAST["x"], 0.0, RAIDER_MAST["z_top"] - 0.20)
    mid = (RAIDER_MAST["x"], 0.0, RAIDER_MAST["z_top"] - 2.20)
    lines = [
        (top, (20.60, 0.0, 4.30)),
        (top, (-19.60, 0.0, 4.90)),
        (mid, (20.60, 0.0, 4.30)),
        (mid, (-19.60, 0.0, 4.90)),
        (top, (-3.00, 0.0, RAIDER_FUNNEL["z1"])),
    ]
    for s in (-1.0, 1.0):
        for dx in (-1.60, 0.0, 1.60):
            x = RAIDER_MAST["x"] + dx
            y = h.deck_w_frac * h.half_beam_at(x)
            lines.append((top, (x, s * y, h.deck_surface_z(x) + 0.02)))
    for p0, p1 in lines:
        bx.add(_core.taper_cyl(p0, p1, 0.030, 0.030, 4), bx.mat("metal"))
    add("Rigging", rig)

    # ---- 甲板属具 ----------------------------------------------------
    fit = Part()
    deck_kit.hatch(fit, -13.50, 2.20, 1.80, h.deck_top(-13.50, 0.0),
                   hull_mat=DARK, wood_mat=WOOD, dark_mat=DARK)
    deck_kit.capstan(fit, 17.20, h.deck_top(17.20, 0.0), dark_mat=DARK,
                     wood_mat=WOOD)
    deck_kit.wheel(fit, -16.60, h.deck_top(-16.60, 0.0) + 0.02, 0.62, 0.055,
                   dark_mat=DARK, wood_mat=WOOD)
    deck_kit.binnacle(fit, -15.80, h.deck_top(-15.80, 0.0), dark_mat=DARK,
                      wood_mat=WOOD, brass_mat=BRASS)
    for x, s in ((18.90, 1), (18.90, -1), (-17.80, 1), (-17.80, -1),
                 (12.20, 1), (12.20, -1), (-11.20, 1), (-11.20, -1)):
        deck_kit.bollard(fit, x, s * (h.deck_w_frac * h.half_beam_at(x) - 0.55),
                         h.deck_top(x, 0.0) + 0.01, dark_mat=DARK)
    for x, s in ((20.30, 1), (20.30, -1)):
        y = s * (h.deck_w_frac * h.half_beam_at(x) - 0.45)
        deck_kit.barrel(fit, x, y, h.deck_top(x, y), wood_mat=WOOD,
                        metal_mat=METAL)
    deck_kit.rope_coil(fit, 11.00, 2.10, h.deck_top(11.00, 2.10) + 0.02,
                       dark_mat=DARK)
    add("Deck_Fittings", fit)

    flag = Part()
    flag.add(taper_cyl((-20.40, 0.0, 3.72), (-20.40, 0.0, 7.10),
                       0.065, 0.038, 6), WOOD)
    build_flag(flag, -20.44, 0.0, 2.80, 5.10, 6.60, RED)
    mtop = (RAIDER_MAST["x"], 0.0, RAIDER_MAST["z_top"] + 0.30)
    flag.add(taper_cyl((mtop[0], 0.0, RAIDER_MAST["z_top"] - 0.10),
                       (mtop[0], 0.0, mtop[2] + 0.45), 0.045, 0.025, 6), WOOD)
    build_pennant(flag, mtop[0], -0.10, mtop[2] + 0.20, 4.00, 0.40, RED)
    add("Flags", flag)
    return parts


def raider_config():
    return dict(
        asset="SN_Enemy_Ironclad_Raider",
        collection="SN_Enemy_Ironclad_Raider_Prototype",
        prefix="SN_ER_",
        root="SN_ER_Root",
        workbench=(75.0, -110.0, 0.0),
        tri_budget=7800,
        enemy_class="Heavy",
        enemy_archetype="ironclad_raider",
        style="low-poly flat-shaded casemate ironclad variant, single funnel",
        pivots=[],
        bbox=(44.85, 14.75, 21.10),
        bbox_tol=(0.90, 0.60, 0.80),
        deck_top=raider_deck_top,
    )


# ============================================================
# 4. 小型炮艇（Light，蒸汽炮艇）
# ============================================================

GUNBOAT_HULL = HullSpec(
    stations=[
        (-7.60, 1.70, 2.05, -0.95),
        (-7.20, 1.95, 2.00, -1.20),
        (-6.40, 2.12, 1.96, -1.40),
        (-5.20, 2.24, 1.93, -1.52),
        (-3.80, 2.30, 1.90, -1.58),
        (-2.20, 2.32, 1.88, -1.60),
        (-0.60, 2.30, 1.88, -1.60),
        (1.00, 2.24, 1.90, -1.55),
        (2.60, 2.14, 1.94, -1.45),
        (4.20, 1.98, 2.00, -1.30),
        (5.60, 1.76, 2.08, -1.12),
        (7.00, 1.45, 2.18, -0.85),
        (7.90, 1.05, 2.30, -0.55),
        (8.40, 0.50, 2.42, -0.15),
    ],
    profile=[(0.00, 0.00), (0.40, 0.015), (0.72, 0.05), (0.90, 0.14),
             (1.00, 0.30), (1.02, 0.50), (1.01, 0.68), (0.99, 0.84),
             (0.97, 1.00)],
    deck_w_frac=0.97, deck_camber=0.07, bulwark_h=0.52, cap_t=0.070,
    bulwark_out=0.030, bulwark_in=0.070,
)

GUNBOAT_MAST = dict(x=2.70, deck_z=1.90, z0=1.88, z_low=4.90, z_top=7.60,
                    r_low=(0.200, 0.130), r_top=(0.090, 0.035))
GUNBOAT_FUNNEL = dict(x=-0.10, z0=2.00, z1=5.60, r0=0.42, r1=0.34,
                      lean=-0.12, base_hw=0.62)
GUNBOAT_CABIN = dict(x0=-3.60, x1=-1.60, hy=1.05, z0=1.88, z1=3.15)
GUNBOAT_SHIELD = dict(x_front=5.95, x_back=4.30, y=1.24, z0=1.88, z1=2.85)


def gunboat_deck_top(x, y):
    return GUNBOAT_HULL.deck_top(x, y)


def _gunboat_parts():
    h = GUNBOAT_HULL
    prefix = "SN_EG_"
    parts = {}

    def add(name, part, parent="ROOT"):
        parts[prefix + name] = (part, parent)

    def hull_mat(x, z):
        return RED if z <= h.keel_z_at(x) + 0.80 else IRON

    add("Hull", build_hull(h, hull_mat))
    add("Deck", build_deck(h, IRON, METAL, ny=8))
    add("Bulwark", build_bulwark(h, IRON, METAL))

    keel = Part()
    stem = ([(8.28, -1.10), (8.50, -0.55), (8.62, 0.55), (8.62, 2.40),
             (8.46, 2.40), (8.44, 0.55), (8.30, -0.55)], 0.08)
    keel.merge(build_keel_stem_rudder(h, IRON, METAL, bow_prism=stem,
                                      rudder_z0=-0.85,
                                      prop=(-7.95, -0.95, 0.75)))
    add("Keel_Stem_Rudder", keel)

    transom = Part()
    build_transom(transom, IRON, GLASS, BRASS, -7.70, 1.55, 0.95, 2.18,
                  windows=2, nameplate=False)
    add("Transom", transom)

    # ---- 驾驶室 / 烟囱 / 装甲炮盾 ------------------------------------
    sup = Part()
    c = GUNBOAT_CABIN
    deckz = h.deck_z_at(-2.60)
    bottom = [(c["x0"], -c["hy"], c["z0"]), (c["x1"], -c["hy"], c["z0"]),
              (c["x1"], c["hy"], c["z0"]), (c["x0"], c["hy"], c["z0"])]
    top = [(c["x0"] + 0.06, -c["hy"] + 0.10, c["z1"]),
           (c["x1"] - 0.04, -c["hy"] + 0.10, c["z1"]),
           (c["x1"] - 0.04, c["hy"] - 0.10, c["z1"]),
           (c["x0"] + 0.06, c["hy"] - 0.10, c["z1"])]
    sup.add(hexa(bottom, top), IRON)
    for s in (-1.0, 1.0):
        for wx in (-3.10, -2.10):
            sup.add(box((wx - 0.36, s * (c["hy"] - 0.02) - 0.03, c["z0"] + 0.42),
                        (wx + 0.36, s * c["hy"] + 0.03, c["z0"] + 0.95)), GLASS)
        sup.add(box((c["x0"] + 0.02, s * (c["hy"] - 0.02) - 0.03,
                     c["z0"] + 0.34),
                    (c["x1"] - 0.02, s * c["hy"] + 0.03, c["z0"] + 0.40)),
                BRASS)
    sup.add(box((c["x0"] + 0.12, -0.34, c["z0"] + 0.30),
                (c["x0"] + 0.16, 0.34, c["z0"] + 1.05)), GLASS)
    sup.add(box((c["x0"] + 0.08, -c["hy"] + 0.06, c["z1"]),
                (c["x1"] - 0.06, c["hy"] - 0.06, c["z1"] + 0.08)), BRASS)
    for s in (-1.0, 1.0):
        sup.add(box((c["x0"] + 0.10, s * (c["hy"] - 0.10) - 0.03,
                     c["z1"] + 0.08),
                    (c["x1"] - 0.08, s * (c["hy"] - 0.10) + 0.03,
                     c["z1"] + 0.70)), METAL)
    sup.add(box((c["x0"] + 0.10, -(c["hy"] - 0.10) - 0.03,
                 c["z1"] + 0.64),
                (c["x1"] - 0.08, (c["hy"] - 0.10) + 0.03, c["z1"] + 0.72)),
            METAL)
    build_smokestack(sup, GUNBOAT_FUNNEL, METAL, BRASS, IRON)

    # 艏部装甲炮盾：U 形三面（正面留炮口）
    sh = GUNBOAT_SHIELD
    for s in (-1.0, 1.0):
        sup.add(box((sh["x_front"] - 0.20, s * 0.46, sh["z0"]),
                    (sh["x_front"], s * sh["y"], sh["z1"] + 0.10)), IRON)
        sup.add(box((sh["x_back"], s * (sh["y"] - 0.10), sh["z0"]),
                    (sh["x_front"], s * sh["y"], sh["z1"] + 0.10)), IRON)
        sup.add(box((sh["x_front"] - 0.21, s * 0.46 - 0.02,
                     sh["z1"] + 0.04),
                    (sh["x_front"] + 0.02, s * sh["y"] + 0.02,
                     sh["z1"] + 0.12)), BRASS)
    sup.add(box((sh["x_front"] - 0.20, -0.46, sh["z1"] - 0.16),
                (sh["x_front"], 0.46, sh["z1"] + 0.10)), IRON)
    for s in (-1.0, 1.0):
        sup.add(box((sh["x_back"] - 0.12, s * (sh["y"] - 0.22) - 0.06,
                     sh["z0"]),
                    (sh["x_back"], s * (sh["y"] - 0.22) + 0.06,
                     sh["z1"] - 0.10)), METAL)
    add("Superstructure", sup)

    # ---- 桅 / 横桁 / 索具 --------------------------------------------
    mast = Part()
    b = rig_kit.builder(mast, _core, materials=rig_kit.KIT_MATERIALS)
    rig_kit.steamer_mast(b, GUNBOAT_MAST)
    yard_z = 6.30
    b.add(_core.taper_cyl((GUNBOAT_MAST["x"] + 0.22, -1.30, yard_z),
                          (GUNBOAT_MAST["x"] + 0.22, 1.30, yard_z),
                          0.075, 0.060, 6), b.mat("wood"))
    b.add(_core.taper_cyl((GUNBOAT_MAST["x"] + 0.14, -0.86, yard_z - 0.16),
                          (GUNBOAT_MAST["x"] + 0.14, 0.86, yard_z - 0.16),
                          0.12, 0.12, 8), b.mat("canvas_shade"))
    for s in (-1, 1):
        b.add(_core.taper_cyl((GUNBOAT_MAST["x"] + 0.22, s * 1.20, yard_z),
                              (GUNBOAT_MAST["x"] + 0.22, s * 1.42, yard_z),
                              0.10, 0.10, 6), b.mat("metal"))
    add("Mast", mast)

    rig = Part()
    bx = rig_kit.builder(rig, _core, materials=rig_kit.KIT_MATERIALS)
    top = (GUNBOAT_MAST["x"], 0.0, GUNBOAT_MAST["z_top"] - 0.20)
    lines = [(top, (8.35, 0.0, 2.48)), (top, (-7.55, 0.0, 2.15)),
             (top, (0.0, 0.0, GUNBOAT_FUNNEL["z1"]))]
    for s in (-1.0, 1.0):
        for dx in (-0.85, 0.85):
            x = GUNBOAT_MAST["x"] + dx
            y = h.deck_w_frac * h.half_beam_at(x)
            lines.append((top, (x, s * y, h.deck_surface_z(x) + 0.02)))
    for p0, p1 in lines:
        bx.add(_core.taper_cyl(p0, p1, 0.026, 0.026, 4), bx.mat("metal"))
    add("Rigging", rig)

    # ---- 甲板属具 ----------------------------------------------------
    fit = Part()
    deck_kit.hatch(fit, -4.40, 1.20, 1.00, h.deck_top(-4.40, 0.0),
                   hull_mat=DARK, wood_mat=WOOD, dark_mat=DARK)
    deck_kit.windlass(fit, 1.20, h.deck_top(1.20, 0.0), dark_mat=DARK,
                      wood_mat=WOOD)
    deck_kit.wheel(fit, -6.30, h.deck_top(-6.30, 0.0) + 0.02, 0.44, 0.042,
                   dark_mat=DARK, wood_mat=WOOD)
    deck_kit.binnacle(fit, -5.70, h.deck_top(-5.70, 0.0), dark_mat=DARK,
                      wood_mat=WOOD, brass_mat=BRASS)
    for x, s in ((6.90, 1), (6.90, -1), (-6.90, 1), (-6.90, -1),
                 (-3.40, 1), (-3.40, -1)):
        deck_kit.bollard(fit, x, s * (h.deck_w_frac * h.half_beam_at(x) - 0.38),
                         h.deck_top(x, 0.0) + 0.01, dark_mat=DARK)
    deck_kit.barrel(fit, 0.20, 1.55, h.deck_top(0.20, 1.55), wood_mat=WOOD,
                    metal_mat=METAL)
    add("Deck_Fittings", fit)

    flag = Part()
    mtop = (GUNBOAT_MAST["x"], 0.0, GUNBOAT_MAST["z_top"] + 0.25)
    flag.add(taper_cyl((GUNBOAT_MAST["x"], 0.0, GUNBOAT_MAST["z_top"] - 0.10),
                       (mtop[0], 0.0, mtop[2] + 0.40), 0.040, 0.022, 6), WOOD)
    build_pennant(flag, mtop[0], -0.08, mtop[2] + 0.15, 2.80, 0.30, RED)
    flag.add(taper_cyl((-7.45, 0.0, 2.18), (-7.45, 0.0, 3.90), 0.045, 0.028, 6),
             WOOD)
    build_flag(flag, -7.49, 0.0, 1.50, 3.05, 3.80, RED)
    add("Flags", flag)
    return parts


def gunboat_config():
    return dict(
        asset="SN_Enemy_Gunboat",
        collection="SN_Enemy_Gunboat_Prototype",
        prefix="SN_EG_",
        root="SN_EG_Root",
        workbench=(-95.0, -110.0, 0.0),
        tri_budget=3600,
        enemy_class="Light",
        enemy_archetype="gunboat",
        style="low-poly flat-shaded steam gunboat with armoured bow shield",
        pivots=[],
        bbox=(16.90, 4.75, 10.10),
        bbox_tol=(0.55, 0.35, 0.55),
        deck_top=gunboat_deck_top,
    )


# ============================================================
# 注册表 / 武器 socket / 炮门 socket
# ============================================================

SHIP_PARTS = {
    "SN_Enemy_Pirate_Sloop": _sloop_parts,
    "SN_Enemy_Merchant_Armed": _merchant_parts,
    "SN_Enemy_Ironclad_Raider": _raider_parts,
    "SN_Enemy_Gunboat": _gunboat_parts,
}
SHIP_CONFIG_FACTORIES = {
    "SN_Enemy_Pirate_Sloop": sloop_config,
    "SN_Enemy_Merchant_Armed": merchant_config,
    "SN_Enemy_Ironclad_Raider": raider_config,
    "SN_Enemy_Gunboat": gunboat_config,
}
SHIP_CONFIGS = {asset: factory() for asset, factory in SHIP_CONFIG_FACTORIES.items()}
SHIP_CLASS_ORDER = ["SN_Enemy_Pirate_Sloop", "SN_Enemy_Gunboat",
                    "SN_Enemy_Merchant_Armed", "SN_Enemy_Ironclad_Raider"]


def _sock(asset, suffix, x, y, rot_z, socket_class, clearance_r,
          clearance_x, clearance_y, note, clearance_h=20.0):
    """构建一条甲板 socket 规格；declared 值必须 <= 实测值（脚本断言）。"""
    top = SHIP_CONFIGS[asset]["deck_top"]
    return {
        "suffix": suffix,
        "x": float(x),
        "y": float(y),
        "rot_z": float(rot_z),
        "socket_class": socket_class,
        "clearance_r": float(clearance_r),
        "clearance_x": float(clearance_x),
        "clearance_y": float(clearance_y),
        "clearance_h": float(clearance_h),
        "deck_z": round(top(x, y), 4),
        "note": note,
    }


# clearance 声明口径：一律低于 Blender 内 16 向 / 向上射线实测值（脚本断言
# 实测 >= 声明 - 0.06 m）。木甲板款带索具 / 上层建筑的船，clearance_h 低于 20。
WEAPON_SOCKETS = {
    "SN_Enemy_Pirate_Sloop": [
        _sock("SN_Enemy_Pirate_Sloop", "Port_1", -3.0, 1.55, 90.0, "Light",
              0.85, 0.85, 1.40, "后甲板左舷：主舱口与舵轮柜之间，轻型舷炮位"),
        _sock("SN_Enemy_Pirate_Sloop", "Starboard_1", -3.0, -1.55, -90.0,
              "Light", 0.85, 0.85, 1.40, "后甲板右舷，与 Port_1 镜像"),
        _sock("SN_Enemy_Pirate_Sloop", "Bow", 8.80, 0.0, 0.0, "Light",
              0.90, 0.90, 1.10, "艏甲板中线：艏炮位，+X 朝船首",
              clearance_h=3.80),
    ],
    "SN_Enemy_Merchant_Armed": [
        _sock("SN_Enemy_Merchant_Armed", "Port_1", 6.0, 2.90, 90.0, "Medium",
              0.80, 0.80, 1.70, "前甲板左舷：货舱口与前桅之间，中型舷炮位"),
        _sock("SN_Enemy_Merchant_Armed", "Starboard_1", 6.0, -2.90, -90.0,
              "Medium", 0.80, 0.80, 1.70, "前甲板右舷，与 Port_1 镜像"),
        _sock("SN_Enemy_Merchant_Armed", "Port_2", -8.0, 3.10, 90.0, "Medium",
              0.75, 0.75, 1.70, "主甲板左舷后段：主桅与艉楼之间，中型舷炮位"),
        _sock("SN_Enemy_Merchant_Armed", "Starboard_2", -8.0, -3.10, -90.0,
              "Medium", 0.75, 0.75, 1.70, "主甲板右舷后段，与 Port_2 镜像"),
        _sock("SN_Enemy_Merchant_Armed", "Bow", 14.0, 0.0, 0.0, "Medium",
              1.00, 1.00, 1.20, "艏甲板中线：猎击炮位，+X 朝船首",
              clearance_h=6.80),
        _sock("SN_Enemy_Merchant_Armed", "Stern", -15.60, 0.0, 180.0, "Medium",
              0.80, 0.80, 1.20, "艉楼甲板中线：舰尾炮位，+X 朝船尾",
              clearance_h=1.40),
    ],
    "SN_Enemy_Ironclad_Raider": [
        _sock("SN_Enemy_Ironclad_Raider", "Port_1", 13.0, 3.20, 90.0, "Heavy",
              1.60, 1.60, 4.00, "炮房前方左舷甲板：重炮位，与舷侧炮列同侧"),
        _sock("SN_Enemy_Ironclad_Raider", "Starboard_1", 13.0, -3.20, -90.0,
              "Heavy", 1.60, 1.60, 4.00, "炮房前方右舷甲板，与 Port_1 镜像"),
        _sock("SN_Enemy_Ironclad_Raider", "Port_2", -13.0, 2.80, 90.0,
              "Medium", 1.60, 1.60, 3.60, "后甲板左舷：烟囱与艉部之间，中型炮位"),
        _sock("SN_Enemy_Ironclad_Raider", "Starboard_2", -13.0, -2.80, -90.0,
              "Medium", 1.60, 1.60, 3.60, "后甲板右舷，与 Port_2 镜像"),
    ],
    "SN_Enemy_Gunboat": [
        _sock("SN_Enemy_Gunboat", "Bow_1", 4.40, 0.0, 0.0, "Heavy",
              1.00, 1.00, 1.10, "艏部装甲炮盾内：固定重炮位，+X 朝船首",
              clearance_h=3.50),
        _sock("SN_Enemy_Gunboat", "Port_1", -4.50, 1.35, 90.0, "Light",
              0.65, 0.65, 1.10, "后甲板左舷：驾驶室后方轻型炮位"),
        _sock("SN_Enemy_Gunboat", "Starboard_1", -4.50, -1.35, -90.0, "Light",
              0.65, 0.65, 1.10, "后甲板右舷，与 Port_1 镜像"),
    ],
}


def glb_weapon_socket_name(suffix):
    return "SN_Socket_Weapon_" + suffix


def blend_weapon_socket_name(asset, suffix):
    return SHIP_CONFIGS[asset]["prefix"] + "Socket_Weapon_" + suffix


def glb_gun_port_socket_name(suffix):
    return "SN_Socket_GunPort_" + suffix


def blend_gun_port_socket_name(asset, suffix):
    return SHIP_CONFIGS[asset]["prefix"] + "Socket_GunPort_" + suffix


def weapon_socket_entries(asset):
    """按 socket_index 顺序返回 [(index, spec)]。"""
    return list(enumerate(WEAPON_SOCKETS[asset], start=1))


def expected_weapon_socket_names(asset):
    return [glb_weapon_socket_name(spec["suffix"])
            for _i, spec in weapon_socket_entries(asset)]


GUN_PORTS = {"SN_Enemy_Ironclad_Raider": []}
for _side_name, _side in (("Port", 1), ("Starboard", -1)):
    for _i, _x in enumerate(RAIDER_GUN_X, start=1):
        _pose = raider_gun_port_pose(_x, _side)
        GUN_PORTS["SN_Enemy_Ironclad_Raider"].append({
            "suffix": "%s_%d" % (_side_name, _i),
            "side_index": _i,
            "x": float(_x),
            "side": int(_side),
            "port_class": "Medium",
            "port_w": round(RAIDER_PORT_W, 3),
            "port_h": round(RAIDER_GUN_Z1 - RAIDER_GUN_Z0, 3),
            "sill_z": round(RAIDER_GUN_Z0, 3),
            "deck_z": round(_pose["deck_z"], 3),
            "inboard_depth": 1.10,
            "outboard_clearance": 6.00,
            "lid": "top",
            "lid_hinge_z": round(RAIDER_GUN_Z1 + 0.18, 3),
            "elev_min_deg": -6.0,
            "elev_max_deg": 12.0,
            "traverse_deg": 0.0,
            "mount_scale": 1.0,
            "note": "空炮门：炮管由 SN_Weapon_CasemateGun 模块经 port_pitch 装配",
        })


def gun_port_entries(asset):
    return list(enumerate(GUN_PORTS.get(asset, []), start=1))


def expected_gun_port_names(asset):
    return [glb_gun_port_socket_name(spec["suffix"])
            for _i, spec in gun_port_entries(asset)]


def gun_port_pose_for(asset, suffix):
    for _index, spec in gun_port_entries(asset):
        if spec["suffix"] == suffix:
            return raider_gun_port_pose(spec["x"], spec["side"])
    raise KeyError("%s 没有炮门 %s" % (asset, suffix))


def validate_specs():
    """纯 Python 规格自检（dryrun / 构建前门禁共用）。"""
    failures = []
    for asset, cfg in SHIP_CONFIGS.items():
        socks = WEAPON_SOCKETS.get(asset, [])
        if len(socks) < 2:
            failures.append("%s: 武器 socket 少于 2 个" % asset)
        names = set()
        for index, spec in weapon_socket_entries(asset):
            name = glb_weapon_socket_name(spec["suffix"])
            if name in names:
                failures.append("%s: 重复 socket 名 %s" % (asset, name))
            names.add(name)
            if spec["socket_class"] not in {"Light", "Medium", "Heavy", "Tower",
                                            "Side"}:
                failures.append("%s: %s class 非法" % (asset, name))
            if spec["clearance_r"] < 0.5:
                failures.append("%s: %s clearance_r 过小" % (asset, name))
            if spec["clearance_r"] > min(spec["clearance_x"],
                                         spec["clearance_y"]) + 1e-6:
                failures.append("%s: %s clearance_r 大于 cx/cy" % (asset, name))
            if abs(spec["rot_z"] % 360.0) not in (0.0, 90.0, 180.0, 270.0):
                failures.append("%s: %s rot_z 不是 90° 倍数" % (asset, name))
            if abs(spec["y"]) + 0.12 >= _deck_half_width(asset, spec["x"]):
                failures.append("%s: %s y=%.2f 超出甲板半宽" % (asset, name,
                                                             spec["y"]))
            if spec["deck_z"] <= 0.0:
                failures.append("%s: %s deck_z 非法" % (asset, name))
        by_suffix = {spec["suffix"]: spec for spec in socks}
        for spec in socks:
            suffix = spec["suffix"]
            if suffix.startswith("Port_"):
                mirror = "Starboard_" + suffix[len("Port_"):]
                other = by_suffix.get(mirror)
                if other is None:
                    failures.append("%s: %s 缺镜像 %s" % (asset, suffix, mirror))
                    continue
                if abs(spec["x"] - other["x"]) > 1e-6 or \
                        abs(spec["y"] + other["y"]) > 1e-6:
                    failures.append("%s: %s 不镜像" % (asset, suffix))
    # 炮门：左右各 4 个、class 与端口尺寸满足 casemate 模块
    for asset in ("SN_Enemy_Ironclad_Raider",):
        ports = GUN_PORTS.get(asset, [])
        if len(ports) != 8:
            failures.append("%s: 炮门数量 %d != 8" % (asset, len(ports)))
        for spec in ports:
            if spec["port_class"] != "Medium":
                failures.append("%s/%s: port_class 必须 Medium（匹配 casemate 炮）"
                                % (asset, spec["suffix"]))
            if spec["port_w"] < 1.90 or spec["port_h"] < 1.90:
                failures.append("%s/%s: 炮门开口小于 casemate 炮 1.9×1.9"
                                % (asset, spec["suffix"]))
            if spec["deck_z"] <= spec["sill_z"]:
                failures.append("%s/%s: deck_z 不高于 sill_z"
                                % (asset, spec["suffix"]))
    return failures


HULLS = {
    "SN_Enemy_Pirate_Sloop": SLOOP_HULL,
    "SN_Enemy_Merchant_Armed": MERCHANT_HULL,
    "SN_Enemy_Ironclad_Raider": RAIDER_HULL,
    "SN_Enemy_Gunboat": GUNBOAT_HULL,
}


def _deck_half_width(asset, x):
    hull = HULLS[asset]
    return hull.deck_w_frac * hull.half_beam_at(x)


# ============================================================
# 装配（Blender 侧）
# ============================================================

def build_all_geometry(asset):
    return SHIP_PARTS[asset]()


def build_config(asset):
    cfg = SHIP_CONFIGS[asset]
    pivots = cfg["pivots"]
    origins = {"ROOT": (0.0, 0.0, 0.0)}
    for pivot in pivots:
        origins[pivot.key] = (0.0, 0.0, 0.0)
    root_props = {
        "asset": asset,
        "version": "1.0",
        "units": "metres",
        "pivot": "waterline, centre of hull",
        "forward_axis": "+X",
        "style": cfg["style"],
        "tri_budget": cfg["tri_budget"],
        "combat_kit": COMBAT_KIT_SPEC,
        "enemy_class": cfg["enemy_class"],
        "enemy_archetype": cfg["enemy_archetype"],
        "baked_weapons": False,
        "weapon_socket_spec": SOCKET_SPEC,
    }
    if GUN_PORTS.get(asset):
        root_props["gun_port_socket_spec"] = GUN_PORT_SPEC
    return assembly.BuildConfig(
        collection=cfg["collection"],
        prefix=cfg["prefix"],
        root_name=cfg["root"],
        workbench_pos=cfg["workbench"],
        material_colors=dict(MATERIAL_FALLBACK),
        material_reuse={},
        root_props=root_props,
        pivots=list(pivots),
        origins=origins,
        name_plates={},
        text_material=BRASS,
        report_title=asset,
        tri_budget=cfg["tri_budget"],
        root_size=3.0,
    )


def build_all(asset):
    """在 Blender 中幂等重建一艘敌舰（几何 + 共享贴图材质 / UV）。"""
    import bpy
    import sn_shared_materials as shared

    shared.build_materials(force=False)
    cfg = build_config(asset)
    parts = build_all_geometry(asset)
    coll = assembly.build_collection(parts, cfg)
    root = bpy.data.objects.get(cfg.root_name)
    if root is None:
        raise RuntimeError("找不到根节点 %s" % cfg.root_name)
    report = shared.apply_collection(coll, space="root", root=root)
    if report.get("failures"):
        raise RuntimeError("%s: 共享贴图材质/UV 失败 %r"
                           % (asset, report["failures"]))
    tris = sum(tri_count(part) for part, _parent in parts.values())
    print("COMBAT_KIT %-26s objects=%d meshes=%d tris=%d uv_loops=%d"
          % (asset, len(coll.objects), report["objects"], tris,
             report["uv_loops"]))
    return coll


def build_all_ships():
    results = []
    for asset in SHIP_CLASS_ORDER:
        results.append(build_all(asset))
    return results


def world_vertices(asset, parts=None):
    """把 Pivot 子件按装配变换（绕 Y 旋转 + Pivot 位移）折算到根坐标。

    纯 Python 的包围盒 / z 范围必须与 Blender 装配后的世界坐标一致，否则
    `report()` 与 GLB 实测会差一个 Pivot 偏置（2026-10-22 merchant 桅顶差 0.33 m）。
    """
    parts = parts if parts is not None else build_all_geometry(asset)
    pivots = {pivot.key: pivot for pivot in SHIP_CONFIGS[asset]["pivots"]}
    for _name, (part, parent) in parts.items():
        if parent == "ROOT" or parent not in pivots:
            yield part.verts
            continue
        pivot = pivots[parent]
        rotation = pivot.rotation
        location = pivot.location
        if abs(rotation[0]) > 1e-9 or abs(rotation[2]) > 1e-9:
            raise RuntimeError("world_vertices 只支持绕 Y 的 Pivot 旋转")
        ca, sa = math.cos(rotation[1]), math.sin(rotation[1])
        yield [(location[0] + x * ca + z * sa,
                location[1] + y,
                location[2] - x * sa + z * ca)
               for (x, y, z) in part.verts]


def report(asset, verbose=True):
    """纯几何统计（不 import bpy）：tri / 包围盒 / 材质 / 对象清单。"""
    parts = build_all_geometry(asset)
    tris = 0
    mn = [1e18] * 3
    mx = [-1e18] * 3
    materials = set()
    for _name, (part, _parent) in parts.items():
        tris += tri_count(part)
        materials.update(m for _f, m in part.faces)
    for verts in world_vertices(asset, parts):
        for vertex in verts:
            for axis in range(3):
                if vertex[axis] < mn[axis]:
                    mn[axis] = vertex[axis]
                if vertex[axis] > mx[axis]:
                    mx[axis] = vertex[axis]
    size = [round(mx[i] - mn[i], 3) for i in range(3)]
    info = {
        "asset": asset,
        "objects": len(parts),
        "tris": tris,
        "budget": SHIP_CONFIGS[asset]["tri_budget"],
        "size": size,
        "z_min": round(mn[2], 3),
        "z_max": round(mx[2], 3),
        "materials": sorted(materials),
        "unknown_materials": sorted(materials - ALLOWED_MATERIALS),
        "weapon_sockets": len(WEAPON_SOCKETS.get(asset, [])),
        "gun_ports": len(GUN_PORTS.get(asset, [])),
    }
    if verbose:
        print("COMBAT_KIT_REPORT " + repr(info))
    return info


if __name__ == "__main__":
    build_all_ships()

