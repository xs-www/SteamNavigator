# -*- coding: utf-8 -*-
# @static-doc
# 作用：旧资产 UV 迁移 B 的 GLB 独立验收（纯 Python，不进 Blender/Godot）——
# 核对 12 件船模块 / 4 艘船 / 5 件旧小镇道具的节点 / 网格 / 图元 / 三角面 / 世界尺寸 /
# 材质名 / doubleSided，以及"每个图元都有 TEXCOORD_0"、"材质全部 SN_Tex_* 且引用外部
# shared_materials/<texture>.png"、"外部 PNG 与授权 tile 逐字节一致"、"没有内嵌图片"；
# 模块与船的 Core 副本必须与 assets 副本逐字节一致。
#
# 期望值来自迁移前 GLB 基线（.design/legacy_uv_b/baseline.json）：节点数 / 网格数 /
# tri / 尺寸必须与迁移前一致，证明这次只改材质与 UV、没有动几何。图元数允许**少于**
# 基线：多个旧材质映射到同一张 `SN_Tex_*` 时（如 `SN_Canvas` / `SN_Canvas_Shade`、
# `SN_Flag_White` / `SN_White`）同一 mesh 的槽位会合并，图元随之减少；只要不增加且
# 不少于网格数即视为合法。
#
# 用法：
#   python tools/modeling/generators/verify_legacy_uv_b_glb.py
#   python tools/modeling/generators/verify_legacy_uv_b_glb.py <单个 GLB>
#
# 通过标准：每件 ALL OK，否则返回非 0 退出码。
# @end-static-doc

import hashlib
import json
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import sn_shared_materials as smat

WORKDIR = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
TEX_URI_PREFIX = "shared_materials/"
SIZE_TOL = 0.05
GROUND_TOL = 0.05

DIRS = {
    "modules": os.path.join(WORKDIR, "assets", "models", "modules"),
    "ships": os.path.join(WORKDIR, "assets", "models", "ships"),
    "town": os.path.join(WORKDIR, "dev_mods", "core", "assets", "models", "props"),
}
CORE_DIRS = {
    "modules": os.path.join(WORKDIR, "dev_mods", "core", "assets", "models", "modules"),
    "ships": os.path.join(WORKDIR, "dev_mods", "core", "assets", "models", "ships"),
    "town": None,   # 旧小镇只存在于 core mod
}

# 资产 -> (类别, 节点数, 网格数, 图元数, tri, 迁移前世界尺寸 (x, y, z), 期望材质集合)
# 注：4 艘船的节点数已包含 M0-3 船侧武器 socket（+4/+4/+3/+3）与 M0-4 船体帆索
# socket（PF +6 / SF +7 / IC +9；PS 无帆索），见 verify_ship_weapon_sockets_glb.py
# 与 sn_ship_rig_sockets.py；网格 / 图元 / tri / 尺寸 / 材质口径不变。
EXPECTED = {
    # modules（12：11 件专用 + modules/SN_Boiler_Unit 占位副本）
    "SN_Boiler_Efficient": ("modules", 1, 1, 4, 540, (1.805, 2.6, 1.6), {"SN_Tex_Brass", "SN_Tex_Iron", "SN_Tex_Metal", "SN_Tex_Wood_Dark"}),
    "SN_Boiler_Performance": ("modules", 1, 1, 4, 1152, (3.4, 2.94, 2.1143), {"SN_Tex_Brass", "SN_Tex_Iron", "SN_Tex_Metal", "SN_Tex_Wood_Dark"}),
    "SN_Boiler_Standard": ("modules", 1, 1, 4, 860, (2.82, 2.62, 1.9), {"SN_Tex_Brass", "SN_Tex_Iron", "SN_Tex_Metal", "SN_Tex_Wood_Dark"}),
    "SN_Boiler_Unit": ("modules", 1, 1, 2, 476, (3.0, 2.5, 2.0), {"SN_Tex_Metal", "SN_Tex_Wood"}),
    "SN_Cabin_Passenger": ("modules", 1, 1, 6, 792, (3.4, 2.55, 2.4), {"SN_Tex_Brass", "SN_Tex_Iron", "SN_Tex_Metal", "SN_Tex_Wood", "SN_Tex_Wood_Dark", "SN_Tex_Wood_Deck"}),
    "SN_Cargo_Large_Hold": ("modules", 1, 1, 4, 672, (4.006, 2.6, 2.81), {"SN_Tex_Brass", "SN_Tex_Metal", "SN_Tex_Wood", "SN_Tex_Wood_Dark"}),
    "SN_Cargo_Medium_Hold": ("modules", 1, 1, 4, 492, (3.2, 2.2, 2.4), {"SN_Tex_Brass", "SN_Tex_Metal", "SN_Tex_Wood", "SN_Tex_Wood_Dark"}),
    "SN_Cargo_Small_Hold": ("modules", 1, 1, 4, 456, (2.4, 1.8, 2.0), {"SN_Tex_Brass", "SN_Tex_Metal", "SN_Tex_Wood", "SN_Tex_Wood_Dark"}),
    "SN_Nav_Chart_Room": ("modules", 1, 1, 5, 636, (2.8, 2.6, 2.2), {"SN_Tex_Brass", "SN_Tex_Iron", "SN_Tex_Metal", "SN_Tex_Wood", "SN_Tex_Wood_Dark"}),
    "SN_Nav_Spyglass": ("modules", 1, 1, 4, 328, (1.38, 1.75, 0.8), {"SN_Tex_Brass", "SN_Tex_Metal", "SN_Tex_Wood", "SN_Tex_Wood_Dark"}),
    "SN_Safety_Lifeboat": ("modules", 1, 1, 4, 660, (4.2, 1.1, 1.5), {"SN_Tex_Brass", "SN_Tex_Canvas_Shade", "SN_Tex_Wood", "SN_Tex_Wood_Dark"}),
    "SN_Safety_Valve": ("modules", 1, 1, 3, 428, (1.4881, 1.84, 1.256), {"SN_Tex_Brass", "SN_Tex_Iron", "SN_Tex_Metal"}),
    # ships（4）
    "SN_Ironclad": ("ships", 14, 1, 8, 8830, (60.1346, 28.64, 18.0), {"SN_Tex_Brass", "SN_Tex_Canvas_Shade", "SN_Tex_Iron", "SN_Tex_Iron_Red", "SN_Tex_Metal", "SN_Tex_Wood", "SN_Tex_Wood_Dark", "SN_Tex_Wood_Deck"}),
    "SN_Paddle_Freighter": ("ships", 56, 39, 95, 12200, (59.5276, 19.52, 14.1), {"SN_Tex_Brass", "SN_Tex_Iron", "SN_Tex_Iron_Red", "SN_Tex_Metal", "SN_Tex_Wood", "SN_Tex_Wood_Deck"}),
    "SN_Paddle_Steamer": ("ships", 38, 32, 90, 11764, (24.56, 10.47, 8.74), {"SN_Tex_Brass", "SN_Tex_Canvas_Shade", "SN_Tex_Glass_Dark", "SN_Tex_Iron", "SN_Tex_Iron_Red", "SN_Tex_Metal", "SN_Tex_Wood_Deck"}),
    "SN_Schooner_Fame": ("ships", 42, 29, 73, 13174, (33.4411, 26.8191, 6.88), {"SN_Tex_Brass", "SN_Tex_Canvas_Shade", "SN_Tex_Glass_Dark", "SN_Tex_Iron", "SN_Tex_Iron_Red", "SN_Tex_Metal", "SN_Tex_Wood", "SN_Tex_Wood_Dark", "SN_Tex_Wood_Deck"}),
    # town（5 件剩余旧纯色道具；5 栋旧小镇建筑已由建筑套件批次迁移，不在本表）
    "SN_HT_Cargo_Lighter": ("town", 1, 1, 7, 616, (8.0, 1.6, 3.0), {"SN_Tex_Brass", "SN_Tex_Canvas_Shade", "SN_Tex_Iron", "SN_Tex_Metal", "SN_Tex_Wood", "SN_Tex_Wood_Dark", "SN_Tex_Wood_Deck"}),
    "SN_HT_Dock_Worker_A": ("town", 1, 1, 3, 192, (0.62, 1.8, 0.494), {"SN_Tex_Canvas_Shade", "SN_Tex_Metal", "SN_Tex_Wood_Dark"}),
    "SN_HT_Dock_Worker_B": ("town", 1, 1, 4, 228, (0.74, 1.8, 0.5), {"SN_Tex_Canvas_Shade", "SN_Tex_Metal", "SN_Tex_Wood", "SN_Tex_Wood_Dark"}),
    "SN_HT_Fence_Row": ("town", 1, 1, 2, 264, (6.0, 1.5, 0.3), {"SN_Tex_Iron", "SN_Tex_Stone"}),
    "SN_HT_Rowboat": ("town", 1, 1, 4, 496, (4.2, 0.8, 1.5), {"SN_Tex_Iron", "SN_Tex_Wood", "SN_Tex_Wood_Dark", "SN_Tex_Wood_Deck"}),
}

TILE_SHA = {}


def _sha_file(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _tile_sha():
    if not TILE_SHA:
        for name, report in smat.texture_report().items():
            TILE_SHA[report["texture"]] = _sha_file(os.path.join(WORKDIR, report["file"]))
    return TILE_SHA


def load_glb(path):
    with open(path, "rb") as fh:
        data = fh.read()
    magic, _version, length = struct.unpack_from("<III", data, 0)
    if magic != 0x46546C67:
        raise ValueError("%s 不是 GLB" % path)
    offset, gltf = 12, None
    while offset < length:
        clen, ctype = struct.unpack_from("<II", data, offset)
        payload = data[offset + 8: offset + 8 + clen]
        if ctype == 0x4E4F534A:
            gltf = json.loads(payload.decode("utf-8"))
        offset += 8 + clen
    if gltf is None:
        raise ValueError("%s 缺少 JSON chunk" % path)
    return gltf


def _mat_mul(a, b):
    out = [0.0] * 16
    for row in range(4):
        for col in range(4):
            out[row * 4 + col] = sum(a[row * 4 + k] * b[k * 4 + col]
                                     for k in range(4))
    return out


def _identity():
    return [1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0,
            0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0]


def _node_matrix(node):
    if "matrix" in node:
        m = node["matrix"]
        return [m[col * 4 + row] for row in range(4) for col in range(4)]
    t = node.get("translation", [0.0, 0.0, 0.0])
    q = node.get("rotation", [0.0, 0.0, 0.0, 1.0])
    s = node.get("scale", [1.0, 1.0, 1.0])
    x, y, z, w = q
    qm = [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w), 0.0,
          2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w), 0.0,
          2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y), 0.0,
          0.0, 0.0, 0.0, 1.0]
    tm = _identity()
    tm[3], tm[7], tm[11] = t
    sm = _identity()
    sm[0], sm[5], sm[10] = s
    return _mat_mul(tm, _mat_mul(qm, sm))


def _transform(m, p):
    return [m[0] * p[0] + m[1] * p[1] + m[2] * p[2] + m[3],
            m[4] * p[0] + m[5] * p[1] + m[6] * p[2] + m[7],
            m[8] * p[0] + m[9] * p[1] + m[10] * p[2] + m[11]]


def gltf_stats(path):
    gltf = load_glb(path)
    accessors = gltf.get("accessors", [])
    meshes = gltf.get("meshes", [])
    nodes = gltf.get("nodes", [])
    materials = gltf.get("materials", [])
    prims = tris = prims_without_uv = 0
    uv_counts = []
    for mesh in meshes:
        for prim in mesh.get("primitives", []):
            prims += 1
            attrs = prim.get("attributes", {})
            pos_count = accessors[attrs["POSITION"]]["count"]
            count = (accessors[prim["indices"]]["count"]
                     if "indices" in prim else pos_count)
            tris += count // 3
            if "TEXCOORD_0" not in attrs:
                prims_without_uv += 1
                continue
            uv_counts.append((pos_count, accessors[attrs["TEXCOORD_0"]]["count"]))
    lo = [float("inf")] * 3
    hi = [float("-inf")] * 3

    def include(mesh_index, world):
        for prim in meshes[mesh_index].get("primitives", []):
            pos = prim.get("attributes", {}).get("POSITION")
            if pos is None:
                continue
            acc = accessors[pos]
            for x in (acc.get("min", [0, 0, 0])[0], acc.get("max", [0, 0, 0])[0]):
                for y in (acc.get("min", [0, 0, 0])[1], acc.get("max", [0, 0, 0])[1]):
                    for z in (acc.get("min", [0, 0, 0])[2], acc.get("max", [0, 0, 0])[2]):
                        p = _transform(world, (x, y, z))
                        for i in range(3):
                            lo[i] = min(lo[i], p[i])
                            hi[i] = max(hi[i], p[i])

    def walk(index, parent):
        node = nodes[index]
        world = _mat_mul(parent, _node_matrix(node))
        if "mesh" in node:
            include(node["mesh"], world)
        for child in node.get("children", []):
            walk(child, world)

    roots = gltf.get("scenes", [{}])[0].get("nodes", []) or list(range(len(nodes)))
    for root in roots:
        walk(root, _identity())

    images = gltf.get("images", [])
    base_dir = os.path.dirname(os.path.abspath(path))
    texture_of_material = {}
    for material in materials:
        pbr = material.get("pbrMetallicRoughness", {})
        texture_index = pbr.get("baseColorTexture", {}).get("index")
        uri = None
        if texture_index is not None:
            source = gltf.get("textures", [])[int(texture_index)].get("source")
            if source is not None:
                uri = images[int(source)].get("uri")
        texture_of_material[material.get("name")] = uri

    return {
        "nodes": len(nodes),
        "meshes": len(meshes),
        "primitives": prims,
        "tris": tris,
        "prims_without_uv": prims_without_uv,
        "uv_counts": uv_counts,
        "materials": [m.get("name", "?") for m in materials],
        "double_sided": all(bool(m.get("doubleSided", False)) for m in materials),
        "has_camera": "cameras" in gltf,
        "size_yup": [round(hi[i] - lo[i], 4) for i in range(3)],
        "bbox_min_yup": [round(v, 4) for v in lo],
        "images": [{"uri": im.get("uri"), "embedded": "uri" not in im,
                    "resolved": (os.path.join(base_dir, im["uri"]) if "uri" in im else None),
                    "name": im.get("name")}
                   for im in images],
        "texture_of_material": texture_of_material,
    }


def check_one(name, path):
    flags = []
    stats = gltf_stats(path)
    category, exp_nodes, exp_meshes, exp_prims, exp_tris, exp_size, exp_mats = EXPECTED[name]
    if stats["nodes"] != exp_nodes:
        flags.append("nodes=%d/%d" % (stats["nodes"], exp_nodes))
    if stats["meshes"] != exp_meshes:
        flags.append("meshes=%d/%d" % (stats["meshes"], exp_meshes))
    if stats["primitives"] > exp_prims:
        flags.append("prims=%d>%d" % (stats["primitives"], exp_prims))
    elif stats["primitives"] < stats["meshes"]:
        flags.append("prims=%d<meshes=%d" % (stats["primitives"], stats["meshes"]))
    if stats["tris"] != exp_tris:
        flags.append("tris=%d/%d" % (stats["tris"], exp_tris))
    for i in range(3):
        if abs(stats["size_yup"][i] - exp_size[i]) > SIZE_TOL:
            flags.append("size[%s]=%.3f!=%.3f" % ("xyz"[i], stats["size_yup"][i],
                                                  exp_size[i]))
    if category != "ships" and abs(stats["bbox_min_yup"][1]) > GROUND_TOL:
        flags.append("groundY=%.3f" % stats["bbox_min_yup"][1])
    actual_mats = set(stats["materials"])
    if actual_mats != exp_mats:
        flags.append("mats missing=%s extra=%s" % (
            sorted(exp_mats - actual_mats), sorted(actual_mats - exp_mats)))
    if stats["prims_without_uv"]:
        flags.append("prims_without_uv=%d" % stats["prims_without_uv"])
    if any(pos != uv for pos, uv in stats["uv_counts"]):
        flags.append("uv_count_mismatch")
    if not stats["double_sided"]:
        flags.append("not-all-doubleSided")
    if stats["has_camera"]:
        flags.append("has-camera")
    if not stats["images"]:
        flags.append("no-images")

    tile_shas = _tile_sha()
    texture_names = smat.texture_names()
    for material, uri in stats["texture_of_material"].items():
        if uri is None:
            flags.append("material-without-texture=%s" % material)
            continue
        expected_texture = texture_names.get(material)
        if expected_texture is None:
            flags.append("unknown-material=%s" % material)
            continue
        if uri != TEX_URI_PREFIX + expected_texture + ".png":
            flags.append("uri[%s]=%s" % (material, uri))
    for image in stats["images"]:
        if image["embedded"]:
            flags.append("embedded-image")
            continue
        if not image["uri"].startswith(TEX_URI_PREFIX):
            flags.append("bad-uri=%s" % image["uri"])
            continue
        if not os.path.isfile(image["resolved"]):
            flags.append("missing-png=%s" % image["uri"])
            continue
        texture = os.path.splitext(os.path.basename(image["uri"]))[0]
        if tile_shas.get(texture) != _sha_file(image["resolved"]):
            flags.append("png-bytes-mismatch=%s" % image["uri"])
    return stats, flags


def _check_core_copy(name, path, category):
    core_dir = CORE_DIRS.get(category)
    if not core_dir:
        return []
    core_path = os.path.join(core_dir, name + ".glb")
    if not os.path.isfile(core_path):
        return ["missing core copy"]
    if _sha_file(path) != _sha_file(core_path):
        return ["core copy differs"]
    return []


def main():
    target = sys.argv[1] if len(sys.argv) > 1 else None
    if target:
        paths = [target]
    else:
        paths = [os.path.join(DIRS[EXPECTED[name][0]], name + ".glb")
                 for name in sorted(EXPECTED)]
    failures = []
    print("%-24s %-8s %5s %5s %5s %6s %-24s %-42s %s" % (
        "glb", "cat", "nodes", "mesh", "prims", "tris", "size(x,y,z)",
        "materials", "flags"))
    print("-" * 160)
    for path in paths:
        name = os.path.splitext(os.path.basename(path))[0]
        if name not in EXPECTED:
            print("[SKIP] %s（不在本次迁移清单）" % name)
            continue
        category = EXPECTED[name][0]
        try:
            stats, flags = check_one(name, path)
        except Exception as exc:  # noqa: BLE001 - verifier must report, not crash
            failures.append((name, ["exception: %s" % exc]))
            print("%-24s EXCEPTION %s" % (name, exc))
            continue
        flags += _check_core_copy(name, path, category)
        if flags:
            failures.append((name, flags))
        print("%-24s %-8s %5d %5d %5d %6d %-24s %-42s %s" % (
            name, category, stats["nodes"], stats["meshes"], stats["primitives"],
            stats["tris"], "%.2f,%.2f,%.2f" % tuple(stats["size_yup"]),
            ",".join(sorted(stats["materials"])),
            ", ".join(flags) if flags else "ok"))
    print("-" * 160)
    print("files = %d, failures = %d" % (len(paths), len(failures)))
    if failures:
        for name, flags in failures:
            print("  FAIL %s: %s" % (name, ", ".join(flags)))
        return 1
    print("ALL LEGACY UV B GLB OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
