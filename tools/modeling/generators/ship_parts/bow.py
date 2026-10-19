# -*- coding: utf-8 -*-
"""可复用艏部构件：艏斜桁 / jibboom / 雕刻艏饰（纯 Python）。

艏柱位置、斜桁长度、艏饰安装点都由调用方传入；材质主色（hull/ochre）也由调用方给，
公共件只依赖标准木/金属/黄铜材质名。
"""

from .core import box, lerp3, revolved, taper_cyl, translate, vadd, vmul, vnorm, vsub
from .palette import MAT_BRASS, MAT_METAL, MAT_WOOD


def bowsprit(part, bowsprit_cfg, jibboom_cfg, wood_mat=MAT_WOOD,
             metal_mat=MAT_METAL):
    """艏斜桁 + 延伸杆 + 铁箍 + 艏柱系固箍（坐标与 schooner 生成器原实现一致）。"""
    part.add(taper_cyl(bowsprit_cfg["root"], bowsprit_cfg["tip"],
                       bowsprit_cfg["r0"], bowsprit_cfg["r1"], 8), wood_mat)
    part.add(taper_cyl(jibboom_cfg["root"], jibboom_cfg["tip"],
                       jibboom_cfg["r0"], jibboom_cfg["r1"], 6), wood_mat)
    axis = vnorm(vsub(bowsprit_cfg["tip"], bowsprit_cfg["root"]))
    for t in (0.16, 0.34, 0.52):
        p = lerp3(bowsprit_cfg["root"], bowsprit_cfg["tip"], t)
        r = (bowsprit_cfg["r0"]
             + (bowsprit_cfg["r1"] - bowsprit_cfg["r0"]) * t + 0.025)
        part.add(taper_cyl(vadd(p, vmul(axis, -0.055)),
                           vadd(p, vmul(axis, 0.055)), r, r, 8), metal_mat)
    for zc in (3.05, 3.28):
        part.add(box((12.28, -0.20, zc - 0.05), (12.62, 0.20, zc + 0.05)),
                 metal_mat)


def figurehead(part, cfg, brass_mat=MAT_BRASS):
    """雕刻艏饰：黄铜卷饰 + 赭黄胸像 + 深色眼点。

    cfg 需要：scroll_root/scroll_tip/scroll_tip2/scroll_end、bust_lo/bust_hi、
    head_center、eye_lo/eye_hi、ochre_mat、hull_mat。坐标保持 schooner 原值。
    """
    part.add(taper_cyl(cfg["scroll_root"], cfg["scroll_tip"],
                       cfg.get("scroll_r0", 0.150), cfg.get("scroll_r1", 0.055), 6),
             brass_mat)
    part.add(taper_cyl(cfg["scroll_tip2"], cfg["scroll_end"],
                       0.060, 0.020, 6), brass_mat)
    part.add(box(cfg["bust_lo"], cfg["bust_hi"]), cfg["ochre_mat"])
    part.add(translate(revolved([(0.00, 0.10), (0.10, 0.145), (0.24, 0.13),
                                 (0.34, 0.05)], 8),
                       *cfg["head_center"]), cfg["ochre_mat"])
    for yy in cfg.get("eye_ys", (-0.055, 0.055)):
        part.add(box((cfg["eye_x"][0], yy - 0.022, cfg["eye_z"][0]),
                     (cfg["eye_x"][1], yy + 0.022, cfg["eye_z"][1])),
                 cfg["hull_mat"])
