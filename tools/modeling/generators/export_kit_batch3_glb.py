# -*- coding: utf-8 -*-
# @static-doc
# 作用：模型素材库批次 3（建筑 4 + 环境 4）的 GLB 归档导出；复用
# `export_kit_glb.py` 的导出 / 贴图外部化 / Core 同步逻辑，替换资产清单与目录，
# 并把 11 张共享贴图补齐到 architecture / environment 两处 shared_materials。
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
    ("SN_Arch_Warehouse", "SN_Arch_Warehouse_Prototype",
     "SN_Arch_Warehouse_Root", "architecture"),
    ("SN_Arch_Workshop", "SN_Arch_Workshop_Prototype",
     "SN_Arch_Workshop_Root", "architecture"),
    ("SN_Arch_Tavern", "SN_Arch_Tavern_Prototype",
     "SN_Arch_Tavern_Root", "architecture"),
    ("SN_Arch_Factory", "SN_Arch_Factory_Prototype",
     "SN_Arch_Factory_Root", "architecture"),
    ("SN_Env_Reef", "SN_Env_Reef_Prototype",
     "SN_Env_Reef_Root", "environment"),
    ("SN_Env_Wreck", "SN_Env_Wreck_Prototype",
     "SN_Env_Wreck_Root", "environment"),
    ("SN_Env_Lighthouse", "SN_Env_Lighthouse_Prototype",
     "SN_Env_Lighthouse_Root", "environment"),
    ("SN_Env_Buoy", "SN_Env_Buoy_Prototype",
     "SN_Env_Buoy_Root", "environment"),
]


def export_all():
    report = base.export_all()
    shared = {}
    for category in ("architecture", "environment"):
        shared[category] = base._sync_shared_textures(category)
    report["shared_textures"] = shared
    print("KIT_BATCH3_EXPORT_DONE %r" % {
        "count": len(report["results"]),
        "workbench": report["workbench"],
        "shared_architecture": len(shared["architecture"]),
        "shared_environment": len(shared["environment"]),
    })
    return report


if __name__ == "__main__":
    export_all()
