# -*- coding: utf-8 -*-
"""Steam Navigator — 可复用船体部件几何核心（纯 Python，不依赖 bpy）。

把原先散落在各船生成器里的 `Part`、向量/基本体、放样与镜像工具集中到这里，
供 `ship_parts.deck` / `bow` / `stern` / `assembly` 以及各船生成器复用。

约定：
- 1 unit = 1 m；+X 船首、+Y 左舷、+Z 向上（与 Blender 生成器一致）。
- 仅几何与数据容器；不 import bpy / bmesh，可被 `dryrun_*` 直接加载。
- `PartSpec` 是“可复用部件”的装配契约：部件几何 + 父级键 + 局部原点 + 附件 socket。
"""

import math
from dataclasses import dataclass, field


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


def lerp3(a, b, t):
    return (a[0] + (b[0] - a[0]) * t,
            a[1] + (b[1] - a[1]) * t,
            a[2] + (b[2] - a[2]) * t)


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


def polyline_tube(points, radii, sides=4):
    """沿折线生成连续圆管（帆缘绳 / 索具）；每段独立闭合，接缝处自然重叠。"""
    parts = []
    for i in range(len(points) - 1):
        parts.append(taper_cyl(points[i], points[i + 1],
                               radii[i], radii[i + 1], sides))
    return merge(parts)


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


def bar_between(p0, p1, thickness):
    """两点之间的方截面长条（绳梯横档 / 小撑杆）。"""
    d = vsub(p1, p0)
    L = vlen(d)
    if L < 1e-6:
        return [], []
    u = vmul(d, 1.0 / L)
    ref = (0.0, 0.0, 1.0)
    if abs(u[2]) > 0.99:
        ref = (1.0, 0.0, 0.0)
    v = vnorm(vcross(ref, u))
    w = vnorm(vcross(u, v))
    c = vmul(vadd(p0, p1), 0.5)
    return frame_box(c, u, v, w, L * 0.5, thickness * 0.5, thickness * 0.5)


def ring_band(cx, cz, r_in, r_out, y0, y1, seg=12):
    """环形板（径向厚度 r_out-r_in，y 方向厚度），用于轮圈 / 盘绳。"""
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
        faces.append((a, a + 3, b + 3, b))
        faces.append((a + 1, b + 1, b + 2, a + 2))
        faces.append((a, b, b + 1, a + 1))
        faces.append((a + 3, a + 2, b + 2, b + 3))
    return verts, faces


def prism_xz(poly, y0, y1):
    """XZ 平面多边形沿 Y 挤出成闭合棱柱（艏柱 / 艉柱 / 舵）。"""
    n = len(poly)
    verts = [(x, y0, z) for x, z in poly] + [(x, y1, z) for x, z in poly]
    faces = [tuple(range(n))[::-1], tuple(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, n + j, n + i))
    return verts, faces


def prism_xy(poly, z0, z1):
    """XY 平面多边形沿 Z 挤出成闭合棱柱（甲板 / 平台板）。"""
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


def torus_x(cx, cy, cz, R, r, seg=12, tube=4):
    """绕 X 轴的圆环（舵轮轮圈 / 盘绳）。中心 (cx,cy,cz)，环半径 R、管半径 r。"""
    verts = []
    for i in range(seg):
        u = 2.0 * math.pi * i / seg
        cu, su = math.cos(u), math.sin(u)
        for k in range(tube):
            v = 2.0 * math.pi * k / tube
            rr = R + r * math.cos(v)
            verts.append((cx + r * math.sin(v), cy + rr * cu, cz + rr * su))
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

def torus_z(cx, cy, cz, R, r, seg=12, tube=4):
    """绕 Z 轴的圆环（甲板盘绳）。"""
    verts = []
    for i in range(seg):
        u = 2.0 * math.pi * i / seg
        cu, su = math.cos(u), math.sin(u)
        for k in range(tube):
            v = 2.0 * math.pi * k / tube
            rr = R + r * math.cos(v)
            verts.append((cx + rr * cu, cy + rr * su, cz + r * math.sin(v)))
    faces = []
    for i in range(seg):
        i2 = (i + 1) % seg
        for k in range(tube):
            k2 = (k + 1) % tube
            faces.append((i * tube + k, i2 * tube + k,
                          i2 * tube + k2, i * tube + k2))
    return verts, faces




@dataclass
class PartSpec:
    """可复用部件的装配契约。

    name:    局部对象名（不含船名前缀），如 "Deck_Capstan"。
    part:    纯几何 Part。
    parent:  父级键：ROOT / FORE / MAIN / 其它装配 pivot 名。
    origin:  部件局部坐标原点（对应父级 pivot 的世界位置）。
    sockets: 附件点 {socket_name: (x, y, z)}（部件局部坐标）。
    tags:    检索/兼容性标签，如 ("deck", "capstan", "kit:deck")。
    """
    name: str
    part: Part
    parent: str = "ROOT"
    origin: tuple = (0.0, 0.0, 0.0)
    sockets: dict = field(default_factory=dict)
    tags: tuple = ()


def tri_count(part):
    return sum(max(0, len(f) - 2) for f, _m in part.faces)
