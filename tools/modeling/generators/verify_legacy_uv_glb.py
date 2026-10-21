# -*- coding: utf-8 -*-
# @static-doc
# 作用：旧资产 UV 迁移 A 的 GLB 独立验收（纯 Python，不进 Blender/Godot）——
# 核对 37 件道具 / 设施的三角面、图元数、世界尺寸、贴地、材质名、doubleSided，
# 以及「每个图元都有 TEXCOORD_0」「每个材质都引用外部 shared_materials/<texture>.png」
# 「外部 PNG 与授权 tile 逐字节一致」「没有内嵌图片」。
#
# 期望值来自迁移前 GLB 基线（`capture_baseline.py`）：tri 与尺寸必须与迁移前一致，
# 证明这次只改材质与 UV、没有动几何。
#
# 用法：
#   python tools/modeling/generators/verify_legacy_uv_glb.py
#   python tools/modeling/generators/verify_legacy_uv_glb.py <单个 GLB>
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
DIRS = {
    "props": os.path.join(WORKDIR, "assets", "models", "props"),
    "port": os.path.join(WORKDIR, "assets", "models", "port"),
}
TEX_URI_PREFIX = "shared_materials/"
SIZE_TOL = 0.05
GROUND_TOL = 0.05

# 资产 -> (tri, 图元数, 迁移前 GLB 世界尺寸 (x, y, z), 期望材质集合)
EXPECTED = {
    # props（31 件，迁移前 6282 tri）
    "SN_Barrel": (168, 3, (0.9, 1.1, 0.9), {"SN_Tex_Metal", "SN_Tex_Wood", "SN_Tex_Wood_Dark"}),
    "SN_Bell": (176, 1, (0.68, 0.88, 0.5359), {"SN_Tex_Metal"}),
    "SN_Boiler_Unit": (476, 2, (3.0, 2.5, 2.0), {"SN_Tex_Metal", "SN_Tex_Wood"}),
    "SN_Buoy": (260, 2, (1.1413, 1.8, 1.2), {"SN_Tex_Metal", "SN_Tex_Wood_Dark"}),
    "SN_Capstan": (292, 2, (1.2, 1.1, 1.2), {"SN_Tex_Metal", "SN_Tex_Wood"}),
    "SN_Cargo_Net": (248, 2, (3.0, 0.104, 3.0), {"SN_Tex_Canvas_Shade", "SN_Tex_Metal"}),
    "SN_Chain_Coil": (352, 1, (1.0428, 0.266, 0.941), {"SN_Tex_Metal"}),
    "SN_Coal_Chute": (128, 2, (2.5, 1.5, 1.5), {"SN_Tex_Metal", "SN_Tex_Wood_Dark"}),
    "SN_Coal_Pile": (240, 1, (3.0, 1.17, 2.5), {"SN_Tex_Coal"}),
    "SN_Crate": (120, 3, (1.2, 1.2, 1.2), {"SN_Tex_Metal", "SN_Tex_Wood", "SN_Tex_Wood_Dark"}),
    "SN_Dock_Fender": (46, 2, (0.3, 2.5, 0.3), {"SN_Tex_Metal", "SN_Tex_Wood_Dark"}),
    "SN_Dock_Ladder": (156, 1, (0.608, 3.2, 0.275), {"SN_Tex_Metal"}),
    "SN_Dock_Stairs": (120, 2, (3.0, 3.0, 2.0), {"SN_Tex_Stone", "SN_Tex_Wood"}),
    "SN_Dock_Wall": (588, 3, (6.0, 3.5, 3.0), {"SN_Tex_Metal", "SN_Tex_Stone", "SN_Tex_Wood_Dark"}),
    "SN_Fender_Ball": (120, 2, (0.824, 0.9, 0.8), {"SN_Tex_Canvas_Shade", "SN_Tex_Metal"}),
    "SN_Flag_Pole": (116, 2, (1.4243, 6.0, 0.2587), {"SN_Tex_Canvas_Shade", "SN_Tex_Wood"}),
    "SN_Gangway": (252, 2, (6.0, 0.52, 1.2), {"SN_Tex_Metal", "SN_Tex_Wood"}),
    "SN_Gas_Lamp": (194, 2, (0.35, 3.5, 0.3141), {"SN_Tex_Canvas_Shade", "SN_Tex_Metal"}),
    "SN_Gear_Crate": (200, 2, (0.82, 0.818, 0.858), {"SN_Tex_Metal", "SN_Tex_Wood"}),
    "SN_Grab_Bucket": (228, 1, (1.494, 1.46, 1.5), {"SN_Tex_Metal"}),
    "SN_Handcart": (228, 2, (2.02, 1.0, 1.06), {"SN_Tex_Metal", "SN_Tex_Wood"}),
    "SN_Keel_Block": (96, 2, (1.2, 0.6, 0.8114), {"SN_Tex_Metal", "SN_Tex_Wood_Dark"}),
    "SN_Mooring_Bollard": (288, 1, (0.62, 0.7, 0.62), {"SN_Tex_Metal"}),
    "SN_Mooring_Rope": (172, 1, (0.88, 0.44, 0.9), {"SN_Tex_Canvas_Shade"}),
    "SN_Ore_Pile": (150, 1, (4.0, 1.5, 3.0), {"SN_Tex_Iron_Red"}),
    "SN_Pallet": (96, 1, (1.2, 0.135, 1.0), {"SN_Tex_Wood"}),
    "SN_Plate_Stack": (144, 2, (2.994, 0.55, 2.0), {"SN_Tex_Metal", "SN_Tex_Wood_Dark"}),
    "SN_Port_Sign": (120, 2, (2.04, 1.6, 0.25), {"SN_Tex_Metal", "SN_Tex_Wood"}),
    "SN_Sack_Pile": (160, 1, (1.4503, 0.795, 0.95), {"SN_Tex_Canvas_Shade"}),
    "SN_Steam_Pipe": (108, 1, (2.04, 0.414, 0.2679), {"SN_Tex_Metal"}),
    "SN_Timber_Stack": (240, 3, (4.0, 1.222, 1.51), {"SN_Tex_Metal", "SN_Tex_Wood", "SN_Tex_Wood_Dark"}),
    # port（6 件，迁移前 4996 tri）
    "SN_Dry_Dock": (516, 3, (18.0, 2.6, 8.0), {"SN_Tex_Metal", "SN_Tex_Stone", "SN_Tex_Wood_Dark"}),
    "SN_Market_Stall": (768, 5, (5.0, 3.2, 3.0), {"SN_Tex_Brass", "SN_Tex_Canvas_Shade", "SN_Tex_Metal", "SN_Tex_Wood", "SN_Tex_Wood_Dark"}),
    "SN_Notice_Board": (272, 4, (2.8, 2.6, 0.5), {"SN_Tex_Canvas_Shade", "SN_Tex_Metal", "SN_Tex_Wood", "SN_Tex_Wood_Dark"}),
    "SN_Shipyard_Gantry": (1064, 4, (14.0, 10.0, 4.0139), {"SN_Tex_Brass", "SN_Tex_Iron", "SN_Tex_Metal", "SN_Tex_Wood_Dark"}),
    "SN_Signal_Tower": (1052, 5, (3.2, 8.5, 2.4), {"SN_Tex_Brass", "SN_Tex_Canvas_Shade", "SN_Tex_Iron", "SN_Tex_Metal", "SN_Tex_Wood_Dark"}),
    "SN_Water_Tank": (1324, 4, (4.0, 5.2, 4.0), {"SN_Tex_Brass", "SN_Tex_Iron", "SN_Tex_Metal", "SN_Tex_Stone"}),
}
PORT_TARGETS = {
    "SN_Dry_Dock", "SN_Market_Stall", "SN_Notice_Board",
    "SN_Shipyard_Gantry", "SN_Signal_Tower", "SN_Water_Tank",
}
CATEGORY_OF = {name: ("port" if name in PORT_TARGETS else "props")
               for name in EXPECTED}

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


# ---------------------------------------------------------------- GLB 解析

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
            out[row * 4 + col] = sum(a[row * 4 + k] * b[k * 4 + col] for k in range(4))
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
    prims = 0
    tris = 0
    prims_without_uv = 0
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
    material_textures = []
    texture_of_material = {}
    for material in materials:
        pbr = material.get("pbrMetallicRoughness", {})
        texture_index = pbr.get("baseColorTexture", {}).get("index")
        uri = None
        if texture_index is not None:
            source = gltf.get("textures", [])[int(texture_index)].get("source")
            if source is not None:
                uri = images[int(source)].get("uri")
        material_textures.append(uri)
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
        "material_uris": material_textures,
        "texture_of_material": texture_of_material,
    }


def check_one(name, path):
    flags = []
    stats = gltf_stats(path)
    exp_tris, exp_prims, exp_size, exp_mats = EXPECTED[name]
    if stats["nodes"] != 1:
        flags.append("nodes=%d" % stats["nodes"])
    if stats["meshes"] != 1:
        flags.append("meshes=%d" % stats["meshes"])
    if stats["primitives"] != exp_prims:
        flags.append("prims=%d/%d" % (stats["primitives"], exp_prims))
    if stats["tris"] != exp_tris:
        flags.append("tris=%d/%d" % (stats["tris"], exp_tris))
    for i in range(3):
        if abs(stats["size_yup"][i] - exp_size[i]) > SIZE_TOL:
            flags.append("size[%s]=%.3f!=%.3f" % ("xyz"[i], stats["size_yup"][i],
                                                  exp_size[i]))
    if abs(stats["bbox_min_yup"][1]) > GROUND_TOL:
        flags.append("groundY=%.3f" % stats["bbox_min_yup"][1])
    actual_mats = set(stats["materials"])
    if actual_mats != exp_mats:
        missing = sorted(exp_mats - actual_mats)
        extra = sorted(actual_mats - exp_mats)
        flags.append("mats missing=%s extra=%s" % (missing, extra))
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


def main():
    target = sys.argv[1] if len(sys.argv) > 1 else None
    if target:
        paths = [target]
    else:
        paths = [os.path.join(DIRS[CATEGORY_OF[name]], name + ".glb")
                 for name in sorted(EXPECTED)]
    failures = []
    print("%-22s %-6s %5s %5s %6s %-24s %-34s %s" % (
        "glb", "cat", "mesh", "prims", "tris", "size(x,y,z)",
        "materials", "flags"))
    print("-" * 150)
    for path in paths:
        name = os.path.splitext(os.path.basename(path))[0]
        if name not in EXPECTED:
            print("[SKIP] %s（不在本次迁移清单）" % name)
            continue
        try:
            stats, flags = check_one(name, path)
        except Exception as exc:  # noqa: BLE001 - verifier must report, not crash
            failures.append((name, ["exception: %s" % exc]))
            print("%-22s EXCEPTION %s" % (name, exc))
            continue
        if flags:
            failures.append((name, flags))
        print("%-22s %-6s %5d %5d %6d %-24s %-34s %s" % (
            name, CATEGORY_OF[name], stats["meshes"], stats["primitives"],
            stats["tris"], "%.2f,%.2f,%.2f" % tuple(stats["size_yup"]),
            ",".join(sorted(stats["materials"])),
            ", ".join(flags) if flags else "ok"))
    print("-" * 150)
    print("files = %d, failures = %d" % (len(paths), len(failures)))
    if failures:
        for name, flags in failures:
            print("  FAIL %s: %s" % (name, ", ".join(flags)))
        return 1
    print("ALL LEGACY UV GLB OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
