# -*- coding: utf-8 -*-
# @static-doc
# 作用：蓝图生成器集成测试的确定性蒸汽船 GLB fixture 构建器；仅在临时目录创建低面数船体、
# 上层舱室、烟囱和桅杆，覆盖外轮廓、结构折线与共面三角边过滤场景。
# @end-static-doc

import math
import os
import sys

import bpy


def _args():
    values = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if len(values) != 1:
        raise ValueError("expected output GLB path")
    return os.path.abspath(values[0])


def _box(name, location, scale):
    bpy.ops.mesh.primitive_cube_add(location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj


def build(path):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    hull = _box("Fixture_Hull", (0.0, 0.0, 1.0), (6.0, 1.5, 1.0))
    cabin = _box("Fixture_Cabin", (-0.8, 0.0, 2.5), (2.0, 1.1, 0.5))
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.38, depth=2.8,
                                        location=(-1.2, 0.0, 4.4))
    funnel = bpy.context.object
    funnel.name = "Fixture_Funnel"
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.10, depth=4.4,
                                        location=(2.1, 0.0, 4.2))
    mast = bpy.context.object
    mast.name = "Fixture_Mast"
    for obj in (hull, cabin, funnel, mast):
        obj.select_set(True)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=False,
                              export_cameras=False, export_lights=False)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.splitext(path)[0] + ".blend")
    print("BLUEPRINT_FIXTURE %s" % path)


if __name__ == "__main__":
    build(_args())
