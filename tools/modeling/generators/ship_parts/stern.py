# -*- coding: utf-8 -*-
"""可复用艉部构件：艉廊 + 艉窗 + 檐口 + 艉灯（纯 Python）。

x0/x1、窗位、灯位、材质主色全部由调用方给出；默认值对应 SN_Schooner_Fame 的当前尺寸。
"""

from .core import box, taper_cyl
from .palette import MAT_BRASS, MAT_FLAG_BLUE


def stern_gallery(part, x0, x1, ochre_mat, hull_mat,
                  window_ys=(-0.98, 0.0, 0.98),
                  lantern_ys=(-1.48, 1.48),
                  glass_mat=MAT_FLAG_BLUE, brass_mat=MAT_BRASS):
    """艉部弧形艉廊 + 3 扇艉窗 + 黑色檐口 + 双灯（schooner 原实现）。"""
    part.add(box((x1, -1.78, 1.98), (x0, 1.78, 2.90)), ochre_mat)
    part.add(box((x1 - 0.03, -1.80, 2.84), (x0 + 0.02, 1.80, 2.94)), hull_mat)
    part.add(box((x1 - 0.03, -1.80, 1.94), (x0 + 0.02, 1.80, 2.02)), hull_mat)
    for yc in window_ys:
        part.add(box((x1 - 0.04, yc - 0.34, 2.12), (x1, yc + 0.34, 2.62)),
                 glass_mat)
        # 左 0.04 m、右 0.04 m 窗框，保持镜像对称
        for dy in (-0.38, 0.34):
            part.add(box((x1 - 0.05, yc + dy, 2.08), (x1 + 0.01, yc + dy + 0.04,
                                                     2.66)), brass_mat)
        for dz in (2.06, 2.60):
            part.add(box((x1 - 0.05, yc - 0.38, dz), (x1 + 0.01, yc + 0.38,
                                                     dz + 0.04)), brass_mat)
    for ys in lantern_ys:
        part.add(taper_cyl((-12.38, ys, 2.90), (-12.50, ys, 3.28), 0.045, 0.075, 6),
                 brass_mat)
        part.add(box((-12.56, ys - 0.11, 3.24), (-12.40, ys + 0.11, 3.56)),
                 glass_mat)
        part.add(box((-12.58, ys - 0.13, 3.54), (-12.38, ys + 0.13, 3.62)),
                 brass_mat)
