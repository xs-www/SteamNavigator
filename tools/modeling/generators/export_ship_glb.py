# -*- coding: utf-8 -*-
"""SN_Paddle_Freighter 归档脚本：备份旧 GLB → 保存工作台 → 导出 GLB → 船体快照。

由 Lead 在人工验收通过后运行（Builder 不保存/导出）：
    import io
    p = r"D:\\桌面\\sisi_apps\\SteamNavigator\\tools\\modeling\\generators\\export_ship_glb.py"
    exec(compile(io.open(p, encoding="utf-8").read(), p, "exec"), {"__name__": "__main__"})

规则
----
- 导出前把 SN_PF_Root 临时归零，导出后还原，保证 GLB 轴心 = 船体中部水线；
- 旧 GLB 先备份到 .design/ships/backup_glb/；
- 工作台 .blend 保持 SN_PF_Root 在 (-45, 0, 0)；
- 船体快照 .design/ships/SN_Paddle_Freighter.blend 用 copy=True 写出，
  不切换当前文件（历史上切文件曾导致子代理写错场景）。
"""

import os
import shutil

ROOT_DIR = r"D:\桌面\sisi_apps\SteamNavigator"
COLLECTION = "SN_Paddle_Freighter_Prototype"
ROOT_NAME = "SN_PF_Root"

GLB = os.path.join(ROOT_DIR, "assets", "models", "ships", "SN_Paddle_Freighter.glb")
BACKUP_DIR = os.path.join(ROOT_DIR, ".design", "ships", "backup_glb")
BLEND = os.path.join(ROOT_DIR, ".design", "ships", "SN_Paddle_Freighter.blend")
WORKBENCH = os.path.join(ROOT_DIR, ".design", "SN_Asset_Workbench.blend")


def main():
    import bpy
    col = bpy.data.collections[COLLECTION]
    root = bpy.data.objects[ROOT_NAME]
    objs = list(col.objects)
    print("导出集合 %s：%d 对象" % (COLLECTION, len(objs)))

    if os.path.exists(GLB):
        os.makedirs(BACKUP_DIR, exist_ok=True)
        n = 1
        while True:
            bak = os.path.join(BACKUP_DIR, "SN_Paddle_Freighter.%02d.glb" % n)
            if not os.path.exists(bak):
                break
            n += 1
        shutil.copy2(GLB, bak)
        print("旧 GLB 备份 -> %s" % bak)

    # 1) 保存工作台（保留根节点 (-45,0,0) 摆位）
    bpy.ops.wm.save_as_mainfile(filepath=WORKBENCH)
    print("工作台已保存: %s" % WORKBENCH)

    old_loc = tuple(root.location)

    # 2) 导出 GLB：根节点归零 + 只选集合内对象
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objs:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = root
    root.location = (0.0, 0.0, 0.0)
    bpy.context.view_layer.update()
    bpy.ops.export_scene.gltf(
        filepath=GLB,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_extras=True,
        export_cameras=False,
        export_lights=False,
    )
    print("GLB 导出: %s (%.1f KB)" % (GLB, os.path.getsize(GLB) / 1024.0))

    # 3) 船体快照：只写集合 + 相关 datablock（不切换当前文件，避免历史事故）
    #    用 bpy.data.libraries.write 只打包本资产；根节点临时归零，让快照轴心 = 中部水线。
    root.location = (0.0, 0.0, 0.0)
    bpy.context.view_layer.update()
    try:
        data = {col}
        for ob in objs:
            data.add(ob)
            if ob.type == "MESH" and ob.data is not None:
                data.add(ob.data)
        for mat in bpy.data.materials:
            if mat.users > 0:
                data.add(mat)
        bpy.data.libraries.write(BLEND, data, fake_user=True, compress=True)
        print("船体快照: %s (%.1f KB)" % (BLEND, os.path.getsize(BLEND) / 1024.0))
    except Exception as exc:  # 保底：整文件副本（含工作台其他对象）
        print("libraries.write 失败(%s)，回退为工作台副本" % exc)
        bpy.ops.wm.save_as_mainfile(filepath=BLEND, copy=True)

    root.location = old_loc
    bpy.context.view_layer.update()
    # 4) 再存一次工作台，确保磁盘状态 = 根节点在 (-45,0,0)
    bpy.ops.wm.save_as_mainfile(filepath=WORKBENCH)
    print("根节点位置已还原: %s" % (tuple(round(v, 2) for v in root.location),))


if __name__ == "__main__":
    main()
