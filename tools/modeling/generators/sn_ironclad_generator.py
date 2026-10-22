# -*- coding: utf-8 -*-
# @static-doc
# 作用：舷侧炮铁甲舰 `SN_Ironclad` 的参数化生成脚本（纯 Python 几何 + Blender 装配入口），
# 同时是**炮门几何参数**唯一真源：`GUN_X` / `GUN_Z0..1` / `GUN_LENGTH` / `gun_port_pose()`，
# 供 `sn_ship_gun_ports.py`（船体 socket）与 `sn_casemate_gun_generator.py`（独立炮模块）复用。
#
# 工单：tools/modeling/briefs/sn_ironclad_broadside.json
# 集合：`SN_Ironclad_Prototype`；工作台摆位 (0, 90, 0)；轴心 = 水线中心（x=0 船中、z=0 水线、+X 船首）
# 尺寸：60.0 × 18.0 × 28.65 m（LOA 含艏斜桁与艉廊；z -4.2 .. 24.45），预算 ≤ 12 000 tri
# 材质：共享贴图 `SN_Tex_*`（8 个槽）；UV 由 `sn_shared_materials.apply_collection(space="local")` 写
#
# 设计（1860 年代舷侧炮铁甲舰）
# - 低干舷铁壳：17 站放样，装甲带外凸 380 mm；水下锈红、水线以上铁灰。
# - 撞角艏 + 艉廊；水线装甲带带竖向板缝。
# - 舷侧炮门：每舷 6 个（炮门框 + 深色炮口板 + 上翻炮门盖），另 2 门艏 pivot 炮。
# - 中央装甲炮房（斜壁）+ 指挥塔 + 双后倾烟囱 + 通风筒 + 天窗。
# - 三桅横桁 + 艏斜桁 + 支索/侧支索；甲板：木甲板、舷墙、舱口格栅、绞盘、舵轮、小艇、锚、螺旋桨、艉旗。
#
# 2026-10-22 casemate 模块化（本批）：船体**不再烘炮管/炮口箍**——
# `build_guns(with_barrels=False)` 只留炮门框 + 深色炮口板 + 炮门盖；炮管改为独立模块
# `SN_Weapon_CasemateGun`，经 12 个 `SN_Socket_GunPort_*` 挂载（契约见
# docs/design/WEAPON_SOCKET_CONTRACT.md §9）。`with_barrels=True` 仍保留“炮管烘死”的旧变体，
# 仅供 `apply_casemate_assets.py` 做“现存资产 = 生成器”的几何门禁与差异比对。
#
# 用法：
# - Blender 内：`import runpy; runpy.run_path(<本文件>, run_name="__main__")`
# - 纯 Python 干跑：`python tools/modeling/generators/dryrun_ironclad.py`
# @end-static-doc

import math
import os
import sys

try:
    _HERE = os.path.dirname(os.path.abspath(__file__))
except NameError:  # Blender Text Editor / 无 __file__ 时回退
    _HERE = os.getcwd()
if _HERE not in sys.path:
    sys.path.insert(0, _HERE)

import rig_kit  # noqa: E402

COLLECTION = "SN_Ironclad_Prototype"
OBJECT = "SN_Ironclad"
WORKBENCH_POS = (0.0, 90.0, 0.0)
TARGET_SIZE = (60.0, 18.0, 28.65)
TRI_BUDGET = 12000
Z_MIN = -4.2
Z_MAX = 24.45

# 共享贴图材质（2026-10-22 起：旧纯色名已由 legacy UV 迁移 B 换名，生成器同步到同一套）
IRON = "SN_Tex_Iron"
RED = "SN_Tex_Iron_Red"
DECK = "SN_Tex_Wood_Deck"
WOOD = "SN_Tex_Wood"
DARK = "SN_Tex_Wood_Dark"
MET = "SN_Tex_Metal"
BRASS = "SN_Tex_Brass"
CANVAS = "SN_Tex_Canvas_Shade"

ALLOWED_MATERIALS = {IRON, RED, DECK, WOOD, DARK, MET, BRASS, CANVAS}
NEW_MATERIALS = {}  # 共享贴图材质由 sn_shared_materials.build_materials() 统一创建

# 船体站：x 从艉到艏（m）
STATIONS = [-26.0, -23.0, -19.5, -16.0, -12.5, -9.0, -5.5, -2.0, 1.5,
            5.0, 8.5, 12.0, 15.5, 19.0, 22.0, 24.5, 27.0]
DECK_Z = 4.6
KEEL_Z = -4.2

# 每舷炮门中心 x（英雄化：6 门/舷，间距约 7 m，读感优先于写实密度）
GUN_X = [-17.5, -10.5, -3.5, 3.5, 10.5, 17.5]

# --------------------------------------------------------------------------- #
# 炮门 / 炮管几何参数（船体与独立 casemate 炮模块的唯一真源）
# --------------------------------------------------------------------------- #
GUN_Z0, GUN_Z1 = 1.30, 3.20              # 炮门上下沿（船体局部 z）
GUN_Z_MID = (GUN_Z0 + GUN_Z1) / 2.0      # 2.25
GUN_PORT_HALF = 0.95                     # 炮门半宽（沿 x）
GUN_PORT_FRAME = 0.20                    # 炮门框宽
GUN_INBOARD = 0.40                       # 炮尾起点在船壳面内侧 0.40 m（炮尾藏进船体）
GUN_LENGTH = 1.95                        # 炮管全长（沿炮膛轴线）
GUN_R_BREECH, GUN_R_MUZZLE = 0.44, 0.36  # 炮尾 / 炮口半径
GUN_MUZZLE_BAND_FROM = 1.78              # 炮口箍起点（沿轴线的距离）
GUN_MUZZLE_BAND_R = 0.50                 # 炮口箍半径
GUN_TOE_OUT = 0.21                       # 炮管前外张（+X 分量，固定机位可读性）
GUN_RISE = 0.03                          # 炮管上抬（+Z 分量）


# 三桅：x / 下桅顶 / 上桅顶 / 横桁 (z, 半长)
MASTS = [
    dict(x=15.0, lower_top=14.8, top_top=23.0,
         yards=[(13.8, 9.0), (17.8, 7.2), (21.2, 5.0)]),
    dict(x=-10.0, lower_top=15.5, top_top=24.2,
         yards=[(14.4, 8.0), (18.4, 6.4), (22.0, 4.6)]),
    dict(x=-20.0, lower_top=13.2, top_top=20.5,
         yards=[(12.6, 6.0), (16.2, 4.6), (19.0, 3.4)]),
]

FUNNELS = [
    dict(x=1.4, z0=7.0, z1=14.6, r0=0.85, r1=0.60, lean=-0.60),
    dict(x=-2.2, z0=7.0, z1=14.2, r0=0.80, r1=0.57, lean=-0.55),
]


# --------------------------------------------------------------------------- #
# 纯几何工具（无 bpy 依赖）
# --------------------------------------------------------------------------- #

class Part:
    def __init__(self):
        self.verts = []
        self.faces = []

    def add(self, verts, faces, material):
        offset = len(self.verts)
        self.verts.extend(verts)
        for face in faces:
            self.faces.append((tuple(i + offset for i in face), material))

    def add_indexed(self, verts, faces_mats):
        offset = len(self.verts)
        self.verts.extend(verts)
        for face, material in faces_mats:
            self.faces.append((tuple(i + offset for i in face), material))


def box(lo, hi):
    x0, y0, z0 = lo
    x1, y1, z1 = hi
    return hexa(
        [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0)],
        [(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)],
    )


def hexa(bottom, top):
    verts = list(bottom) + list(top)
    faces = [
        (0, 3, 2, 1), (4, 5, 6, 7),
        (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7),
    ]
    return verts, faces


def translate(vf, dx, dy, dz):
    verts, faces = vf
    return [(x + dx, y + dy, z + dz) for x, y, z in verts], faces


def ring(n, rx, ry, z, cx=0.0, cy=0.0, phase=None):
    if phase is None:
        phase = math.pi / n
    return [
        (cx + rx * math.cos(phase + 2.0 * math.pi * i / n),
         cy + ry * math.sin(phase + 2.0 * math.pi * i / n),
         z)
        for i in range(n)
    ]


def revolved(profile, sides):
    """垂直回转体：profile = [(z, r), ...]；r=0 的端部用单极点收口（不产生退化面）。"""
    phase = math.pi / sides
    body = list(profile)
    bottom_pole = None
    top_pole = None
    if body[0][1] < 1e-9:
        bottom_pole = (0.0, 0.0, body[0][0])
        body = body[1:]
    if body[-1][1] < 1e-9:
        top_pole = (0.0, 0.0, body[-1][0])
        body = body[:-1]
    verts = []
    offsets = []
    for z, r in body:
        offsets.append(len(verts))
        verts.extend(ring(sides, r, r, z, phase=phase))
    faces = []
    for k in range(len(body) - 1):
        a, b = offsets[k], offsets[k + 1]
        for i in range(sides):
            j = (i + 1) % sides
            faces.append((a + i, a + j, b + j, b + i))
    if bottom_pole is not None:
        pi = len(verts)
        verts.append(bottom_pole)
        a = offsets[0]
        for i in range(sides):
            faces.append((pi, a + (i + 1) % sides, a + i))
    else:
        a = offsets[0]
        for i in range(1, sides - 1):
            faces.append((a, a + i + 1, a + i))
    if top_pole is not None:
        ti = len(verts)
        verts.append(top_pole)
        a = offsets[-1]
        for i in range(sides):
            faces.append((ti, a + i, a + (i + 1) % sides))
    else:
        a = offsets[-1]
        for i in range(1, sides - 1):
            faces.append((a, a + i, a + i + 1))
    return verts, faces


def taper_cyl(p0, p1, r0, r1, sides=8):
    """任意轴线的锥台（闭合）。"""
    x0, y0, z0 = p0
    x1, y1, z1 = p1
    dx, dy, dz = x1 - x0, y1 - y0, z1 - z0
    length = math.sqrt(dx * dx + dy * dy + dz * dz)
    if length < 1e-9:
        raise ValueError("taper_cyl 长度为 0")
    dx, dy, dz = dx / length, dy / length, dz / length
    # 选一个与轴不平行的参考向量
    if abs(dz) < 0.9:
        rx, ry, rz = 0.0, 0.0, 1.0
    else:
        rx, ry, rz = 1.0, 0.0, 0.0
    ux = dy * rz - dz * ry
    uy = dz * rx - dx * rz
    uz = dx * ry - dy * rx
    ul = math.sqrt(ux * ux + uy * uy + uz * uz)
    ux, uy, uz = ux / ul, uy / ul, uz / ul
    vx = dy * uz - dz * uy
    vy = dz * ux - dx * uz
    vz = dx * uy - dy * ux
    verts = []
    for (cx, cy, cz), r in (((x0, y0, z0), r0), ((x1, y1, z1), r1)):
        for i in range(sides):
            a = 2.0 * math.pi * i / sides
            ca, sa = math.cos(a), math.sin(a)
            verts.append((cx + r * (ux * ca + vx * sa),
                          cy + r * (uy * ca + vy * sa),
                          cz + r * (uz * ca + vz * sa)))
    faces = []
    for i in range(sides):
        j = (i + 1) % sides
        faces.append((i, j, sides + j, sides + i))
    for i in range(1, sides - 1):
        faces.append((0, i + 1, i))
        faces.append((sides, sides + i, sides + i + 1))
    return verts, faces


def strut(p0, p1, r=0.035, sides=4):
    return taper_cyl(p0, p1, r, r, sides)


def loft(sections, mat_fn):
    """沿 X 放样：每站同一顶点数的闭合截面；返回逐面材质。"""
    n = len(sections[0])
    verts = [p for sec in sections for p in sec]
    faces = []
    for k in range(len(sections) - 1):
        a, b = k * n, (k + 1) * n
        for i in range(n):
            j = (i + 1) % n
            face = (a + i, a + j, b + j, b + i)
            faces.append((face, mat_fn(verts, face)))
    # 首尾封盖（三角扇）
    for sec_idx in (0, len(sections) - 1):
        base = sec_idx * n
        for i in range(1, n - 1):
            face = (base, base + i, base + i + 1)
            faces.append((face, mat_fn(verts, face)))
    return verts, faces


def beam_deck(x):
    if x >= 0.0:
        t = x / 28.0
        return 6.0 * max(0.03, 1.0 - t * t) ** 0.55
    t = x / 29.0
    return 6.0 * max(0.05, 1.0 - t * t) ** 0.45


def section(x):
    b = beam_deck(x)
    w = b * 1.06
    return [
        (x, -b, DECK_Z),
        (x, -b * 1.02, 3.2),
        (x, -w, 0.9),
        (x, -w * 0.99, -0.9),
        (x, -w * 0.82, -2.2),
        (x, -w * 0.45, -3.6),
        (x, 0.0, KEEL_Z),
        (x, w * 0.45, -3.6),
        (x, w * 0.82, -2.2),
        (x, w * 0.99, -0.9),
        (x, w, 0.9),
        (x, b * 1.02, 3.2),
        (x, b, DECK_Z),
    ]


def side_y_at(x, z):
    """船壳在 (x, z) 处的半宽（用于贴炮门/装甲带）。"""
    b = beam_deck(x)
    w = b * 1.06
    if z <= 0.9:
        return w
    if z >= 3.2:
        return b * 1.02
    t = (z - 0.9) / (3.2 - 0.9)
    return w + (b * 1.02 - w) * t


def gun_bore_dir(side):
    """炮膛轴线方向（船体局部；side=+1 为 +Y 左舷 / -1 为右舷）。"""
    dx, dy, dz = GUN_TOE_OUT, float(side) * 0.977, GUN_RISE
    length = math.sqrt(dx * dx + dy * dy + dz * dz)
    return (dx / length, dy / length, dz / length)


def gun_port_pose(x, side):
    """炮门平面中心的局部位姿 —— 炮门 socket 与独立 casemate 炮模块共用的挂载基准。

    - `center`：炮膛轴线与船壳面的交点（炮门平面中心）；
    - `bore`：轴线方向 = socket 局部 +X；
    - `rot_z_deg` / `rot_y_deg`：把模块局部 +X 转到轴线的 Blender XYZ 欧拉角（先 Z 后 Y）；
    - `plane_offset` / `protrusion`：炮门平面在烘焙炮管上的位置 / 门外的外露长度。
    """
    y_mid = side_y_at(x, GUN_Z_MID)
    dx, dy, dz = gun_bore_dir(side)
    p0 = (x, side * (y_mid - GUN_INBOARD), GUN_Z_MID)
    t = GUN_INBOARD / abs(dy)  # 沿轴线从炮尾走到船壳面的距离
    center = (p0[0] + dx * t, p0[1] + dy * t, p0[2] + dz * t)
    return {
        "x": x,
        "side": side,
        "center": center,
        "bore": (dx, dy, dz),
        "plane_offset": t,
        "protrusion": GUN_LENGTH - t,
        "rot_z_deg": math.degrees(math.atan2(dy, dx)),
        "rot_y_deg": -math.degrees(math.asin(dz)),
        "z_mid": GUN_Z_MID,
        "port_half": GUN_PORT_HALF,
        "sill_z": GUN_Z0,
    }


def hull_material(verts, face):
    zs = [verts[i][2] for i in face]
    if min(zs) > DECK_Z - 0.05:
        return DECK
    cz = sum(zs) / len(zs)
    if cz < -0.9:
        return RED
    return IRON


# --------------------------------------------------------------------------- #
# 1. 船体 / 撞角艏 / 艉廊
# --------------------------------------------------------------------------- #

def build_hull(m):
    sections = [section(x) for x in STATIONS]
    m.add_indexed(*loft(sections, hull_material))

    # 撞角艏（水下前伸的楔形冲角）
    verts = [
        (27.0, -1.10, -1.60), (27.0, 1.10, -1.60), (27.0, 1.10, 0.50), (27.0, -1.10, 0.50),
        (30.0, -0.18, -0.90), (30.0, 0.18, -0.90), (30.0, 0.18, -0.20), (30.0, -0.18, -0.20),
    ]
    faces = [
        (4, 5, 6, 7), (0, 3, 2, 1),
        (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7),
    ]
    m.add(verts, faces, IRON)

    # 艏柱（收窄艏部平面）
    m.add(*box((27.0, -0.14, -2.6), (27.8, 0.14, 5.0)), IRON)
    m.add(*box((26.6, -0.20, 4.6), (27.8, 0.20, 5.35)), MET)

    # 艉廊 / 艉楼（延伸到 -28.5，构成 LOA）
    m.add(*box((-28.5, -2.9, 2.4), (-26.0, 2.9, 4.8)), IRON)
    m.add(*box((-28.6, -2.4, 4.8), (-26.0, 2.4, 5.55)), IRON)
    for y in (-1.8, 0.0, 1.8):  # 艉窗（嵌进艉廊后壁）
        m.add(*box((-28.56, y - 0.42, 3.15), (-28.49, y + 0.42, 4.1)), DARK)
        m.add(*box((-28.60, y - 0.48, 3.08), (-28.53, y + 0.48, 4.17)), BRASS)
    m.add(*box((-28.58, -1.5, 4.55), (-28.49, 1.5, 4.72)), BRASS)  # 铭牌

    # 艉部上翘甲板（艉廊顶的木甲板盖板）
    m.add(*box((-28.55, -2.4, 5.55), (-26.0, 2.4, 5.68)), DECK)


# --------------------------------------------------------------------------- #
# 2. 水线装甲带 + 板缝
# --------------------------------------------------------------------------- #

def build_armor_belt(m):
    # 英雄化：装甲带更高更外凸（2.2 m 高 / 外凸 380 mm），远景也能读出“铁甲”
    z0, z1 = -1.10, 1.10
    off = 0.38
    for k in range(len(STATIONS) - 1):
        x0, x1 = STATIONS[k], STATIONS[k + 1]
        w0, w1 = beam_deck(x0) * 1.06, beam_deck(x1) * 1.06
        for s in (-1.0, 1.0):
            y0, y1 = s * w0, s * w1
            bottom = [(x0, y0, z0), (x1, y1, z0), (x1, y1 + s * off, z0), (x0, y0 + s * off, z0)]
            top = [(x0, y0, z1), (x1, y1, z1), (x1, y1 + s * off, z1), (x0, y0 + s * off, z1)]
            m.add(*hexa(bottom, top), IRON)
    # 竖向板缝（每站一道，加宽到 120 mm）
    for x in STATIONS[1:-1]:
        w = beam_deck(x) * 1.06
        for s in (-1.0, 1.0):
            y0 = s * w
            m.add(*box((x - 0.06, y0, z0), (x + 0.06, y0 + s * (off + 0.05), z1)), MET)


# --------------------------------------------------------------------------- #
# 3. 舷侧炮列 + 艏 pivot 炮
# --------------------------------------------------------------------------- #

def build_guns(m, with_barrels=True):
    """舷侧炮门列 + 艏 pivot 炮。

    `with_barrels=False`（当前资产默认）：只留炮门框 / 深色炮口板 / 上翻炮门盖，
    炮管与炮口箍交给独立模块 `SN_Weapon_CasemateGun` 经 `SN_Socket_GunPort_*` 挂载；
    `with_barrels=True` 保留旧“烘死炮管”变体，仅供几何门禁/差异比对。
    """
    z_lo, z_hi = GUN_Z0, GUN_Z1
    z_mid = GUN_Z_MID
    frame = GUN_PORT_FRAME
    port_half = GUN_PORT_HALF
    for x in GUN_X:
        y_lo = side_y_at(x, z_lo)
        y_hi = side_y_at(x, z_hi)
        y_top = side_y_at(x, z_hi + frame)
        y_bot = side_y_at(x, z_lo - frame)
        y_mid = side_y_at(x, z_mid)
        for s in (-1.0, 1.0):
            def ystrip(z0, z1, yi0, yi1):
                bot = [(x - port_half - frame, s * yi0, z0), (x + port_half + frame, s * yi0, z0),
                       (x + port_half + frame, s * (yi0 + 0.12), z0), (x - port_half - frame, s * (yi0 + 0.12), z0)]
                top = [(x - port_half - frame, s * yi1, z1), (x + port_half + frame, s * yi1, z1),
                       (x + port_half + frame, s * (yi1 + 0.12), z1), (x - port_half - frame, s * (yi1 + 0.12), z1)]
                m.add(*hexa(bot, top), MET)

            def xstrip(za, zb, yia, yib):
                for xa, xb in ((x - port_half - frame, x - port_half), (x + port_half, x + port_half + frame)):
                    bot = [(xa, s * yia, za), (xb, s * yia, za),
                           (xb, s * (yia + 0.12), za), (xa, s * (yia + 0.12), za)]
                    top = [(xa, s * yib, zb), (xb, s * yib, zb),
                           (xb, s * (yib + 0.12), zb), (xa, s * (yib + 0.12), zb)]
                    m.add(*hexa(bot, top), MET)

            # 炮门框（四条边，贴着船壳斜面，金属色与铁壳拉开）
            ystrip(z_hi, z_hi + frame, y_hi, y_top)
            ystrip(z_lo - frame, z_lo, y_bot, y_lo)
            xstrip(z_lo, z_hi, y_lo, y_hi)
            # 深色炮口板（贴着斜面，略凹）：空炮门时它就是“炮门里的暗腔”遮挡面
            bot = [(x - port_half, s * (y_lo - 0.05), z_lo),
                   (x + port_half, s * (y_lo - 0.05), z_lo),
                   (x + port_half, s * (y_lo + 0.06), z_lo),
                   (x - port_half, s * (y_lo + 0.06), z_lo)]
            top = [(x - port_half, s * (y_hi - 0.05), z_hi),
                   (x + port_half, s * (y_hi - 0.05), z_hi),
                   (x + port_half, s * (y_hi + 0.06), z_hi),
                   (x - port_half, s * (y_hi + 0.06), z_hi)]
            m.add(*hexa(bot, top), DARK)
            if with_barrels:
                # 炮管（前外张 + 上抬，让固定 3/4 机位能看到管长）+ 黄铜炮口箍
                dx, dy, dz = gun_bore_dir(s)
                p0 = (x, s * (y_mid - GUN_INBOARD), z_mid)
                p1 = (p0[0] + dx * GUN_LENGTH, p0[1] + dy * GUN_LENGTH,
                      p0[2] + dz * GUN_LENGTH)
                m.add(*taper_cyl(p0, p1, GUN_R_BREECH, GUN_R_MUZZLE, 8), MET)
                m0 = (p0[0] + dx * GUN_MUZZLE_BAND_FROM,
                      p0[1] + dy * GUN_MUZZLE_BAND_FROM,
                      p0[2] + dz * GUN_MUZZLE_BAND_FROM)
                m.add(*taper_cyl(m0, p1, GUN_MUZZLE_BAND_R, GUN_MUZZLE_BAND_R, 8), BRASS)
            # 上翻炮门盖（更大，强化"炮列"读感）
            zin0, zin1 = z_hi + frame - 0.02, z_hi + frame + 0.08
            zout0, zout1 = z_hi + frame + 0.62, z_hi + frame + 0.72
            y_in, y_out = s * y_hi, s * (y_hi + 0.75)
            bottom = [(x - 1.10, y_in, zin0), (x + 1.10, y_in, zin0),
                      (x + 1.10, y_out, zout0), (x - 1.10, y_out, zout0)]
            top = [(x - 1.10, y_in, zin1), (x + 1.10, y_in, zin1),
                   (x + 1.10, y_out, zout1), (x - 1.10, y_out, zout1)]
            m.add(*hexa(bottom, top), IRON)


    # 艏部两门 pivot gun（朝前，英雄化）
    for s in (-1.0, 1.0):
        y = s * 2.1
        m.add(*box((18.2, y - 0.80, DECK_Z), (20.6, y + 0.80, DECK_Z + 0.85)), DARK)
        m.add(*box((19.3, y - 0.30, DECK_Z + 0.82), (19.9, y + 0.30, DECK_Z + 1.05)), IRON)
        m.add(*taper_cyl((19.0, y - 0.20, DECK_Z + 1.00),
                         (22.4, y - 0.20, DECK_Z + 1.00), 0.34, 0.26, 8), MET)
        m.add(*taper_cyl((22.2, y - 0.20, DECK_Z + 1.00),
                         (22.45, y - 0.20, DECK_Z + 1.00), 0.40, 0.40, 8), BRASS)
        m.add(*box((18.6, y - 0.62, DECK_Z + 0.25), (20.0, y + 0.62, DECK_Z + 0.90)), IRON)


def build_plating(m):
    """上船壳板缝 + 水平列板线 + 装甲带上缘黄铜压条（英雄化：加宽加厚）。"""
    for x in STATIONS[1:-1]:
        b = beam_deck(x)
        w = b * 1.06
        for s in (-1.0, 1.0):
            bottom = [(x - 0.06, s * w, 1.10), (x + 0.06, s * w, 1.10),
                      (x + 0.06, s * (w + 0.05), 1.10), (x - 0.06, s * (w + 0.05), 1.10)]
            top = [(x - 0.06, s * b, 4.45), (x + 0.06, s * b, 4.45),
                   (x + 0.06, s * (b + 0.05), 4.45), (x - 0.06, s * (b + 0.05), 4.45)]
            m.add(*hexa(bottom, top), MET)
    for k in range(len(STATIONS) - 1):
        x0, x1 = STATIONS[k], STATIONS[k + 1]
        y0, y1 = side_y_at(x0, 3.0), side_y_at(x1, 3.0)
        for s in (-1.0, 1.0):
            bot = [(x0, s * y0, 3.55), (x1, s * y1, 3.55),
                   (x1, s * (y1 + 0.05), 3.55), (x0, s * (y0 + 0.05), 3.55)]
            top = [(x0, s * y0, 3.67), (x1, s * y1, 3.67),
                   (x1, s * (y1 + 0.05), 3.67), (x0, s * (y0 + 0.05), 3.67)]
            m.add(*hexa(bot, top), MET)
    for k in range(len(STATIONS) - 1):
        x0, x1 = STATIONS[k], STATIONS[k + 1]
        w0, w1 = beam_deck(x0) * 1.06, beam_deck(x1) * 1.06
        for s in (-1.0, 1.0):
            bot = [(x0, s * w0, 1.10), (x1, s * w1, 1.10),
                   (x1, s * (w1 + 0.40), 1.10), (x0, s * (w0 + 0.40), 1.10)]
            top = [(x0, s * w0, 1.17), (x1, s * w1, 1.17),
                   (x1, s * (w1 + 0.40), 1.17), (x0, s * (w0 + 0.40), 1.17)]
            m.add(*hexa(bot, top), BRASS)


# --------------------------------------------------------------------------- #
# 4. 装甲炮房 / 指挥塔 / 烟囱 / 通风 / 天窗
# --------------------------------------------------------------------------- #

def build_superstructure(m):
    # 中央装甲炮房（斜壁）
    bottom = [(-6.2, -4.1, DECK_Z), (6.2, -4.1, DECK_Z), (6.2, 4.1, DECK_Z), (-6.2, 4.1, DECK_Z)]
    top = [(-5.6, -3.4, 7.0), (5.6, -3.4, 7.0), (5.6, 3.4, 7.0), (-5.6, 3.4, 7.0)]
    m.add(*hexa(bottom, top), IRON)
    # 炮房侧面装甲肋 + 顶圈
    for x in (-4.2, -2.1, 0.0, 2.1, 4.2):
        for s in (-1.0, 1.0):
            y = s * 3.75
            m.add(*box((x - 0.07, y - 0.04, DECK_Z), (x + 0.07, y + 0.04, 6.95)), MET)
    for s in (-1.0, 1.0):
        ya, yb = sorted((s * 3.43, s * 3.51))
        m.add(*box((-6.2, ya, 6.75), (6.2, yb, 6.95)), BRASS)
        ya2, yb2 = sorted((s * 4.06, s * 4.12))
        m.add(*box((-6.2, ya2, DECK_Z), (6.2, yb2, DECK_Z + 0.18)), BRASS)
    # 炮房顶栏杆
    posts = [(-5.4, -3.3), (5.4, -3.3), (5.4, 3.3), (-5.4, 3.3),
             (0.0, -3.3), (0.0, 3.3), (-5.4, 0.0), (5.4, 0.0)]
    for px, py in posts:
        m.add(*box((px - 0.04, py - 0.04, 7.0), (px + 0.04, py + 0.04, 7.9)), MET)
    m.add(*box((-5.45, -3.35, 7.85), (5.45, -3.3, 7.95)), MET)
    m.add(*box((-5.45, 3.3, 7.85), (5.45, 3.35, 7.95)), MET)
    m.add(*box((-5.45, -3.35, 7.85), (-5.4, 3.35, 7.95)), MET)
    m.add(*box((5.4, -3.35, 7.85), (5.45, 3.35, 7.95)), MET)

    # 指挥塔（前部，落在 x=4.3）
    m.add(*translate(revolved([(7.0, 1.15), (9.0, 1.05)], 8), 4.3, 0.0, 0.0), IRON)
    m.add(*translate(revolved([(8.9, 1.18), (9.05, 1.18)], 8), 4.3, 0.0, 0.0), MET)
    for k in range(4):
        a = math.pi / 4.0 + k * math.pi / 2.0
        cx, cy = 4.3 + 1.10 * math.cos(a), 1.10 * math.sin(a)
        m.add(*box((cx - 0.28, cy - 0.09, 7.55), (cx + 0.28, cy + 0.09, 7.95)), DARK)

    # 双烟囱（后倾）
    for f in FUNNELS:
        z0, z1 = f["z0"], f["z1"]
        lean = f["lean"]
        levels = [(z0, f["r0"]), (z0 + 0.55 * (z1 - z0), f["r0"] * 0.86),
                  (z1 - 0.25, f["r1"] * 1.06), (z1, f["r1"])]
        verts = []
        for z, r in levels:
            cx = f["x"] + lean * (z - z0) / (z1 - z0)
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
        m.add(verts, faces, MET)
        # 黄铜箍 + 顶圈
        for z in (z0 + 1.0, z0 + 3.6):
            t = (z - z0) / (z1 - z0)
            cx = f["x"] + lean * t
            r = (f["r0"] + (f["r1"] - f["r0"]) * t) + 0.035
            m.add(*translate(revolved([(z - 0.09, r), (z + 0.09, r)], 8), cx, 0.0, 0.0), BRASS)
        cx_top = f["x"] + lean
        m.add(*translate(revolved([(z1 - 0.08, f["r1"] + 0.09), (z1 + 0.06, f["r1"] + 0.09)], 8),
                         cx_top, 0.0, 0.0), BRASS)
        # 烟囱基座 + 蒸汽管
        m.add(*box((f["x"] - 0.95, -0.75, 7.0), (f["x"] + 0.95, 0.75, 7.45)), IRON)
        m.add(*taper_cyl((f["x"] - 0.55, 0.8, 7.35), (f["x"] - 0.55, 0.8, 9.1), 0.10, 0.10, 6), BRASS)

    # 炮房顶通风筒 + 天窗（与顶盖同轴）
    for x in (-4.6, 3.0):
        m.add(*translate(revolved([(7.0, 0.32), (8.15, 0.26)], 8), x, 0.0, 0.0), MET)
        m.add(*translate(box((-0.26, -0.26, 8.1), (0.26, 0.26, 8.42)), x, 0.0, 0.0), MET)
    m.add(*box((-2.4, -1.2, 7.0), (-0.8, 1.2, 7.22)), BRASS)
    m.add(*box((-2.3, -1.1, 7.22), (-0.9, 1.1, 7.26)), DARK)

    # 艏部驾驶台（指挥塔前，带落到甲板的支撑柱）
    m.add(*box((6.4, -2.6, 7.0), (8.4, 2.6, 7.16)), WOOD)
    for px in (6.7, 8.1):
        m.add(*box((px - 0.5, -2.5, 7.16), (px + 0.5, -2.45, 7.9)), MET)
        m.add(*box((px - 0.5, 2.45, 7.16), (px + 0.5, 2.5, 7.9)), MET)
    m.add(*box((6.2, -2.6, 7.86), (8.4, -2.5, 7.94)), BRASS)
    m.add(*box((6.2, 2.5, 7.86), (8.4, 2.6, 7.94)), BRASS)
    for px in (6.7, 8.1):
        for s in (-1.0, 1.0):
            m.add(*box((px - 0.06, s * 2.45 - 0.06, DECK_Z),
                       (px + 0.06, s * 2.45 + 0.06, 7.0)), MET)


# --------------------------------------------------------------------------- #
# 5. 三桅 + 横桁 + 收帆 + 艏斜桁 + 索具
# --------------------------------------------------------------------------- #

def build_masts(m):
    """三桅 + 横桁 + 收帆 + 艏斜桁承座 + 锚吊架（几何来自 rig_kit.ironclad_masts）。"""
    b = rig_kit.builder(m, sys.modules[__name__], materials=rig_kit.KIT_MATERIALS, legacy=True)
    rig_kit.ironclad_masts(b, MASTS, {"deck_z": DECK_Z, "beam_deck": beam_deck})


def build_rigging(m):
    """静索 / 侧支索（几何来自 rig_kit.ironclad_rigging）。"""
    b = rig_kit.builder(m, sys.modules[__name__], materials=rig_kit.KIT_MATERIALS, legacy=True)
    rig_kit.ironclad_rigging(b, MASTS, {"beam_deck": beam_deck})


def build_bulwark(m):
    xs = [x for x in STATIONS if -25.0 <= x <= 26.0]
    for k in range(len(xs) - 1):
        x0, x1 = xs[k], xs[k + 1]
        b0, b1 = beam_deck(x0), beam_deck(x1)
        for s in (-1.0, 1.0):
            y0a, y0b = sorted((s * (b0 - 0.14), s * b0))
            y1a, y1b = sorted((s * (b1 - 0.14), s * b1))
            bottom = [(x0, y0a, DECK_Z), (x1, y1a, DECK_Z),
                      (x1, y1b, DECK_Z), (x0, y0b, DECK_Z)]
            top = [(x0, y0a, 5.5), (x1, y1a, 5.5), (x1, y1b, 5.5), (x0, y0b, 5.5)]
            m.add(*hexa(bottom, top), IRON)
            # 黄铜压条
            rb0a, rb0b = sorted((s * (b0 - 0.17), s * (b0 + 0.03)))
            rb1a, rb1b = sorted((s * (b1 - 0.17), s * (b1 + 0.03)))
            rbot = [(x0, rb0a, 5.5), (x1, rb1a, 5.5), (x1, rb1b, 5.5), (x0, rb0b, 5.5)]
            rtop = [(x0, rb0a, 5.64), (x1, rb1a, 5.64), (x1, rb1b, 5.64), (x0, rb0b, 5.64)]
            m.add(*hexa(rbot, rtop), BRASS)


# --------------------------------------------------------------------------- #
# 7. 甲板件：舱口 / 绞盘 / 舵轮 / 小艇 / 锚 / 螺旋桨 / 旗
# --------------------------------------------------------------------------- #

def _hatch(m, x, size, bars=5):
    h = size / 2.0
    for s in (-1.0, 1.0):
        m.add(*box((x - h, s * h - 0.06, DECK_Z), (x + h, s * h + 0.06, DECK_Z + 0.26)), DARK)
        m.add(*box((x + s * h - 0.06, -h, DECK_Z), (x + s * h + 0.06, h, DECK_Z + 0.26)), DARK)
    for k in range(bars):
        y = -h + 0.18 + k * (2 * h - 0.36) / max(1, bars - 1)
        m.add(*box((x - h + 0.02, y - 0.04, DECK_Z + 0.20),
                   (x + h - 0.02, y + 0.04, DECK_Z + 0.27)), MET)


def _boat(m, x, y, scale=1.0):
    """小艇：三站放样实体 + 两道垫木。"""
    L = 4.4 * scale
    B = 0.75 * scale
    H = 0.62 * scale
    z0 = DECK_Z + 0.20
    stations = [(-L / 2, 0.35), (0.0, 1.0), (L / 2, 0.32)]
    sections = []
    for dx, f in stations:
        xx = x + dx
        b = B * f
        sections.append([
            (xx, y - b, z0 + H), (xx, y - 0.62 * b, z0 + 0.42 * H),
            (xx, y - 0.24 * b, z0), (xx, y + 0.24 * b, z0),
            (xx, y + 0.62 * b, z0 + 0.42 * H), (xx, y + b, z0 + H),
        ])
    verts = [p for sec in sections for p in sec]
    faces = []
    n = 6
    for k in range(2):
        a, b = k * n, (k + 1) * n
        for i in range(n):
            j = (i + 1) % n
            faces.append((a + i, a + j, b + j, b + i))
    for idx in (0, 2):
        base = idx * n
        for i in range(1, n - 1):
            faces.append((base, base + i, base + i + 1))
    m.add(verts, faces, WOOD)
    for dx in (-1.2 * scale, 1.2 * scale):
        m.add(*box((x + dx - 0.12, y - 0.55, DECK_Z), (x + dx + 0.12, y + 0.55, DECK_Z + 0.20)), DARK)
    m.add(*box((x - 1.3 * scale, y - 0.10, z0 + H - 0.06), (x + 1.3 * scale, y + 0.10, z0 + H + 0.02)), DARK)


def build_deck_fittings(m):
    # 甲板板缝（沿 X 的长条，打散大面积木甲板）
    for y in (-1.8, 0.0, 1.8):
        m.add(*box((-24.0, y - 0.03, DECK_Z), (24.0, y + 0.03, DECK_Z + 0.012)), DARK)
    for y in (-3.4, 3.4):
        m.add(*box((-15.0, y - 0.03, DECK_Z), (15.0, y + 0.03, DECK_Z + 0.012)), DARK)
    # 舱口格栅
    _hatch(m, 9.8, 2.6, 5)
    _hatch(m, -14.6, 2.2, 4)
    # 绞盘（落在 x=18.6，手杆穿过鼓身）
    m.add(*translate(revolved([(DECK_Z, 0.62), (DECK_Z + 0.18, 0.55),
                               (DECK_Z + 0.62, 0.45)], 8), 18.6, 0.0, 0.0), DARK)
    m.add(*translate(revolved([(DECK_Z + 0.60, 0.62), (DECK_Z + 0.76, 0.62)], 8),
                     18.6, 0.0, 0.0), MET)
    m.add(*box((18.6 - 0.62, -0.07, DECK_Z + 0.56), (18.6 + 0.62, 0.07, DECK_Z + 0.70)), MET)
    m.add(*box((18.6 - 0.07, -0.62, DECK_Z + 0.56), (18.6 + 0.07, 0.62, DECK_Z + 0.70)), MET)
    # 舵轮 + 罗经柜
    m.add(*box((-23.2, -0.55, DECK_Z), (-22.4, 0.55, DECK_Z + 0.30)), DARK)
    m.add(*taper_cyl((-22.8, 0.0, DECK_Z + 0.30), (-22.8, 0.0, DECK_Z + 1.05), 0.08, 0.08, 6), MET)
    m.add(*translate(revolved([(DECK_Z + 0.95, 0.46), (DECK_Z + 1.10, 0.46)], 8),
                     -22.8, 0.0, 0.0), WOOD)
    m.add(*box((-22.8 - 0.66, -0.05, DECK_Z + 0.98), (-22.8 + 0.66, 0.05, DECK_Z + 1.06)), MET)
    m.add(*box((-22.8 - 0.05, -0.66, DECK_Z + 0.98), (-22.8 + 0.05, 0.66, DECK_Z + 1.06)), MET)
    m.add(*box((-24.2, -0.38, DECK_Z), (-23.5, 0.38, DECK_Z + 0.62)), WOOD)
    m.add(*translate(revolved([(DECK_Z + 0.62, 0.22), (DECK_Z + 0.86, 0.12),
                               (DECK_Z + 0.94, 0.0)], 8), -23.85, 0.0, 0.0), BRASS)
    # 两艘小艇（主桅两侧）
    _boat(m, -12.8, 2.9, 1.0)
    _boat(m, -12.8, -2.9, 1.0)
    # 系缆桩
    for x in (-24.6, -17.5, 17.5, 23.5):
        for s in (-1.0, 1.0):
            b = beam_deck(x) - 0.28
            m.add(*box((x - 0.10, s * b - 0.10, DECK_Z), (x + 0.10, s * b + 0.10, DECK_Z + 0.42)), MET)
    # 锚（两舷艏部）
    for s in (-1.0, 1.0):
        x, y = 23.0, s * (beam_deck(23.0) - 0.10)
        m.add(*box((x - 0.10, y - 0.10, DECK_Z + 0.05), (x + 0.10, y + 0.10, DECK_Z + 1.55)), MET)
        m.add(*box((x - 0.10, y - 0.70, DECK_Z + 1.28), (x + 0.10, y + 0.70, DECK_Z + 1.42)), MET)
        for sy in (-1.0, 1.0):
            m.add(*taper_cyl((x, y + sy * 0.12, DECK_Z + 0.35),
                             (x, y + sy * 0.52, DECK_Z + 0.05), 0.10, 0.06, 6), MET)
        m.add(*translate(revolved([(DECK_Z + 1.55, 0.17), (DECK_Z + 1.70, 0.17)], 8),
                         x, y, 0.0), MET)

    # 螺旋桨（4 叶，叶根落在桨毂半径内）
    m.add(*box((-27.4, -0.32, -2.2), (-26.2, 0.32, -1.2)), MET)
    m.add(*taper_cyl((-27.0, 0.0, -2.1), (-27.8, 0.0, -2.1), 0.35, 0.30, 8), BRASS)
    x0b, x1b = -27.75, -27.55
    for k in range(4):
        a = k * math.pi / 2.0 + math.pi / 4.0
        uy, uz = math.cos(a), math.sin(a)
        vy, vz = -math.sin(a), math.cos(a)
        ring = []
        for r, ww in ((0.25, -0.09), (0.25, 0.09), (0.95, 0.09), (0.95, -0.09)):
            ring.append((r * uy + ww * vy, -2.1 + r * uz + ww * vz))
        bottom = [(x0b, py, pz) for py, pz in ring]
        top = [(x1b, py, pz) for py, pz in ring]
        m.add(*hexa(bottom, top), BRASS)
    m.add(*box((-27.1, -0.22, -2.3), (-26.2, 0.22, 0.6)), MET)

    # 艉旗杆 + 旗；主桅旗
    m.add(*taper_cyl((-27.6, 0.0, 5.68), (-27.6, 0.0, 9.6), 0.07, 0.045, 6), WOOD)
    _flag(m, -27.57, 0.0, 2.2, 9.15, 9.55)

    # 舰艏两舷铜铭牌（贴住船壳斜面）
    for s in (-1.0, 1.0):
        x = 23.6
        ya, yb = sorted((s * (side_y_at(x, 3.35) - 0.06), s * (side_y_at(x, 3.55) + 0.02)))
        m.add(*box((x, ya, 3.35), (x + 1.3, yb, 3.62)), BRASS)
    # 吊艇架
    for x in (-15.0, -10.6):
        for s in (-1.0, 1.0):
            m.add(*box((x - 0.30, s * 3.6 - 0.06, DECK_Z), (x - 0.18, s * 3.6 + 0.06, DECK_Z + 0.9)), MET)


# --------------------------------------------------------------------------- #
# 组装 / Blender 侧
# --------------------------------------------------------------------------- #

def _flag(m, x, y0, y1, z0, z1, seg=4, thickness=0.025):
    """沿 Y 飘的薄旗面：前后两张网格 + 四周边缘，闭合成薄板。"""
    top = [(x + 0.10 * math.sin((i / seg) * math.pi * 1.5), y0 + (y1 - y0) * i / seg, z1)
           for i in range(seg + 1)]
    bot = [(x + 0.06 * math.sin((i / seg) * math.pi * 1.5), y0 + (y1 - y0) * i / seg, z0)
           for i in range(seg + 1)]
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
        faces.append((mcols + i + 1, off + mcols + i + 1, off + mcols + i, mcols + i))
    faces.append((0, mcols, off + mcols, off))
    faces.append((off + seg, off + mcols + seg, mcols + seg, seg))
    m.add(verts, faces, CANVAS)


def build_ironclad(with_barrels=False):
    m = Part()
    build_hull(m)
    build_armor_belt(m)
    build_plating(m)
    build_guns(m, with_barrels=with_barrels)
    build_superstructure(m)
    build_masts(m)
    build_rigging(m)
    build_bulwark(m)
    build_deck_fittings(m)
    return m


def build_all_geometry(with_barrels=False):
    return {OBJECT: build_ironclad(with_barrels=with_barrels)}


def _ensure_material(name):
    import bpy
    mat = bpy.data.materials.get(name)
    if mat is not None:
        return mat
    spec = NEW_MATERIALS.get(name)
    if spec is None:
        raise RuntimeError("材质 %s 不存在且未在 NEW_MATERIALS 声明" % name)
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*spec["base"], 1.0)
    bsdf.inputs["Roughness"].default_value = spec["roughness"]
    bsdf.inputs["Metallic"].default_value = spec["metallic"]
    mat.diffuse_color = (*spec["base"], 1.0)
    return mat


def _make_object(name, part, location):
    import bpy
    import bmesh

    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([tuple(v) for v in part.verts], [], [list(f) for f, _ in part.faces])
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
    for mat_name in slots:
        mesh.materials.append(_ensure_material(mat_name))
    index = {m: i for i, m in enumerate(slots)}
    for poly, (_face, mat_name) in zip(mesh.polygons, part.faces):
        poly.material_index = index[mat_name]
        poly.use_smooth = False

    obj = bpy.data.objects.new(name, mesh)
    bpy.data.collections[COLLECTION].objects.link(obj)
    obj.location = location
    return obj


def build_all(with_barrels=False, apply_materials=True):
    """幂等重建船体网格（默认空炮门变体）+ 共享贴图材质 / UV。

    注意：本函数只重建 `SN_Ironclad` 网格对象本身；船体上的 socket 空节点由
    `sn_ship_weapon_sockets` / `sn_ship_rig_sockets` / `sn_ship_gun_ports` 各自补齐。
    """
    import bpy

    coll = bpy.data.collections.get(COLLECTION)
    if coll is None:
        coll = bpy.data.collections.new(COLLECTION)
        bpy.context.scene.collection.children.link(coll)

    old = bpy.data.objects.get(OBJECT)
    if old is not None:
        old_mesh = old.data
        bpy.data.objects.remove(old, do_unlink=True)
        if old_mesh is not None and old_mesh.users == 0:
            bpy.data.meshes.remove(old_mesh)
    for stale in [m for m in bpy.data.meshes if m.users == 0 and m.name.startswith(OBJECT)]:
        bpy.data.meshes.remove(stale)

    import sn_shared_materials as shared
    if apply_materials:
        shared.build_materials(force=False)

    geometry = build_all_geometry(with_barrels=with_barrels)
    obj = _make_object(OBJECT, geometry[OBJECT], WORKBENCH_POS)
    if apply_materials:
        report_mat = shared.apply_collection(coll, space="local")
        if report_mat.get("failures"):
            raise RuntimeError("共享贴图材质/UV 应用失败：%r" % report_mat["failures"])
        print("TEXTURED %s: %d 对象 / %d 材质 / UV loops=%d" % (
            OBJECT, report_mat["objects"], len(report_mat["materials"]),
            report_mat["uv_loops"]))
    return obj


def report():
    import bpy
    import bmesh

    obj = bpy.data.objects[OBJECT]
    mesh = obj.data
    mesh.calc_loop_triangles()
    tris = len(mesh.loop_triangles)

    bm = bmesh.new()
    bm.from_mesh(mesh)
    bm.edges.ensure_lookup_table()
    loose = sum(1 for v in bm.verts if not v.link_edges)
    degen = sum(1 for f in bm.faces if f.calc_area() < 1e-9)
    nonman = sum(1 for e in bm.edges if not e.is_manifold)
    boundary = sum(1 for e in bm.edges if e.is_boundary)
    bm.free()
    overflow = sum(1 for p in mesh.polygons if p.material_index >= len(mesh.materials))

    xs = [v.co.x for v in mesh.vertices]
    ys = [v.co.y for v in mesh.vertices]
    zs = [v.co.z for v in mesh.vertices]
    size = [round(max(xs) - min(xs), 3), round(max(ys) - min(ys), 3), round(max(zs) - min(zs), 3)]

    out = {
        "object": OBJECT,
        "location": [round(v, 4) for v in obj.location],
        "tris": tris,
        "budget": TRI_BUDGET,
        "verts": len(mesh.vertices),
        "size": size,
        "target": list(TARGET_SIZE),
        "size_delta": [round(size[i] - TARGET_SIZE[i], 3) for i in range(3)],
        "z_min": round(min(zs), 3),
        "z_max": round(max(zs), 3),
        "materials": [m.name for m in mesh.materials],
        "loose_verts": loose,
        "degenerate_faces": degen,
        "non_manifold_edges": nonman,
        "boundary_edges": boundary,
        "mat_slot_overflow": overflow,
    }
    out["health"] = {
        "all_manifold": nonman == 0 and boundary == 0,
        "no_loose": loose == 0,
        "no_degenerate": degen == 0,
        "no_mat_overflow": overflow == 0,
        "within_budget": tris <= TRI_BUDGET,
        "size_ok": all(abs(d) <= 0.5 for d in out["size_delta"]),
        "waterline_ok": abs(min(zs) - Z_MIN) <= 0.2 and abs(max(zs) - Z_MAX) <= 0.4,
    }
    out["scene"] = {
        "objects": len(bpy.data.objects),
        "mesh": sum(1 for o in bpy.data.objects if o.type == "MESH"),
        "collections": [c.name for c in bpy.data.collections],
        "materials": sorted(m.name for m in bpy.data.materials),
    }
    print("IRONCLAD_REPORT " + repr(out))
    return out


if __name__ == "__main__":
    build_all()
    report()
