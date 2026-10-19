# -*- coding: utf-8 -*-
"""Steam Navigator — P0 整改归档脚本（人工验收后由 Lead 执行）。

顺序（每一步都可回滚）：
  1. 备份即将被覆盖的 .glb 到 .design/props/backup_glb/（带时间戳，本地不入库）
  2. 清掉拼接测试临时对象 SN_TMP_Splice_1..3（复用 p0_rework 的 clear_splice_test）
  3. 逐件归零导出 SN_Mooring_Bollard.glb / SN_Ore_Pile.glb
  4. 保存工作台 .design/SN_Asset_Workbench.blend
  5. 打印终态：对象数 / 集合内容 / mesh datablock / 文件大小

注意：本脚本会写磁盘（GLB + .blend），只应在人工验收通过后执行。
"""

import bpy
import os
import runpy
import shutil
import time

WORKDIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
GEN_DIR = os.path.join(WORKDIR, "tools", "modeling", "generators")
P0_SCRIPT = os.path.join(GEN_DIR, "p0_rework_2026-10-19.py")
EXPORT_SCRIPT = os.path.join(GEN_DIR, "export_props_glb.py")
GLB_DIR = os.path.join(WORKDIR, "assets", "models", "props")
# 备份是本地产物，仍放 gitignore 的 .design/ 下
BACKUP_DIR = os.path.join(WORKDIR, ".design", "props", "backup_glb")
TARGETS = ["SN_Mooring_Bollard", "SN_Ore_Pile"]


def backup_existing():
    stamp = time.strftime("%Y%m%d-%H%M%S")
    os.makedirs(BACKUP_DIR, exist_ok=True)
    made = []
    for name in TARGETS:
        src = os.path.join(GLB_DIR, "%s.glb" % name)
        if os.path.exists(src):
            dst = os.path.join(BACKUP_DIR, "%s.%s.glb" % (name, stamp))
            shutil.copy2(src, dst)
            made.append((src, dst))
    print("BACKUP " + repr(made))
    return made


def finalize():
    before = {
        "objects": len(bpy.data.objects),
        "mesh_objects": sum(1 for o in bpy.data.objects if o.type == "MESH"),
        "materials": len(bpy.data.materials),
    }

    backup_existing()

    p0 = runpy.run_path(P0_SCRIPT)
    removed = p0["clear_splice_test"]()
    print("SPLICE_CLEARED " + repr(removed))

    export = runpy.run_path(EXPORT_SCRIPT)
    files = export["export_many"]()

    bpy.ops.wm.save_mainfile()

    after = {
        "objects": len(bpy.data.objects),
        "mesh_objects": sum(1 for o in bpy.data.objects if o.type == "MESH"),
        "materials": len(bpy.data.materials),
        "mesh_datablocks": len(bpy.data.meshes),
        "props": sorted(o.name for o in bpy.data.collections["SN_IronHarbor_Props"].objects),
        "temp_left": sorted(o.name for o in bpy.data.objects if o.name.startswith("SN_TMP_")),
        "file": bpy.data.filepath,
        "glb": [(os.path.basename(f), os.path.getsize(f)) for f in files],
    }
    print("FINALIZE_DONE " + repr({"before": before, "after": after}))
    return after


if __name__ == "__main__":
    finalize()
