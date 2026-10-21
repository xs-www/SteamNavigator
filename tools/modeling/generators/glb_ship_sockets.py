# -*- coding: utf-8 -*-
# @static-doc
# 作用：船侧武器 socket 的 GLB 后处理（纯 Python）——把 BLEND 内带资产前缀的
# `SN_PF_Socket_Weapon_Port_1` 这类节点归一化为契约标准名 `SN_Socket_Weapon_Port_1`，
# 并把本次 socket 名单作为 `weapon_sockets` 列表写进船体 Root 节点的 extras。
#
# ## 为什么需要后处理
# - 4 艘船在同一个 Blender 工作台里并排，`SN_Socket_Weapon_Port_1` 这类标准名会撞全局对象命名空间
#   （Blender 静默加 `.001`）；所以 BLEND 内统一带资产前缀，导出后再归一化，做法与
#   `glb_weapon_nodes.py`（武器 v2）完全一致。
# - Blender 的 IDProperty 不支持字符串数组，`weapon_sockets` 列表只能在 GLB JSON 层写入
#   （Blender 侧只保留 `weapon_socket_count` / `socket_spec`）。
#
# ## 契约
# - 每个 socket 节点必须存在且唯一、名字以 `SN_Socket_Weapon_` 开头、且是 Root 节点的子节点；
# - Root extras：`weapon_sockets`（按 socket_index 顺序的名字数组）、`weapon_socket_count`、
#   `socket_spec = "hull-sockets@1"`；其余既有 extras（asset / version / …）原样保留；
# - mesh / Root 名字不变，BIN chunk 不受影响（只重写 JSON chunk）。
#
# 用法：`glb_ship_sockets.standardize(path, asset)`，在贴图外部化之后调用。
# @end-static-doc

import json
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import sn_ship_weapon_sockets as socks

SOCKET_PREFIX = socks.SOCKET_PREFIX
_MAGIC = 0x46546C67
_JSON = 0x4E4F534A
_BIN = 0x004E4942


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
    for ship in socks.SHIPS:
        if ship["asset"] == asset:
            return ship
    raise RuntimeError("未知船体资产 %s" % asset)


def standardize(path, asset):
    """归一化 socket 节点名 + 写 Root extras；返回报告 dict。"""
    ship = _ship_of(asset)
    expected = socks.expected_sockets()[asset]
    expected_names = [name for _index, name, _sock in expected]
    root_name = ship["root"]
    version, chunks = _read_glb(path)
    out_chunks = []
    report = {"asset": asset, "glb": path, "renamed": 0, "root": root_name,
              "sockets": expected_names, "failures": []}
    for chunk_type, payload in chunks:
        if chunk_type != _JSON:
            out_chunks.append((chunk_type, payload))
            continue
        gltf = json.loads(payload.decode("utf-8"))
        nodes = gltf.get("nodes", [])
        renamed = 0
        for node in nodes:
            name = node.get("name", "")
            marker = "_Socket_Weapon_"
            if marker in name and not name.startswith(SOCKET_PREFIX + "_"):
                suffix = name.split(marker, 1)[1]
                node["name"] = SOCKET_PREFIX + "_" + suffix
                renamed += 1
        report["renamed"] = renamed

        by_name = {}
        for index, node in enumerate(nodes):
            name = node.get("name", "")
            if name.startswith(SOCKET_PREFIX + "_"):
                if name in by_name:
                    report["failures"].append("重复 socket 节点名 %s" % name)
                by_name[name] = index
        for name in expected_names:
            if name not in by_name:
                report["failures"].append("缺少 socket 节点 %s" % name)
        for name, index in by_name.items():
            if name not in expected_names:
                report["failures"].append("规格外 socket 节点 %s" % name)

        root_index = None
        for index, node in enumerate(nodes):
            if node.get("name") == root_name:
                root_index = index
                break
        if root_index is None:
            report["failures"].append("找不到 Root 节点 %s" % root_name)
        else:
            root = nodes[root_index]
            children = list(root.get("children", []))
            for name in expected_names:
                index = by_name.get(name)
                if index is None:
                    continue
                # 确保 socket 是 Root 的直接子节点（重复父级则先摘掉）
                for other_index, other in enumerate(nodes):
                    if other_index == index:
                        continue
                    other_children = other.get("children")
                    if other_children and index in other_children:
                        other["children"] = [c for c in other_children if c != index]
                if index not in children:
                    children.append(index)
            root["children"] = children
            extras = root.setdefault("extras", {})
            extras["weapon_sockets"] = expected_names
            extras["weapon_socket_count"] = len(expected_names)
            extras["socket_spec"] = socks.SOCKET_SPEC
        report["passed"] = not report["failures"]
        if not report["passed"]:
            # 失败不写盘，保留可诊断的中间态报告
            raise RuntimeError("GLB socket 归一化失败 %s: %s"
                               % (asset, "; ".join(report["failures"])))
        out_chunks.append((chunk_type, json.dumps(
            gltf, ensure_ascii=False, separators=(",", ":")).encode("utf-8")))
    _write_glb(path, version, out_chunks)
    return report


if __name__ == "__main__":
    report = standardize(sys.argv[1], sys.argv[2])
    print(json.dumps(report, ensure_ascii=False, indent=1))
