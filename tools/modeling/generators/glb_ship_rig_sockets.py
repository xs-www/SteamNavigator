# -*- coding: utf-8 -*-
# @static-doc
# 作用：M0-4 船体帆索 socket 的 GLB 后处理（纯 Python）——把 BLEND 内带资产前缀的
# `SN_PF_Socket_Mast_Fore` / `SN_SF_Socket_Yard_Main` / `SN_IC_Socket_Mast_Fore`
# 归一化为契约标准名 `SN_Socket_Mast|Yard|Sail_*`，并把名单作为 `rig_sockets`
# 数组写进船体 Root 节点的 extras。
#
# 只处理 Mast/Yard/Sail 三类节点：M0-3 武器 socket（`SN_Socket_Weapon_*`）与船体
# 既有通用 socket（`SN_Socket_Engine/Cabin/...`）原样保留。为什么需要后处理：
# 3 艘船并排在同一工作台，标准名会撞 Blender 全局命名空间（静默加 `.001`）；
# Blender IDProperty 也不支持字符串数组，所以名单只能在 GLB JSON 层写入
# （与 `glb_ship_sockets.py` 同构）。
#
# 用法：`glb_ship_rig_sockets.standardize(path, asset)`，在贴图外部化之后调用。
# @end-static-doc

import json
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import sn_ship_rig_sockets as rig

_MAGIC = 0x46546C67
_JSON = 0x4E4F534A
RIG_PREFIXES = ("SN_Socket_Mast_", "SN_Socket_Yard_", "SN_Socket_Sail_")


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


def _ship_of(asset):
    for ship in rig.SHIPS:
        if ship["asset"] == asset:
            return ship
    raise RuntimeError("未知船体资产 %s" % asset)


def _is_rig_name(name):
    return name.startswith(RIG_PREFIXES)


def standardize(path, asset):
    """归一化 rig socket 节点名 + 写 Root extras；返回报告 dict。"""
    ship = _ship_of(asset)
    specs = rig.build_specs()[asset]
    expected = [sock["glb_name"] for sock in specs]
    root_name = ship["root"]
    version, chunks = _read_glb(path)
    out_chunks = []
    report = {"asset": asset, "glb": path, "renamed": 0, "root": root_name,
              "sockets": expected, "failures": []}
    for chunk_type, payload in chunks:
        if chunk_type != _JSON:
            out_chunks.append((chunk_type, payload))
            continue
        gltf = json.loads(payload.decode("utf-8"))
        nodes = gltf.get("nodes", [])
        renamed = 0
        for node in nodes:
            name = node.get("name", "")
            if name.startswith("SN_Socket_"):
                continue
            if "_Socket_" not in name:
                continue
            suffix = name.split("_Socket_", 1)[1]
            if suffix.split("_")[0] in ("Mast", "Yard", "Sail"):
                node["name"] = "SN_Socket_" + suffix
                renamed += 1
        report["renamed"] = renamed
        by_name = {}
        for index, node in enumerate(nodes):
            name = node.get("name", "")
            if _is_rig_name(name):
                if name in by_name:
                    report["failures"].append("重复 socket 节点名 %s" % name)
                by_name[name] = index
        for name in expected:
            if name not in by_name:
                report["failures"].append("缺少 socket 节点 %s" % name)
        for name in by_name:
            if name not in expected:
                report["failures"].append("规格外 socket 节点 %s" % name)
        root_index = next((i for i, node in enumerate(nodes)
                           if node.get("name") == root_name), None)
        if root_index is None:
            report["failures"].append("找不到 Root 节点 %s" % root_name)
        else:
            for name in expected:
                index = by_name.get(name)
                if index is None:
                    continue
                node = nodes[index]
                if "mesh" in node:
                    report["failures"].append("%s 带 mesh（应为空节点）" % name)
                parent = None
                for other_index, other in enumerate(nodes):
                    if index in other.get("children", []):
                        parent = other_index
                        break
                if parent != root_index:
                    report["failures"].append("%s 不是 Root 的直接子节点" % name)
            root = nodes[root_index]
            extras = root.setdefault("extras", {})
            extras["rig_sockets"] = expected
            extras["rig_socket_count"] = len(expected)
            extras["rig_socket_spec"] = rig.SOCKET_SPEC
            for name, sock in zip(expected, specs):
                index = by_name.get(name)
                if index is None:
                    continue
                node_extras = nodes[index].setdefault("extras", {})
                node_extras["socket_kind"] = sock["kind"]
                node_extras["mast_key"] = sock["mast_key"]
                node_extras["socket_spec"] = rig.SOCKET_SPEC
        report["passed"] = not report["failures"]
        if not report["passed"]:
            raise RuntimeError("GLB rig socket 归一化失败 %s: %s"
                               % (asset, "; ".join(report["failures"])))
        out_chunks.append((chunk_type, json.dumps(
            gltf, ensure_ascii=False, separators=(",", ":")).encode("utf-8")))
    _write_glb(path, version, out_chunks)
    return report


if __name__ == "__main__":
    print(json.dumps(standardize(sys.argv[1], sys.argv[2]),
                     ensure_ascii=False, indent=1))
