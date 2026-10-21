# -*- coding: utf-8 -*-
# @static-doc
# 作用：舰载特殊武器三件套 GLB 的结构与共享贴图自检；复用
# `verify_weapon_glb.py` 的解析与检查逻辑，只替换 EXPECTED 清单。
#
# 用法：
#     python tools/modeling/generators/verify_weapon_batch2_glb.py
# @end-static-doc

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import verify_weapon_glb as base  # noqa: E402

base.EXPECTED = {
    "SN_Weapon_Ballista": (
        15, 5, 1956, (5.04, 3.05, 2.20),
        {"SN_Tex_Iron", "SN_Tex_Metal", "SN_Tex_Iron_Red", "SN_Tex_Wood",
         "SN_Tex_Wood_Dark", "SN_Tex_Wood_Deck", "SN_Tex_Brass",
         "SN_Tex_Canvas_Shade"},
        {"SN_Mount", "SN_Pivot_Yaw", "SN_Pivot_Pitch", "SN_Recoil",
         "SN_Muzzle", "SN_Anchor_1", "SN_Anchor_2", "SN_Anchor_3",
         "SN_Anchor_4"},
    ),
    "SN_Weapon_ArrowTower": (
        12, 6, 3428, (3.80, 3.80, 6.55),
        {"SN_Tex_Iron", "SN_Tex_Metal", "SN_Tex_Iron_Red", "SN_Tex_Wood",
         "SN_Tex_Wood_Dark", "SN_Tex_Wood_Deck", "SN_Tex_Brass",
         "SN_Tex_Canvas_Shade"},
        {"SN_Mount", "SN_Anchor_1", "SN_Anchor_2", "SN_Anchor_3",
         "SN_Anchor_4"},
    ),
    "SN_Weapon_HarpoonLauncher": (
        15, 5, 1908, (4.60, 1.84, 2.28),
        {"SN_Tex_Iron", "SN_Tex_Metal", "SN_Tex_Iron_Red",
         "SN_Tex_Wood_Dark", "SN_Tex_Brass"},
        {"SN_Mount", "SN_Pivot_Yaw", "SN_Pivot_Pitch", "SN_Recoil",
         "SN_Muzzle", "SN_Anchor_1", "SN_Anchor_2", "SN_Anchor_3",
         "SN_Anchor_4"},
    ),
}
base.DEFAULT_DIR = os.path.join(base.WORKDIR, "assets", "models", "weapons")

REQUIRED_EXTRAS = {
    "assembly_spec", "weapon_class", "assembly_profile", "socket", "mount",
    "pivot_yaw", "pivot_pitch", "recoil", "muzzle", "has_yaw", "has_pitch",
    "has_recoil", "has_muzzle", "muzzle_count", "yaw_axis", "pitch_axis",
    "recoil_axis", "mount_class", "pivot_profile", "mount_frame",
    "base_footprint_x", "base_footprint_y", "envelope_x", "envelope_y",
    "height", "swept_radius", "anchor_count",
}


def check_root_extras():
    """确认 glTF root 节点 extras 带上了 socket 契约数值。"""
    files = [os.path.join(base.DEFAULT_DIR, n)
             for n in sorted(os.listdir(base.DEFAULT_DIR))
             if os.path.splitext(n)[0] in base.EXPECTED]
    failures = []
    for path in files:
        name = os.path.splitext(os.path.basename(path))[0]
        gltf = base.load_glb(path)
        root = next((n for n in gltf.get("nodes", [])
                     if n.get("name", "").endswith("_Root")), None)
        if root is None:
            failures.append("%s: missing Root node" % name)
            continue
        extras = root.get("extras") or {}
        missing = REQUIRED_EXTRAS - set(extras)
        if missing:
            failures.append("%s: extras missing %s" % (
                name, ",".join(sorted(missing))))
        else:
            print("%-24s extras: class=%s profile=%s base=%sx%s env=%sx%s "
                  "height=%s swept=%s anchors=%s" % (
                      name, extras["mount_class"], extras["pivot_profile"],
                      extras["base_footprint_x"], extras["base_footprint_y"],
                      extras["envelope_x"], extras["envelope_y"],
                      extras["height"], extras["swept_radius"],
                      extras["anchor_count"]))
    return failures


if __name__ == "__main__":
    extras_failures = check_root_extras()
    rc = base.main()
    if extras_failures:
        print("EXTRAS FAILURES:")
        for item in extras_failures:
            print("  " + item)
        rc = 1
    sys.exit(rc)
