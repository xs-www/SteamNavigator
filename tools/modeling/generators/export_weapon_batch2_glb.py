# -*- coding: utf-8 -*-
# @static-doc
# 作用：舰载特殊武器三件套（弩炮 / 箭塔 / 蒸汽鱼叉）的 GLB 归档导出；复用
# `export_weapon_glb.py` 的导出 / 贴图外部化 / Core 同步逻辑，只替换资产清单。
#
# 用法（已连 Blender 的会话）：
#     import runpy; runpy.run_path(<本文件>, run_name="__main__")
# @end-static-doc

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import export_weapon_glb as base  # noqa: E402

base.WEAPONS = [
    ("SN_Weapon_Ballista", "SN_Weapon_Ballista_Prototype",
     "SN_Weapon_Ballista_Root"),
    ("SN_Weapon_ArrowTower", "SN_Weapon_ArrowTower_Prototype",
     "SN_Weapon_ArrowTower_Root"),
    ("SN_Weapon_HarpoonLauncher", "SN_Weapon_HarpoonLauncher_Prototype",
     "SN_Weapon_HarpoonLauncher_Root"),
]


if __name__ == "__main__":
    base.export_all()
