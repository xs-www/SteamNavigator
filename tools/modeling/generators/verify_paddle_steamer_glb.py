# -*- coding: utf-8 -*-
"""SN_Paddle_Steamer GLB 结构自检（纯 Python，不进 Blender / Godot）。

读 GLB 头 + JSON chunk，核对：节点数、网格节点数、材质名与 doubleSided、
三角面数、世界包围盒（glTF 为 Y-up）与轴心；并检查 GLB 中不含蒸汽几何。

用法：
    python tools/modeling/generators/verify_paddle_steamer_glb.py [glb 路径]
"""

import json
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
DEFAULT_GLB = os.path.join(ROOT, "assets", "models", "ships", "SN_Paddle_Steamer.glb")

MATS = {"SN_White", "SN_Iron_Hull", "SN_Iron_Red", "SN_Wood_Deck",
        "SN_Metal", "SN_Brass", "SN_Flag_Blue", "SN_Flag_White",
        # Batch C: ship-local secondary white for the superstructure (see
        # PADDLE_STEAMER_VISUAL_POLISH_C.md); other shared materials stay unused.
        "SN_PS_UpperWhite"}
EXPECTED_TRIS = 11764
EXPECTED_SIZE = (24.56, 10.47, 8.74)   # glTF Y-up: X 船长 / Y 高 / Z 宽
TOL = 0.30
FORBIDDEN_NODE_PREFIX = "SN_PS_Steam"


def read_glb(path):
    with open(path, "rb") as f:
        data = f.read()
    magic, version, length = struct.unpack_from("<III", data, 0)
    if magic != 0x46546C67:
        raise SystemExit("not a GLB: %s" % path)
    off = 12
    js = None
    bin_len = 0
    while off < len(data):
        clen, ctype = struct.unpack_from("<II", data, off)
        chunk = data[off + 8:off + 8 + clen]
        if ctype == 0x4E4F534A:
            js = json.loads(chunk.decode("utf-8"))
        elif ctype == 0x004E4942:
            bin_len = len(chunk)
        off += 8 + clen + ((4 - clen % 4) % 4)
    return data, js, bin_len


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_GLB
    data, g, bin_len = read_glb(path)
    print("GLB: %s" % path)
    print("size: %.1f KB (bin %.1f KB)  version=%s" % (
        len(data) / 1024.0, bin_len / 1024.0, g.get("asset", {}).get("version")))

    nodes = g.get("nodes", [])
    meshes = g.get("meshes", [])
    materials = g.get("materials", [])
    accessors = g.get("accessors", [])
    print("nodes=%d meshes=%d materials=%d accessors=%d" % (
        len(nodes), len(meshes), len(materials), len(accessors)))

    children = {i: n.get("children", []) for i, n in enumerate(nodes)}
    roots = [i for i in range(len(nodes)) if not any(i in c for c in children.values())]
    print("root nodes: %s" % [nodes[i].get("name") for i in roots])

    total_tris = 0
    mesh_nodes = 0
    node_names = [n.get("name", "") for n in nodes]
    for n in nodes:
        if "mesh" not in n:
            continue
        mesh_nodes += 1
        prims = meshes[n["mesh"]].get("primitives", [])
        for p in prims:
            if "indices" in p:
                total_tris += accessors[p["indices"]]["count"] // 3
            else:
                total_tris += accessors[p["attributes"]["POSITION"]]["count"] // 3
    print("mesh nodes=%d  tris=%d" % (mesh_nodes, total_tris))

    names = []
    bad = []
    for m in materials:
        nm = m.get("name", "?")
        names.append(nm)
        if nm not in MATS:
            bad.append(nm)
        print("  %-14s doubleSided=%s" % (nm, m.get("doubleSided", False)))
        if not m.get("doubleSided", False):
            bad.append("not doubleSided: " + nm)
    missing = MATS - set(names)
    if missing:
        bad.append("missing:" + ",".join(sorted(missing)))

    def node_matrix(n):
        if "matrix" in n:
            m = n["matrix"]
            return [[m[0], m[4], m[8], m[12]],
                    [m[1], m[5], m[9], m[13]],
                    [m[2], m[6], m[10], m[14]],
                    [m[3], m[7], m[11], m[15]]]
        t = n.get("translation", [0, 0, 0])
        s = n.get("scale", [1, 1, 1])
        return [[s[0], 0, 0, t[0]], [0, s[1], 0, t[1]],
                [0, 0, s[2], t[2]], [0, 0, 0, 1]]

    def mul(a, b):
        return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)]
                for i in range(4)]

    wmn = [1e18] * 3
    wmx = [-1e18] * 3

    def walk(i, parent):
        n = nodes[i]
        m = mul(parent, node_matrix(n))
        if "mesh" in n:
            for p in meshes[n["mesh"]].get("primitives", []):
                acc = accessors[p["attributes"]["POSITION"]]
                for corner in range(8):
                    v = [acc["min"][0] if corner & 1 else acc["max"][0],
                         acc["min"][1] if corner & 2 else acc["max"][1],
                         acc["min"][2] if corner & 4 else acc["max"][2]]
                    w = [m[r][0] * v[0] + m[r][1] * v[1] + m[r][2] * v[2] + m[r][3]
                         for r in range(3)]
                    for k in range(3):
                        wmn[k] = min(wmn[k], w[k])
                        wmx[k] = max(wmx[k], w[k])
        for c in n.get("children", []):
            walk(c, m)

    ident = [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]]
    for r in roots:
        walk(r, ident)
    print("world bbox (Y-up): min=%s max=%s" % (
        [round(v, 2) for v in wmn], [round(v, 2) for v in wmx]))
    print("  -> X=%.2f  Y=%.2f  Z=%.2f" % (
        wmx[0] - wmn[0], wmx[1] - wmn[1], wmx[2] - wmn[2]))

    fails = []
    steam_nodes = [n.get("name", "") for n in nodes
                   if n.get("name", "").startswith(FORBIDDEN_NODE_PREFIX)
                   and n.get("name", "") != "SN_PS_Steam_Pipes"]
    if bad:
        fails.append("materials: %s" % bad)
    if steam_nodes:
        fails.append("steam nodes present: %s" % steam_nodes)
    if total_tris != EXPECTED_TRIS:
        fails.append("tris %d != %d" % (total_tris, EXPECTED_TRIS))
    if mesh_nodes != 32:
        fails.append("mesh nodes %d != 32" % mesh_nodes)
    size = (wmx[0] - wmn[0], wmx[1] - wmn[1], wmx[2] - wmn[2])
    for i, axis in enumerate("XYZ"):
        if abs(size[i] - EXPECTED_SIZE[i]) > TOL:
            fails.append("%s size %.2f != %.2f" % (axis, size[i], EXPECTED_SIZE[i]))
    if abs(wmn[1] + 1.32) > TOL:
        fails.append("waterline pivot: min Y %.2f != -1.32" % wmn[1])

    if fails:
        print("\nFAILURES:")
        for f in fails:
            print("  " + f)
        return 1
    print("\nGLB OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
