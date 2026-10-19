# -*- coding: utf-8 -*-
"""Steam Navigator — 港口设施锚点 GLB 结构自检（纯 Python，不需要 Blender）。

逐件读取 assets/models/port/SN_<Name>.glb，核对：
- GLB 头 / JSON chunk 合法；
- 单节点（或最多一个 mesh 节点）、无相机 / 无灯光 / 无贴图；
- 三角面数 <= 工单 tri_budget 的 1.2 倍；
- glTF Y-up 包围盒换算回 Blender 尺寸（X, Z, Y）后与 items.size 误差 <= 0.1 m；
- 轴心在底面中心：节点无平移、包围盒 X/Z 中心 ≈ 0、Y 最低点 ≈ 0；
- 材质全部在调色板内、doubleSided = true。

用法：
    python tools/modeling/generators/verify_port_glb.py
"""

import json
import math
import os
import struct
import sys

WORKDIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
GLB_DIR = os.path.join(WORKDIR, "assets", "models", "port")

TARGETS = [
    ("SN_Market_Stall", 1800, (5.0, 3.0, 3.2)),
    ("SN_Notice_Board", 500, (2.8, 0.5, 2.6)),
    ("SN_Water_Tank", 1400, (4.0, 4.0, 5.2)),
    ("SN_Signal_Tower", 1600, (3.2, 2.4, 8.5)),
    ("SN_Shipyard_Gantry", 2600, (14.0, 4.0, 10.0)),
    ("SN_Dry_Dock", 2200, (18.0, 8.0, 2.6)),
]

PALETTE = {
    "SN_Wood", "SN_Wood_Dark", "SN_Wood_Deck", "SN_Metal", "SN_Iron",
    "SN_Brass", "SN_Stone", "SN_Canvas", "SN_Canvas_Shade",
}

SIZE_TOL = 0.1
TRI_SLACK = 1.2


def read_glb(path):
    with open(path, "rb") as fh:
        data = fh.read()
    magic, version, length = struct.unpack_from("<4sII", data, 0)
    if magic != b"glTF" or version != 2:
        raise ValueError("不是 glTF 2.0 二进制文件: %r v%d" % (magic, version))
    if length != len(data):
        raise ValueError("GLB 长度字段 %d != 文件大小 %d" % (length, len(data)))
    off = 12
    json_chunk = None
    while off < length:
        clen, ctype = struct.unpack_from("<II", data, off)
        off += 8
        chunk = data[off:off + clen]
        off += clen
        if ctype == 0x4E4F534A:
            json_chunk = chunk
        elif ctype == 0x004E4942:
            pass
    if json_chunk is None:
        raise ValueError("缺少 JSON chunk")
    return json.loads(json_chunk.decode("utf-8"))


def check_one(name, budget, target):
    path = os.path.join(GLB_DIR, "%s.glb" % name)
    failures = []
    if not os.path.exists(path):
        return {"name": name, "ok": False, "failures": ["缺少 GLB 文件 %s" % path]}

    gltf = read_glb(path)
    nodes = gltf.get("nodes", [])
    meshes = gltf.get("meshes", [])
    materials = gltf.get("materials", [])
    accessors = gltf.get("accessors", [])

    if len(nodes) != 1:
        failures.append("节点数 %d != 1" % len(nodes))
    if len(meshes) != 1:
        failures.append("mesh 数 %d != 1" % len(meshes))
    if gltf.get("cameras"):
        failures.append("包含相机节点")
    if gltf.get("extensions", {}).get("KHR_lights_punctual") or any(
            "KHR_lights_punctual" in n.get("extensions", {}) for n in nodes):
        failures.append("包含灯光")
    if gltf.get("images") or gltf.get("textures"):
        failures.append("包含贴图（本批应为纯调色板材质）")

    node = nodes[0] if nodes else {}
    if node.get("translation") not in (None, [0, 0, 0]):
        failures.append("节点带平移 %r（轴心应归零）" % (node.get("translation"),))

    tris = 0
    mins = [math.inf] * 3
    maxs = [-math.inf] * 3
    for mesh in meshes:
        for prim in mesh.get("primitives", []):
            mode = prim.get("mode", 4)
            if mode != 4:
                failures.append("图元 mode=%d（应为三角形 4）" % mode)
            idx = prim.get("indices")
            if idx is not None:
                tris += accessors[idx]["count"] // 3
            else:
                pos = accessors[prim["attributes"]["POSITION"]]
                tris += pos["count"] // 3
            pos = accessors[prim["attributes"]["POSITION"]]
            for k in range(3):
                mins[k] = min(mins[k], pos["min"][k])
                maxs[k] = max(maxs[k], pos["max"][k])

    size = [round(maxs[k] - mins[k], 4) for k in range(3)]
    # glTF Y-up：Blender 尺寸 = (gltf X, gltf Z, gltf Y)
    blender_size = [size[0], size[2], size[1]]
    delta = [round(blender_size[i] - target[i], 4) for i in range(3)]
    center_x = round((mins[0] + maxs[0]) / 2.0, 4)
    center_z = round((mins[2] + maxs[2]) / 2.0, 4)
    ground = round(mins[1], 4)

    if tris > int(budget * TRI_SLACK):
        failures.append("三角面 %d > %d (1.2×预算)" % (tris, int(budget * TRI_SLACK)))
    if any(abs(d) > SIZE_TOL for d in delta):
        failures.append("尺寸偏差 %r 超过 %.2f m" % (delta, SIZE_TOL))
    if abs(center_x) > 0.02 or abs(center_z) > 0.02:
        failures.append("包围盒中心未在轴心 (x=%.4f z=%.4f)" % (center_x, center_z))
    if abs(ground) > 0.02:
        failures.append("包围盒最低点 y=%.4f（应贴地 0）" % ground)

    mat_names = []
    for mat in materials:
        mat_names.append(mat.get("name", ""))
        if mat.get("doubleSided") is not True:
            failures.append("材质 %s 非 doubleSided" % mat.get("name"))
        if "pbrMetallicRoughness" not in mat:
            failures.append("材质 %s 缺少 PBR 参数" % mat.get("name"))
    bad_mats = [m for m in mat_names if m not in PALETTE]
    if bad_mats:
        failures.append("材质不在调色板: %r" % bad_mats)

    return {
        "name": name,
        "ok": not failures,
        "failures": failures,
        "tris": tris,
        "budget": budget,
        "size_blender": blender_size,
        "target": list(target),
        "size_delta": delta,
        "bbox_y_up": {"min": [round(v, 4) for v in mins],
                      "max": [round(v, 4) for v in maxs]},
        "center_x": center_x,
        "center_z": center_z,
        "ground_y": ground,
        "materials": mat_names,
        "file_kb": round(os.path.getsize(path) / 1024.0, 1),
    }


def main():
    results = []
    total_tris = 0
    for name, budget, target in TARGETS:
        res = check_one(name, budget, target)
        results.append(res)
        total_tris += res.get("tris", 0)
        status = "PASS" if res["ok"] else "FAIL"
        print("%-20s %s tris=%-5s size=%s delta=%s" % (
            name, status, res.get("tris"),
            res.get("size_blender"), res.get("size_delta")))
        for item in res["failures"]:
            print("    ! %s" % item)
    print("TOTAL_TRIS %d / 10500" % total_tris)
    if total_tris > 10500:
        print("FAIL: 合计三角面超预算")
        results.append({"name": "TOTAL", "ok": False, "failures": ["over total budget"]})
    ok = all(r["ok"] for r in results)
    print("VERIFY_PORT_GLB " + json.dumps({"ok": ok, "total_tris": total_tris},
                                         ensure_ascii=False))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
