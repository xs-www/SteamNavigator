# -*- coding: utf-8 -*-
# @static-doc
# 作用：舰载特殊武器三件套（弩炮 / 箭塔 / 蒸汽鱼叉）的预览渲染；复用
# `render_weapon_preview.py` 的隔离 / 相机 / 灯光 / 地面逻辑，只替换资产清单与
# lineup 文件名。
#
# 用法（已连 Blender 的会话）：
#     import runpy; runpy.run_path(<本文件>, run_name="__main__")
# 输出：.design/weapons/preview/ 与 docs/design/screenshots/weapons/
# @end-static-doc

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import render_weapon_preview as base  # noqa: E402

base.WEAPONS = [
    ("SN_Weapon_Ballista", "SN_Weapon_Ballista_Prototype",
     "SN_Weapon_Ballista_Root", "ballista"),
    ("SN_Weapon_ArrowTower", "SN_Weapon_ArrowTower_Prototype",
     "SN_Weapon_ArrowTower_Root", "arrow_tower"),
    ("SN_Weapon_HarpoonLauncher", "SN_Weapon_HarpoonLauncher_Prototype",
     "SN_Weapon_HarpoonLauncher_Root", "harpoon_launcher"),
]
base.LINEUP_NAME = "weapon_batch2_lineup"
base.LINEUP_ROTATE_Z = {}

if __name__ == "__main__":
    base.main()
