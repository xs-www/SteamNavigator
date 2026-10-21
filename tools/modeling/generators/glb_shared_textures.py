# @static-doc
# 作用：把铁港建筑 GLB 的内嵌 trim-sheet 贴图外部化为稳定共享 URI（`iron_harbor_shared/<cell>.png`）并压缩 BIN chunk，使多栋建筑在 Godot 中共享同一 `Texture2D`；纯 Python（无 bpy），支持 dry-run / GLB 结构报告。
#
# ## 契约与约束
# - 只把 `images[].bufferView` 的内嵌图改成 `images[].uri`；保留 image 顺序，因此 `textures[].source` 与材质索引不动。
# - 共享 PNG 必须与手写源 `docs/design/textures/iron_harbor/tiles/<cell>.png` 逐字节一致（`tile_matches`）；不一致时写出实际导出的字节并在报告里标 false，不静默换皮肤。
# - 重写 BIN 时只保留被 accessor 引用的 bufferView，按 4 字节对齐重建并重映射 accessor 索引；`buffers[0].byteLength` 取新 BIN 长度。
# - 输出 GLB 保持 spec 对齐（JSON chunk 空格补齐、BIN chunk 0 补齐、header 总长自洽）。
# - 外部 PNG 放在 GLB 同目录子目录（`iron_harbor_shared/`），相对 URI 不使用 `..`，松散目录与挂载 ZIP 内路径都成立。
# - 不修改内容清单 / manifest / 运行时接线；接线由 Lead 在验收后执行。
#
# ## 重点逻辑
# ### `externalize_glb(src, dst)`
# - 提取每张内嵌图的字节 → 按 image name 归一 cell → 写共享 PNG → 改 URI → 去掉 image bufferView → 压缩 BIN 重写；返回逐图字节/tile 一致性/前后体积。
# ### `structure_report(path)`
# - 只读解析节点/材质/贴图 URI/tri/glTF 与 Godot 两套包围盒（glTF Y-up ↔ Godot Z-up 映射），供结构验收与 LOD0/LOD1 对账。
# @end-static-doc

# -*- coding: utf-8 -*-
"""Externalize the shared iron-harbor trim textures out of the building GLBs.

Role
----
Turns a single-file building GLB (Blender glTF export with 5-6 embedded 512x512
PNG tiles) into the *shared-texture* GLB variant: every embedded image becomes a
stable external URI (``iron_harbor_shared/<cell>.png``) inside the content mod,
the BIN chunk is compacted so the image bytes are no longer duplicated per
building, and the shared PNG files are written once for the whole kit.

Why
---
Each of the five `SN_HT_*` buildings embeds its own copy of the same trim-sheet
tiles.  Godot's runtime GLB loader (`GLTFDocument.append_from_file`) builds one
`ImageTexture` per embedded image, so the five copies are five distinct
Texture2D instances: `PortStage._material_signature()` includes the albedo
texture instance id, the static batcher therefore cannot fold the buildings
together, and draw calls grow by ~20 (71 -> 91 measured in batch B).

Keeping the GLB container is deliberate: `PathGuard.ASSET_EXTENSIONS` only
allows ``.glb`` (plus png/webp/svg/ogg/wav) inside a content mod, so the
``.gltf + .bin + shared png`` variant is structurally rejected by the mod
scanner.  A GLB may legally reference external image URIs, which keeps the
archive self-contained at the mod level (the PNGs ship in the same
``.snavmod.zip``) while making the runtime texture instance shareable.

What the rewrite does
---------------------
1. parse the GLB header, JSON chunk and BIN chunk (pure Python, no bpy);
2. collect every embedded image's byte range, write the shared PNG once
   (byte-identical to the authored tile under
   ``docs/design/textures/iron_harbor/tiles/``; a mismatch is reported instead
   of silently shipping a different surface), and replace the image entry with
   ``{"name": <cell>, "uri": "<uri_prefix>/<cell>.png"}``;
3. drop the image bufferViews and rebuild the BIN chunk from the bufferViews
   the accessors actually use (4-byte aligned), remapping every accessor;
4. write a new GLB whose JSON/BIN chunks keep the glTF alignment rules and whose
   BIN chunk no longer contains PNG bytes.

Run
---
    python tools/modeling/generators/glb_shared_textures.py \
        --assets SN_HT_Warehouse_Long SN_HT_Warehouse_Short \
        --report .design/buildings/iron_harbor/shared_textures_report.json

Use ``--dry-run`` to only report the projected size; ``--structure`` to dump a
one-GLB structure report (nodes / meshes / triangles / materials / images / bbox)
without rewriting anything.  Everything is plain Python so it can run in CI or
inside Blender's bundled interpreter.
"""

import hashlib
import json
import os
import struct
import sys

GLB_MAGIC = 0x46546C67
CHUNK_JSON = 0x4E4F534A
CHUNK_BIN = 0x004E4942

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
CONTENT_PROPS = os.path.join(REPO_ROOT, "dev_mods", "core", "assets", "models", "props")
TILES_DIR = os.path.join(REPO_ROOT, "docs", "design", "textures", "iron_harbor", "tiles")
SHARED_DIR = os.path.join(CONTENT_PROPS, "iron_harbor_shared")
DEFAULT_URI_PREFIX = "iron_harbor_shared"
BUILDINGS = [
    "SN_HT_Warehouse_Long",
    "SN_HT_Warehouse_Short",
    "SN_HT_Harbor_Office",
    "SN_HT_Cargo_Shed",
    "SN_HT_Tavern",
]


# --------------------------------------------------------------------------- #
# GLB container helpers
# --------------------------------------------------------------------------- #

def read_glb(path):
    """Return ``(json_dict, bin_bytes)`` for a binary glTF file."""
    with open(path, "rb") as handle:
        data = handle.read()
    magic, version, length = struct.unpack_from("<III", data, 0)
    if magic != GLB_MAGIC:
        raise ValueError("%s is not a GLB (bad magic)" % path)
    if version != 2:
        raise ValueError("%s: unsupported GLB version %d" % (path, version))
    if length != len(data):
        raise ValueError("%s: GLB header length %d != file size %d" % (path, length, len(data)))
    offset = 12
    json_chunk = None
    bin_chunk = b""
    while offset + 8 <= length:
        chunk_length, chunk_type = struct.unpack_from("<II", data, offset)
        offset += 8
        chunk = data[offset:offset + chunk_length]
        offset += chunk_length
        if chunk_type == CHUNK_JSON:
            json_chunk = chunk
        elif chunk_type == CHUNK_BIN:
            bin_chunk = chunk
    if json_chunk is None:
        raise ValueError("%s: no JSON chunk" % path)
    document = json.loads(json_chunk.decode("utf-8").rstrip("\x00 "))
    return document, bin_chunk


def write_glb(path, document, bin_chunk):
    """Serialize ``document`` + BIN chunk into a spec-compliant GLB."""
    json_bytes = json.dumps(document, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    json_bytes += b" " * ((4 - len(json_bytes) % 4) % 4)
    bin_bytes = bytearray(bin_chunk)
    while len(bin_bytes) % 4:
        bin_bytes.append(0)
    total = 12 + 8 + len(json_bytes)
    if bin_bytes:
        total += 8 + len(bin_bytes)
    out = bytearray()
    out += struct.pack("<III", GLB_MAGIC, 2, total)
    out += struct.pack("<II", len(json_bytes), CHUNK_JSON)
    out += json_bytes
    if bin_bytes:
        out += struct.pack("<II", len(bin_bytes), CHUNK_BIN)
        out += bytes(bin_bytes)
    directory = os.path.dirname(os.path.abspath(path))
    if directory:
        os.makedirs(directory, exist_ok=True)
    with open(path, "wb") as handle:
        handle.write(bytes(out))
    return total


def sha256_bytes(payload):
    return hashlib.sha256(payload).hexdigest()


def sha256_file(path):
    if not os.path.exists(path):
        return None
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


# --------------------------------------------------------------------------- #
# Image / bufferView extraction
# --------------------------------------------------------------------------- #

def _buffer_view_bytes(document, bin_chunk, index):
    view = document["bufferViews"][index]
    start = int(view.get("byteOffset", 0))
    return bin_chunk[start:start + int(view["byteLength"])]


def _used_buffer_views(document):
    used = set()
    for accessor in document.get("accessors", []):
        if "bufferView" in accessor:
            used.add(int(accessor["bufferView"]))
    return used


def _image_cell_name(document, image, payload):
    """Best-effort cell id for an embedded image.

    Blender names the image after the tile file stem (``brick_wall``); older
    exports may carry the ``SN_TEX_`` prefix.  If neither is present, fall back
    to matching the payload hash against the authored tiles.
    """
    name = str(image.get("name") or "").strip()
    if name.startswith("SN_TEX_"):
        name = name[len("SN_TEX_"):]
    if name and os.path.exists(os.path.join(TILES_DIR, name + ".png")):
        return name
    payload_hash = sha256_bytes(payload)
    for file_name in sorted(os.listdir(TILES_DIR)) if os.path.isdir(TILES_DIR) else []:
        if not file_name.endswith(".png"):
            continue
        path = os.path.join(TILES_DIR, file_name)
        if sha256_file(path) == payload_hash:
            return file_name[:-4]
    return name or ("image_" + payload_hash[:12])


# --------------------------------------------------------------------------- #
# Rewrite
# --------------------------------------------------------------------------- #

def externalize_glb(src, dst, shared_dir=SHARED_DIR, uri_prefix=DEFAULT_URI_PREFIX,
                    tiles_dir=TILES_DIR, write_pngs=True, prefer_authored=False):
    """Rewrite ``src`` so its embedded images become shared external URIs.

    ``prefer_authored=True`` ships the authored tile bytes (from ``tiles_dir``)
    instead of the bytes re-encoded by the exporter, so a shared PNG stays
    byte-identical to the source texture even when Blender re-encodes it.

    Returns a report dict; writes ``dst`` (may equal ``src`` for an in-place
    rewrite) and the shared PNGs once.
    """
    document, bin_chunk = read_glb(src)
    size_before = os.path.getsize(src)
    images = document.get("images", [])
    if not images:
        return {"ok": True, "src": src, "dst": dst, "images": [],
                "note": "no images", "bytes_before": size_before,
                "bytes_after": size_before}

    used_before = _used_buffer_views(document)
    external = []
    shared_files = {}
    png_reports = []
    for index, image in enumerate(images):
        if "uri" in image:
            external.append({"index": index, "name": image.get("name"),
                             "uri": image["uri"], "already_external": True})
            continue
        view_index = int(image["bufferView"])
        payload = _buffer_view_bytes(document, bin_chunk, view_index)
        cell = _image_cell_name(document, image, payload)
        png_name = cell + ".png"
        png_path = os.path.join(shared_dir, png_name)
        tile_path = os.path.join(tiles_dir, png_name)
        payload_hash = sha256_bytes(payload)
        tile_hash = sha256_file(tile_path)
        shipped = payload
        authored = False
        if prefer_authored and os.path.isfile(tile_path):
            with open(tile_path, "rb") as handle:
                shipped = handle.read()
            authored = True
        shipped_hash = sha256_bytes(shipped)
        if write_pngs:
            os.makedirs(shared_dir, exist_ok=True)
            if sha256_file(png_path) != shipped_hash:
                with open(png_path, "wb") as handle:
                    handle.write(shipped)
        png_reports.append({
            "cell": cell,
            "png": os.path.relpath(png_path, REPO_ROOT),
            "bytes": len(shipped),
            "sha256": shipped_hash,
            "exported_sha256": payload_hash,
            "tile_matches": tile_hash == payload_hash,
            "authored": authored,
            "written": write_pngs,
        })
        shared_files[cell] = png_path
        uri = uri_prefix.rstrip("/") + "/" + png_name if uri_prefix else png_name
        image.clear()
        image.update({"name": cell, "uri": uri})
        external.append({"index": index, "name": cell, "uri": uri,
                         "already_external": False, "buffer_view": view_index,
                         "bytes": len(payload), "sha256": payload_hash,
                         "tile_matches": tile_hash == payload_hash,
                         "authored": authored})

    # Rebuild the BIN chunk from the bufferViews the accessors actually use.
    remap = {}
    new_views = []
    new_bin = bytearray()
    for old_index in sorted(used_before):
        view = dict(document["bufferViews"][old_index])
        view["buffer"] = 0
        payload = _buffer_view_bytes(document, bin_chunk, old_index)
        while len(new_bin) % 4:
            new_bin.append(0)
        view["byteOffset"] = len(new_bin)
        new_bin.extend(payload)
        remap[old_index] = len(new_views)
        new_views.append(view)
    document["bufferViews"] = new_views
    for accessor in document.get("accessors", []):
        if "bufferView" in accessor:
            accessor["bufferView"] = remap[int(accessor["bufferView"])]
    document["buffers"] = [{"byteLength": len(new_bin)}] if new_bin else []
    bytes_after = write_glb(dst, document, bytes(new_bin))
    return {
        "ok": True,
        "src": os.path.relpath(src, REPO_ROOT),
        "dst": os.path.relpath(dst, REPO_ROOT),
        "bytes_before": size_before,
        "bytes_after": bytes_after,
        "bytes_saved": size_before - bytes_after,
        "images": external,
        "pngs": png_reports,
        "buffer_views_before": len(document.get("bufferViews", [])),
        "shared_png_count": len(shared_files),
    }


# --------------------------------------------------------------------------- #
# Structure report
# --------------------------------------------------------------------------- #

def gltf_to_godot(point):
    """glTF Y-up -> Godot 4 space.

    Godot 4 is Y-up like glTF, so the runtime importer applies NO axis swap:
    the accessor bbox already is the Godot-space bbox. The helper is kept as a
    named conversion point (and to document the earlier wrong Z-up assumption).
    """
    return [point[0], point[1], point[2]]


def structure_report(path):
    """Read-only structure summary used by the acceptance/verification tools."""
    document, bin_chunk = read_glb(path)
    tris = 0
    primitives = 0
    bbox_min = [float("inf")] * 3
    bbox_max = [float("-inf")] * 3
    accessors = document.get("accessors", [])
    for mesh in document.get("meshes", []):
        for primitive in mesh.get("primitives", []):
            primitives += 1
            indices = primitive.get("indices")
            if indices is not None:
                tris += int(accessors[int(indices)]["count"]) // 3
            position = primitive.get("attributes", {}).get("POSITION")
            if position is not None:
                accessor = accessors[int(position)]
                if "min" in accessor and "max" in accessor:
                    for axis in range(3):
                        bbox_min[axis] = min(bbox_min[axis], float(accessor["min"][axis]))
                        bbox_max[axis] = max(bbox_max[axis], float(accessor["max"][axis]))
    images = []
    for image in document.get("images", []):
        entry = {"name": image.get("name"), "mime": image.get("mimeType")}
        if "uri" in image:
            entry["uri"] = image["uri"]
            resolved = os.path.join(os.path.dirname(os.path.abspath(path)), image["uri"])
            entry["resolved"] = os.path.relpath(resolved, REPO_ROOT)
            entry["exists"] = os.path.exists(resolved)
            entry["bytes"] = os.path.getsize(resolved) if os.path.exists(resolved) else None
            entry["sha256"] = sha256_file(resolved)
        else:
            entry["embedded"] = True
            entry["buffer_view"] = image.get("bufferView")
            view = document["bufferViews"][int(image["bufferView"])]
            start = int(view.get("byteOffset", 0))
            entry["bytes"] = int(view["byteLength"])
            entry["sha256"] = sha256_bytes(bin_chunk[start:start + int(view["byteLength"])])
        images.append(entry)
    materials = []
    for material in document.get("materials", []):
        pbr = material.get("pbrMetallicRoughness", {})
        texture = pbr.get("baseColorTexture", {})
        texture_index = texture.get("index")
        source = None
        if texture_index is not None:
            source = document.get("textures", [])[int(texture_index)].get("source")
        image_uri = None
        if source is not None:
            image_entry = document.get("images", [])[int(source)]
            image_uri = image_entry.get("uri") or ("<embedded:%s>" % image_entry.get("name"))
        materials.append({
            "name": material.get("name"),
            "base_color_texture": texture_index,
            "image": image_uri,
            "metallic": pbr.get("metallicFactor"),
            "roughness": pbr.get("roughnessFactor"),
            "double_sided": bool(material.get("doubleSided")),
        })
    nodes = []
    for node in document.get("nodes", []):
        nodes.append({
            "name": node.get("name"),
            "mesh": node.get("mesh"),
            "translation": node.get("translation"),
            "rotation": node.get("rotation"),
            "scale": node.get("scale"),
            "children": node.get("children"),
        })
    bbox = None
    if bbox_min[0] <= bbox_max[0]:
        bbox = {
            "gltf_min": [round(v, 5) for v in bbox_min],
            "gltf_max": [round(v, 5) for v in bbox_max],
            "gltf_size": [round(bbox_max[i] - bbox_min[i], 5) for i in range(3)],
            "godot_min": [round(v, 5) for v in gltf_to_godot(bbox_min)],
            "godot_max": [round(v, 5) for v in gltf_to_godot(bbox_max)],
            "godot_size": [round(bbox_max[i] - bbox_min[i], 5) for i in range(3)],
        }
    return {
        "path": os.path.relpath(path, REPO_ROOT),
        "bytes": os.path.getsize(path),
        "nodes": nodes,
        "meshes": len(document.get("meshes", [])),
        "primitives": primitives,
        "tris": tris,
        "materials": materials,
        "images": images,
        "buffer_bytes": int(document.get("buffers", [{}])[0].get("byteLength", 0)) if document.get("buffers") else 0,
        "bbox": bbox,
        "sha256": sha256_file(path),
    }


# --------------------------------------------------------------------------- #
# CLI
# --------------------------------------------------------------------------- #

def _report(asset_reports, extra=None, shared_dir=SHARED_DIR, uri_prefix=DEFAULT_URI_PREFIX):
    payload = {
        "assets": asset_reports,
        "shared_dir": os.path.relpath(shared_dir, REPO_ROOT),
        "uri_prefix": uri_prefix,
        "tiles_dir": os.path.relpath(TILES_DIR, REPO_ROOT),
        "all_tiles_match": all(
            png["tile_matches"]
            for report in asset_reports.values()
            for png in report.get("pngs", [])
        ),
    }
    if extra:
        payload.update(extra)
    return payload


def main(argv):
    assets = list(BUILDINGS)
    dry_run = False
    structure = False
    report_path = None
    assets_dir = CONTENT_PROPS
    out_dir = None
    shared_dir = SHARED_DIR
    uri_prefix = DEFAULT_URI_PREFIX
    index = 1
    while index < len(argv):
        argument = argv[index]
        if argument == "--assets":
            assets = []
            index += 1
            while index < len(argv) and not argv[index].startswith("--"):
                assets.append(argv[index])
                index += 1
            continue
        if argument == "--dry-run":
            dry_run = True
        elif argument == "--structure":
            structure = True
        elif argument == "--assets-dir":
            index += 1
            assets_dir = os.path.abspath(argv[index])
        elif argument == "--out-dir":
            index += 1
            out_dir = os.path.abspath(argv[index])
        elif argument == "--shared-dir":
            index += 1
            shared_dir = os.path.abspath(argv[index])
        elif argument == "--uri-prefix":
            index += 1
            uri_prefix = argv[index].strip("/")
        elif argument == "--report":
            index += 1
            report_path = os.path.abspath(argv[index])
        else:
            raise SystemExit("unknown argument: %s" % argument)
        index += 1

    if structure:
        reports = {asset: structure_report(os.path.join(assets_dir, asset + ".glb")) for asset in assets}
        print(json.dumps(reports, indent=2, ensure_ascii=False))
        return 0

    if dry_run:
        reports = {}
        for asset in assets:
            path = os.path.join(assets_dir, asset + ".glb")
            document, bin_chunk = read_glb(path)
            image_bytes = 0
            for image in document.get("images", []):
                image_bytes += int(document["bufferViews"][int(image["bufferView"])]["byteLength"])
            reports[asset] = {
                "bytes_before": os.path.getsize(path),
                "embedded_image_bytes": image_bytes,
                "projected_bytes": os.path.getsize(path) - image_bytes,
                "image_count": len(document.get("images", [])),
            }
        print(json.dumps(_report(reports, {"dry_run": True}), indent=2, ensure_ascii=False))
        return 0

    reports = {}
    for asset in assets:
        path = os.path.join(assets_dir, asset + ".glb")
        dst = path if out_dir is None else os.path.join(out_dir, asset + ".glb")
        reports[asset] = externalize_glb(path, dst, shared_dir=shared_dir, uri_prefix=uri_prefix)
    payload = _report(reports, shared_dir=shared_dir, uri_prefix=uri_prefix)
    if report_path:
        os.makedirs(os.path.dirname(os.path.abspath(report_path)), exist_ok=True)
        with open(report_path, "w", encoding="utf-8") as handle:
            json.dump(payload, handle, indent=2, ensure_ascii=False)
    print(json.dumps(payload, indent=2, ensure_ascii=False))
    return 0 if payload["all_tiles_match"] else 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
