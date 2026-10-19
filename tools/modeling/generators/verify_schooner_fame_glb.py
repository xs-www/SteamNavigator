# -*- coding: utf-8 -*-
"""SN_Schooner_Fame GLB 结构自检（纯 Python，不进 Blender / Godot）。

读 GLB 头 + JSON chunk，核对：节点数、网格节点数、材质名与 doubleSided、
三角面数、世界包围盒（glTF 为 Y-up）与轴心。

用法：
    python tools/modeling/generators/verify_schooner_fame_glb.py [glb 路径]
"""

import json
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
DEFAULT_GLB = os.path.join(ROOT, "assets", "models", "ships", "SN_Schooner_Fame.glb")

MATS = {"SN_Hull_Black", "SN_Ochre", "SN_Wood", "SN_Wood_Dark", "SN_Wood_Deck",
        "SN_Canvas", "SN_Canvas_Shade", "SN_Metal", "SN_Brass",
        "SN_Flag_Red", "SN_Flag_White", "SN_Flag_Blue"}
EXPECTED_MESH_NODES = 29      # 28 几何 mesh + FAME 文字铭牌（无星条旗 / 无旗杆）
EXPECTED_SIZE = (33.44, 26.82, 6.88)   # glTF Y-up: X 船长 / Y 高 / Z 宽
TOL = 0.80
TRI_MIN, TRI_MAX = 12000, 18000
WATERLINE_MIN_Y = -2.74


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
        ds = m.get("doubleSided", False)
        print("  %-16s doubleSided=%s" % (nm, ds))
        if not ds:
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
    size = (wmx[0] - wmn[0], wmx[1] - wmn[1], wmx[2] - wmn[2])
    print("  -> X=%.2f  Y=%.2f  Z=%.2f" % size)

    fails = []
    if bad:
        fails.append("materials: %s" % bad)
    if not (TRI_MIN <= total_tris <= TRI_MAX):
        fails.append("tris %d out of [%d, %d]" % (total_tris, TRI_MIN, TRI_MAX))
    if mesh_nodes != EXPECTED_MESH_NODES:
        fails.append("mesh nodes %d != %d" % (mesh_nodes, EXPECTED_MESH_NODES))
    for i, axis in enumerate("XYZ"):
        if abs(size[i] - EXPECTED_SIZE[i]) > TOL:
            fails.append("%s size %.2f != %.2f" % (axis, size[i], EXPECTED_SIZE[i]))
    if abs(wmn[1] - WATERLINE_MIN_Y) > TOL:
        fails.append("waterline pivot: min Y %.2f != %.2f" % (
            wmn[1], WATERLINE_MIN_Y))
    node_names = [n.get("name", "") for n in nodes]
    if not any(n == "SN_SF_Root" for n in node_names):
        fails.append("missing SN_SF_Root node")
    if not any(n == "SN_SF_Mast_Fore_Pivot" for n in node_names):
        fails.append("missing SN_SF_Mast_Fore_Pivot")
    if not any(n == "SN_SF_Mast_Main_Pivot" for n in node_names):
        fails.append("missing SN_SF_Mast_Main_Pivot")

    if fails:
        print("\nFAILURES:")
        for f in fails:
            print("  " + f)
        return 1
    print("\nGLB OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
