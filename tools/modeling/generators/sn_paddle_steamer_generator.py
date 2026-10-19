# -*- coding: utf-8 -*-
"""Steam Navigator — SN_Paddle_Steamer 小型明轮蒸汽船参数化生成脚本。

工单
----
tools/modeling/briefs/sn_ship_paddle_steamer.json
集合：SN_Paddle_Steamer_Prototype（新增，不触碰既有对象）
轴心：船体中部水线（z = 0），+X = 船首，+Z = 向上，1 unit = 1 m
预算：<= 12000 tri
材质：SN_White / SN_Iron_Hull / SN_Iron_Red / SN_Wood_Deck / SN_Metal /
      SN_Brass / SN_Flag_Blue / SN_Flag_White

设计要点
--------
参考澳大利亚明轮蒸汽船 PS Enterprise（澳大利亚国家博物馆，伯利·格里芬湖）：
- 白色内河船身 + 深色水线以下船底 + 暗红压条；船体 LOA 24 m、型宽 5.6 m；
- 两舷梯形格栅轮罩（水平白色格栅 + 深色内衬 + 暗红顶沿），轮径 3.1 m；
- 前部封闭驾驶室（侧板 ENTERPRISE 铭牌）+ 后部白色立柱雨棚的敞开游步甲板；
- 黑色烟囱 + 黄铜箍 + 暗红顶圈；艏部旗杆挂澳洲旗；艉部弧形低平台 + 舵 + 舵柄。
  烟囱蒸汽不建模（按用户要求留给游戏内粒子/VFX 渲染）。
- 全部几何由本文件顶部参数表生成，改数值即可重建；不手工摆点。
- 几何函数是纯 Python（不 import bpy），可用 dryrun_paddle_steamer.py 离线校验。
- Blender 侧只做集合 / 材质 / 空物体层级 / 父级 / 文字铭牌；几何全部来自
  build_all_geometry()。

用法
----
Blender 内：import runpy; runpy.run_path(<本文件>, run_name="__main__")
纯 Python 干跑：python tools/modeling/generators/dryrun_paddle_steamer.py
"""

import math

# ============================================================
# 参数区
# ============================================================

COLLECTION = "SN_Paddle_Steamer_Prototype"
PREFIX = "SN_PS_"
ROOT_NAME = "SN_PS_Root"

# 工作台摆位（导出 GLB 时根节点临时归零，见 export_ship_glb.py）
WORKBENCH_POS = (45.0, 0.0, 0.0)

# 材质：名称 -> (线性 base color, roughness, metallic)
COLORS = {
    "SN_White":      ((0.760, 0.735, 0.680), 0.55, 0.00),
    "SN_Flag_Blue":  ((0.012, 0.035, 0.120), 0.75, 0.00),
    "SN_Flag_White": ((0.800, 0.800, 0.800), 0.70, 0.00),
}
# 复用工作台既有材质（不存在时才按下面数值新建）
REUSE_COLORS = {
    "SN_Iron_Hull": ((0.045, 0.048, 0.052), 0.52, 0.35),
    "SN_Iron_Red":  ((0.190, 0.035, 0.022), 0.62, 0.10),
    "SN_Wood_Deck": ((0.300, 0.165, 0.072), 0.76, 0.00),
    "SN_Metal":     ((0.140, 0.150, 0.170), 0.36, 0.90),
    "SN_Brass":     ((0.420, 0.270, 0.075), 0.28, 0.85),
}
MAT_WHITE = "SN_White"
MAT_HULL = "SN_Iron_Hull"
MAT_RED = "SN_Iron_Red"
MAT_DECK = "SN_Wood_Deck"
MAT_METAL = "SN_Metal"
MAT_BRASS = "SN_Brass"
MAT_FLAG = "SN_Flag_Blue"
MAT_FLAG_WHITE = "SN_Flag_White"

# 横剖面站：(x, 半宽 w, 甲板高 dz, 龙骨底 kz)；x 升序（-11.7 艉 -> +12.18 艏）
# 船体 LOA 24.0 m，水线 z = 0，吃水约 1.23 m，舷侧近乎直立（内河平底船）
STATIONS = [
    (-11.70, 1.00, 1.86, -0.55),
    (-11.35, 1.55, 1.80, -0.82),
    (-10.50, 2.02, 1.76, -1.00),
    (-9.30, 2.42, 1.73, -1.12),
    (-7.40, 2.64, 1.72, -1.19),
    (-5.00, 2.74, 1.72, -1.22),
    (-2.00, 2.79, 1.72, -1.23),
    (1.50, 2.80, 1.72, -1.23),
    (4.50, 2.78, 1.73, -1.21),
    (6.60, 2.71, 1.75, -1.16),
    (8.40, 2.54, 1.79, -1.07),
    (9.80, 2.25, 1.83, -0.94),
    (10.80, 1.82, 1.88, -0.76),
    (11.50, 1.28, 1.93, -0.54),
    (11.95, 0.68, 1.98, -0.28),
    (12.18, 0.18, 2.02, 0.02),
]

# 横剖面轮廓：(相对半宽, 相对吃水深度)，从龙骨中心到甲板边缘
# 内河船：平底 + 小圆舭 + 直立舷侧
PROFILE = [
    (0.000, 0.000), (0.500, 0.000), (0.740, 0.020), (0.880, 0.070),
    (0.955, 0.170), (0.990, 0.320), (1.000, 0.520), (1.000, 0.720),
    (1.000, 0.880), (0.990, 1.000),
]

DECK_W_FRAC = 0.990      # 甲板 / 舷墙所在的相对半宽
DECK_CAMBER = 0.08       # 甲板拱高
BULWARK_H = 0.60         # 舷墙高
BULWARK_OUT = 0.030      # 舷墙外偏移
BULWARK_IN = 0.075       # 舷墙内偏移
CAP_T = 0.055            # 舷墙压条厚
WATERLINE_Z = 0.12       # 白色舷侧与深色船底的分界

# 上层建筑
UPPER_Z = 3.42           # 游步甲板面
UPPER_T = 0.16           # 甲板板厚
CABIN = dict(x0=-8.20, x1=3.40, hy=2.25, z0=1.74, z1=3.26)
WHEELHOUSE = dict(x0=3.50, x1=6.60, hy=1.95, z0=UPPER_Z + 0.02, z1=5.38)
CANOPY = dict(x0=-9.35, x1=1.45, hy=2.95, z=5.24, t=0.14)
CASING = dict(x0=1.55, x1=2.95, hy=1.02, z0=UPPER_Z + 0.02, z1=4.10)
FUNNEL = dict(x=2.20, r0=0.46, r1=0.38, z0=4.08, z1=9.05)
PROM = dict(x0=-9.35, x1=7.05, w=2.72)   # 游步甲板平面范围

# 明轮：轮心 x / z，半径，轮宽（y 方向），桨叶数，辐条数，圆周分段
PADDLE = dict(x=-1.20, z=1.55, r=1.55, y_in=2.88, y_out=4.02,
              blades=10, spokes=8, seg=14)
PADDLE_BOX = dict(x0=-4.30, x1=1.90, y0=4.06, y1=4.30,
                  z0=0.90, z1=3.52, top_z=3.60)
LOUVERS = 10             # 轮罩水平格栅数

# 艏旗杆 / 澳洲旗
FLAGSTAFF = dict(x=10.35, z0=1.78, z1=8.55)
FLAG = dict(x0=10.30, z_bot=7.55, w=1.55, h=0.90)

# 艉部弧形平台（低甲板 + 栏杆）
STERN_PLATFORM = dict(x=-11.55, rx=0.62, ry=1.12, z=1.72)

# 甲板属具
PORTHOLE_XS = (-9.0, -6.0, -3.0, 0.0)
BELL = dict(x=6.10, z=5.54)
LIFEBUOY = dict(x=-8.40, y=2.64, z=2.60, R=0.30, r=0.075)


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


def prism_xz(poly, y0, y1):
    """XZ 平面多边形沿 Y 挤出成闭合棱柱（轮罩 / 侧板 / 艉平台）。"""
    n = len(poly)
    verts = [(x, y0, z) for x, z in poly] + [(x, y1, z) for x, z in poly]
    faces = [tuple(range(n))[::-1], tuple(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, n + j, n + i))
    return verts, faces


def prism_xy(poly, z0, z1):
    """XY 平面多边形沿 Z 挤出成闭合棱柱（游步甲板 / 平台板）。"""
    n = len(poly)
    verts = [(x, y, z0) for x, y in poly] + [(x, y, z1) for x, y in poly]
    faces = [tuple(range(n))[::-1], tuple(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, n + i, n + j, j))
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


def srgb_sphere(center, r, seg=8, rings=4):
    """低模球（蒸汽团）：7 段经度 × 4 段纬度。"""
    cx, cy, cz = center
    verts = [(cx, cy, cz + r)]
    for k in range(1, rings):
        phi = math.pi * k / rings
        z = cz + r * math.cos(phi)
        rr = r * math.sin(phi)
        for i in range(seg):
            a = 2.0 * math.pi * i / seg
            verts.append((cx + rr * math.cos(a), cy + rr * math.sin(a), z))
    verts.append((cx, cy, cz - r))
    faces = []
    for i in range(seg):
        j = (i + 1) % seg
        faces.append((0, 1 + i, 1 + j))
    for k in range(rings - 2):
        a = 1 + k * seg
        b = 1 + (k + 1) * seg
        for i in range(seg):
            j = (i + 1) % seg
            faces.append((a + i, b + i, b + j, a + j))
    last = 1 + (rings - 2) * seg
    bottom = len(verts) - 1
    for i in range(seg):
        j = (i + 1) % seg
        faces.append((last + i, bottom, last + j))
    return verts, faces


def torus_y(cx, cy, cz, R, r, seg=12, tube=6):
    """绕 Y 轴的圆环（救生圈）：返 (verts, faces, seg, tube)。"""
    verts = []
    for i in range(seg):
        u = 2.0 * math.pi * i / seg
        cu, su = math.cos(u), math.sin(u)
        for k in range(tube):
            v = 2.0 * math.pi * k / tube
            rr = R + r * math.cos(v)
            verts.append((cx + rr * cu, cy + r * math.sin(v), cz + rr * su))
    faces = []
    for i in range(seg):
        i2 = (i + 1) % seg
        for k in range(tube):
            k2 = (k + 1) % tube
            faces.append((i * tube + k, i2 * tube + k,
                          i2 * tube + k2, i * tube + k2))
    return verts, faces


def mirror_part(part):
    """沿 Y = 0 镜像（左舷 <-> 右舷），保持面法线朝外。"""
    out = Part()
    out.verts = [(x, -y, z) for (x, y, z) in part.verts]
    out.faces = [(tuple(reversed(f)), m) for (f, m) in part.faces]
    return out


def merge_parts(parts):
    out = Part()
    for p in parts:
        out.merge(p)
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
# 船体 / 甲板 / 舷墙 / 龙骨 / 舵
# ============================================================

def build_hull():
    """闭合船体：16 个横剖面站放样；水线以下深色船底，舷侧白色。"""
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
    # 艏 / 艉封板：以环心做三角扇，避免平底共线点造成退化三角形
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
        cz = sum(verts[i][2] for i in f) / len(f)
        part.faces.append((f, MAT_HULL if cz < WATERLINE_Z else MAT_WHITE))
    return part


def build_deck():
    """主甲板：沿站生成带拱度的木甲板（单层，法线朝上，材质双面）。"""
    xs = stations_in(-11.60, 12.10)
    ny = 6
    verts, faces = [], []
    for x in xs:
        wd = DECK_W_FRAC * half_beam_at(x)
        z0 = deck_surface_z(x)
        for k in range(ny + 1):
            t = -1.0 + 2.0 * k / ny
            verts.append((x, t * wd, z0 + DECK_CAMBER * (1.0 - t * t)))
    for i in range(len(xs) - 1):
        for k in range(ny):
            a = i * (ny + 1) + k
            b = (i + 1) * (ny + 1) + k
            faces.append((a, b, b + 1, a + 1))
    part = Part()
    part.add((verts, faces), MAT_DECK)
    part.recalc = False
    return part


def build_bulwark():
    """白色舷墙 + 暗红压条。"""
    xs = stations_in(-11.65, 12.14)
    loop = deck_loop_points(xs)
    normals = loop_normals(loop)
    part = Part()
    part.merge(band_loop(loop, normals, BULWARK_H, BULWARK_OUT, -BULWARK_IN,
                         MAT_WHITE))
    cap = band_loop(loop, normals, CAP_T, BULWARK_OUT + 0.025,
                    -BULWARK_IN - 0.015, MAT_RED, z0=None)
    # 压条抬到舷墙顶端
    for i, v in enumerate(cap.verts):
        v = list(v)
        v[2] += BULWARK_H - 0.012
        cap.verts[i] = tuple(v)
    part.merge(cap)
    return part


def build_hull_strakes():
    """舷侧外凸压条：暗红水线带 + 暗红舷缘带（沿船体侧表面放样）。"""
    xs = stations_in(-11.40, 11.90)
    part = Part()
    for side in (1, -1):
        for z0, z1, mat in ((0.14, 0.24, MAT_RED), (1.42, 1.52, MAT_RED)):
            verts = []
            for x in xs:
                zm = 0.5 * (z0 + z1)
                yo = hull_y_at(x, zm) + 0.022
                yi = yo - 0.045
                verts.extend([(x, side * yo, z0), (x, side * yo, z1),
                              (x, side * yi, z1), (x, side * yi, z0)])
            faces = []
            n = len(xs)
            for i in range(n - 1):
                a, b = i * 4, (i + 1) * 4
                faces.append((a, b, b + 1, a + 1))          # 外表面
                faces.append((a + 1, b + 1, b + 2, a + 2))  # 上表面
                faces.append((a + 2, b + 2, b + 3, a + 3))  # 内表面
                faces.append((a + 3, b + 3, b, a))          # 下表面
            faces.append((0, 1, 2, 3))
            a = (n - 1) * 4
            faces.append((a, a + 1, a + 2, a + 3))
            part.add((verts, faces), mat)
    return part


def build_keel():
    part = Part()
    part.add(box((-11.20, -0.15, -1.32), (11.20, 0.15, -1.18)), MAT_HULL)
    # 艏柱 / 艉柱
    part.add(box((11.98, -0.10, -0.30), (12.22, 0.10, 2.06)), MAT_WHITE)
    part.add(box((-11.82, -0.10, -0.60), (-11.64, 0.10, 1.86)), MAT_WHITE)
    return part


def build_rudder():
    part = Part()
    part.add(box((-12.28, -0.09, -1.28), (-12.02, 0.09, 1.30)), MAT_HULL)
    part.add(box((-12.34, -0.055, 0.20), (-12.26, 0.055, 1.30)), MAT_HULL)
    # 舵杆：从舵体顶连到舵柄
    part.add(box((-12.22, -0.065, 1.28), (-12.08, 0.065, 1.58)), MAT_METAL)
    part.add(box((-12.32, -0.46, 1.34), (-11.86, 0.46, 1.48)), MAT_RED)
    # 舵柄
    part.add(box((-12.30, -0.10, 1.44), (-11.20, 0.10, 1.58)), MAT_DECK)
    return part


def build_stern_platform():
    """艉部弧形低平台（D 形）+ 暗红压条 + 弧形栏杆。"""
    sp = STERN_PLATFORM
    steps = 7
    arcs = []
    for i in range(steps + 1):
        a = -0.5 * math.pi + math.pi * i / steps
        arcs.append((sp["x"] - sp["rx"] * math.cos(a),
                     sp["ry"] * math.sin(a)))
    part = Part()
    part.add(prism_xy(arcs, sp["z"] - 0.12, sp["z"] + 0.02), MAT_DECK)
    # 外缘暗红压条（沿弧线，内收 6%）
    inner = [(sp["x"] + (x - sp["x"]) * 0.94, y * 0.94) for x, y in arcs]
    n = len(arcs)
    verts = []
    for (xo, yo), (xi, yi) in zip(arcs, inner):
        verts.extend([(xo, yo, sp["z"] + 0.02), (xo, yo, sp["z"] + 0.08),
                      (xi, yi, sp["z"] + 0.08), (xi, yi, sp["z"] + 0.02)])
    faces = []
    for i in range(n - 1):
        a, b = i * 4, (i + 1) * 4
        faces.append((a, b, b + 1, a + 1))          # 外缘
        faces.append((a + 1, b + 1, b + 2, a + 2))  # 顶面
        faces.append((a + 2, b + 2, b + 3, a + 3))  # 内缘
        faces.append((a + 3, b + 3, b, a))          # 底面
    faces.append((0, 1, 2, 3))
    a = (n - 1) * 4
    faces.append((a, a + 1, a + 2, a + 3))
    part.add((verts, faces), MAT_RED)
    # 弧形栏杆：立柱 + 两道横杆
    rail_pts = []
    for i in range(steps + 1):
        a = -0.5 * math.pi + math.pi * i / steps
        rail_pts.append((sp["x"] - sp["rx"] * 0.95 * math.cos(a),
                         sp["ry"] * 0.95 * math.sin(a)))
    for x, y in rail_pts:
        part.add(box((x - 0.035, y - 0.035, sp["z"]),
                     (x + 0.035, y + 0.035, sp["z"] + 0.78)), MAT_METAL)
    for i in range(steps):
        p0, p1 = rail_pts[i], rail_pts[i + 1]
        d = vsub((p1[0], p1[1], 0.0), (p0[0], p0[1], 0.0))
        L = vlen(d) or 1.0
        u = vmul(d, 1.0 / L)
        v = (-u[1], u[0], 0.0)
        for hz in (0.40, 0.76):
            c = (0.5 * (p0[0] + p1[0]), 0.5 * (p0[1] + p1[1]), sp["z"] + hz)
            part.add(frame_box(c, u, v, (0.0, 0.0, 1.0), L * 0.5, 0.02, 0.02),
                     MAT_METAL)
    return part


def build_portholes():
    """两舷舷窗：黄铜窗圈 + 深色玻璃。"""
    part = Part()
    for x in PORTHOLE_XS:
        for side in (1, -1):
            y = hull_y_at(x, 1.12)
            p0 = (x, side * (y - 0.012), 1.12)
            p1 = (x, side * (y + 0.075), 1.12)
            part.add(taper_cyl(p0, p1, 0.15, 0.13, sides=6), MAT_BRASS)
            p2 = (x, side * (y + 0.074), 1.12)
            p3 = (x, side * (y + 0.088), 1.12)
            part.add(taper_cyl(p2, p3, 0.105, 0.105, sides=6), MAT_HULL)
    return part


# ============================================================
# 明轮 / 轮罩
# ============================================================

def build_paddle_wheel():
    """左舷明轮（+Y）。轴心即 Pivot 位置，几何先按船体坐标生成。"""
    cfg = PADDLE
    xc, zc, r = cfg["x"], cfg["z"], cfg["r"]
    y_lo, y_hi = cfg["y_in"], cfg["y_out"]
    y_mid = 0.5 * (y_lo + y_hi)
    hw = 0.5 * (y_hi - y_lo)
    part = Part()
    # 轮毂 + 两侧轮毂法兰
    part.add(taper_cyl((xc, y_lo, zc), (xc, y_hi, zc), 0.32, 0.32, 10), MAT_HULL)
    for yy in (y_lo + 0.05, y_hi - 0.05):
        part.add(taper_cyl((xc, yy - 0.045, zc), (xc, yy + 0.045, zc),
                           0.46, 0.46, 10), MAT_METAL)
    # 内外两道主轮缘 + 内加强环；外侧黄铜轮缘条
    for y0, y1 in ((y_lo, y_lo + 0.09), (y_hi - 0.09, y_hi)):
        part.add(ring_band(xc, zc, r - 0.13, r, y0, y1, cfg["seg"]), MAT_HULL)
        part.add(ring_band(xc, zc, 0.92, 1.01, y0, y1, cfg["seg"]), MAT_HULL)
    part.add(ring_band(xc, zc, r - 0.03, r + 0.015, y_hi - 0.05, y_hi + 0.02,
                       cfg["seg"]), MAT_BRASS)
    # 辐条（每个轮缘平面 8 根）
    rm = 0.5 * (0.46 + r - 0.13)
    hu = rm - 0.46
    for i in range(cfg["spokes"]):
        a = 2.0 * math.pi * i / cfg["spokes"]
        u = (math.cos(a), 0.0, math.sin(a))
        v = (-math.sin(a), 0.0, math.cos(a))
        for yy in (y_lo + 0.045, y_hi - 0.045):
            c = (xc + u[0] * rm, yy, zc + u[2] * rm)
            part.add(frame_box(c, u, v, (0.0, 1.0, 0.0), hu, 0.04, 0.042),
                     MAT_HULL)
    # 4 根斜撑：把内外轮缘连成整体
    for i in range(4):
        a = 2.0 * math.pi * i / 4 + 0.18
        ca, sa = math.cos(a), math.sin(a)
        part.add(taper_cyl((xc + ca * (r - 0.06), y_lo + 0.045, zc + sa * (r - 0.06)),
                           (xc + math.cos(a + 0.55) * (r - 0.06), y_hi - 0.045,
                            zc + math.sin(a + 0.55) * (r - 0.06)),
                           0.04, 0.04, 5), MAT_METAL)
    # 桨叶（10 片，跨满轮宽）
    for i in range(cfg["blades"]):
        a = 2.0 * math.pi * i / cfg["blades"]
        u = (-math.sin(a), 0.0, math.cos(a))
        w = (math.cos(a), 0.0, math.sin(a))
        c = (xc + w[0] * (r - 0.10), y_mid, zc + w[2] * (r - 0.10))
        part.add(frame_box(c, u, w, (0.0, 1.0, 0.0), 0.18, 0.030, hw - 0.035),
                 MAT_HULL)
    # 轴端 + 黄铜轴帽
    part.add(taper_cyl((xc, y_lo - 0.10, zc), (xc, y_hi + 0.10, zc),
                       0.20, 0.20, 8), MAT_METAL)
    part.add(taper_cyl((xc, y_hi + 0.10, zc), (xc, y_hi + 0.18, zc),
                       0.13, 0.08, 8), MAT_BRASS)
    # 4 个曲柄销（向内收，避免伸进轮罩）
    for i in range(4):
        a = 2.0 * math.pi * i / 4 + 0.78
        c = (xc + math.cos(a) * 0.72, y_hi - 0.07, zc + math.sin(a) * 0.72)
        part.add(taper_cyl((c[0], c[1] - 0.15, c[2]), c, 0.065, 0.05, 6),
                 MAT_BRASS)
    return part


def build_paddle_box():
    """左舷（+Y）梯形格栅轮罩：白箱板 + 深色内衬 + 水平格栅 + 暗红顶沿。"""
    b = PADDLE_BOX
    part = Part()
    outer = [
        (b["x0"] + 0.00, b["z0"] + 0.00),
        (b["x1"] - 0.00, b["z0"] + 0.00),
        (b["x1"] - 0.00, b["z0"] + 2.00),
        (b["x1"] - 0.22, b["z0"] + 2.70),
        (b["x1"] - 0.45, b["z1"] - 0.22),
        (b["x1"] - 0.65, b["z1"]),
        (b["x0"] + 0.45, b["z1"]),
        (b["x0"] + 0.25, b["z1"] - 0.22),
        (b["x0"] + 0.05, b["z0"] + 2.70),
        (b["x0"] + 0.00, b["z0"] + 2.00),
    ]
    part.add(prism_xz(outer, b["y0"], b["y1"]), MAT_WHITE)
    # 顶部压条：沿箱顶外沿再加 6 cm 红边
    top_band = [
        (b["x1"] - 0.42, b["z1"] - 0.06), (b["x1"] - 0.62, b["z1"] + 0.075),
        (b["x0"] + 0.42, b["z1"] + 0.075), (b["x0"] + 0.22, b["z1"] - 0.06),
    ]
    part.add(prism_xz(top_band, b["y0"] - 0.02, b["y1"] + 0.02), MAT_RED)
    # 深色格栅内衬（比外板外凸 1 cm，形成 recess 读感）
    lx0, lx1 = b["x0"] + 0.18, b["x1"] - 0.16
    lz0, lz1 = b["z0"] + 0.42, b["z1"] - 0.30
    liner = [(lx0, lz0), (lx1, lz0),
             (lx1 - 0.02, lz1 - 0.55), (lx1 - 0.20, lz1),
             (lx0 + 0.40, lz1), (lx0 + 0.20, lz1 - 0.55)]
    part.add(prism_xz(liner, b["y1"] - 0.005, b["y1"] + 0.012), MAT_HULL)
    # 水平白色格栅
    for i in range(LOUVERS):
        t = (i + 0.5) / LOUVERS
        z = lz0 + (lz1 - lz0) * t
        shrink = 0.22 * t
        x0 = lx0 + 0.06 + shrink
        x1 = lx1 - 0.06 - shrink * 0.6
        h = 0.045
        part.add(box((x0, b["y1"] + 0.008, z - h),
                     (x1, b["y1"] + 0.055, z + h)), MAT_WHITE)
    # 格栅外框（上下白边）
    part.add(box((lx0, b["y1"] + 0.004, lz0 - 0.10),
                 (lx1, b["y1"] + 0.05, lz0 - 0.02)), MAT_WHITE)
    part.add(box((lx0 + 0.08, b["y1"] + 0.004, lz1 + 0.02),
                 (lx1 - 0.26, b["y1"] + 0.05, lz1 + 0.10)), MAT_WHITE)
    # 黄铜铭牌 + 系留铰链
    part.add(box((b["x0"] + 0.62, b["y1"] + 0.012, 2.98),
                 (b["x0"] + 1.42, b["y1"] + 0.045, 3.18)), MAT_BRASS)
    for z in (1.10, 2.20):
        part.add(box((b["x0"] - 0.02, b["y1"] - 0.04, z - 0.06),
                     (b["x0"] + 0.12, b["y1"] + 0.06, z + 0.06)), MAT_METAL)
    # 与船体连接的撑架（两根）
    for x in (b["x0"] + 0.35, b["x1"] - 0.35):
        part.add(box((x - 0.12, 2.70, 1.22), (x + 0.12, b["y0"], 1.62)),
                 MAT_HULL)
    return part


# ============================================================
# 上层建筑：主甲板舱室 / 游步甲板 / 驾驶室 / 雨棚
# ============================================================

def build_cabin():
    """主甲板客舱：白墙 + 玻璃窗 + 黄铜窗台 + 木门 + 暗红腰线。"""
    c = CABIN
    x0, x1, hy = c["x0"], c["x1"], c["hy"]
    z0, z1 = c["z0"], c["z1"]
    part = Part()
    part.add(box((x0, -hy, z0), (x1, hy, z1)), MAT_WHITE)
    # 暗红腰线
    for sy in (1, -1):
        part.add(box((x0 - 0.01, sy * hy - 0.012, 2.40),
                     (x1 + 0.01, sy * hy + 0.012, 2.53)), MAT_RED)
    # 侧窗
    win_xs = (-7.25, -5.95, -4.65, -3.35, -2.05, -0.75)
    for sy in (1, -1):
        y = sy * (hy + 0.008)
        for x in win_xs:
            part.add(box((x - 0.36, y - 0.02, 2.44), (x + 0.36, y + 0.02, 3.16)),
                     MAT_HULL)
            part.add(box((x - 0.44, y - 0.005, 2.36), (x + 0.44, y + 0.05, 2.43)),
                     MAT_BRASS)
            part.add(box((x - 0.44, y - 0.005, 3.17), (x + 0.44, y + 0.05, 3.24)),
                     MAT_BRASS)
    # 门（两舷各一 + 后门）
    for sy in (1, -1):
        y = sy * (hy + 0.008)
        x = 2.10
        part.add(box((x - 0.40, y - 0.02, z0), (x + 0.40, y + 0.035, 3.06)),
                 MAT_DECK)
        part.add(box((x + 0.26, y + 0.02, 2.02), (x + 0.33, y + 0.06, 2.14)),
                 MAT_BRASS)
    part.add(box((x0 - 0.01, -0.52, z0), (x0 + 0.03, 0.52, 3.08)), MAT_DECK)
    # 舱顶通风筒底座
    for x in (-6.30, 1.10):
        part.add(box((x - 0.22, -0.22, z1), (x + 0.22, 0.22, z1 + 0.38)),
                 MAT_METAL)
    return part


def build_promenade():
    """游步甲板板 + 暗红封檐 + 白色支柱。"""
    xs = [-9.35, -8.60, -7.40, -6.00, -4.00, -2.00, 0.00, 2.00, 4.00,
          5.60, 6.60, 7.05]

    def wfunc(x):
        return min(PROM["w"], 0.94 * half_beam_at(x))

    poly = [(x, wfunc(x)) for x in xs] + [(x, -wfunc(x)) for x in reversed(xs)]
    part = Part()
    part.add(prism_xy(poly, UPPER_Z - UPPER_T, UPPER_Z), MAT_DECK)
    # 暗红封檐：沿外圈下缘的窄带
    loop = [(x, wfunc(x), UPPER_Z) for x in xs] + \
           [(x, -wfunc(x), UPPER_Z) for x in reversed(xs)]
    normals = loop_normals(loop)
    fascia = band_loop(loop, normals, 0.11, 0.035, -0.02, MAT_RED,
                       z0=UPPER_Z - UPPER_T - 0.01)
    part.merge(fascia)
    # 支撑柱：在外侧窗墙之间托住游步甲板
    for sy in (1, -1):
        for x in (-9.00, -7.55, -6.10, -4.65, -3.20, -1.75, -0.30, 1.15, 2.60):
            part.add(box((x - 0.055, sy * 2.30 - 0.055, deck_surface_z(x)),
                         (x + 0.055, sy * 2.30 + 0.055, UPPER_Z - UPPER_T)),
                     MAT_WHITE)
    return part


def build_upper_railings():
    """游步甲板三面栏杆（后 / 两舷 / 前）；两舷在明轮台处断开。"""
    part = Part()
    z = UPPER_Z
    h = 0.86
    for sy in (1, -1):
        part.merge(railing_run((-9.30, sy * 2.62), (-4.52, sy * 2.62), z, h))
        part.merge(railing_run((2.12, sy * 2.62), (7.02, sy * 2.62), z, h))
    part.merge(railing_run((7.02, -2.62), (7.02, 2.62), z, h))
    part.merge(railing_run((-9.30, 2.62), (-9.30, -2.62), z, h))
    return part


def build_sponson():
    """左舷明轮台：游步甲板向外伸出的走台 + 外缘栏杆（右舷镜像）。"""
    x0, x1 = -4.55, 2.15
    y0, y1 = 2.58, 4.34
    z = UPPER_Z
    part = Part()
    poly = [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]
    part.add(prism_xy(poly, z - 0.14, z), MAT_DECK)
    # 外缘暗红封檐
    part.add(box((x0 - 0.03, y1 - 0.02, z - 0.15),
                 (x1 + 0.03, y1 + 0.03, z - 0.02)), MAT_RED)
    for xe in (x0 - 0.02, x1 - 0.01):
        part.add(box((xe - 0.02, y0, z - 0.15), (xe + 0.03, y1, z - 0.02)),
                 MAT_RED)
    # 栏杆：外缘 + 两端
    part.merge(railing_run((x0 + 0.06, y1 - 0.06), (x1 - 0.06, y1 - 0.06),
                           z, 0.80, spacing=1.35))
    part.merge(railing_run((x0 + 0.06, y0 + 0.10), (x0 + 0.06, y1 - 0.06),
                           z, 0.80, spacing=1.35))
    part.merge(railing_run((x1 - 0.06, y0 + 0.10), (x1 - 0.06, y1 - 0.06),
                           z, 0.80, spacing=1.35))
    # 支撑斜撑（自船体舷侧到走台外缘）
    for x in (x0 + 0.55, x1 - 0.55):
        p0 = (x, 2.62, z - 1.55)
        p1 = (x, 4.15, z - 0.16)
        part.add(taper_cyl(p0, p1, 0.06, 0.05, 6), MAT_HULL)
    return part


def build_bulwark_railings():
    """舷墙顶栏杆：沿甲板边缘的立柱 + 两道扶手。"""
    xs = stations_in(-11.60, 12.10)
    loop = deck_loop_points(xs)
    normals = loop_normals(loop)
    cap_z = None
    part = Part()
    # 立柱：沿闭合环均匀取样（隔点），从舷墙顶立起
    total = len(loop)
    for i in range(0, total, 2):
        x, y, _z = loop[i]
        nx, ny = normals[i]
        base = deck_surface_z(x) + DECK_CAMBER + BULWARK_H
        px = x + nx * 0.0
        py = y + ny * 0.0
        part.add(box((px - 0.032, py - 0.032, base),
                     (px + 0.032, py + 0.032, base + 0.62)), MAT_METAL)
    # 扶手：沿闭合环的一圈细带（顶部扶手）
    for hz0, hz1, out in ((0.595, 0.64, 0.026),):
        verts = []
        for (x, y, _z), (nx, ny) in zip(loop, normals):
            base = deck_surface_z(x) + DECK_CAMBER + BULWARK_H
            verts.extend([
                (x + nx * out, y + ny * out, base + hz0),
                (x + nx * out, y + ny * out, base + hz1),
                (x + nx * (out - 0.05), y + ny * (out - 0.05), base + hz1),
                (x + nx * (out - 0.05), y + ny * (out - 0.05), base + hz0),
            ])
        faces = []
        n = len(loop)
        for k in range(n):
            k2 = (k + 1) % n
            a, b = k * 4, k2 * 4
            faces.append((a, b, b + 1, a + 1))
            faces.append((a + 1, b + 1, b + 3, a + 3))
            faces.append((a + 3, b + 3, b + 2, a + 2))
            faces.append((a + 2, b + 2, b, a))
        part.add((verts, faces), MAT_METAL)
    return part


def build_wheelhouse():
    """前部封闭驾驶室：白墙 + 三面玻璃 + 顶板 + 暗红檐 + 木门。"""
    w = WHEELHOUSE
    x0, x1, hy = w["x0"], w["x1"], w["hy"]
    z0, z1 = w["z0"], w["z1"]
    part = Part()
    part.add(box((x0, -hy, z0), (x1, hy, z1)), MAT_WHITE)
    # 正面三扇窗
    for sy in (-1.0, 0.0, 1.0):
        cy = sy * 0.68
        part.add(box((x1 - 0.01, cy - 0.50, 4.10), (x1 + 0.02, cy + 0.50, 5.02)),
                 MAT_HULL)
        part.add(box((x1 - 0.02, cy - 0.55, 4.02), (x1 + 0.06, cy + 0.55, 4.10)),
                 MAT_BRASS)
        part.add(box((x1 - 0.02, cy - 0.55, 5.02), (x1 + 0.06, cy + 0.55, 5.10)),
                 MAT_BRASS)
    # 白色窗间柱
    for cy in (-1.42, -0.12, 1.42):
        part.add(box((x1 - 0.01, cy - 0.07, 4.05), (x1 + 0.04, cy + 0.07, 5.08)),
                 MAT_WHITE)
    # 侧窗两扇
    for sy in (1, -1):
        y = sy * (hy + 0.01)
        for cx in (4.30, 5.65):
            part.add(box((cx - 0.52, y - 0.02, 4.10), (cx + 0.52, y + 0.02, 5.02)),
                     MAT_HULL)
            part.add(box((cx - 0.58, y - 0.005, 4.02), (cx + 0.58, y + 0.055, 4.10)),
                     MAT_BRASS)
            part.add(box((cx - 0.58, y - 0.005, 5.02), (cx + 0.58, y + 0.055, 5.10)),
                     MAT_BRASS)
    # 后门
    part.add(box((x0 - 0.03, -0.44, z0), (x0 + 0.02, 0.44, 4.92)), MAT_DECK)
    # 顶板 + 暗红封檐（只做四边窄条，顶面保持白色）
    part.add(box((x0 - 0.28, -hy - 0.22, z1), (x1 + 0.30, hy + 0.22, z1 + 0.16)),
             MAT_WHITE)
    ex0, ex1 = x0 - 0.30, x1 + 0.32
    ey = hy + 0.24
    part.add(box((ex0, -ey, z1 + 0.10), (ex1, -ey + 0.10, z1 + 0.17)), MAT_RED)
    part.add(box((ex0, ey - 0.10, z1 + 0.10), (ex1, ey, z1 + 0.17)), MAT_RED)
    part.add(box((ex0, -ey, z1 + 0.10), (ex0 + 0.10, ey, z1 + 0.17)), MAT_RED)
    part.add(box((ex1 - 0.10, -ey, z1 + 0.10), (ex1, ey, z1 + 0.17)), MAT_RED)
    return part


def build_canopy():
    """后部游步甲板雨棚：白色顶板 + 暗红封檐 + 白色立柱。"""
    c = CANOPY
    part = Part()
    part.add(box((c["x0"], -c["hy"], c["z"]), (c["x1"], c["hy"], c["z"] + c["t"])),
             MAT_WHITE)
    # 封檐：四边窄条（顶面保持白色）
    ex0, ex1 = c["x0"] - 0.04, c["x1"] + 0.04
    ey = c["hy"] + 0.04
    zb, zt = c["z"] + 0.10, c["z"] + c["t"] + 0.02
    part.add(box((ex0, -ey, zb), (ex1, -ey + 0.10, zt)), MAT_RED)
    part.add(box((ex0, ey - 0.10, zb), (ex1, ey, zt)), MAT_RED)
    part.add(box((ex0, -ey, zb), (ex0 + 0.10, ey, zt)), MAT_RED)
    part.add(box((ex1 - 0.10, -ey, zb), (ex1, ey, zt)), MAT_RED)
    # 立柱
    for sy in (1, -1):
        for x in (-9.10, -6.80, -4.50, -2.20, 0.10, 1.18):
            part.add(box((x - 0.05, sy * (c["hy"] - 0.10) - 0.05,
                          UPPER_Z),
                         (x + 0.05, sy * (c["hy"] - 0.10) + 0.05, c["z"])),
                     MAT_WHITE)
    # 顶板下的横梁（两根）
    for x in (-6.80, -2.20):
        part.add(box((x - 0.06, -c["hy"], c["z"] - 0.10),
                     (x + 0.06, c["hy"], c["z"])), MAT_WHITE)
    return part


def build_stairs():
    """艉部中央楼梯：5 级踏步 + 两侧扶手。"""
    part = Part()
    x_top, x_bot = -9.50, -10.70
    z_top, z_bot = UPPER_Z, deck_surface_z(-10.7)
    n = 5
    for i in range(n):
        t = (i + 0.5) / n
        x = x_bot + (x_top - x_bot) * t
        z = z_bot + (z_top - z_bot) * t
        part.add(box((x - 0.13, -0.52, z - 0.055), (x + 0.13, 0.52, z + 0.02)),
                 MAT_DECK)
    # 扶手
    for sy in (1, -1):
        p0 = (x_bot, sy * 0.56, z_bot + 0.02)
        p1 = (x_top, sy * 0.56, z_top + 0.02)
        d = vsub(p1, p0)
        L = vlen(d)
        u = vmul(d, 1.0 / L)
        v = (-u[1], u[0], 0.0)
        w = vnorm(vcross(u, v))
        c = vmul(vadd(p0, p1), 0.5)
        part.add(frame_box(c, u, v, w, L * 0.5, 0.022, 0.022), MAT_METAL)
        for i in range(3):
            t = i / 2.0
            c2 = vadd(p0, vmul(d, t))
            part.add(box((c2[0] - 0.028, c2[1] - 0.028, c2[2]),
                         (c2[0] + 0.028, c2[1] + 0.028, c2[2] + 0.70)), MAT_METAL)
    return part


# ============================================================
# 烟囱 / 蒸汽 / 旗帜
# ============================================================

def build_funnel():
    """烟囱围罩 + 黑色烟囱 + 黄铜箍 + 暗红顶圈 + 汽笛 + 蒸汽管。"""
    f = FUNNEL
    part = Part()
    c = CASING
    part.add(box((c["x0"], -c["hy"], c["z0"]), (c["x1"], c["hy"], c["z1"])),
             MAT_WHITE)
    part.add(box((c["x0"] - 0.03, -c["hy"] - 0.03, c["z1"] - 0.18),
                 (c["x1"] + 0.03, c["hy"] + 0.03, c["z1"])), MAT_RED)
    # 烟囱筒
    part.add(taper_cyl((f["x"], 0.0, f["z0"]), (f["x"], 0.0, f["z1"]),
                       f["r0"], f["r1"], 12), MAT_HULL)
    # 顶圈
    part.add(taper_cyl((f["x"], 0.0, f["z1"] - 0.16), (f["x"], 0.0, f["z1"] + 0.04),
                       f["r1"] + 0.05, f["r1"] + 0.05, 12), MAT_RED)
    part.add(taper_cyl((f["x"], 0.0, f["z1"] + 0.04), (f["x"], 0.0, f["z1"] + 0.10),
                       f["r1"] + 0.05, f["r1"] - 0.02, 12), MAT_HULL)
    # 黄铜箍
    for frac in (0.28, 0.62):
        z = f["z0"] + (f["z1"] - f["z0"]) * frac
        r = f["r0"] + (f["r1"] - f["r0"]) * frac
        part.add(taper_cyl((f["x"], 0.0, z - 0.055), (f["x"], 0.0, z + 0.055),
                           r + 0.045, r + 0.045, 12), MAT_BRASS)
    # 汽笛 + 蒸汽管
    part.add(taper_cyl((f["x"] + 0.42, 0.58, 4.10), (f["x"] + 0.42, 0.58, 4.95),
                       0.055, 0.045, 6), MAT_BRASS)
    part.add(taper_cyl((f["x"] - 0.30, -0.58, c["z1"] - 0.10),
                       (f["x"] - 0.30, -0.58, c["z1"] + 0.75), 0.075, 0.065, 6),
             MAT_BRASS)
    return part


def build_flagstaff():
    f = FLAGSTAFF
    part = Part()
    part.add(taper_cyl((f["x"], 0.0, f["z0"] - 0.10), (f["x"], 0.0, f["z1"]),
                       0.095, 0.045, 8), MAT_WHITE)
    part.add(taper_cyl((f["x"], 0.0, f["z1"] - 0.02), (f["x"], 0.0, f["z1"] + 0.12),
                       0.09, 0.03, 8), MAT_BRASS)
    # 底部基座
    part.add(taper_cyl((f["x"], 0.0, f["z0"] - 0.16), (f["x"], 0.0, f["z0"]),
                       0.18, 0.13, 8), MAT_METAL)
    return part


def _flag_xy(u, v):
    """旗帜在 u（沿旗面 von 旗杆到旗尾）与 v（下到上）处的世界坐标。"""
    f = FLAG
    x = f["x0"] - f["w"] * u
    z = f["z_bot"] + f["h"] * v
    y = 0.085 * math.sin(u * math.pi * 1.55) * (1.0 - 0.25 * v) \
        + 0.020 * v
    return x, y, z


def build_flag():
    """澳洲旗：蓝色双面薄旗 + 白色十字 + 红色内十字 + 四颗白星。

    旗面为闭合薄棱柱（每格前后两层 + 四周封边），装饰为薄盒，全部闭合。
    """
    f = FLAG
    nu, nv = 6, 3
    th = 0.008
    part = Part()
    front = []
    back = []
    for i in range(nu + 1):
        for j in range(nv + 1):
            x, y, z = _flag_xy(i / nu, j / nv)
            front.append((x, y - th, z))
            back.append((x, y + th, z))
    n = (nu + 1) * (nv + 1)
    verts = front + back
    faces = []
    for i in range(nu):
        for j in range(nv):
            a = i * (nv + 1) + j
            b = (i + 1) * (nv + 1) + j
            faces.append((a, b, b + 1, a + 1))
            faces.append((n + a + 1, n + b + 1, n + b, n + a))
    # 四周封边
    ringv = []
    for i in range(nu + 1):
        ringv.append(i * (nv + 1))
    for j in range(1, nv + 1):
        ringv.append(nu * (nv + 1) + j)
    for i in range(nu - 1, -1, -1):
        ringv.append(i * (nv + 1) + nv)
    for j in range(nv - 1, 0, -1):
        ringv.append(j)
    for k in range(len(ringv)):
        a = ringv[k]
        b = ringv[(k + 1) % len(ringv)]
        faces.append((a, b, n + b, n + a))
    part.add((verts, faces), MAT_FLAG)

    # --- 装饰（闭合薄盒）---
    def deco_box(u0, u1, v0, v1, mat, out=0.004):
        corners = [_flag_xy(u0, v0), _flag_xy(u1, v0),
                   _flag_xy(u1, v1), _flag_xy(u0, v1)]
        ys = [p[1] for p in corners]
        y0, y1 = min(ys) - th - out, max(ys) + th + out
        poly = [(p[0], p[2]) for p in corners]
        part.add(prism_xz(poly, y0, y1), mat)

    # Union Jack 简化：白十字 + 红内十字（旗首上半）
    deco_box(0.16, 0.28, 0.55, 0.98, MAT_FLAG_WHITE)
    deco_box(0.02, 0.44, 0.70, 0.82, MAT_FLAG_WHITE)
    deco_box(0.19, 0.25, 0.55, 0.98, MAT_RED)
    deco_box(0.02, 0.44, 0.74, 0.78, MAT_RED)
    # 星星（菱形薄盒）：联邦星 + 南十字四星
    stars = [(0.53, 0.22, 0.072), (0.70, 0.40, 0.060),
             (0.80, 0.72, 0.060), (0.60, 0.66, 0.048), (0.36, 0.20, 0.048)]
    for u, v, s in stars:
        x, y, z = _flag_xy(u, v)
        c = (x, y, z)
        uu = (0.7071, 0.0, 0.7071)
        vv = (-0.7071, 0.0, 0.7071)
        part.add(frame_box(c, uu, vv, (0.0, 1.0, 0.0), s * 0.75, s,
                           th + 0.006), MAT_FLAG_WHITE)
    return part


# ============================================================
# 甲板属具
# ============================================================

def build_bow_fittings():
    """艏部：锚 + 锚链筒 + 起锚绞盘 + 系缆桩 + 木楔。"""
    part = Part()
    # 锚链筒
    for side in (1, -1):
        p0 = (10.10, side * (hull_y_at(10.1, 1.30) + 0.02), 1.30)
        p1 = (10.10, side * (hull_y_at(10.1, 1.30) + 0.26), 1.30)
        part.add(taper_cyl(p0, p1, 0.16, 0.18, 6), MAT_HULL)
        # 锚：杆 + 横杆 + 两臂 + 爪 + 环
        ax, ay, az = 9.92, side * 2.52, 1.22
        part.add(box((ax - 0.06, ay - 0.05, az - 0.62), (ax + 0.06, ay + 0.05, az + 0.62)),
                 MAT_HULL)
        part.add(box((ax - 0.05, ay - 0.34, az + 0.46), (ax + 0.05, ay + 0.34, az + 0.56)),
                 MAT_HULL)
        for ad in (1, -1):
            u = vnorm((ad * 0.92, 0.0, -0.39))
            v = (0.0, 1.0, 0.0)
            w = vnorm(vcross(u, v))
            c = (ax + ad * 0.22, ay, az - 0.72)
            part.add(frame_box(c, u, v, w, 0.28, 0.05, 0.05), MAT_HULL)
            part.add(box((ax + ad * 0.46 - 0.09, ay - 0.045, az - 0.92),
                         (ax + ad * 0.46 + 0.09, ay + 0.045, az - 0.74)), MAT_METAL)
        part.add(taper_cyl((ax, ay, az + 0.62), (ax, ay, az + 0.74), 0.07, 0.07, 6),
                 MAT_METAL)
    # 起锚绞盘（横向绞筒 + 两侧支架 + 手柄）
    part.add(taper_cyl((7.85, -0.85, 2.02), (7.85, 0.85, 2.02), 0.22, 0.22, 8),
             MAT_DECK)
    for sy in (1, -1):
        part.add(box((7.62, sy * 0.95 - 0.10, 1.74), (7.74, sy * 0.95 + 0.10, 2.26)),
                 MAT_HULL)
        part.add(box((8.10, sy * 0.95 - 0.10, 1.74), (8.22, sy * 0.95 + 0.10, 2.26)),
                 MAT_HULL)
    part.add(taper_cyl((8.20, 0.72, 2.02), (8.20, 1.10, 2.02), 0.05, 0.05, 6),
             MAT_METAL)
    # 系缆桩（艏部两舷）
    for x, sy in ((6.40, 1), (6.40, -1), (9.20, 1), (9.20, -1)):
        y = sy * min(2.30, 0.9 * half_beam_at(x))
        part.add(taper_cyl((x, y, 1.72), (x, y, 2.02), 0.09, 0.075, 8), MAT_HULL)
        part.add(taper_cyl((x, y, 2.02), (x, y, 2.10), 0.14, 0.14, 8), MAT_BRASS)
    return part


def build_stern_fittings():
    """艉部：系缆桩 + 绞盘 + 煤箱 + 排水口。"""
    part = Part()
    for x, sy in ((-9.40, 1), (-9.40, -1)):
        y = sy * min(2.30, 0.9 * half_beam_at(x))
        part.add(taper_cyl((x, y, 1.72), (x, y, 2.02), 0.09, 0.075, 8), MAT_HULL)
        part.add(taper_cyl((x, y, 2.02), (x, y, 2.10), 0.14, 0.14, 8), MAT_BRASS)
    # 小绞盘（柱状卷筒 + 顶盖 + 十字手柄）
    cy = -1.55
    part.add(taper_cyl((-10.30, cy, 1.74), (-10.30, cy, 2.16), 0.20, 0.20, 10),
             MAT_HULL)
    part.add(taper_cyl((-10.30, cy, 2.16), (-10.30, cy, 2.24), 0.30, 0.28, 10),
             MAT_BRASS)
    for i in range(4):
        a = 2.0 * math.pi * i / 4
        part.add(box((-10.30 + math.cos(a) * 0.18 - 0.03, cy + math.sin(a) * 0.18 - 0.03,
                      2.22),
                     (-10.30 + math.cos(a) * 0.55 + 0.03, cy + math.sin(a) * 0.55 + 0.03,
                      2.28)), MAT_METAL)
    return part


def build_lifebuoy():
    """救生圈：白/红相间圆环，挂在舷墙外。"""
    lb = LIFEBUOY
    verts, faces = torus_y(lb["x"], lb["y"], lb["z"], lb["R"], lb["r"],
                           seg=12, tube=6)
    part = Part()
    part.verts = verts
    for idx, f in enumerate(faces):
        seg = (idx // 6) % 12
        part.faces.append((f, MAT_RED if seg in (0, 3, 6, 9) else MAT_WHITE))
    # 挂绳
    part.add(taper_cyl((lb["x"] - 0.22, lb["y"], lb["z"] + 0.28),
                       (lb["x"] - 0.22, lb["y"], lb["z"] + 0.52), 0.02, 0.02, 4),
             MAT_DECK)
    return part


def build_bell():
    """驾驶室顶上的黄铜钟 + 支架。"""
    b = BELL
    part = Part()
    part.add(box((b["x"] - 0.30, -0.035, b["z"]), (b["x"] + 0.30, 0.035, b["z"] + 0.10)),
             MAT_METAL)
    profile = [(0.0, 0.19), (0.03, 0.185), (0.07, 0.16), (0.14, 0.13),
               (0.25, 0.10), (0.33, 0.16)]
    verts, faces = revolved(profile, sides=10)
    part.add(translate((verts, faces), b["x"], 0.0, b["z"] + 0.10), MAT_BRASS)
    return part


def build_deck_details():
    """甲板细节：天窗 + 通风筒 + 卷缆 + 长凳。"""
    part = Part()
    # 雨棚顶上的两座小舷窗（黄铜框）
    for x in (-7.60, -3.10):
        part.add(box((x - 0.42, -0.34, CANOPY["z"] + CANOPY["t"]),
                     (x + 0.42, 0.34, CANOPY["z"] + CANOPY["t"] + 0.14)), MAT_METAL)
        part.add(box((x - 0.34, -0.26, CANOPY["z"] + CANOPY["t"] + 0.14),
                     (x + 0.34, 0.26, CANOPY["z"] + CANOPY["t"] + 0.18)), MAT_BRASS)
    # 通风筒（两座，倾斜喇叭口）
    for x, y in ((-8.60, 1.90), (-5.40, -1.90)):
        p0 = (x, y, UPPER_Z)
        p1 = (x, y, UPPER_Z + 1.05)
        part.add(taper_cyl(p0, p1, 0.11, 0.09, 8), MAT_METAL)
        part.add(taper_cyl((x, y, UPPER_Z + 1.05),
                           (x + 0.18, y, UPPER_Z + 1.38), 0.10, 0.30, 8),
                 MAT_METAL)
    # 卷缆（艉甲板）
    for i in range(2):
        part.add(torus_y(-11.00, 0.55 + i * 0.16, 1.80, 0.28, 0.06,
                         seg=8, tube=4), MAT_DECK)
    # 长凳（游步甲板靠两舷）
    for sy in (1, -1):
        for x0 in (-8.40, -5.40):
            part.add(box((x0, sy * 2.18 - 0.16, UPPER_Z + 0.02),
                         (x0 + 1.10, sy * 2.18 + 0.16, UPPER_Z + 0.08)), MAT_DECK)
            part.add(box((x0, sy * 2.18 - 0.14, UPPER_Z + 0.08),
                         (x0 + 1.10, sy * 2.18 + 0.14, UPPER_Z + 0.48)), MAT_DECK)
    return part


def build_steam_pipes():
    """从锅炉围罩沿游步甲板通到两舷轮罩的黄铜蒸汽管。"""
    part = Part()
    for side in (1, -1):
        pts = [(2.30, side * 0.95, 4.05),
               (1.70, side * 2.05, 3.84),
               (0.20, side * 2.72, 3.60),
               (-1.20, side * 4.12, 3.36)]
        for i in range(len(pts) - 1):
            part.add(taper_cyl(pts[i], pts[i + 1], 0.065, 0.065, 6), MAT_BRASS)
        part.add(taper_cyl((pts[0][0], pts[0][1], pts[0][2]),
                           (pts[0][0], pts[0][1], pts[0][2] + 0.16), 0.11, 0.11, 6),
                 MAT_METAL)
    return part


# ============================================================
# 装配
# ============================================================

PIVOT_PORT = (PADDLE["x"], 0.5 * (PADDLE["y_in"] + PADDLE["y_out"]), PADDLE["z"])
PIVOT_STARBOARD = (PIVOT_PORT[0], -PIVOT_PORT[1], PIVOT_PORT[2])

NAME_PLATES = {
    "SN_PS_Nameplate_Port": dict(
        text="ENTERPRISE", size=0.26, base=(4.95, 1.962, 3.79),
        matrix=((-1, 0, 0), (0, 0, 1), (0, 1, 0))),
    "SN_PS_Nameplate_Starboard": dict(
        text="ENTERPRISE", size=0.26, base=(4.95, -1.962, 3.79),
        matrix=((1, 0, 0), (0, 0, -1), (0, 1, 0))),
}


def build_all_geometry():
    """返回 {对象名: (Part, 父级键)}；父级键 = ROOT / PADDLE_PORT / PADDLE_STARBOARD。"""
    parts = {}

    def add(name, part, parent="ROOT"):
        parts[name] = (part, parent)

    add("SN_PS_Hull", build_hull())
    add("SN_PS_Deck", build_deck())
    add("SN_PS_Bulwark", build_bulwark())
    add("SN_PS_Hull_Strakes", build_hull_strakes())
    add("SN_PS_Keel", build_keel())
    add("SN_PS_Rudder", build_rudder())
    add("SN_PS_Stern_Platform", build_stern_platform())
    add("SN_PS_Bulwark_Railings", build_bulwark_railings())
    add("SN_PS_Portholes", build_portholes())

    add("SN_PS_Cabin", build_cabin())
    add("SN_PS_Promenade", build_promenade())
    add("SN_PS_Upper_Railings", build_upper_railings())
    add("SN_PS_Wheelhouse", build_wheelhouse())
    add("SN_PS_Canopy", build_canopy())
    add("SN_PS_Stairs", build_stairs())

    wheel = build_paddle_wheel()
    add("SN_PS_Paddle_Port", wheel, "PADDLE_PORT")
    add("SN_PS_Paddle_Starboard", mirror_part(wheel), "PADDLE_STARBOARD")
    pbox = build_paddle_box()
    add("SN_PS_Paddle_Box_Port", pbox)
    add("SN_PS_Paddle_Box_Starboard", mirror_part(pbox))
    sponson = build_sponson()
    add("SN_PS_Sponson_Port", sponson)
    add("SN_PS_Sponson_Starboard", mirror_part(sponson))

    add("SN_PS_Funnel", build_funnel())
    add("SN_PS_Steam_Pipes", build_steam_pipes())
    add("SN_PS_Flagstaff", build_flagstaff())
    add("SN_PS_Flag", build_flag())

    add("SN_PS_Bow_Fittings", build_bow_fittings())
    add("SN_PS_Stern_Fittings", build_stern_fittings())
    add("SN_PS_Lifebuoy", build_lifebuoy())
    add("SN_PS_Bell", build_bell())
    add("SN_PS_Deck_Details", build_deck_details())
    return parts


# ============================================================
# Blender 侧：集合 / 材质 / 空物体层级（不进干跑）
# ============================================================

def _clean_previous():
    import bpy
    for ob in list(bpy.data.objects):
        if ob.name.startswith(PREFIX):
            bpy.data.objects.remove(ob, do_unlink=True)
    old = bpy.data.collections.get(COLLECTION)
    if old is not None:
        bpy.data.collections.remove(old)
    for me in list(bpy.data.meshes):
        if me.name.startswith(PREFIX) and me.users == 0:
            bpy.data.meshes.remove(me)
    for cu in list(bpy.data.curves):
        if cu.name.startswith(PREFIX):
            bpy.data.curves.remove(cu)


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
    mat.use_backface_culling = False
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
        ob.parent = parent
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


def _add_text(name, spec, collection, parent, material):
    """文字铭牌：FONT 曲线转 mesh，旋转/平移到船体坐标。"""
    import bpy
    from mathutils import Matrix, Vector
    cu = bpy.data.curves.new(name + "_Curve", 'FONT')
    cu.body = spec["text"]
    cu.size = spec["size"]
    cu.extrude = 0.004
    cu.resolution_u = 1
    cu.align_x = 'CENTER'
    cu.align_y = 'CENTER'
    ob = bpy.data.objects.new(name + "_Tmp", cu)
    collection.objects.link(ob)
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    bpy.data.objects.remove(ob, do_unlink=True)
    bpy.data.curves.remove(cu)
    me.name = name
    # 文字曲线转网格后清理：焊接重复点、溶解退化边、删除零面积面
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.dissolve_degenerate(bm, dist=1e-5, edges=bm.edges)
    zero = [f for f in bm.faces if f.calc_area() < 1e-10]
    if zero:
        bmesh.ops.delete(bm, geom=zero, context="FACES")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    me.update()
    rot = Matrix(spec["matrix"])
    base = Vector(spec["base"])
    for v in me.vertices:
        v.co = rot @ v.co + base
    me.materials.append(material)
    for poly in me.polygons:
        poly.material_index = 0
        poly.use_smooth = False
    ob = bpy.data.objects.new(name, me)
    collection.objects.link(ob)
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
    root["asset"] = "SN_Paddle_Steamer"
    root["version"] = "1.0"
    root["units"] = "metres"
    root["pivot"] = "waterline, centre of hull"
    root["forward_axis"] = "+X"
    root["style"] = "low-poly flat-shaded Australian river paddle steamer"
    root["tri_budget"] = 12000

    pivots = {
        "PADDLE_PORT": _add_empty(PREFIX + "Paddle_Port_Pivot", PIVOT_PORT, root, 1.2),
        "PADDLE_STARBOARD": _add_empty(PREFIX + "Paddle_Starboard_Pivot",
                                       PIVOT_STARBOARD, root, 1.2),
    }

    parts = build_all_geometry()
    origins = {"ROOT": (0.0, 0.0, 0.0),
               "PADDLE_PORT": PIVOT_PORT,
               "PADDLE_STARBOARD": PIVOT_STARBOARD}
    for name, (part, parent_key) in parts.items():
        parent = root if parent_key == "ROOT" else pivots[parent_key]
        _make_object(name, part, col, parent, origins[parent_key])

    text_mat = _ensure_material(MAT_METAL)
    for name, spec in NAME_PLATES.items():
        _add_text(name, spec, col, root, text_mat)
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
        print("SN_Paddle_Steamer: %d 对象 / %d 网格 / %d 空物体" % (
            info["objects"], info["meshes"], info["empties"]))
        print("三角面: %d / 预算 12000" % tris)
        print("包围盒: %.2f x %.2f x %.2f m  (min %s / max %s)" % (
            info["bbox"][0], info["bbox"][1], info["bbox"][2],
            info["bbox_min"], info["bbox_max"]))
        print("材质: %s" % ", ".join(mats))
        print("根节点位置: %s" % info["root_location"])
        print("对象清单:")
        for ob in sorted(col.objects, key=lambda o: o.name):
            if ob.type == "MESH":
                t = sum(max(1, len(p.vertices) - 2) for p in ob.data.polygons)
                print("  %-34s mesh  %5d tri  parent=%s" % (
                    ob.name, t, ob.parent.name if ob.parent else "-"))
            else:
                print("  %-34s empty" % ob.name)
    return info


if __name__ == "__main__":
    build_all()
    report()
