# -*- coding: utf-8 -*-
"""Steam Navigator — SN_Paddle_Freighter 大型明轮蒸汽货轮参数化生成脚本。

工单
----
tools/modeling/briefs/sn_paddle_freighter.json
集合：SN_Paddle_Freighter_Prototype（新增，不触碰既有对象）
轴心：船体中部水线（z = 0），+X = 船首，+Z = 向上，1 unit = 1 m
预算：<= 14000 tri
材质：SN_Iron_Hull / SN_Iron_Red / SN_Wood_Deck / SN_Wood / SN_Metal / SN_Brass
（后三个复用工作台既有材质）

设计要点
--------
- 1850s–70s 明轮蒸汽货轮：铁壳黑船身 + 红水线、两舷明轮与圆弧轮罩、
  两根后倾烟囱、艏楼 / 主甲板 / 艉楼三段甲板、4 个货舱口 + 4 根吊杆、
  双桅横桁 + 艏斜桁、锅炉舱天窗、蒸汽管、舵轮、救生艇、舷窗。
- 全部几何由本文件顶部参数表生成，改数值即可重建；不手工摆点。
- 几何函数是纯 Python（不 import bpy），可用 dryrun_ship.py 离线校验。
- Blender 侧只做集合 / 材质 / 空物体层级 / 父级；几何全部来自 build_all_geometry()。

用法
----
Blender 内：import runpy; runpy.run_path(<本文件>, run_name="__main__")
纯 Python 干跑：python tools/modeling/generators/dryrun_ship.py
"""

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

# ============================================================
# 参数区
# ============================================================

COLLECTION = "SN_Paddle_Freighter_Prototype"
PREFIX = "SN_PF_"
ROOT_NAME = "SN_PF_Root"

# 工作台里的摆位（导出 GLB 时根节点临时归零，见 export_ship_glb.py）
WORKBENCH_POS = (-45.0, 0.0, 0.0)

# 材质：名称 -> (线性 base color, roughness, metallic)
COLORS = {
    "SN_Iron_Hull": ((0.045, 0.048, 0.052), 0.52, 0.35),
    "SN_Iron_Red":  ((0.190, 0.035, 0.022), 0.62, 0.10),
    "SN_Brass":     ((0.420, 0.270, 0.075), 0.28, 0.85),
}
# 复用工作台既有材质（不存在时才按下面数值新建）
REUSE_COLORS = {
    "SN_Wood":      ((0.200, 0.088, 0.035), 0.70, 0.00),
    "SN_Wood_Deck": ((0.300, 0.165, 0.072), 0.76, 0.00),
    "SN_Metal":     ((0.140, 0.150, 0.170), 0.36, 0.90),
}
MAT_IRON = "SN_Iron_Hull"
MAT_RED = "SN_Iron_Red"
MAT_BRASS = "SN_Brass"
MAT_WOOD = "SN_Wood"
MAT_DECK = "SN_Wood_Deck"
MAT_METAL = "SN_Metal"

# 横剖面站：(x, 半宽 w, 甲板高 dz, 龙骨底 kz)；x 升序（-27.5 艉 -> +27.5 艏）
# 船体 LOA 55.0 m，水线 z = 0，吃水约 2.6 m
STATIONS = [
    (-27.50, 0.45, 3.48, -0.30),
    (-26.50, 1.50, 3.44, -1.15),
    (-25.00, 2.55, 3.40, -1.85),
    (-22.50, 3.50, 3.34, -2.30),
    (-19.00, 4.10, 3.26, -2.50),
    (-15.00, 4.42, 3.18, -2.58),
    (-10.00, 4.58, 3.10, -2.62),
    (-5.00, 4.68, 3.06, -2.64),
    (0.00, 4.70, 3.06, -2.64),
    (5.00, 4.70, 3.10, -2.64),
    (10.00, 4.62, 3.18, -2.64),
    (15.00, 4.45, 3.30, -2.64),
    (19.50, 3.95, 3.46, -2.62),
    (22.50, 3.00, 3.58, -2.55),
    (24.50, 2.00, 3.66, -2.25),
    (26.00, 1.10, 3.72, -1.50),
    (27.00, 0.50, 3.76, -0.60),
    (27.50, 0.10, 3.78, 0.20),
]

# 横剖面轮廓：(相对半宽, 相对吃水深度)，从龙骨中心到甲板边缘
PROFILE = [
    (0.000, 0.000), (0.400, 0.030), (0.680, 0.090), (0.840, 0.190),
    (0.940, 0.340), (0.990, 0.520), (1.000, 0.700), (0.975, 0.860),
    (0.945, 1.000),
]

DECK_W_FRAC = 0.945      # 甲板 / 舷墙所在的相对半宽
DECK_CAMBER = 0.10       # 甲板拱高
BULWARK_H = 0.85         # 舷墙高
BULWARK_T = 0.12         # 舷墙厚
FORE_X = 20.3            # 艏楼前端（断阶）x
POOP_X = -20.8           # 艉楼前端（断阶）x
FORE_RAISE = 1.15        # 艏楼甲板抬高
POOP_RAISE = 1.05        # 艉楼甲板抬高
BREAK_T = 0.30           # 断阶舱壁厚

# 明轮：轮心 x / z，半径，轮宽（y 方向），桨叶数，辐条数，圆周分段
PADDLE = dict(x=-1.0, z=1.30, r=2.55, y_in=4.95, y_out=6.85,
              blades=14, spokes=8, seg=16)
# 轮罩：覆盖上半轮（-6°..186°）的半包箱板；外板窗 r=2.02，内板窗 r=2.30
# （蒸汽管以 49° 斜穿内板平面，椭圆截面包络约 2.21，留 0.09 m 余量）
PADDLE_BOX = dict(r_in=2.02, r_in_inner=2.30, r_out=3.35, cap_r_in=2.75,
                  a0=math.radians(-6.0), a1=math.radians(186.0), seg=16)

# 锅炉 / 机舱围罩
CASING = dict(x0=-7.40, x1=5.00, y=2.70, z_top=4.55)

# 烟囱：x、底部半径、顶部半径、高度、后倾角
FUNNELS = [
    dict(x=2.40, r0=1.05, r1=0.80, h=7.60, rake=10.0),
    dict(x=-4.90, r0=1.00, r1=0.76, h=7.30, rake=10.0),
]

# 桥楼 / 驾驶室
BRIDGE = dict(x=-1.2, z=6.55, half_len=1.90, half_wid=6.40, house_len=3.20,
              house_wid=3.80, house_h=2.10)

# 桅杆：名称、x、甲板基准 z、下桅顶、上桅顶、桁位 z、桁长、收帆束长
MASTS = [
    dict(key="Fore", x=22.80, z0=4.40, z_low=14.00, z_top=15.60,
         yard_z=12.80, yard_w=6.80, sail_w=5.60),
    dict(key="Main", x=-23.80, z0=4.10, z_low=15.00, z_top=16.60,
         yard_z=13.60, yard_w=7.40, sail_w=6.00),
]

BOWSPRIT = dict(x0=27.00, z0=3.95, x1=31.00, z1=5.10, r0=0.30, r1=0.10)

# 货舱口：x 中心、长、宽、围板高
HATCHES = [
    dict(x=16.40, lx=3.80, ly=2.80, h=0.55),
    dict(x=10.20, lx=3.80, ly=2.80, h=0.55),
    dict(x=-11.20, lx=4.00, ly=3.00, h=0.55),
    dict(x=-17.20, lx=4.00, ly=3.00, h=0.55),
]

# 吊杆：名称、根部 x/y/z（根部贴桅杆，带鹅颈箍）、端部 x/y/z、根部半径、端部半径
BOOMS = [
    ("Fore",  22.80,  0.55, 5.35,  12.60,  3.20, 9.60, 0.16, 0.10),
    ("Main", -23.80,  0.55, 5.05, -13.20,  3.40, 9.20, 0.17, 0.11),
]

# 甲板机械 / 细节
DECKHOUSE = dict(x=6.55, lx=2.90, ly=4.20, z0=None, h=1.80)  # z0 由主甲板决定
PORTHOLE_Z = 2.25
PORTHOLE_STEP = 3.20
PORTHOLE_X0 = -22.0
PORTHOLE_X1 = 24.0


# ============================================================
# 纯几何工具（无 bpy 依赖）
# ============================================================

class Part:
    """一组顶点 + 带材质名的面，对应 Blender 里的一个 mesh 对象。"""

    def __init__(self):
        self.verts = []
        self.faces = []
        self.recalc = True      # 闭合件进 Blender 后重算法线；单层曲面设 False

    def add(self, vf, material):
        verts, faces = vf
        off = len(self.verts)
        self.verts.extend(verts)
        for f in faces:
            self.faces.append((tuple(i + off for i in f), material))

    def tris(self):
        return sum(max(1, len(f) - 2) for f, _m in self.faces)

    def merge(self, other):
        off = len(self.verts)
        self.verts.extend(other.verts)
        self.faces.extend((tuple(i + off for i in f), m) for f, m in other.faces)
        self.recalc = self.recalc and other.recalc
        return self


def vadd(a, b):
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def vsub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def vmul(a, s):
    return (a[0] * s, a[1] * s, a[2] * s)


def vcross(a, b):
    return (a[1] * b[2] - a[2] * b[1],
            a[2] * b[0] - a[0] * b[2],
            a[0] * b[1] - a[1] * b[0])


def vlen(a):
    return math.sqrt(a[0] * a[0] + a[1] * a[1] + a[2] * a[2])


def vnorm(a):
    L = vlen(a) or 1.0
    return (a[0] / L, a[1] / L, a[2] / L)


def lerp(a, b, t):
    return a + (b - a) * t


def box(lo, hi):
    x0, y0, z0 = lo
    x1, y1, z1 = hi
    return hexa([(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0)],
                [(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)])


def hexa(bottom, top):
    verts = list(bottom) + list(top)
    faces = [(0, 3, 2, 1), (4, 5, 6, 7),
             (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    return verts, faces


def translate(vf, dx, dy, dz):
    verts, faces = vf
    return [(x + dx, y + dy, z + dz) for x, y, z in verts], faces


def rotate_y(vf, angle, cx=0.0, cz=0.0):
    """绕 Y 轴旋转（俯仰 / 后倾），以 (cx, cz) 为轴心。"""
    ca, sa = math.cos(angle), math.sin(angle)
    verts, faces = vf
    out = []
    for x, y, z in verts:
        dx, dz = x - cx, z - cz
        out.append((cx + dx * ca + dz * sa, y, cz - dx * sa + dz * ca))
    return out, faces


def merge(items):
    verts, faces = [], []
    for vf in items:
        v, f = vf
        off = len(verts)
        verts.extend(v)
        faces.extend(tuple(i + off for i in face) for face in f)
    return verts, faces


def ring(n, rx, ry, z, cx=0.0, cy=0.0, phase=None):
    if phase is None:
        phase = math.pi / n
    return [(cx + rx * math.cos(phase + 2.0 * math.pi * i / n),
             cy + ry * math.sin(phase + 2.0 * math.pi * i / n),
             z) for i in range(n)]


def taper_cyl(p0, p1, r0, r1, sides=8, caps=True):
    """任意轴向的圆台（低模）；caps=True 时两端封盖，形成闭合壳体。"""
    d = vnorm(vsub(p1, p0))
    u = vcross(d, (0.0, 0.0, 1.0))
    if vlen(u) < 1e-6:
        u = vcross(d, (1.0, 0.0, 0.0))
    u = vnorm(u)
    v = vnorm(vcross(d, u))
    verts = []
    for p, r in ((p0, r0), (p1, r1)):
        for i in range(sides):
            a = 2.0 * math.pi * i / sides
            verts.append(vadd(p, vadd(vmul(u, r * math.cos(a)),
                                      vmul(v, r * math.sin(a)))))
    faces = []
    for i in range(sides):
        j = (i + 1) % sides
        faces.append((i, j, sides + j, sides + i))
    if caps:
        faces.append(tuple(range(sides))[::-1])
        faces.append(tuple(range(sides, 2 * sides)))
    return verts, faces


def frame_box(center, u, v, w, hu, hv, hw):
    """以正交轴 u/v/w 与半尺寸构造一个长方体。"""
    c = center
    pts = []
    for sw in (-1, 1):
        for sv in (-1, 1):
            for su in (-1, 1):
                pts.append(vadd(c, vadd(vmul(u, su * hu),
                                        vadd(vmul(v, sv * hv), vmul(w, sw * hw)))))
    faces = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 2, 6, 4),
             (1, 5, 7, 3), (0, 4, 5, 1), (2, 3, 7, 6)]
    return pts, faces


def ring_band(cx, cz, r_in, r_out, y0, y1, seg=12):
    """环形板（径向厚度 r_out-r_in，y 方向厚度），用于明轮轮圈。"""
    verts, faces = [], []
    for i in range(seg):
        a = 2.0 * math.pi * i / seg
        co, si = math.cos(a), math.sin(a)
        verts.extend([
            (cx + r_out * co, y0, cz + r_out * si),
            (cx + r_out * co, y1, cz + r_out * si),
            (cx + r_in * co, y1, cz + r_in * si),
            (cx + r_in * co, y0, cz + r_in * si),
        ])
    for i in range(seg):
        a = i * 4
        b = ((i + 1) % seg) * 4
        faces.append((a, a + 3, b + 3, b))          # y0 侧面
        faces.append((a + 1, b + 1, b + 2, a + 2))  # y1 侧面
        faces.append((a, b, b + 1, a + 1))          # 外圈
        faces.append((a + 3, a + 2, b + 2, b + 3))  # 内圈
    return verts, faces


def arch_band(cx, cz, r_in, r_out, a0, a1, y0, y1, seg=12):
    """圆弧形板（轮罩侧板 / 月牙板），闭合薄板。"""
    pts = []
    for i in range(seg + 1):
        a = a0 + (a1 - a0) * i / seg
        pts.append((cx + r_out * math.cos(a), cz + r_out * math.sin(a)))
    for i in range(seg, -1, -1):
        a = a0 + (a1 - a0) * i / seg
        pts.append((cx + r_in * math.cos(a), cz + r_in * math.sin(a)))
    n = len(pts)
    verts = [(x, y0, z) for (x, z) in pts] + [(x, y1, z) for (x, z) in pts]
    faces = [tuple(range(n))[::-1], tuple(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, n + j, n + i))
    return verts, faces


def arc_strip(cx, cz, r, a0, a1, y0, y1, seg=12):
    """圆弧面（轮罩顶盖），单层曲面，法线朝外。"""
    verts, faces = [], []
    for i in range(seg + 1):
        a = a0 + (a1 - a0) * i / seg
        x = cx + r * math.cos(a)
        z = cz + r * math.sin(a)
        verts.extend([(x, y0, z), (x, y1, z)])
    for i in range(seg):
        a = i * 2
        b = (i + 1) * 2
        faces.append((a, b, b + 1, a + 1))
    return verts, faces


def surface2d(pts, thickness, axis="y", offset=0.0):
    """把 XZ 平面内的简单多边形沿 axis 挤出成薄板（闭合）。"""
    n = len(pts)
    verts = []
    for s in (-0.5, 0.5):
        d = s * thickness + offset
        if axis == "y":
            verts.extend([(x, d, z) for (x, z) in pts])
        else:
            verts.extend([(d, x, z) for (x, z) in pts])
    faces = [tuple(range(n))[::-1], tuple(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, n + j, n + i))
    return verts, faces


def revolved(profile, sides=8):
    """绕 Z 轴旋成体：profile = [(z, r), ...]，两端以三角扇封盖。"""
    verts = []
    for z, r in profile:
        for i in range(sides):
            a = 2.0 * math.pi * i / sides
            verts.append((r * math.cos(a), r * math.sin(a), z))
    faces = []
    n = len(profile)
    for k in range(n - 1):
        a, b = k * sides, (k + 1) * sides
        for i in range(sides):
            j = (i + 1) % sides
            faces.append((a + i, a + j, b + j, b + i))
    top = (n - 1) * sides
    for i in range(1, sides - 1):
        faces.append((0, i, i + 1))
        faces.append((top, top + i + 1, top + i))
    return verts, faces


def arc_box(cx, cz, r_in, r_out, a0, a1, y0, y1, seg=12):
    """弧形闭合箱体（轮罩顶盖，径向厚度 r_out-r_in）。"""
    verts, faces = [], []
    for i in range(seg + 1):
        a = a0 + (a1 - a0) * i / seg
        co, si = math.cos(a), math.sin(a)
        verts.extend([(cx + r_out * co, y0, cz + r_out * si),
                      (cx + r_out * co, y1, cz + r_out * si),
                      (cx + r_in * co, y1, cz + r_in * si),
                      (cx + r_in * co, y0, cz + r_in * si)])
    for i in range(seg):
        a, b = i * 4, (i + 1) * 4
        faces.append((a, b, b + 1, a + 1))
        faces.append((a + 3, a + 2, b + 2, b + 3))
        faces.append((a + 1, b + 1, b + 2, a + 2))
        faces.append((a, a + 3, b + 3, b))
    for k in (0, seg):
        a = k * 4
        faces.append((a, a + 1, a + 2, a + 3))
    return verts, faces


def hollow_band(p0, p1, r_in, r_out, sides=8):
    """空心圆筒（绕 p0->p1 轴）：内外壁 + 上下环面，闭合；用作桅箍。"""
    d = vnorm(vsub(p1, p0))
    u = vcross(d, (0.0, 0.0, 1.0))
    if vlen(u) < 1e-6:
        u = vcross(d, (1.0, 0.0, 0.0))
    u = vnorm(u)
    v = vnorm(vcross(d, u))
    verts = []
    for p, r in ((p0, r_out), (p1, r_out), (p1, r_in), (p0, r_in)):
        for i in range(sides):
            a = 2.0 * math.pi * i / sides
            verts.append(vadd(p, vadd(vmul(u, r * math.cos(a)),
                                      vmul(v, r * math.sin(a)))))
    faces = []
    for k in range(4):
        a = k * sides
        b = ((k + 1) % 4) * sides
        for i in range(sides):
            j = (i + 1) % sides
            faces.append((a + i, a + j, b + j, b + i))
    return verts, faces


def mirror_part(part):
    """沿 Y = 0 镜像（左舷 <-> 右舷），保持面法线朝外。"""
    out = Part()
    out.verts = [(x, -y, z) for (x, y, z) in part.verts]
    out.faces = [(tuple(reversed(f)), m) for (f, m) in part.faces]
    return out


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


def deck_raise_at(x):
    if x >= FORE_X:
        return FORE_RAISE
    if x <= POOP_X:
        return POOP_RAISE
    return 0.0


def deck_surface_z(x):
    return deck_z_at(x) + deck_raise_at(x) + 0.02


def stations_in(x0, x1):
    """取 [x0, x1] 内的站，并补上两端点（按插值），x 升序返回。"""
    out = [x0]
    for st in STATIONS:
        if x0 + 1e-6 < st[0] < x1 - 1e-6:
            out.append(st[0])
    out.append(x1)
    return sorted(set(out))


def hull_profile_at(x, z):
    """船体侧表面：给定 x 与目标高度 z，返回 (y, 外法线 y 分量符号)。"""
    w, dz, kz = interp_station(x)
    if dz - kz < 1e-6:
        return w * DECK_W_FRAC, 1.0
    fzt = (z - kz) / (dz - kz)
    fzt = max(0.0, min(1.0, fzt))
    for i in range(len(PROFILE) - 1):
        fy0, fz0 = PROFILE[i]
        fy1, fz1 = PROFILE[i + 1]
        if fz0 <= fzt <= fz1:
            t = (fzt - fz0) / (fz1 - fz0) if fz1 - fz0 > 1e-9 else 0.0
            return (fy0 + t * (fy1 - fy0)) * w, 1.0
    return PROFILE[-1][0] * w, 1.0


# ============================================================
# 船体 / 甲板 / 舷墙 / 龙骨 / 舵
# ============================================================

def build_hull():
    """闭合船体：18 个横剖面站放样；水线附近的面用红色船底漆。"""
    part = Part()
    rings = []
    for x, w, dz, kz in STATIONS:
        pts = [(x, fy * w, kz + fz * (dz - kz)) for (fy, fz) in PROFILE]
        # 注意：镜像必须包含甲板边缘点（pts[1:]），遗漏会导致右舷少一层列板
        rings.append(pts + [(x, -y, z) for (x, y, z) in reversed(pts[1:])])
    nr = len(rings[0])
    verts, idx = [], []
    for ring in rings:
        idx.append(len(verts))
        verts.extend(ring)
    faces = []
    for i in range(len(rings) - 1):
        a, b = idx[i], idx[i + 1]
        for j in range(nr):
            j2 = (j + 1) % nr
            faces.append((a + j, a + j2, b + j2, b + j))
    faces.append(tuple(idx[0] + k for k in range(nr))[::-1])
    faces.append(tuple(idx[-1] + k for k in range(nr)))
    part.verts = verts
    for f in faces:
        cz = sum(verts[i][2] for i in f) / len(f)
        part.faces.append((f, MAT_RED if cz < 0.30 else MAT_IRON))
    return part


def deck_grid_part(xs, width_frac, raise_h, material, camber=DECK_CAMBER,
                   ny=6, z_bias=0.02):
    """沿站生成带拱度的甲板面（单层，法线朝上）。"""
    verts, faces = [], []
    for x in xs:
        w = half_beam_at(x)
        wd = width_frac * w
        z0 = deck_z_at(x) + raise_h + z_bias
        for k in range(ny + 1):
            t = -1.0 + 2.0 * k / ny
            verts.append((x, t * wd, z0 + camber * (1.0 - t * t)))
    for i in range(len(xs) - 1):
        for k in range(ny):
            a = i * (ny + 1) + k
            b = (i + 1) * (ny + 1) + k
            faces.append((a, b, b + 1, a + 1))
    part = Part()
    part.add((verts, faces), material)
    part.recalc = False
    return part


def build_main_deck():
    return deck_grid_part(stations_in(-27.5, 27.5), DECK_W_FRAC, 0.0, MAT_DECK)


def build_forecastle_deck():
    return deck_grid_part(stations_in(FORE_X, 27.5), DECK_W_FRAC, FORE_RAISE, MAT_DECK)


def build_poop_deck():
    return deck_grid_part(stations_in(-27.5, POOP_X), DECK_W_FRAC, POOP_RAISE, MAT_DECK)


def build_forecastle_deck():
    return deck_grid_part(stations_in(FORE_X, 27.5), DECK_W_FRAC, FORE_RAISE, MAT_DECK)


def build_poop_deck():
    return deck_grid_part(stations_in(-27.5, POOP_X), DECK_W_FRAC, POOP_RAISE, MAT_DECK)


def loop_points(xs):
    """甲板边缘闭合环：左舷 x0->x1，再右舷 x1->x0。"""
    loop = []
    for x in xs:
        loop.append((x, DECK_W_FRAC * half_beam_at(x), deck_surface_z(x)))
    for x in reversed(xs):
        loop.append((x, -DECK_W_FRAC * half_beam_at(x), deck_surface_z(x)))
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


def band_from_loop(loop, normals, z_bot, z_top, out_off, in_off, material):
    """沿闭合环的带状闭合体（舷墙 / 压条 / 栏杆基座）。"""
    verts = []
    for (x, y, _z), (nx, ny) in zip(loop, normals):
        verts.extend([
            (x + nx * out_off, y + ny * out_off, z_bot),
            (x + nx * out_off, y + ny * out_off, z_top),
            (x + nx * in_off, y + ny * in_off, z_bot),
            (x + nx * in_off, y + ny * in_off, z_top),
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


def build_bulwark(x0, x1):
    xs = stations_in(x0, x1)
    loop = loop_points(xs)
    nrm = loop_normals(loop)
    part = Part()
    z_bot = [p[2] - 0.03 for p in loop]
    z_top = [p[2] + BULWARK_H for p in loop]
    # 每点高度不同，band_from_loop 用统一 z，这里展开成逐点版本
    verts = []
    for (x, y, _z), (nx, ny), zb, zt in zip(loop, nrm, z_bot, z_top):
        verts.extend([
            (x + nx * BULWARK_T * 0.5, y + ny * BULWARK_T * 0.5, zb),
            (x + nx * BULWARK_T * 0.5, y + ny * BULWARK_T * 0.5, zt),
            (x - nx * BULWARK_T * 0.5, y - ny * BULWARK_T * 0.5, zb),
            (x - nx * BULWARK_T * 0.5, y - ny * BULWARK_T * 0.5, zt),
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
    part.add((verts, faces), MAT_IRON)
    # 黄铜压条
    cap = []
    R = BULWARK_T * 0.5 + 0.05
    for (x, y, _z), (nx, ny), zt in zip(loop, nrm, z_top):
        cap.extend([
            (x + nx * R, y + ny * R, zt - 0.01),
            (x + nx * R, y + ny * R, zt + 0.06),
            (x - nx * R, y - ny * R, zt - 0.01),
            (x - nx * R, y - ny * R, zt + 0.06),
        ])
    cfaces = []
    for k in range(n):
        k2 = (k + 1) % n
        a, b = k * 4, k2 * 4
        cfaces.append((a, b, b + 1, a + 1))
        cfaces.append((a + 3, a + 2, b + 2, b + 3))
        cfaces.append((a + 1, b + 1, b + 3, a + 3))
        cfaces.append((a, a + 2, b + 2, b))
    part.add((cap, cfaces), MAT_BRASS)
    return part


def build_break_wall(x, raise_h, facing=1.0):
    """断阶舱壁：主甲板 -> 抬升甲板，带舱门与直梯。"""
    part = Part()
    w = DECK_W_FRAC * half_beam_at(x) - 0.04
    za = deck_z_at(x) - 0.05
    zb = deck_z_at(x) + raise_h + 0.05
    part.add(box((x - BREAK_T * 0.5, -w, za), (x + BREAK_T * 0.5, w, zb)), MAT_IRON)
    # 舱门（木门 + 黄铜门框）
    xf = x - facing * (BREAK_T * 0.5 + 0.02)
    yd = 1.60
    part.add(box((xf - 0.04, yd - 0.55, za), (xf + 0.02, yd + 0.55, za + 1.90)), MAT_WOOD)
    for (fy0, fy1, fz0, fz1) in ((yd - 0.62, yd - 0.55, za, za + 1.98),
                                 (yd + 0.55, yd + 0.62, za, za + 1.98),
                                 (yd - 0.62, yd + 0.62, za + 1.90, za + 1.98)):
        part.add(box((xf - 0.06, fy0, fz0), (xf + 0.01, fy1, fz1)), MAT_BRASS)
    # 直梯（两根边梁 + 5 级踏棍）
    yl = -1.90
    for sy in (-0.34, 0.34):
        part.add(box((xf - 0.05, yl + sy - 0.04, za), (xf + 0.02, yl + sy + 0.04,
                                                       za + raise_h + 0.55)), MAT_METAL)
    for i in range(5):
        z = za + 0.22 + i * (raise_h + 0.30) / 5.0
        part.add(box((xf - 0.07, yl - 0.30, z - 0.025), (xf, yl + 0.30, z + 0.025)),
                 MAT_METAL)
    return part


def build_raised_plating():
    """艏楼 / 艉楼抬高甲板与 hull 顶缘之间的舷侧封板（左右各一条，闭合）。"""
    part = Part()
    for x0, x1, raise_h in ((FORE_X, 27.50, FORE_RAISE),
                            (-27.50, POOP_X, POOP_RAISE)):
        xs = stations_in(x0, x1)
        for side in (1, -1):
            verts = []
            for x in xs:
                w = DECK_W_FRAC * half_beam_at(x)
                z0 = deck_z_at(x)
                z1 = deck_z_at(x) + raise_h + 0.03
                y = side * w
                yi = side * (w - 0.07)
                verts.extend([(x, y, z0), (x, y, z1), (x, yi, z1), (x, yi, z0)])
            n = len(xs)
            faces = []
            for i in range(n - 1):
                a, b = i * 4, (i + 1) * 4
                faces.append((a, b, b + 1, a + 1))       # 外壁
                faces.append((a + 3, a + 2, b + 2, b + 3))  # 内壁
                faces.append((a + 1, b + 1, b + 2, a + 2))  # 顶面
                faces.append((a, a + 3, b + 3, b))       # 底面
            faces.append((3, 2, 1, 0))
            last = (n - 1) * 4
            faces.append((last, last + 1, last + 2, last + 3))
            part.add((verts, faces), MAT_IRON)
    return part


def build_keel():
    part = Part()
    rings = []
    for x, w, dz, kz in STATIONS:
        rings.append([(x, -0.19, kz - 0.10), (x, 0.19, kz - 0.10),
                      (x, 0.19, kz + 0.22), (x, -0.19, kz + 0.22)])
    verts, idx = [], []
    for r in rings:
        idx.append(len(verts))
        verts.extend(r)
    faces = []
    for i in range(len(rings) - 1):
        a, b = idx[i], idx[i + 1]
        for j in range(4):
            j2 = (j + 1) % 4
            faces.append((a + j, a + j2, b + j2, b + j))
    faces.append((idx[0] + 3, idx[0] + 2, idx[0] + 1, idx[0] + 0))
    faces.append((idx[-1] + 0, idx[-1] + 1, idx[-1] + 2, idx[-1] + 3))
    part.add((verts, faces), MAT_IRON)
    # 艏柱 + 艉柱
    part.add(box((27.30, -0.14, 0.20), (27.62, 0.14, 3.82)), MAT_IRON)
    part.add(box((-27.64, -0.14, -0.40), (-27.34, 0.14, 3.52)), MAT_IRON)
    return part


def build_rudder():
    part = Part()
    part.add(box((-28.42, -0.12, -2.10), (-27.66, 0.12, 1.90)), MAT_IRON)
    part.add(box((-28.46, -0.14, 1.95), (-27.62, 0.14, 2.30)), MAT_IRON)
    for zc in (1.10, 0.05, -1.05):
        part.add(box((-28.50, -0.155, zc - 0.09), (-27.60, 0.155, zc + 0.09)),
                 MAT_METAL)
    return part


def build_portholes():
    """两舷舷窗：黄铜窗圈，沿船体侧表面外凸。"""
    part = Part()
    xs = []
    x = PORTHOLE_X0
    while x <= PORTHOLE_X1 + 1e-6:
        xs.append(x)
        x += PORTHOLE_STEP
    for x in xs:
        wy, _s = hull_profile_at(x, PORTHOLE_Z)
        for side in (1, -1):
            p0 = (x, side * (wy + 0.01), PORTHOLE_Z)
            p1 = (x, side * (wy + 0.10), PORTHOLE_Z)
            part.add(taper_cyl(p0, p1, 0.17, 0.15, sides=6), MAT_BRASS)
    return part


def build_hawse_and_anchors():
    part = Part()
    # 锚链筒
    for side in (1, -1):
        p0 = (25.30, side * 1.72, 2.55)
        p1 = (25.30, side * 1.95, 2.55)
        part.add(taper_cyl(p0, p1, 0.20, 0.22, sides=6), MAT_METAL)
    # 锚（挂在舷外）：锚杆 + 横杆 + 两臂 + 锚爪 + 锚环
    ax, az = 24.30, 2.00
    for side in (1, -1):
        y = side * 2.18
        part.add(box((ax - 0.07, y - 0.06, az - 0.80), (ax + 0.07, y + 0.06, az + 0.60)),
                 MAT_IRON)
        part.add(box((ax - 0.06, y - 0.46, az + 0.48), (ax + 0.06, y + 0.46, az + 0.60)),
                 MAT_IRON)
        for ax_dir in (1, -1):
            u = vnorm((ax_dir * 0.94, 0.0, -0.34))
            v = (0.0, 1.0, 0.0)
            w = vnorm(vcross(u, v))
            part.add(frame_box((ax + ax_dir * 0.27, y, az - 1.00), u, v, w,
                               0.32, 0.06, 0.06), MAT_IRON)
            part.add(box((ax + ax_dir * 0.52 - 0.11, y - 0.055, az - 1.20),
                         (ax + ax_dir * 0.52 + 0.11, y + 0.055, az - 0.98)), MAT_METAL)
        part.add(taper_cyl((ax, y, az + 0.62), (ax, y, az + 0.78), 0.09, 0.09, sides=6),
                 MAT_METAL)
    return part


# ============================================================
# 明轮 / 轮罩 / 锅炉与烟囱 / 桥楼
# ============================================================

def build_paddle_wheel():
    """左舷明轮（右舷由 mirror_part 生成）。轴心即为 Pivot 位置。"""
    cfg = PADDLE
    xc, zc, r = cfg["x"], cfg["z"], cfg["r"]
    y_lo, y_hi = cfg["y_in"], cfg["y_out"]
    y_mid = 0.5 * (y_lo + y_hi)
    hw = 0.5 * (y_hi - y_lo)
    part = Part()
    # 轮毂 + 两侧轮毂法兰盘
    part.add(taper_cyl((xc, y_lo, zc), (xc, y_hi, zc), 0.42, 0.42, 10), MAT_IRON)
    for yy in (y_lo + 0.05, y_hi - 0.05):
        part.add(taper_cyl((xc, yy - 0.05, zc), (xc, yy + 0.05, zc), 0.60, 0.60, 10),
                 MAT_METAL)
    # 内外两道主轮缘 + 内加强环；外侧面加黄铜轮缘条
    for y0, y1 in ((y_lo, y_lo + 0.10), (y_hi - 0.10, y_hi)):
        part.add(ring_band(xc, zc, r - 0.16, r, y0, y1, cfg["seg"]), MAT_IRON)
        part.add(ring_band(xc, zc, 1.46, 1.58, y0, y1, cfg["seg"]), MAT_IRON)
    part.add(ring_band(xc, zc, r - 0.03, r + 0.02, y_hi - 0.06, y_hi + 0.02,
                       cfg["seg"]), MAT_BRASS)
    # 辐条（每个轮缘平面 8 根）
    hu = (r - 0.16 - 0.42) * 0.5
    rm = 0.42 + hu
    for i in range(cfg["spokes"]):
        a = 2.0 * math.pi * i / cfg["spokes"]
        u = (math.cos(a), 0.0, math.sin(a))
        v = (-math.sin(a), 0.0, math.cos(a))
        for yy in (y_lo + 0.05, y_hi - 0.05):
            c = (xc + u[0] * rm, yy, zc + u[2] * rm)
            part.add(frame_box(c, u, v, (0.0, 1.0, 0.0), hu, 0.045, 0.05), MAT_IRON)
    # 4 根斜撑：把内外两圈轮缘连成整体
    for i in range(4):
        a = 2.0 * math.pi * i / 4 + 0.2
        ca, sa = math.cos(a), math.sin(a)
        part.add(taper_cyl((xc + ca * (r - 0.08), y_lo + 0.05, zc + sa * (r - 0.08)),
                           (xc + math.cos(a + 0.5) * (r - 0.08), y_hi - 0.05,
                            zc + math.sin(a + 0.5) * (r - 0.08)),
                           0.045, 0.045, 5), MAT_METAL)
    # 桨叶（14 片，跨满轮宽）
    for i in range(cfg["blades"]):
        a = 2.0 * math.pi * i / cfg["blades"]
        u = (-math.sin(a), 0.0, math.cos(a))
        w = (math.cos(a), 0.0, math.sin(a))
        c = (xc + w[0] * (r - 0.12), y_mid, zc + w[2] * (r - 0.12))
        part.add(frame_box(c, u, w, (0.0, 1.0, 0.0), 0.21, 0.035, hw - 0.04), MAT_IRON)
    # 轴端 + 黄铜轴帽
    part.add(taper_cyl((xc, y_lo - 0.12, zc), (xc, y_hi + 0.12, zc), 0.24, 0.24, 8),
             MAT_METAL)
    part.add(taper_cyl((xc, y_hi + 0.12, zc), (xc, y_hi + 0.20, zc), 0.15, 0.10, 8),
             MAT_BRASS)
    return part


def build_paddle_box():
    """左舷轮罩：内外圆弧侧板 + 顶盖 + 端封 + 黄铜饰条。"""
    cfg, b = PADDLE, PADDLE_BOX
    xc, zc = cfg["x"], cfg["z"]
    y_in, y_out = cfg["y_in"], cfg["y_out"]
    a0, a1, seg = b["a0"], b["a1"], b["seg"]
    yi0, yi1 = y_in - 0.13, y_in - 0.03
    yo0, yo1 = y_out + 0.03, y_out + 0.13
    part = Part()
    part.add(arch_band(xc, zc, b["r_in"], b["r_out"], a0, a1, yo0, yo1, seg), MAT_RED)
    part.add(arch_band(xc, zc, b["r_in_inner"], b["r_out"], a0, a1, yi0, yi1, seg),
             MAT_IRON)
    part.add(arc_box(xc, zc, b["r_out"] - 0.06, b["r_out"] + 0.03, a0, a1,
                     yi1, yo0, seg), MAT_IRON)
    # 端封：内外侧板之间的月牙缺口（薄盒封口，保持闭合）
    # 内径收到 cap_r_in，避让明轮扫掠半径，保证轮子旋转不穿模
    for a in (a0, a1):
        ca, sa = math.cos(a), math.sin(a)
        ri, ro = b["cap_r_in"], b["r_out"]
        rm = 0.5 * (ri + ro)
        c = (xc + rm * ca, 0.5 * (yi0 + yo1), zc + rm * sa)
        u = (ca, 0.0, sa)
        v = (-sa, 0.0, ca)
        part.add(frame_box(c, u, v, (0.0, 1.0, 0.0), 0.5 * (ro - ri), 0.02,
                           0.5 * (yo1 - yi0)), MAT_IRON)
    # 外板黄铜饰条
    part.add(arch_band(xc, zc, b["r_in"] + 0.10, b["r_in"] + 0.18, a0 + 0.06,
                       a1 - 0.06, yo1, yo1 + 0.03, seg), MAT_BRASS)
    # 观察窗黄铜包边
    part.add(arch_band(xc, zc, b["r_in"] - 0.05, b["r_in"] + 0.04, a0 + 0.03,
                       a1 - 0.03, yo1, yo1 + 0.03, seg), MAT_BRASS)
    # 外板铭牌
    part.add(box((xc - 2.05, yo1, 3.42), (xc - 0.25, yo1 + 0.03, 3.72)), MAT_BRASS)
    # 与船体连接的两个撑架
    for x in (xc - 2.10, xc + 1.90):
        part.add(box((x - 0.10, y_in - 0.42, 3.30), (x + 0.10, y_in - 0.02, 4.30)),
                 MAT_IRON)
    # 明轮台（sponson）：补船体与轮罩内板之间的甲板缺口；蒸汽管经过处开槽
    part.add(box((xc - 3.40, y_in - 0.47, 2.88), (xc + 0.60, y_in - 0.02, 3.06)),
             MAT_DECK)
    part.add(box((xc + 1.40, y_in - 0.47, 2.88), (xc + 3.40, y_in - 0.02, 3.06)),
             MAT_DECK)
    for x in (xc - 3.30, xc + 3.30):
        part.add(box((x - 0.06, y_in - 0.10, 3.04), (x + 0.06, y_in + 0.04, 3.70)),
                 MAT_BRASS)
    return part


def build_boiler_casing():
    x0, x1, hy, z_top = CASING["x0"], CASING["x1"], CASING["y"], CASING["z_top"]
    z_bot = deck_z_at(0.0) + 0.02
    part = Part()
    part.add(box((x0, -hy, z_bot - 0.05), (x1, hy, z_top)), MAT_IRON)
    for side in (1, -1):
        for x in (-6.10, -1.28, 3.50):
            part.add(box((x - 0.36, side * hy - 0.03, z_bot + 0.45),
                         (x + 0.36, side * hy + 0.03, z_bot + 1.25)), MAT_BRASS)
    # 安全阀 + 汽笛立管
    for side in (1, -1):
        part.add(taper_cyl((-2.90, side * 1.55, z_top), (-2.90, side * 1.55, z_top + 0.55),
                           0.11, 0.13, 6), MAT_BRASS)
        part.add(taper_cyl((-2.90, side * 1.55, z_top + 0.55),
                           (-2.90, side * 1.55, z_top + 0.64), 0.16, 0.10, 6), MAT_METAL)
    return part


def build_skylights():
    part = Part()
    z0 = CASING["z_top"]
    for x, lx, ly in ((4.35, 1.00, 1.50), (-6.60, 1.00, 1.50)):
        half = lx * 0.5
        part.add(box((x - half, -ly * 0.5, z0 - 0.02),
                     (x + half, ly * 0.5, z0 + 0.26)), MAT_METAL)
        part.add(box((x - half + 0.10, -ly * 0.5 + 0.10, z0 + 0.26),
                     (x + half - 0.10, ly * 0.5 - 0.10, z0 + 0.31)), MAT_METAL)
        for sy in (-1, 1):
            part.add(box((x - half, sy * ly * 0.5 - 0.05, z0 + 0.24),
                         (x + half, sy * ly * 0.5 + 0.05, z0 + 0.33)), MAT_BRASS)
    return part


def build_steam_pipes():
    part = Part()
    hub_y = 0.5 * (PADDLE["y_in"] + PADDLE["y_out"])
    for side in (1, -1):
        pts = [(1.90, side * 2.55, 4.78),
               (0.40, side * 4.40, 3.62),
               (PADDLE["x"], side * hub_y, PADDLE["z"])]
        for i in range(len(pts) - 1):
            part.add(taper_cyl(pts[i], pts[i + 1], 0.13, 0.13, 6), MAT_BRASS)
        part.add(taper_cyl((0.40, side * 4.40, 3.62), (0.40, side * 4.62, 3.62),
                           0.19, 0.19, 8), MAT_METAL)
    return part


def build_funnel(f):
    """后倾烟囱：主筒 + 顶箍 + 两道黄铜箍 + 底部裙圈 + 拉索。"""
    rake = math.radians(f["rake"])
    d = (-math.sin(rake), 0.0, math.cos(rake))
    base = (f["x"], 0.0, CASING["z_top"] - 0.05)
    top = vadd(base, vmul(d, f["h"]))
    part = Part()
    part.add(taper_cyl(base, top, f["r0"], f["r1"], 10), MAT_IRON)
    part.add(taper_cyl(vadd(base, vmul(d, -0.20)), vadd(base, vmul(d, 0.45)),
                       f["r0"] + 0.10, f["r0"] + 0.04, 10), MAT_IRON)
    part.add(taper_cyl(vadd(top, vmul(d, -0.34)), vadd(top, vmul(d, 0.02)),
                       f["r1"] + 0.05, f["r1"] + 0.05, 10), MAT_RED)
    for frac in (0.60, 0.86):
        r = f["r0"] + (f["r1"] - f["r0"]) * frac
        c = vadd(base, vmul(d, f["h"] * frac))
        part.add(taper_cyl(vadd(c, vmul(d, -0.10)), vadd(c, vmul(d, 0.10)),
                           r + 0.05, r + 0.05, 10), MAT_BRASS)
    # 拉索
    for side in (1, -1):
        c = vadd(base, vmul(d, f["h"] * 0.92))
        p0 = (c[0], side * (f["r1"] + 0.10), c[2])
        p1 = (f["x"] + side * 1.60, side * (CASING["y"] - 0.10), CASING["z_top"])
        part.add(taper_cyl(p0, p1, 0.035, 0.035, 4), MAT_METAL)
    return part


def railing(p0, p1, z, height=1.0, spacing=1.15, material=MAT_METAL, post=0.05):
    """两点之间的直线栏杆：立柱 + 两道横杆。"""
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]
    L = math.hypot(dx, dy)
    if L < 1e-6:
        return Part()
    u = (dx / L, dy / L, 0.0)
    v = (-u[1], u[0], 0.0)
    n = max(1, int(round(L / spacing)))
    part = Part()
    for i in range(n + 1):
        t = i / n
        c = (p0[0] + dx * t, p0[1] + dy * t, z + height * 0.5)
        part.add(frame_box(c, u, v, (0.0, 0.0, 1.0), post, post, height * 0.5), material)
    for hz in (height * 0.45, height * 0.95):
        c = ((p0[0] + p1[0]) * 0.5, (p0[1] + p1[1]) * 0.5, z + hz)
        part.add(frame_box(c, u, v, (0.0, 0.0, 1.0), L * 0.5, 0.025, 0.025), material)
    return part


def build_bridge():
    b = BRIDGE
    xc = b["x"]
    x0, x1 = xc - b["half_len"], xc + b["half_len"]
    hw, z = b["half_wid"], b["z"]
    part = Part()
    part.add(box((x0, -hw, z - 0.14), (x1, hw, z)), MAT_DECK)
    for sx in (-b["half_len"] + 0.40, b["half_len"] - 0.40):
        for sy in (-2.30, 2.30):
            part.add(box((xc + sx - 0.10, sy - 0.10, CASING["z_top"] - 0.02),
                         (xc + sx + 0.10, sy + 0.10, z - 0.12)), MAT_IRON)
    for sy in (-hw + 0.30, hw - 0.30):
        part.add(box((xc - 0.10, sy - 0.10, 4.40), (xc + 0.10, sy + 0.10, z - 0.12)),
                 MAT_IRON)
    for p0, p1 in (((x0, -hw), (x1, -hw)), ((x0, hw), (x1, hw)),
                   ((x0, -hw), (x0, -2.10)), ((x0, 2.10), (x0, hw)),
                   ((x1, -hw), (x1, -2.10)), ((x1, 2.10), (x1, hw))):
        part.merge(railing(p0, p1, z, 0.98))
    return part


def build_wheelhouse():
    b = BRIDGE
    xc = b["x"]
    hx0, hx1 = xc - b["house_len"] * 0.5, xc + b["house_len"] * 0.5
    hy = b["house_wid"] * 0.5
    z0 = b["z"] - 0.02
    z1 = z0 + b["house_h"]
    part = Part()
    part.add(box((hx0, -hy, z0), (hx0 + 0.10, hy, z1)), MAT_IRON)
    part.add(box((hx1 - 0.10, -hy, z0), (hx1, hy, z1)), MAT_IRON)
    part.add(box((hx0, -hy, z0), (hx1, -hy + 0.10, z1)), MAT_IRON)
    part.add(box((hx0, hy - 0.10, z0), (hx1, hy, z1)), MAT_IRON)
    # 黄铜窗带（四周外凸 3 cm）
    zc0, zc1 = z1 - 0.85, z1 - 0.40
    part.add(box((hx0 - 0.03, -hy - 0.03, zc0), (hx0 + 0.03, hy + 0.03, zc1)), MAT_BRASS)
    part.add(box((hx1 - 0.03, -hy - 0.03, zc0), (hx1 + 0.03, hy + 0.03, zc1)), MAT_BRASS)
    part.add(box((hx0 - 0.03, -hy - 0.03, zc0), (hx1 + 0.03, -hy + 0.03, zc1)), MAT_BRASS)
    part.add(box((hx0 - 0.03, hy - 0.03, zc0), (hx1 + 0.03, hy + 0.03, zc1)), MAT_BRASS)
    part.add(box((hx0 - 0.18, -hy - 0.18, z1), (hx1 + 0.18, hy + 0.18, z1 + 0.16)),
             MAT_METAL)
    # 后门
    part.add(box((hx0 - 0.02, -0.55, z0), (hx0 + 0.03, 0.55, z0 + 1.20)), MAT_WOOD)
    # 汽笛
    for i, r in enumerate((0.06, 0.055, 0.05)):
        part.add(taper_cyl((hx1 - 0.55, 0.55 + i * 0.16, z1 + 0.16),
                           (hx1 - 0.55, 0.55 + i * 0.16, z1 + 0.55), r, r, 6),
                 MAT_BRASS)
    return part


def build_deckhouse():
    d = DECKHOUSE
    xc, lx, ly, h = d["x"], d["lx"], d["ly"], d["h"]
    z0 = deck_z_at(xc) + 0.02
    x0, x1, hy = xc - lx * 0.5, xc + lx * 0.5, ly * 0.5
    z1 = z0 + h
    part = Part()
    part.add(box((x0, -hy, z0 - 0.04), (x1, hy, z1)), MAT_WOOD)
    part.add(box((x0 - 0.14, -hy - 0.14, z1), (x1 + 0.14, hy + 0.14, z1 + 0.12)),
             MAT_METAL)
    for side in (1, -1):
        for x in (xc - 0.95, xc, xc + 0.95):
            part.add(box((x - 0.32, side * hy - 0.03, z0 + 0.55),
                         (x + 0.32, side * hy + 0.03, z0 + 1.35)), MAT_BRASS)
    part.add(box((x1 - 0.02, -0.50, z0), (x1 + 0.04, 0.50, z0 + 1.55)), MAT_WOOD)
    for sy in (-1, 1):
        part.add(box((x1 - 0.06, sy * 0.50 - 0.06, z0), (x1 + 0.08, sy * 0.50 + 0.06,
                                                          z0 + 1.62)), MAT_BRASS)
    # 厨房烟斗
    part.add(taper_cyl((x0 + 0.55, hy - 0.55, z1), (x0 + 0.55, hy - 0.55, z1 + 1.10),
                       0.09, 0.11, 6), MAT_METAL)
    return part


# ============================================================
# 桅杆 / 索具 / 舱口 / 吊杆 / 甲板属具
# ============================================================

def build_mast(m):
    """蒸汽货轮桅杆（几何来自 rig_kit.steamer_mast）。"""
    part = Part()
    b = rig_kit.builder(part, sys.modules[__name__])
    rig_kit.steamer_mast(b, m)
    return part


def build_yards():
    """蒸汽货轮横桁 + 收帆卷（几何来自 rig_kit.steamer_yard）。"""
    part = Part()
    b = rig_kit.builder(part, sys.modules[__name__])
    for mast in MASTS:
        rig_kit.steamer_yard(b, mast)
    return part


def build_bowsprit():
    """蒸汽货轮艏斜桁（几何来自 rig_kit.steamer_bowsprit）。"""
    part = Part()
    b = rig_kit.builder(part, sys.modules[__name__])
    rig_kit.steamer_bowsprit(b, {
        "x0": BOWSPRIT["x0"], "z0": BOWSPRIT["z0"],
        "x1": BOWSPRIT["x1"], "z1": BOWSPRIT["z1"],
        "r0": BOWSPRIT["r0"], "r1": BOWSPRIT["r1"],
        "gammon_lo": (27.15, -0.24, 3.10),
        "gammon_hi": (27.55, 0.24, 4.05),
    })
    return part


def build_rigging():
    """蒸汽货轮索具（几何来自 rig_kit.steamer_rigging；锚点为本船布局）。"""
    part = Part()
    b = rig_kit.builder(part, sys.modules[__name__])
    rig_kit.steamer_rigging(b, {
        "masts": MASTS,
        "booms": BOOMS,
        "anchors": {
            "fore_head": (30.80, 0.0, 5.02),
            "stem": (27.70, 0.0, 1.15),
            "fore_shroud_a": (23.45, 2.25, 5.58),
            "fore_shroud_b": (21.85, 2.35, 5.58),
            "main_shroud_a": (-24.95, 2.95, 5.30),
            "main_shroud_b": (-22.70, 3.05, 5.30),
            "main_truck": (-27.25, 1.05, 5.40),
        },
    })
    return part


def build_hatches():
    part = Part()
    for h in HATCHES:
        x, lx, ly, hh = h["x"], h["lx"], h["ly"], h["h"]
        zdeck = deck_z_at(x) + 0.02 + 0.06
        z0, z1 = zdeck - 0.12, zdeck + hh
        t = 0.13
        for sy in (-1, 1):
            y0 = sy * ly * 0.5
            part.add(box((x - lx * 0.5, y0 - (t if sy < 0 else 0.0), z0),
                         (x + lx * 0.5, y0 + (0.0 if sy < 0 else t), z1)), MAT_IRON)
        for sx in (-1, 1):
            x0 = sx * lx * 0.5
            part.add(box((x + x0 - (t if sx < 0 else 0.0), -ly * 0.5 + t, z0),
                         (x + x0 + (0.0 if sx < 0 else t), ly * 0.5 - t, z1)), MAT_IRON)
        part.add(box((x - lx * 0.5 + 0.12, -ly * 0.5 + 0.12, z1 - 0.18),
                     (x + lx * 0.5 - 0.12, ly * 0.5 - 0.12, z1 - 0.07)), MAT_DECK)
        for i in range(3):
            xx = x - lx * 0.5 + (i + 1) * lx / 4.0
            part.add(box((xx - 0.055, -ly * 0.5 + 0.10, z1 - 0.05),
                         (xx + 0.055, ly * 0.5 - 0.10, z1 + 0.01)), MAT_METAL)
    return part


def build_booms():
    part = Part()
    for name, hx, hy, hz, tx, ty, tz, r0, r1 in BOOMS:
        # 鹅颈座：空心桅箍（r_in 0.36 > 桅半径 0.346，不穿桅杆）
        part.add(hollow_band((hx, 0, hz - 0.22), (hx, 0, hz + 0.22), 0.36, 0.46, 8),
                 MAT_METAL)
        for side in (1, -1):
            p0 = (hx, side * hy, hz)
            p1 = (tx, side * ty, tz)
            part.add(taper_cyl(p0, p1, r0, r1, 6), MAT_WOOD)
            ya, yb = sorted((side * 0.37, side * 0.62))
            part.add(box((hx - 0.16, ya, hz - 0.14),
                         (hx + 0.16, yb, hz + 0.14)), MAT_METAL)
            v = vsub(p1, p0)
            n = vnorm(v)
            block = vadd(p1, vmul(n, -0.10))
            part.add(box((block[0] - 0.10, block[1] - 0.10, block[2] - 0.10),
                         (block[0] + 0.10, block[1] + 0.10, block[2] + 0.10)), MAT_METAL)
    return part


def build_windlass():
    x = 24.00
    z = deck_z_at(x) + FORE_RAISE + 0.02
    part = Part()
    part.add(taper_cyl((x, -1.20, z + 0.62), (x, 1.20, z + 0.62), 0.42, 0.42, 8),
             MAT_METAL)
    for sy in (-1.30, 1.30):
        part.add(box((x - 0.26, sy - 0.10, z), (x + 0.26, sy + 0.10, z + 0.95)), MAT_IRON)
    part.add(taper_cyl((x, -1.46, z + 0.62), (x, 1.46, z + 0.62), 0.20, 0.20, 8),
             MAT_BRASS)
    for i in range(4):
        # 45° 相位：手柄斜跨甲板，避开艏部收窄的舷墙
        a = math.pi * 0.5 * i + math.pi * 0.25
        u = (math.cos(a), 0.0, math.sin(a))
        v = (-math.sin(a), 0.0, math.cos(a))
        for sy in (-1.55, 1.55):
            c = (x + u[0] * 0.68, sy, z + 0.62 + u[2] * 0.68)
            part.add(frame_box(c, u, v, (0.0, 1.0, 0.0), 0.60, 0.045, 0.045), MAT_METAL)
    return part


def build_capstan():
    x = 19.35
    z0 = deck_z_at(x) + 0.02
    profile = [(0.00, 0.66), (0.10, 0.66), (0.10, 0.52), (0.34, 0.44),
               (0.52, 0.40), (0.64, 0.30), (0.70, 0.20), (0.66, 0.14)]
    part = Part()
    part.add(translate(revolved(profile, 8), x, 0.0, z0), MAT_METAL)
    part.add(taper_cyl((x, 0, z0 + 0.60), (x, 0, z0 + 0.78), 0.14, 0.10, 8), MAT_BRASS)
    for i in range(4):
        a = math.pi * 0.5 * i
        u = (math.cos(a), 0.0, math.sin(a))
        v = (-math.sin(a), 0.0, math.cos(a))
        c = (x + u[0] * 0.36, 0.0, z0 + 0.46 + u[2] * 0.36)
        part.add(frame_box(c, u, v, (0.0, 1.0, 0.0), 0.38, 0.035, 0.035), MAT_METAL)
    return part


def build_bollards():
    part = Part()
    for x in (13.30, 19.30, -14.20, -19.90):
        y = 0.80 * DECK_W_FRAC * half_beam_at(x)
        z = deck_z_at(x) + 0.02
        for side in (1, -1):
            yy = side * y
            part.add(box((x - 0.58, yy - 0.34, z - 0.02), (x + 0.58, yy + 0.34, z + 0.08)),
                     MAT_IRON)
            for dy in (-0.26, 0.26):
                part.add(taper_cyl((x, yy + dy, z + 0.05), (x, yy + dy, z + 0.60),
                                   0.145, 0.125, 6), MAT_METAL)
    return part


def build_vents():
    part = Part()
    z0 = CASING["z_top"] - 0.02
    for side in (1, -1):
        p0 = (4.30, side * 1.90, z0)
        p1 = (4.30, side * 1.90, z0 + 1.05)
        part.add(taper_cyl(p0, p1, 0.30, 0.28, 8), MAT_METAL)
        part.add(taper_cyl(p1, (5.10, side * 1.90, z0 + 1.32), 0.28, 0.40, 8), MAT_METAL)
        part.add(taper_cyl((5.10, side * 1.90, z0 + 1.32),
                           (5.02, side * 1.90, z0 + 1.34), 0.41, 0.43, 8), MAT_BRASS)
    return part


def build_bell():
    x, y = 20.90, 0.0
    z0 = deck_z_at(x) + FORE_RAISE + 0.02
    part = Part()
    for sy in (-0.36, 0.36):
        part.add(box((x - 0.05, y + sy - 0.05, z0), (x + 0.05, y + sy + 0.05, z0 + 1.00)),
                 MAT_IRON)
    part.add(box((x - 0.05, y - 0.42, z0 + 0.92), (x + 0.05, y + 0.42, z0 + 1.00)),
             MAT_IRON)
    profile = [(0.00, 0.14), (0.08, 0.20), (0.18, 0.26), (0.26, 0.25), (0.30, 0.15)]
    part.add(translate(revolved(profile, 6), x, y, z0 + 0.62), MAT_BRASS)
    return part


def build_lifeboat_side():
    """3.4 m 救生艇，挂在左舷后甲板舷墙顶的吊艇架上（架脚不穿舷墙/船体）。"""
    stations = [(-1.70, 0.10, 0.50, 0.0), (-1.10, 0.34, 0.54, 0.0),
                (0.00, 0.50, 0.56, 0.0), (1.10, 0.40, 0.54, 0.0),
                (1.70, 0.12, 0.50, 0.0)]
    profile = [(0.00, 0.00), (0.55, 0.10), (0.92, 0.42), (1.00, 0.80), (0.90, 1.00)]
    rings = []
    for x, w, dz, kz in stations:
        pts = [(x, fy * w, kz + fz * (dz - kz)) for (fy, fz) in profile]
        rings.append(pts + [(x, -y, z) for (x, y, z) in reversed(pts[1:])])
    nr = len(rings[0])
    verts, idx = [], []
    for r in rings:
        idx.append(len(verts))
        verts.extend(r)
    faces = []
    for i in range(len(rings) - 1):
        a, b = idx[i], idx[i + 1]
        for j in range(nr):
            j2 = (j + 1) % nr
            faces.append((a + j, a + j2, b + j2, b + j))
    faces.append(tuple(idx[0] + k for k in range(nr))[::-1])
    faces.append(tuple(idx[-1] + k for k in range(nr)))
    boat = Part()
    boat.add((verts, faces), MAT_WOOD)
    for x in (-0.80, 0.40):
        boat.add(box((x - 0.09, -0.42, 0.28), (x + 0.09, 0.42, 0.36)), MAT_DECK)
    for sy in (-1, 1):
        boat.add(taper_cyl((-1.35, sy * 0.24, 0.44), (1.35, sy * 0.24, 0.44),
                           0.03, 0.03, 5), MAT_DECK)
    dx, dy, dz = -19.00, 4.75, 3.30
    out = Part()
    out.verts = [(x + dx, y + dy, zz + dz) for (x, y, zz) in boat.verts]
    out.faces = boat.faces
    # 吊艇架：底座坐在舷墙黄铜压条顶面（留 5 mm），架杆向外上方伸出，不穿墙不穿壳
    for x in (-20.55, -17.45):
        yb = DECK_W_FRAC * half_beam_at(x)
        cap_top = deck_surface_z(x) + BULWARK_H + 0.06
        zb = cap_top + 0.005
        out.add(box((x - 0.13, yb - 0.15, zb),
                    (x + 0.13, yb + 0.15, zb + 0.10)), MAT_METAL)
        p0 = (x, yb, zb + 0.07)
        p1 = (x, yb + 0.92, zb + 0.55)
        out.add(taper_cyl(p0, p1, 0.09, 0.06, 6), MAT_METAL)
        out.add(box((x - 0.10, p1[1] - 0.10, p1[2] - 0.06),
                    (x + 0.10, p1[1] + 0.10, p1[2] + 0.07)), MAT_METAL)
        tip = (x + (-0.28 if x < -19.0 else 0.28), dy - 0.02, dz + 0.52)
        out.add(taper_cyl((x, p1[1] - 0.02, p1[2] - 0.05), tip, 0.028, 0.028, 4),
                MAT_METAL)
    return out


def build_lifeboat():
    port = build_lifeboat_side()
    return merge_parts([port, mirror_part(port)])


def build_lifeboat():
    port = build_lifeboat_side()
    return merge_parts([port, mirror_part(port)])


def build_steering_gear():
    x, y = -25.95, 0.0
    z0 = deck_z_at(x) + POOP_RAISE + 0.02
    part = Part()
    part.add(taper_cyl((x, y, z0), (x, y, z0 + 0.95), 0.22, 0.15, 8), MAT_METAL)
    # 舵轮：先按 XZ 平面建，再映射到 YZ 平面（绕 X 轴立起）
    wheel = Part()
    wheel.add(ring_band(0.0, 0.0, 0.44, 0.55, -0.03, 0.03, 12), MAT_BRASS)
    for i in range(8):
        a = 2.0 * math.pi * i / 8
        u = (math.cos(a), 0.0, math.sin(a))
        v = (-math.sin(a), 0.0, math.cos(a))
        c = (u[0] * 0.28, 0.0, u[2] * 0.28)
        wheel.add(frame_box(c, u, v, (0.0, 1.0, 0.0), 0.24, 0.03, 0.03), MAT_BRASS)
    wheel.add(taper_cyl((0.0, -0.10, 0.0), (0.0, 0.10, 0.0), 0.11, 0.11, 8), MAT_BRASS)
    # (lx, ly, lz) -> (x + ly, lx, z0 + 1.05 + lz)：轮面立到 YZ 平面
    wpart = Part()
    wpart.verts = [(x + ly, lx, z0 + 1.05 + lz) for (lx, ly, lz) in wheel.verts]
    wpart.faces = wheel.faces
    part.merge(wpart)
    # 罗经柜
    part.add(box((x - 0.28, 1.35 - 0.26, z0), (x + 0.28, 1.35 + 0.26, z0 + 0.85)),
             MAT_WOOD)
    part.add(taper_cyl((x, 1.35, z0 + 0.85), (x, 1.35, z0 + 1.06), 0.22, 0.16, 8),
             MAT_BRASS)
    return part


def build_poop_skylight():
    x, y = -25.40, -1.45
    z0 = deck_z_at(x) + POOP_RAISE + 0.02
    part = Part()
    part.add(box((x - 0.80, y - 0.55, z0), (x + 0.80, y + 0.55, z0 + 0.30)), MAT_METAL)
    part.add(box((x - 0.62, y - 0.38, z0 + 0.30), (x + 0.62, y + 0.38, z0 + 0.34)),
             MAT_METAL)
    for sy in (-1, 1):
        part.add(box((x - 0.80, y + sy * 0.55 - 0.05, z0 + 0.28),
                     (x + 0.80, y + sy * 0.55 + 0.05, z0 + 0.37)), MAT_BRASS)
    return part


def build_flag():
    part = Part()
    part.add(taper_cyl((-27.10, 0, 4.50), (-27.10, 0, 7.60), 0.09, 0.05, 6), MAT_METAL)
    for z in (5.20, 6.10):
        part.add(taper_cyl((-27.10, 0, z), (-27.10, 0, z + 0.08), 0.11, 0.11, 6),
                 MAT_BRASS)
    nu, nv = 4, 3
    verts, faces = [], []
    for i in range(nu + 1):
        u = i / nu
        for j in range(nv + 1):
            v = j / nv
            yy = 0.10 * math.sin(u * math.pi) * (1.0 - 0.3 * v)
            verts.append((-27.08 - 1.05 * u, yy, 6.35 + 0.95 * v))
    for i in range(nu):
        for j in range(nv):
            a = i * (nv + 1) + j
            b = (i + 1) * (nv + 1) + j
            faces.append((a, b, b + 1, a + 1))
    part.add((verts, faces), MAT_RED)
    part.recalc = False     # 单层旗面，材质双面
    return part


# ============================================================
# 装配
# ============================================================

PIVOT_PORT = (PADDLE["x"], 0.5 * (PADDLE["y_in"] + PADDLE["y_out"]), PADDLE["z"])
PIVOT_STARBOARD = (PIVOT_PORT[0], -PIVOT_PORT[1], PIVOT_PORT[2])

SOCKETS = {
    "SN_Socket_Engine": (0.00, 0.00, 3.60),
    "SN_Socket_Cabin": (-25.40, 1.80, 5.40),
    "SN_Socket_Navigation": (22.80, 0.00, 5.00),
    "SN_Socket_Safety": (6.80, 0.00, 3.40),
}


def merge_parts(parts):
    out = Part()
    for p in parts:
        off = len(out.verts)
        out.verts.extend(p.verts)
        out.faces.extend((tuple(i + off for i in f), m) for f, m in p.faces)
    return out


def build_all_geometry():
    """返回 {对象名: (Part, 父级键)}；父级键 = ROOT / PADDLE_PORT / PADDLE_STARBOARD。"""
    parts = {}

    def add(name, part, parent="ROOT"):
        parts[name] = (part, parent)

    add("SN_PF_Hull", build_hull())
    add("SN_PF_Deck", build_main_deck())
    add("SN_PF_Forecastle", build_forecastle_deck())
    add("SN_PF_Poop_Deck", build_poop_deck())
    add("SN_PF_Bulwark", merge_parts([
        build_bulwark(-27.50, -20.85),
        build_bulwark(-20.75, 20.25),
        build_bulwark(20.35, 27.50),
    ]))
    add("SN_PF_Break_Walls", merge_parts([
        build_break_wall(FORE_X, FORE_RAISE, 1.0),
        build_break_wall(POOP_X, POOP_RAISE, -1.0),
    ]))
    add("SN_PF_Raised_Plating", build_raised_plating())
    add("SN_PF_Keel", build_keel())
    add("SN_PF_Rudder", build_rudder())
    add("SN_PF_Portholes", build_portholes())
    add("SN_PF_Anchors", build_hawse_and_anchors())

    wheel = build_paddle_wheel()
    add("SN_PF_Paddle_Port", wheel, "PADDLE_PORT")
    add("SN_PF_Paddle_Starboard", mirror_part(wheel), "PADDLE_STARBOARD")
    pbox = build_paddle_box()
    add("SN_PF_Paddle_Box_Port", pbox)
    add("SN_PF_Paddle_Box_Starboard", mirror_part(pbox))

    add("SN_PF_Boiler_Casing", build_boiler_casing())
    add("SN_PF_Skylights", build_skylights())
    add("SN_PF_Steam_Pipes", build_steam_pipes())
    add("SN_PF_Funnel_Fore", build_funnel(FUNNELS[0]))
    add("SN_PF_Funnel_Main", build_funnel(FUNNELS[1]))
    add("SN_PF_Bridge", build_bridge())
    add("SN_PF_Wheelhouse", build_wheelhouse())
    add("SN_PF_Deckhouse", build_deckhouse())

    add("SN_PF_Mast_Fore", build_mast(MASTS[0]))
    add("SN_PF_Mast_Main", build_mast(MASTS[1]))
    add("SN_PF_Yards", build_yards())
    add("SN_PF_Bowsprit", build_bowsprit())
    add("SN_PF_Rigging", build_rigging())

    add("SN_PF_Cargo_Hatches", build_hatches())
    add("SN_PF_Cargo_Booms", build_booms())
    add("SN_PF_Windlass", build_windlass())
    add("SN_PF_Capstan", build_capstan())
    add("SN_PF_Bollards", build_bollards())
    add("SN_PF_Vents", build_vents())
    add("SN_PF_Bell", build_bell())
    add("SN_PF_Lifeboat", build_lifeboat())
    add("SN_PF_Steering_Gear", build_steering_gear())
    add("SN_PF_Poop_Skylight", build_poop_skylight())
    add("SN_PF_Flag", build_flag())
    return parts


# ============================================================
# Blender 侧：集合 / 材质 / 空物体层级（不进干跑）
# ============================================================

def _clean_previous():
    import bpy
    for ob in list(bpy.data.objects):
        if ob.name.startswith(PREFIX) or ob.name.startswith("SN_Socket_"):
            bpy.data.objects.remove(ob, do_unlink=True)
    old = bpy.data.collections.get(COLLECTION)
    if old is not None:
        bpy.data.collections.remove(old)
    for me in list(bpy.data.meshes):
        if me.name.startswith(PREFIX) and me.users == 0:
            bpy.data.meshes.remove(me)


def _ensure_material(name):
    import bpy
    mat = bpy.data.materials.get(name)
    if mat is not None:
        return mat
    spec = COLORS.get(name) or REUSE_COLORS[name]
    color, rough, metal = spec
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
        out = next((n for n in nt.nodes if n.type == "OUTPUT_MATERIAL"), None)
        if out is None:
            out = nt.nodes.new("ShaderNodeOutputMaterial")
        nt.links.new(bsdf.outputs[0], out.inputs[0])
    bsdf.inputs["Base Color"].default_value = (color[0], color[1], color[2], 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    mat.diffuse_color = (color[0], color[1], color[2], 1.0)
    mat.roughness = rough
    mat.metallic = metal
    return mat


def _make_object(name, part, collection, parent, origin=(0.0, 0.0, 0.0)):
    import bpy
    import bmesh
    me = bpy.data.meshes.new(name)
    local = [(x - origin[0], y - origin[1], z - origin[2]) for (x, y, z) in part.verts]
    me.from_pydata(local, [], [f for f, _m in part.faces])
    me.validate(verbose=False)
    me.update()
    if len(me.polygons) != len(part.faces):
        raise RuntimeError("%s: 面数在 validate 后变化（%d -> %d）" % (
            name, len(part.faces), len(me.polygons)))
    if getattr(part, "recalc", True):
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(me)
        bm.free()
        me.update()
    slots = []
    for _f, mat_name in part.faces:
        if mat_name not in slots:
            slots.append(mat_name)
    for mat_name in slots:
        me.materials.append(_ensure_material(mat_name))
    for poly, (_f, mat_name) in zip(me.polygons, part.faces):
        poly.material_index = slots.index(mat_name)
        poly.use_smooth = False
    ob = bpy.data.objects.new(name, me)
    collection.objects.link(ob)
    if parent is not None:
        ob.parent = parent          # 局部坐标 = 船体坐标；世界位置由根空物体位移决定
    return ob


def _add_empty(name, location, parent, size=1.0):
    import bpy
    ob = bpy.data.objects.new(name, None)
    ob.empty_display_type = "PLAIN_AXES"
    ob.empty_display_size = size
    ob.location = location
    COLLECTION_REF[0].objects.link(ob)
    if parent is not None:
        ob.parent = parent
    return ob


COLLECTION_REF = [None]


def build_all(origin=WORKBENCH_POS):
    """在 Blender 中重建整船（幂等）。origin = 根空物体的工作台摆位。"""
    import bpy
    _clean_previous()
    col = bpy.data.collections.new(COLLECTION)
    bpy.context.scene.collection.children.link(col)
    COLLECTION_REF[0] = col

    root = bpy.data.objects.new(ROOT_NAME, None)
    root.empty_display_type = "PLAIN_AXES"
    root.empty_display_size = 2.5
    root.location = origin
    col.objects.link(root)
    root["asset"] = "SN_Paddle_Freighter"
    root["version"] = "1.0"
    root["units"] = "metres"
    root["pivot"] = "waterline, centre of hull"
    root["forward_axis"] = "+X"
    root["style"] = "low-poly flat-shaded paddle steamer cargo ship"
    root["tri_budget"] = 14000

    pivots = {
        "PADDLE_PORT": _add_empty(PREFIX + "Paddle_Port_Pivot", PIVOT_PORT, root, 1.2),
        "PADDLE_STARBOARD": _add_empty(PREFIX + "Paddle_Starboard_Pivot",
                                       PIVOT_STARBOARD, root, 1.2),
    }
    for name, loc in SOCKETS.items():
        ob = _add_empty(name, loc, root, 0.6)
        ob["socket"] = name

    parts = build_all_geometry()
    origins = {"ROOT": (0.0, 0.0, 0.0),
               "PADDLE_PORT": PIVOT_PORT,
               "PADDLE_STARBOARD": PIVOT_STARBOARD}
    for name, (part, parent_key) in parts.items():
        parent = root if parent_key == "ROOT" else pivots[parent_key]
        _make_object(name, part, col, parent, origins[parent_key])
    bpy.context.view_layer.update()
    return col


def report(verbose=True):
    """只读统计：对象 / 三角面 / 包围盒 / 材质 / 命名 / 健康度摘要。"""
    import bpy
    from mathutils import Vector
    col = bpy.data.collections[COLLECTION]
    meshes = [o for o in col.objects if o.type == "MESH"]
    empties = [o for o in col.objects if o.type == "EMPTY"]
    tris = 0
    mn = Vector((1e18, 1e18, 1e18))
    mx = Vector((-1e18, -1e18, -1e18))
    for ob in meshes:
        tris += sum(max(1, len(p.vertices) - 2) for p in ob.data.polygons)
        for c in ob.bound_box:
            p = ob.matrix_world @ Vector(c)
            for i in range(3):
                mn[i] = min(mn[i], p[i])
                mx[i] = max(mx[i], p[i])
    mats = sorted({m.name for ob in meshes for m in ob.data.materials if m})
    info = {
        "collection": COLLECTION,
        "root": ROOT_NAME,
        "objects": len(col.objects),
        "meshes": len(meshes),
        "empties": len(empties),
        "tris": tris,
        "bbox": [round(mx[i] - mn[i], 3) for i in range(3)],
        "bbox_min": [round(mn[i], 3) for i in range(3)],
        "bbox_max": [round(mx[i], 3) for i in range(3)],
        "materials": mats,
        "root_location": [round(v, 3) for v in bpy.data.objects[ROOT_NAME].location],
    }
    if verbose:
        print("SN_Paddle_Freighter: %d 对象 / %d 网格 / %d 空物体" % (
            info["objects"], info["meshes"], info["empties"]))
        print("三角面: %d / 预算 14000" % tris)
        print("包围盒: %.2f x %.2f x %.2f m  (min %s / max %s)" % (
            info["bbox"][0], info["bbox"][1], info["bbox"][2],
            info["bbox_min"], info["bbox_max"]))
        print("材质: %s" % ", ".join(mats))
        print("根节点位置: %s" % info["root_location"])
        print("对象清单:")
        for ob in sorted(col.objects, key=lambda o: o.name):
            if ob.type == "MESH":
                t = sum(max(1, len(p.vertices) - 2) for p in ob.data.polygons)
                print("  %-28s mesh  %5d tri  parent=%s" % (
                    ob.name, t, ob.parent.name if ob.parent else "-"))
            else:
                print("  %-28s empty" % ob.name)
    return info


if __name__ == "__main__":
    build_all()
    report()

