# -*- coding: utf-8 -*-
# @static-doc
# 作用：`rig_kit` 独立套件（12 件 `SN_Rig_*`）的 GLB 接口节点归一化（纯 Python）——
# BLEND 内为避免工作台重名用 `SN_Rig_Mast_Sail_Socket_Yard_Lower` 这类带前缀名，
# 导出后统一归一化为契约标准名 `SN_Mount` / `SN_Socket_Mast|Yard|Sail_*`，
# 并把 socket 名单写进 Root extras（`rig_sockets` / `rig_socket_count` /
# `rig_socket_spec`）。Blender IDProperty 不支持字符串数组，所以名单只能在 GLB
# JSON 层写，做法与 `glb_ship_sockets.py` / `glb_weapon_nodes.py` 一致。
#
# 用法：`glb_rig_kit.standardize(path, asset)`，在贴图外部化之后调用。
# @end-static-doc

import json
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import rig_kit_batch1_generator as gen

_MAGIC = 0x46546C67
_JSON = 0x4E4F534A

ROLE_PREFIXES = ("SN_Socket_Mast", "SN_Socket_Yard", "SN_Socket_Sail",
                 "SN_Socket_", "SN_Mount")


def _read_glb(path):
    data = open(path, "rb").read()
    magic, version, length = struct.unpack("<III", data[:12])
    if magic != _MAGIC:
        raise RuntimeError("%s: not a GLB" % path)
    offset = 12
    chunks = []
    while offset < length:
        chunk_length, chunk_type = struct.unpack("<II", data[offset:offset + 8])
        chunks.append((chunk_type, data[offset + 8: offset + 8 + chunk_length]))
        offset += 8 + chunk_length
    return version, chunks


def _write_glb(path, version, chunks):
    out = bytearray()
    body = bytearray()
    for chunk_type, payload in chunks:
        pad = (-len(payload)) % 4
        if chunk_type == _JSON:
            payload = payload + b" " * pad
        else:
            payload = payload + b"\x00" * pad
        body += struct.pack("<II", len(payload), chunk_type) + payload
    out += struct.pack("<III", _MAGIC, version, 12 + len(body)) + body
    tmp = path + ".tmp"
    with open(tmp, "wb") as handle:
        handle.write(out)
    os.replace(tmp, path)


def _glb_name(blend_name, prefix):
    suffix = blend_name[len(prefix):]
    return "SN_Mount" if suffix == "Mount" else "SN_" + suffix


def standardize(path, asset):
    """归一化套件接口节点名 + 写 Root extras；返回报告 dict。"""
    spec = gen.SPECS[asset]
    prefix = spec["prefix"]
    root_name = prefix + "Root"
    expected = gen.socket_roles(asset)
    entries = gen.socket_entries(asset)
    version, chunks = _read_glb(path)
    out_chunks = []
    report = {"asset": asset, "glb": path, "root": root_name,
              "sockets": expected, "renamed": 0, "failures": []}
    for chunk_type, payload in chunks:
        if chunk_type != _JSON:
            out_chunks.append((chunk_type, payload))
            continue
        gltf = json.loads(payload.decode("utf-8"))
        nodes = gltf.get("nodes", [])
        by_blend = {node.get("name", ""): node for node in nodes}
        renamed = 0
        for entry in entries:
            node = by_blend.get(entry["name"])
            if node is None:
                report["failures"].append("缺少接口节点 %s" % entry["name"])
                continue
            node["name"] = entry["glb"]
            renamed += 1
            extras = node.setdefault("extras", {})
            extras["socket_spec"] = "rig-sockets@1"
            extras["socket_role"] = ("mount" if entry["glb"] == "SN_Mount"
                                     else entry["glb"][len("SN_Socket_"):].lower())
        names = {}
        for index, node in enumerate(nodes):
            name = node.get("name", "")
            if name in names:
                report["failures"].append("节点重名 %s" % name)
            names[name] = index
            if name.startswith("SN_Socket_") or name == "SN_Mount":
                if "mesh" in node:
                    report["failures"].append("%s 带 mesh（应为空节点）" % name)
        for name in expected:
            if name not in names:
                report["failures"].append("缺少 socket 节点 %s" % name)
        for name in names:
            if name.startswith(("SN_Socket_", "SN_Mount")) and name not in expected:
                report["failures"].append("规格外接口节点 %s" % name)
        root_index = names.get(root_name)
        if root_index is None:
            report["failures"].append("找不到 Root 节点 %s" % root_name)
        else:
            root = nodes[root_index]
            extras = root.setdefault("extras", {})
            extras["rig_sockets"] = expected
            extras["rig_socket_count"] = len(expected)
            extras["rig_socket_spec"] = "rig-sockets@1"
        report["renamed"] = renamed
        report["passed"] = not report["failures"]
        if not report["passed"]:
            raise RuntimeError("GLB rig kit 归一化失败 %s: %s"
                               % (asset, "; ".join(report["failures"])))
        out_chunks.append((chunk_type, json.dumps(
            gltf, ensure_ascii=False, separators=(",", ":")).encode("utf-8")))
    _write_glb(path, version, out_chunks)
    return report


if __name__ == "__main__":
    print(json.dumps(standardize(sys.argv[1], sys.argv[2]),
                     ensure_ascii=False, indent=1))
