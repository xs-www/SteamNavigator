# -*- coding: utf-8 -*-
# @static-doc
# 作用：四台起重机 GLB 的结构自检（纯 Python，不进 Blender）。
#
# 解析 glTF 2.0 二进制（GLB），核对节点数 / 网格数 / 图元 / 三角面 / 材质名 /
# doubleSided / **世界空间** glTF Y-up 包围盒（按节点层级合成 TRS，能正确覆盖
# 挂在 Pivot 下的部件），专抓「改了场景忘了重导 GLB」「轴心/轴向错误」
# 「材质被改成单面」。用法：
#
#     python tools/modeling/generators/verify_cranes_glb.py
#     python tools/modeling/generators/verify_cranes_glb.py <GLB 目录或单文件>
#
# 通过标准：每件 ALL OK，否则返回非 0 退出码。
# @end-static-doc

import json
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
WORKDIR = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
DEFAULT_DIR = os.path.join(WORKDIR, "assets", "models", "props")

# 资产 -> (节点数, 网格数, 三角面, Blender 世界 bbox (x, y, z), 允许材质)
EXPECTED = {
    "SN_Harbor_Crane": (
        33, 31, 3912, (26.50, 6.30, 21.47),
        {"SN_Metal", "SN_Wood", "SN_Wood_Dark", "SN_Stone"},
    ),
    "SN_Mega_Gantry": (
        20, 19, 9420, (39.60, 14.80, 29.65),
        {"SN_Metal", "SN_Iron", "SN_Iron_Red", "SN_Wood_Dark", "SN_Brass",
         "SN_Stone", "SN_Glass_Dark"},
    ),
    "SN_Wooden_Mast_Crane": (
        11, 10, 1932, (14.77, 7.00, 14.25),
        {"SN_Wood", "SN_Wood_Dark", "SN_Wood_Deck", "SN_Metal", "SN_Stone",
         "SN_Brass", "SN_Canvas_Shade"},
    ),
    "SN_Hand_Jib_Crane": (
        7, 6, 896, (4.60, 1.70, 5.17),
        {"SN_Metal", "SN_Iron", "SN_Wood_Dark", "SN_Stone", "SN_Brass",
         "SN_Canvas_Shade"},
    ),
}

SIZE_TOL = 0.05


# ---------------------------------------------------------------- 4x4 矩阵

def _identity():
    return [1.0, 0.0, 0.0, 0.0,
            0.0, 1.0, 0.0, 0.0,
            0.0, 0.0, 1.0, 0.0,
            0.0, 0.0, 0.0, 1.0]


def _mat_mul(a, b):
    out = [0.0] * 16
    for row in range(4):
        for col in range(4):
            out[row * 4 + col] = sum(
                a[row * 4 + k] * b[k * 4 + col] for k in range(4))
    return out


def _from_translation(t):
    m = _identity()
    m[3], m[7], m[11] = t[0], t[1], t[2]
    return m


def _from_scale(s):
    m = _identity()
    m[0], m[5], m[10] = s[0], s[1], s[2]
    return m


def _from_quaternion(q):
    x, y, z, w = q
    return [
        1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w), 0.0,
        2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w), 0.0,
        2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y), 0.0,
        0.0, 0.0, 0.0, 1.0,
    ]


def _node_matrix(node):
    if "matrix" in node:
        m = node["matrix"]      # glTF 矩阵是列主序
        return [m[col * 4 + row] for row in range(4) for col in range(4)]
    t = node.get("translation", [0.0, 0.0, 0.0])
    q = node.get("rotation", [0.0, 0.0, 0.0, 1.0])
    s = node.get("scale", [1.0, 1.0, 1.0])
    return _mat_mul(_from_translation(t),
                    _mat_mul(_from_quaternion(q), _from_scale(s)))


def _transform(m, p):
    return [
        m[0] * p[0] + m[1] * p[1] + m[2] * p[2] + m[3],
        m[4] * p[0] + m[5] * p[1] + m[6] * p[2] + m[7],
        m[8] * p[0] + m[9] * p[1] + m[10] * p[2] + m[11],
    ]


# ---------------------------------------------------------------- GLB

def load_glb(path):
    with open(path, "rb") as f:
        data = f.read()
    magic, _version, length = struct.unpack_from("<III", data, 0)
    if magic != 0x46546C67:
        raise ValueError("%s 不是 GLB" % path)
    offset = 12
    gltf = None
    while offset < length:
        clen, ctype = struct.unpack_from("<II", data, offset)
        payload = data[offset + 8:offset + 8 + clen]
        if ctype == 0x4E4F534A:
            gltf = json.loads(payload.decode("utf-8"))
        offset += 8 + clen
    if gltf is None:
        raise ValueError("%s 缺少 JSON chunk" % path)
    return gltf


def gltf_stats(path):
    gltf = load_glb(path)
    accessors = gltf.get("accessors", [])
    nodes = gltf.get("nodes", [])
    meshes = gltf.get("meshes", [])
    materials = gltf.get("materials", [])

    tris = 0
    prims = 0
    for mesh in meshes:
        for prim in mesh.get("primitives", []):
            prims += 1
            pos_idx = prim.get("attributes", {}).get("POSITION")
            if pos_idx is None:
                continue
            acc = accessors[pos_idx]
            count = (accessors[prim["indices"]]["count"]
                     if "indices" in prim else acc["count"])
            if prim.get("mode", 4) == 4:
                tris += count // 3
            elif prim.get("mode") == 5:
                tris += max(0, count - 2)

    bbox_min = [float("inf")] * 3
    bbox_max = [float("-inf")] * 3

    def include_mesh(mesh_index, world):
        for prim in meshes[mesh_index].get("primitives", []):
            pos_idx = prim.get("attributes", {}).get("POSITION")
            if pos_idx is None:
                continue
            acc = accessors[pos_idx]
            lo = acc.get("min", [0.0, 0.0, 0.0])
            hi = acc.get("max", [0.0, 0.0, 0.0])
            for dx in (lo[0], hi[0]):
                for dy in (lo[1], hi[1]):
                    for dz in (lo[2], hi[2]):
                        p = _transform(world, (dx, dy, dz))
                        for i in range(3):
                            bbox_min[i] = min(bbox_min[i], p[i])
                            bbox_max[i] = max(bbox_max[i], p[i])

    def walk(index, parent):
        node = nodes[index]
        world = _mat_mul(parent, _node_matrix(node))
        if "mesh" in node:
            include_mesh(node["mesh"], world)
        for child in node.get("children", []):
            walk(child, world)

    scene_roots = []
    scenes = gltf.get("scenes", [])
    if scenes:
        scene_roots = scenes[0].get("nodes", [])
    if not scene_roots:
        scene_roots = list(range(len(nodes)))
    for root in scene_roots:
        walk(root, _identity())

    return {
        "nodes": len(nodes),
        "meshes": len(meshes),
        "primitives": prims,
        "tris": tris,
        "materials": [m.get("name", "?") for m in materials],
        "double_sided": all(bool(m.get("doubleSided", False))
                            for m in materials),
        "has_cameras": "cameras" in gltf,
        "bbox_min": [round(v, 4) for v in bbox_min],
        "bbox_max": [round(v, 4) for v in bbox_max],
        "size_yup": [round(bbox_max[i] - bbox_min[i], 4) for i in range(3)],
    }


def main():
    target = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_DIR
    if os.path.isdir(target):
        files = [os.path.join(target, n) for n in sorted(os.listdir(target))
                 if os.path.splitext(n)[0] in EXPECTED]
    else:
        files = [target]
    failures = []
    print("%-24s %5s %5s %6s %-6s %-30s %-26s %s" % (
        "glb", "nodes", "mesh", "tris", "prims", "size(Y-up x,y,z)",
        "materials", "flags"))
    print("-" * 128)
    for path in files:
        name = os.path.splitext(os.path.basename(path))[0]
        s = gltf_stats(path)
        expected = EXPECTED.get(name)
        flags = []
        if expected is not None:
            exp_nodes, exp_meshes, exp_tris, exp_bbox, exp_mats = expected
            if s["nodes"] != exp_nodes:
                flags.append("nodes=%d/%d" % (s["nodes"], exp_nodes))
            if s["meshes"] != exp_meshes:
                flags.append("meshes=%d/%d" % (s["meshes"], exp_meshes))
            if s["tris"] != exp_tris:
                flags.append("tris=%d/%d" % (s["tris"], exp_tris))
            expect_yup = (exp_bbox[0], exp_bbox[2], exp_bbox[1])
            for i in range(3):
                if abs(s["size_yup"][i] - expect_yup[i]) > SIZE_TOL:
                    flags.append("size[%s]=%.3f!=%.3f" % (
                        "xyz"[i], s["size_yup"][i], expect_yup[i]))
            extra = set(s["materials"]) - exp_mats
            if extra:
                flags.append("mat=%s" % ",".join(sorted(extra)))
        if not s["double_sided"]:
            flags.append("not-all-doubleSided")
        if s["has_cameras"]:
            flags.append("has-camera")
        if abs(s["bbox_min"][1]) > SIZE_TOL:
            flags.append("groundY=%.3f" % s["bbox_min"][1])
        if flags:
            failures.append((name, flags))
        print("%-24s %5d %5d %6d %6d %-30s %-26s %s" % (
            name, s["nodes"], s["meshes"], s["tris"], s["primitives"],
            "%.2f,%.2f,%.2f" % tuple(s["size_yup"]),
            ",".join(s["materials"])[:25],
            ", ".join(flags) if flags else "ok"))
    print("-" * 128)
    print("files = %d, failures = %d" % (len(files), len(failures)))
    if failures:
        for name, flags in failures:
            print("  FAIL %s: %s" % (name, ", ".join(flags)))
        return 1
    print("ALL CRANE GLB OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
