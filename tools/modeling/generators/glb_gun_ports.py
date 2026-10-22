# -*- coding: utf-8 -*-
# @static-doc
# 作用：**炮门 socket 的 GLB 后处理**（纯 Python）——把 BLEND 内带资产前缀的
# `SN_IC_Socket_GunPort_Port_1` 归一化为契约标准名 `SN_Socket_GunPort_Port_1`，
# 并把 12 个炮门名单按 `socket_index` 顺序写进铁甲舰 Root 节点的
# `gun_port_sockets` extras（附 `gun_port_socket_count` / `gun_port_socket_spec`）。
#
# ## 为什么不复用 `glb_ship_sockets.py`
# 甲板武器 socket（`SN_Socket_Weapon_*`）与炮门 socket（`SN_Socket_GunPort_*`）是两套语义：
# 前者原点在甲板安装面、后者原点在炮门平面中心；名字前缀不同，Root 列表也必须分开，
# 否则装配层无法区分“这门炮是坐在甲板上还是穿在船壳里”。
#
# ## 契约
# - 每个炮门节点必须存在且唯一、是 Root 直接子节点、不带 mesh；
# - 节点 extras 原样保留（由 `sn_ship_gun_ports.apply_ship()` 写入 Blender IDProperty，
#   导出时 `export_extras=True` 带出）；
# - 只重写 JSON chunk，BIN chunk 不动。
#
# 用法：`glb_gun_ports.standardize(path, "SN_Ironclad")`，在贴图外部化与
# `glb_ship_sockets` / `glb_ship_rig_sockets` 之后调用。
# @end-static-doc

import json
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import sn_ship_gun_ports as gunports

SOCKET_PREFIX = gunports.SOCKET_PREFIX
_MAGIC = 0x46546C67
_JSON = 0x4E4F534A


def _read_glb(path):
    data = open(path, "rb").read()
    magic, version, length = struct.unpack("<III", data[:12])
    if magic != _MAGIC:
        raise RuntimeError("%s: not a GLB" % path)
    offset = 12
    chunks = []
    while offset < length:
        chunk_length, chunk_type = struct.unpack("<II", data[offset:offset + 8])
        chunks.append((chunk_type, data[offset + 8:offset + 8 + chunk_length]))
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
    for ship in gunports.SHIPS:
        if ship["asset"] == asset:
            return ship
    raise RuntimeError("未知船体资产 %s" % asset)


def standardize(path, asset):
    """归一化炮门节点名 + 写 Root extras；返回报告 dict。"""
    ship = _ship_of(asset)
    expected = gunports.expected_ports()[asset]
    expected_names = [name for _index, name, _port in expected]
    root_name = ship["root"]
    version, chunks = _read_glb(path)
    out_chunks = []
    report = {"asset": asset, "glb": path, "renamed": 0, "root": root_name,
              "ports": expected_names, "failures": []}
    for chunk_type, payload in chunks:
        if chunk_type != _JSON:
            out_chunks.append((chunk_type, payload))
            continue
        gltf = json.loads(payload.decode("utf-8"))
        nodes = gltf.get("nodes", [])
        renamed = 0
        for node in nodes:
            name = node.get("name", "")
            if "_Socket_GunPort_" in name and not name.startswith(SOCKET_PREFIX + "_"):
                node["name"] = SOCKET_PREFIX + "_" + name.split("_Socket_GunPort_", 1)[1]
                renamed += 1
        report["renamed"] = renamed

        by_name = {}
        for index, node in enumerate(nodes):
            name = node.get("name", "")
            if name.startswith(SOCKET_PREFIX + "_"):
                if name in by_name:
                    report["failures"].append("重复炮门节点名 %s" % name)
                by_name[name] = index
        for name in expected_names:
            if name not in by_name:
                report["failures"].append("缺少炮门节点 %s" % name)
        for name in by_name:
            if name not in expected_names:
                report["failures"].append("规格外炮门节点 %s" % name)

        root_index = next((i for i, node in enumerate(nodes)
                           if node.get("name") == root_name), None)
        if root_index is None:
            report["failures"].append("找不到 Root 节点 %s" % root_name)
        else:
            root = nodes[root_index]
            children = list(root.get("children", []))
            for name in expected_names:
                index = by_name.get(name)
                if index is None:
                    continue
                node = nodes[index]
                if "mesh" in node:
                    report["failures"].append("%s 带 mesh（应为空节点）" % name)
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
            extras["gun_port_sockets"] = expected_names
            extras["gun_port_socket_count"] = len(expected_names)
            extras["gun_port_socket_spec"] = gunports.SOCKET_SPEC
        report["passed"] = not report["failures"]
        if not report["passed"]:
            raise RuntimeError("GLB 炮门 socket 归一化失败 %s: %s"
                               % (asset, "; ".join(report["failures"])))
        out_chunks.append((chunk_type, json.dumps(
            gltf, ensure_ascii=False, separators=(",", ":")).encode("utf-8")))
    _write_glb(path, version, out_chunks)
    return report


if __name__ == "__main__":
    result = standardize(sys.argv[1], sys.argv[2])
    print(json.dumps(result, ensure_ascii=False, indent=1))
