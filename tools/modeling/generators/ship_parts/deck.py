# -*- coding: utf-8 -*-
"""可直接复用的甲板属具构建器（纯 Python）。

每个函数把几何追加到传入的 `Part`，位置/高度全部由调用方给出，便于不同船型复用；
不自带 `deck_surface_z()` 之类的船体查询，避免和某一艘船的站表耦合。
"""

import math

from .core import (
    Part, box, frame_box, prism_xz, revolved, taper_cyl, torus_x, torus_z,
    translate,
)
from .palette import MAT_BRASS, MAT_FLAG_BLUE, MAT_METAL, MAT_WOOD, MAT_WOOD_DARK

MAT_HULL_LINER = "SN_Hull_Black"


def hatch(part, x, sx, sy, z, hull_mat=MAT_HULL_LINER,
          wood_mat=MAT_WOOD, dark_mat=MAT_WOOD_DARK):
    """舱口：暗色内衬 + 围板 + 格栅。z 为甲板面高度。"""
    part.add(box((x - sx * 0.5, -sy * 0.5, z - 0.30),
                 (x + sx * 0.5, sy * 0.5, z - 0.26)), hull_mat)
    t = 0.11
    part.add(box((x - sx * 0.5 - t, -sy * 0.5 - t, z),
                 (x - sx * 0.5, sy * 0.5 + t, z + 0.17)), dark_mat)
    part.add(box((x + sx * 0.5, -sy * 0.5 - t, z),
                 (x + sx * 0.5 + t, sy * 0.5 + t, z + 0.17)), dark_mat)
    part.add(box((x - sx * 0.5, -sy * 0.5 - t, z),
                 (x + sx * 0.5, -sy * 0.5, z + 0.17)), dark_mat)
    part.add(box((x - sx * 0.5, sy * 0.5, z),
                 (x + sx * 0.5, sy * 0.5 + t, z + 0.17)), dark_mat)
    for i in range(5):
        xx = x - sx * 0.5 + 0.16 + (sx - 0.32) * i / 4.0
        part.add(box((xx - 0.028, -sy * 0.5 + 0.04, z + 0.06),
                     (xx + 0.028, sy * 0.5 - 0.04, z + 0.13)), wood_mat)
    for j in range(3):
        yy = -sy * 0.5 + 0.18 + (sy - 0.36) * j / 2.0
        part.add(box((x - sx * 0.5 + 0.04, yy - 0.028, z + 0.13),
                     (x + sx * 0.5 - 0.04, yy + 0.028, z + 0.19)), wood_mat)


def skylight(part, x, z, glass_mat=MAT_FLAG_BLUE,
             dark_mat=MAT_WOOD_DARK, brass_mat=MAT_BRASS):
    part.add(box((x - 0.92, -0.62, z), (x + 0.92, 0.62, z + 0.20)), dark_mat)
    poly = [(x - 0.86, z + 0.20), (x + 0.86, z + 0.20),
            (x + 0.62, z + 0.58), (x - 0.62, z + 0.58)]
    part.add(prism_xz(poly, -0.52, 0.52), glass_mat)
    for yy in (-0.52, 0.0, 0.52):
        part.add(box((x - 0.86, yy - 0.035, z + 0.20),
                     (x + 0.62, yy + 0.035, z + 0.56)), brass_mat)


def capstan(part, x, z, dark_mat=MAT_WOOD_DARK, wood_mat=MAT_WOOD):
    prof = [(0.00, 0.40), (0.10, 0.46), (0.52, 0.46), (0.66, 0.40),
            (0.92, 0.30), (1.02, 0.30)]
    part.add(translate(revolved(prof, 12), x, 0.0, z), dark_mat)
    for i in range(6):
        a = 2.0 * math.pi * i / 6.0
        ca, sa = math.cos(a), math.sin(a)
        c = (x + ca * 0.42, sa * 0.42, z + 0.84)
        d = (ca * 0.55, sa * 0.55, 0.0)
        u = (d[0], d[1], 0.0)
        v = (-sa, ca, 0.0)
        part.add(frame_box(c, u, v, (0.0, 0.0, 1.0), 0.60, 0.025, 0.025),
                 wood_mat)


def windlass(part, x, z, dark_mat=MAT_WOOD_DARK, wood_mat=MAT_WOOD):
    part.add(taper_cyl((x, -1.08, z + 0.52), (x, 1.08, z + 0.52),
                       0.12, 0.12, 8), dark_mat)
    for ys in (-0.92, 0.92):
        part.add(taper_cyl((x, ys - 0.07, z + 0.52), (x, ys + 0.07, z + 0.52),
                           0.34, 0.34, 10), dark_mat)
    for i in range(4):
        a = 2.0 * math.pi * i / 4.0
        c = (x + math.cos(a) * 0.30, 0.0, z + 0.52 + math.sin(a) * 0.30)
        part.add(frame_box(c, (math.cos(a), 0.0, math.sin(a)),
                           (0.0, 1.0, 0.0), (-math.sin(a), 0.0, math.cos(a)),
                           0.30, 0.028, 0.028), wood_mat)
    for ys in (-1.02, 1.02):
        part.add(box((x - 0.12, ys - 0.08, z - 0.02),
                     (x + 0.12, ys + 0.08, z + 0.54)), dark_mat)


def wheel(part, x, z, R, rim_r, dark_mat=MAT_WOOD_DARK, wood_mat=MAT_WOOD):
    cz = z + 0.86
    part.add(torus_x(x, 0.0, cz, R, rim_r, 14, 4), dark_mat)
    part.add(taper_cyl((x - 0.20, 0.0, cz), (x + 0.20, 0.0, cz), 0.12, 0.12, 8),
             dark_mat)
    for i in range(8):
        a = 2.0 * math.pi * i / 8.0
        y0, z0 = math.cos(a), math.sin(a)
        cy, cz2 = y0 * R * 0.55, cz + z0 * R * 0.55
        part.add(frame_box((x, cy, cz2), (0.0, y0, z0), (1.0, 0.0, 0.0),
                           (0.0, -z0, y0), R * 0.48, 0.026, 0.026), wood_mat)
    for dy in (-0.34, 0.34):
        part.add(box((x - 0.10, dy - 0.05, cz - 0.20),
                     (x + 0.10, dy + 0.05, z + 0.12)), dark_mat)
    part.add(box((x - 0.30, -0.48, z), (x + 0.26, 0.48, z + 0.10)), dark_mat)


def binnacle(part, x, z, dark_mat=MAT_WOOD_DARK, wood_mat=MAT_WOOD,
             brass_mat=MAT_BRASS):
    part.add(box((x - 0.34, -0.30, z), (x + 0.34, 0.30, z + 0.64)), dark_mat)
    part.add(box((x - 0.30, -0.26, z + 0.64), (x + 0.30, 0.26, z + 0.84)),
             wood_mat)
    part.add(taper_cyl((x, 0.0, z + 0.84), (x, 0.0, z + 0.88), 0.15, 0.15, 8),
             brass_mat)


def bell(part, x, z, dark_mat=MAT_WOOD_DARK, brass_mat=MAT_BRASS):
    for yy in (-0.30, 0.30):
        part.add(box((x - 0.06, yy - 0.035, z), (x + 0.06, yy + 0.035, z + 0.82)),
                 dark_mat)
    part.add(box((x - 0.07, -0.38, z + 0.78), (x + 0.07, 0.38, z + 0.86)),
             dark_mat)
    part.add(translate(revolved([(0.00, 0.10), (0.06, 0.14), (0.20, 0.15),
                                 (0.26, 0.12), (0.29, 0.16)], 8),
                       x, 0.0, z + 0.48), brass_mat)


def barrel(part, x, y, z, wood_mat=MAT_WOOD, metal_mat=MAT_METAL):
    part.add(translate(revolved([(0.00, 0.26), (0.06, 0.34), (0.18, 0.38),
                                 (0.50, 0.38), (0.62, 0.34), (0.68, 0.26)], 10),
                       x, y, z), wood_mat)
    for zz in (0.10, 0.50):
        part.add(taper_cyl((x, y, z + zz - 0.025),
                           (x, y, z + zz + 0.025), 0.395, 0.395, 10),
                 metal_mat)


def rope_coil(part, x, y, z, dark_mat=MAT_WOOD_DARK):
    part.add(torus_z(x, y, z + 0.05, 0.40, 0.055, 12, 4), dark_mat)
    part.add(torus_z(x, y, z + 0.13, 0.29, 0.050, 12, 4), dark_mat)


def bollard(part, x, y, z, dark_mat=MAT_WOOD_DARK):
    part.add(taper_cyl((x, y, z), (x, y, z + 0.30), 0.075, 0.075, 8), dark_mat)
    part.add(taper_cyl((x, y, z + 0.28), (x, y, z + 0.36), 0.13, 0.10, 8),
             dark_mat)


def bucket(part, x, y, z, wood_mat=MAT_WOOD, metal_mat=MAT_METAL):
    part.add(translate(revolved([(0.00, 0.17), (0.26, 0.21), (0.34, 0.24)], 10),
                       x, y, z), wood_mat)
    part.add(taper_cyl((x, y, z + 0.32), (x, y, z + 0.35),
                       0.245, 0.245, 10), metal_mat)


def fife_rail(part, x, z, dark_mat=MAT_WOOD_DARK, wood_mat=MAT_WOOD):
    for yy in (-0.92, 0.92):
        part.add(box((x - 0.06, yy - 0.06, z), (x + 0.06, yy + 0.06, z + 0.64)),
                 dark_mat)
    part.add(box((x - 0.09, -1.00, z + 0.60), (x + 0.09, 1.00, z + 0.76)),
             dark_mat)
    for i in range(6):
        yy = -0.85 + 0.34 * i
        part.add(taper_cyl((x, yy, z + 0.74), (x, yy, z + 0.94),
                           0.030, 0.022, 6), wood_mat)


def ladder(part, p0, p1, width, dark_mat=MAT_WOOD_DARK, wood_mat=MAT_WOOD):
    """从 p0 到 p1 的短梯：两根斜梁 + 4 道横档（p0/p1 是单侧梁的世界点）。"""
    from .core import bar_between, lerp3
    part.add(bar_between(p0, p1, 0.060), dark_mat)
    for t in (0.18, 0.40, 0.62, 0.84):
        a = lerp3(p0, p1, t)
        part.add(bar_between((a[0], -width, a[2]), (a[0], width, a[2]), 0.045),
                 wood_mat)
