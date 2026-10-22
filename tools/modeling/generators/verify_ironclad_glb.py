# -*- coding: utf-8 -*-
"""Steam Navigator — SN_Ironclad GLB 结构自检（纯 Python，不进 Blender）。

解析 GLB：节点 / 网格 / 图元 / 三角面 / 材质 / glTF Y-up 包围盒。
预期：26 节点（1 mesh + 4 武器 socket + 9 帆索 socket + 12 炮门 socket）、1 网格、
8 个材质图元、8158 tri、Y-up 尺寸 (60.1346, 28.64, 18.0)。

用法：
    python tools/modeling/generators/verify_ironclad_glb.py
    python tools/modeling/generators/verify_ironclad_glb.py <GLB 路径>
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from verify_modules_glb import gltf_stats  # noqa: E402

WORKDIR = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
DEFAULT_GLB = os.path.join(WORKDIR, "assets", "models", "ships", "SN_Ironclad.glb")

EXPECTED_NODES = 26
EXPECTED_TRIS = 8158
EXPECTED_YUP = (60.1346, 28.64, 18.0)  # glTF Y-up: (Blender X, Blender Z, Blender Y)
EXPECTED_Z = (-4.2, 24.44)             # 水线轴心：glTF Y 从 -4.2（龙骨）到 24.44（主桅顶）
SIZE_TOL = 0.5
PALETTE = {"SN_Tex_Iron", "SN_Tex_Iron_Red", "SN_Tex_Wood_Deck", "SN_Tex_Wood",
           "SN_Tex_Wood_Dark", "SN_Tex_Metal", "SN_Tex_Brass", "SN_Tex_Canvas_Shade"}


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_GLB
    if not os.path.exists(path):
        print("MISSING %s" % path)
        return 1
    s = gltf_stats(path)
    flags = []
    if s["nodes"] != EXPECTED_NODES:
        flags.append("nodes=%d" % s["nodes"])
    if s["meshes"] != 1:
        flags.append("meshes=%d" % s["meshes"])
    if s["tris"] != EXPECTED_TRIS:
        flags.append("tris=%d != %d" % (s["tris"], EXPECTED_TRIS))
    for i in range(3):
        if abs(s["size_yup"][i] - EXPECTED_YUP[i]) > SIZE_TOL:
            flags.append("size_%s=%.3f != %.3f" % ("xyz"[i], s["size_yup"][i], EXPECTED_YUP[i]))
    bad = set(s["materials"]) - PALETTE
    if bad:
        flags.append("materials=%s" % ",".join(sorted(bad)))
    if abs(s["bbox_min"][1] - EXPECTED_Z[0]) > 0.2 or abs(s["bbox_max"][1] - EXPECTED_Z[1]) > 0.4:
        flags.append("z_range=%.3f..%.3f" % (s["bbox_min"][1], s["bbox_max"][1]))
    print("GLB: %s" % path)
    print("  nodes=%d meshes=%d primitives=%d tris=%d" % (
        s["nodes"], s["meshes"], s["primitives"], s["tris"]))
    print("  materials=%s" % ", ".join(s["materials"]))
    print("  bbox(Y-up)=%.3f x %.3f x %.3f" % tuple(s["size_yup"]))
    print("  bbox_min=%s bbox_max=%s" % (s["bbox_min"], s["bbox_max"]))
    if flags:
        print("  FAIL: %s" % ", ".join(flags))
        return 1
    print("  ALL GLB OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
