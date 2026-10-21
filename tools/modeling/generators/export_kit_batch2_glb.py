# -*- coding: utf-8 -*-
# @static-doc
# 作用：模型素材库批次 2（机械 / 货物 / 码头 10 件）的 GLB 归档导出；复用
# `export_kit_glb.py` 的导出 / 贴图外部化 / Core 同步逻辑，只替换资产清单与目录。
#
# 用法（已连 Blender 的会话）：
#     import runpy; runpy.run_path(<本文件>, run_name="__main__")
# @end-static-doc

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import export_kit_glb as base  # noqa: E402

base.KITS = [
    ("SN_Machinery_GearSet", "SN_Machinery_GearSet_Prototype",
     "SN_Machinery_GearSet_Root", "machinery"),
    ("SN_Machinery_Winch", "SN_Machinery_Winch_Prototype",
     "SN_Machinery_Winch_Root", "machinery"),
    ("SN_Machinery_PowerUnit", "SN_Machinery_PowerUnit_Prototype",
     "SN_Machinery_PowerUnit_Root", "machinery"),
    ("SN_Cargo_Crate", "SN_Cargo_Crate_Prototype",
     "SN_Cargo_Crate_Root", "cargo"),
    ("SN_Cargo_CoalScuttle", "SN_Cargo_CoalScuttle_Prototype",
     "SN_Cargo_CoalScuttle_Root", "cargo"),
    ("SN_Cargo_Tank", "SN_Cargo_Tank_Prototype",
     "SN_Cargo_Tank_Root", "cargo"),
    ("SN_Cargo_Pallet", "SN_Cargo_Pallet_Prototype",
     "SN_Cargo_Pallet_Root", "cargo"),
    ("SN_Dock_Structure", "SN_Dock_Structure_Prototype",
     "SN_Dock_Structure_Root", "dock"),
    ("SN_Dock_Jetty", "SN_Dock_Jetty_Prototype",
     "SN_Dock_Jetty_Root", "dock"),
    ("SN_Dock_Mooring", "SN_Dock_Mooring_Prototype",
     "SN_Dock_Mooring_Root", "dock"),
]


if __name__ == "__main__":
    base.export_all()
