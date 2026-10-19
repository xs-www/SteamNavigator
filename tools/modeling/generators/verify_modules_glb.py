# -*- coding: utf-8 -*-
"""Steam Navigator — 船舶模块 GLB 结构自检（纯 Python，不进 Blender）。

解析 glTF 2.0 二进制（GLB）：节点 / 网格 / 图元 / 三角面 / 材质 / doubleSided /
世界包围盒（glTF 为 +Y 向上）。用来在导出后独立核对"文件里的东西"是否与
Blender 场景一致，专抓"改了场景忘了重导 GLB"和轴向/轴心错误。

用法：
    python tools/modeling/generators/verify_modules_glb.py
    python tools/modeling/generators/verify_modules_glb.py <GLB 目录或单个 .glb>
"""

import json
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
WORKDIR = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
DEFAULT_DIR = os.path.join(WORKDIR, "assets", "models", "modules")

EXPECTED = {
    "SN_Boiler_Efficient": (1.80, 1.60, 2.60),
    "SN_Boiler_Standard": (2.80, 1.90, 2.70),
    "SN_Boiler_Performance": (3.40, 2.10, 3.00),
    "SN_Cargo_Small_Hold": (2.40, 2.00, 1.80),
    "SN_Cargo_Medium_Hold": (3.20, 2.40, 2.20),
    "SN_Cargo_Large_Hold": (4.00, 2.80, 2.60),
    "SN_Nav_Spyglass": (1.35, 0.80, 1.75),
    "SN_Nav_Chart_Room": (2.80, 2.20, 2.60),
    "SN_Safety_Lifeboat": (4.20, 1.50, 1.10),
    "SN_Safety_Valve": (1.50, 1.30, 1.85),
    "SN_Cabin_Passenger": (3.40, 2.40, 2.60),
}

SIZE_TOL = 0.12


def load_glb(path):
    with open(path, "rb") as f:
        data = f.read()
    magic, version, length = struct.unpack_from("<III", data, 0)
    if magic != 0x46546C67:
        raise ValueError("%s 不是 GLB" % path)
    offset = 12
    json_chunk = None
    while offset < length:
        clen, ctype = struct.unpack_from("<II", data, offset)
        payload = data[offset + 8:offset + 8 + clen]
        if ctype == 0x4E4F534A:
            json_chunk = json.loads(payload.decode("utf-8"))
        offset += 8 + clen
    if json_chunk is None:
        raise ValueError("%s 缺少 JSON chunk" % path)
    return json_chunk


def gltf_stats(path):
    gltf = load_glb(path)
    accessors = gltf.get("accessors", [])
    nodes = gltf.get("nodes", [])
    meshes = gltf.get("meshes", [])
    materials = gltf.get("materials", [])

    tris = 0
    prim_count = 0
    bbox_min = [float("inf")] * 3
    bbox_max = [float("-inf")] * 3
    for mesh in meshes:
        for prim in mesh.get("primitives", []):
            prim_count += 1
            mode = prim.get("mode", 4)
            attrs = prim.get("attributes", {})
            pos_idx = attrs.get("POSITION")
            if pos_idx is None:
                continue
            acc = accessors[pos_idx]
            for i in range(3):
                bbox_min[i] = min(bbox_min[i], acc.get("min", [0, 0, 0])[i])
                bbox_max[i] = max(bbox_max[i], acc.get("max", [0, 0, 0])[i])
            if "indices" in prim:
                count = accessors[prim["indices"]]["count"]
            else:
                count = acc["count"]
            if mode == 4:
                tris += count // 3
            elif mode == 5:
                tris += max(0, count - 2)

    mat_names = [m.get("name", "?") for m in materials]
    double_sided = [bool(m.get("doubleSided", False)) for m in materials]
    return {
        "nodes": len(nodes),
        "meshes": len(meshes),
        "primitives": prim_count,
        "tris": tris,
        "materials": mat_names,
        "double_sided": double_sided,
        "bbox_min": [round(v, 4) for v in bbox_min],
        "bbox_max": [round(v, 4) for v in bbox_max],
        "size_yup": [round(bbox_max[i] - bbox_min[i], 4) for i in range(3)],
    }


def main():
    target = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_DIR
    if os.path.isdir(target):
        files = sorted(os.path.join(target, n) for n in os.listdir(target) if n.endswith(".glb"))
    else:
        files = [target]
    failures = []
    print("%-28s %6s %6s %6s %-34s %-30s %s" % (
        "glb", "nodes", "meshes", "tris", "materials", "size(Y-up x,y,z)", "flags"))
    print("-" * 130)
    for path in files:
        name = os.path.splitext(os.path.basename(path))[0]
        s = gltf_stats(path)
        size_yup = s["size_yup"]
        expected = EXPECTED.get(name)
        flags = []
        if s["nodes"] != 1:
            flags.append("nodes=%d" % s["nodes"])
        if expected is not None:
            # glTF Y-up: 文件 (x, y, z) = Blender (x, z, y)
            expect_yup = (expected[0], expected[2], expected[1])
            for i in range(3):
                if abs(size_yup[i] - expect_yup[i]) > SIZE_TOL:
                    flags.append("size[%s]=%.3f!=%.3f" % ("xyz"[i], size_yup[i], expect_yup[i]))
        if not any(s["double_sided"]):
            flags.append("no-doubleSided")
        if flags:
            failures.append((name, flags))
        print("%-28s %6d %6d %6d %-34s %-30s %s" % (
            name, s["nodes"], s["meshes"], s["tris"],
            ",".join(s["materials"])[:33],
            "%.3f,%.3f,%.3f" % tuple(size_yup),
            ", ".join(flags) if flags else "ok"))

    print("-" * 130)
    print("files = %d, failures = %d" % (len(files), len(failures)))
    if failures:
        for name, flags in failures:
            print("  FAIL %s: %s" % (name, ", ".join(flags)))
        return 1
    print("ALL GLB OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
