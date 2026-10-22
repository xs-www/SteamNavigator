# -*- coding: utf-8 -*-
# @static-doc
# 作用：纯 Python 的 GLB 世界空间几何读取器：按 glTF 节点层级合成完整 TRS（含四元数
# 旋转 / matrix / 非均匀缩放），读取 POSITION accessor 的真实顶点，求得**世界包围盒**、
# 三角面数、UV 完整性、节点根名，供 LOD0↔LOD1 对比、门禁与验收脚本复用。
#
# ## 契约与约束
# - 不依赖 bpy / Godot；只读 GLB，不修改文件。复用 `glb_shared_textures.read_glb`
#   的容器解析与 `structure_report` 的材质 / image 报告，本模块只补「真实几何」。
# - POSITION 只支持 float32（componentType 5126），与 Blender glTF 导出/本仓库资产一致；
#   其它类型直接抛 ValueError，不静默换算法。
# - 包围盒取实际顶点（不是 accessor min/max 的 8 角点），因此带旋转 Pivot 的多节点船体
#   与 kit 拼装件的 bbox 是精确值；LOD1 单节点也走同一条路径，可以直接对账。
# - `uv_missing` / `uv_count_mismatch` 用于守护"每个图元都有 TEXCOORD_0 且数量等于
#   POSITION"，不判断 UV 数值是否合理（盒式投影由 Blender 侧负责）。
#
# ## 重点逻辑
# ### `world_bounds(path, only_nodes=None)`
# - 根节点 = 没有被任何节点 `children` 引用的节点；沿 children 递归合成
#   `parent @ trs(node)`，把每个 mesh primitive 的 POSITION 变换到世界空间累积 min/max。
# - 同时返回 `tris`（indices.count/3 或 POSITION.count/3）、`mesh_nodes`、`root_nodes`、
#   `primitives`、`uv_missing`、`uv_count_mismatch`，一次遍历拿到门禁需要的全部几何事实。
# ### `node_world_matrices(path)`
# - 返回 `{node_index: matrix}`，供需要按节点核对（例如 socket 空节点）的脚本使用。
# @end-static-doc

import importlib.util
import os

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))

COMPONENTS = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}
IDENTITY = [[1.0, 0.0, 0.0, 0.0],
            [0.0, 1.0, 0.0, 0.0],
            [0.0, 0.0, 1.0, 0.0],
            [0.0, 0.0, 0.0, 1.0]]


def _glb_tools():
    path = os.path.join(HERE, "glb_shared_textures.py")
    spec = importlib.util.spec_from_file_location("glb_shared_textures", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


# --------------------------------------------------------------------------- #
# Matrix / accessor helpers
# --------------------------------------------------------------------------- #

def _mat_mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)]
            for i in range(4)]


def _mat_apply(matrix, point):
    return [matrix[r][0] * point[0] + matrix[r][1] * point[1]
            + matrix[r][2] * point[2] + matrix[r][3] for r in range(3)]


def _quaternion_matrix(quaternion):
    x, y, z, w = [float(value) for value in quaternion]
    xx, yy, zz = x * x, y * y, z * z
    xy, xz, yz = x * y, x * z, y * z
    xw, yw, zw = x * w, y * w, z * w
    return [[1.0 - 2.0 * (yy + zz), 2.0 * (xy - zw), 2.0 * (xz + yw), 0.0],
            [2.0 * (xy + zw), 1.0 - 2.0 * (xx + zz), 2.0 * (yz - xw), 0.0],
            [2.0 * (xz - yw), 2.0 * (yz + xw), 1.0 - 2.0 * (xx + yy), 0.0],
            [0.0, 0.0, 0.0, 1.0]]


def node_matrix(node):
    """Full TRS (translation * rotation * scale) or an explicit 4x4 matrix."""
    if "matrix" in node:
        m = node["matrix"]
        return [[float(m[0]), float(m[4]), float(m[8]), float(m[12])],
                [float(m[1]), float(m[5]), float(m[9]), float(m[13])],
                [float(m[2]), float(m[6]), float(m[10]), float(m[14])],
                [float(m[3]), float(m[7]), float(m[11]), float(m[15])]]
    rotation = node.get("rotation")
    matrix = _quaternion_matrix(rotation) if rotation else [row[:] for row in IDENTITY]
    scale = node.get("scale", [1.0, 1.0, 1.0])
    for row in range(3):
        for column in range(3):
            matrix[row][column] *= float(scale[column])
    translation = node.get("translation", [0.0, 0.0, 0.0])
    for row in range(3):
        matrix[row][3] = float(translation[row])
    return matrix


def _accessor_floats(document, bin_chunk, index):
    accessors = document.get("accessors", [])
    accessor = accessors[int(index)]
    component_type = int(accessor.get("componentType", 0))
    if component_type != 5126:
        raise ValueError("accessor %d: only float32 POSITION is supported (got %d)"
                         % (index, component_type))
    count = int(accessor["count"])
    components = COMPONENTS[accessor["type"]]
    view = document["bufferViews"][int(accessor["bufferView"])]
    start = int(view.get("byteOffset", 0)) + int(accessor.get("byteOffset", 0))
    stride = view.get("byteStride")
    if stride is None:
        stride = components * 4
    stride = int(stride)
    values = []
    import struct
    for item in range(count):
        offset = start + item * stride
        values.append(struct.unpack_from("<" + "f" * components, bin_chunk, offset))
    return values


# --------------------------------------------------------------------------- #
# Public API
# --------------------------------------------------------------------------- #

def node_world_matrices(path):
    """Return ``{node_index: world_matrix}`` (roots get their own TRS)."""
    glb = _glb_tools()
    document, _bin = glb.read_glb(path)
    nodes = document.get("nodes", [])
    child_indices = {int(child) for node in nodes for child in node.get("children", [])}
    roots = [index for index in range(len(nodes)) if index not in child_indices]
    world = {}

    def walk(index, parent):
        matrix = _mat_mul(parent, node_matrix(nodes[index]))
        world[index] = matrix
        for child in nodes[index].get("children", []):
            walk(int(child), matrix)

    for root in roots:
        walk(root, [row[:] for row in IDENTITY])
    return world


def world_bounds(path):
    """Exact world-space geometry facts for one GLB."""
    glb = _glb_tools()
    document, bin_chunk = glb.read_glb(path)
    nodes = document.get("nodes", [])
    meshes = document.get("meshes", [])
    accessors = document.get("accessors", [])
    child_indices = {int(child) for node in nodes for child in node.get("children", [])}
    roots = [index for index in range(len(nodes)) if index not in child_indices]
    bounds_min = [float("inf")] * 3
    bounds_max = [float("-inf")] * 3
    stats = {
        "tris": 0,
        "primitives": 0,
        "mesh_nodes": 0,
        "uv_missing": 0,
        "uv_count_mismatch": 0,
        "nodes": len(nodes),
        "root_nodes": [nodes[index].get("name") for index in roots],
    }

    def walk(index, parent):
        node = nodes[index]
        matrix = _mat_mul(parent, node_matrix(node))
        if "mesh" in node:
            stats["mesh_nodes"] += 1
            for primitive in meshes[int(node["mesh"])].get("primitives", []):
                stats["primitives"] += 1
                attributes = primitive.get("attributes", {})
                indices = primitive.get("indices")
                if indices is not None:
                    stats["tris"] += int(accessors[int(indices)]["count"]) // 3
                position_index = attributes.get("POSITION")
                if position_index is None:
                    continue
                positions = _accessor_floats(document, bin_chunk, int(position_index))
                if indices is None:
                    stats["tris"] += len(positions) // 3
                uv_index = attributes.get("TEXCOORD_0")
                if uv_index is None:
                    stats["uv_missing"] += 1
                elif int(accessors[int(uv_index)]["count"]) != len(positions):
                    stats["uv_count_mismatch"] += 1
                for position in positions:
                    world = _mat_apply(matrix, position)
                    for axis in range(3):
                        bounds_min[axis] = min(bounds_min[axis], world[axis])
                        bounds_max[axis] = max(bounds_max[axis], world[axis])
        for child in node.get("children", []):
            walk(int(child), matrix)

    for root in roots:
        walk(root, [row[:] for row in IDENTITY])

    if bounds_min[0] > bounds_max[0]:
        return {"stats": stats, "min": None, "max": None, "size": None,
                "center": None, "path": os.path.relpath(path, REPO_ROOT)}
    return {
        "stats": stats,
        "min": [round(value, 6) for value in bounds_min],
        "max": [round(value, 6) for value in bounds_max],
        "size": [round(bounds_max[axis] - bounds_min[axis], 6) for axis in range(3)],
        "center": [round((bounds_max[axis] + bounds_min[axis]) * 0.5, 6)
                   for axis in range(3)],
        "path": os.path.relpath(path, REPO_ROOT),
    }


def compare_bounds(lod0, lod1, tolerance=0.02):
    """Axis-wise size / min / max deltas between two `world_bounds()` results."""
    if not lod0.get("min") or not lod1.get("min"):
        return {"ok": False, "reason": "missing bbox", "size_delta": None,
                "min_delta": None, "max_delta": None}
    size_delta = [round(lod1["size"][axis] - lod0["size"][axis], 6) for axis in range(3)]
    min_delta = [round(lod1["min"][axis] - lod0["min"][axis], 6) for axis in range(3)]
    max_delta = [round(lod1["max"][axis] - lod0["max"][axis], 6) for axis in range(3)]
    worst = max(abs(value) for value in size_delta + min_delta + max_delta)
    return {
        "ok": worst <= tolerance,
        "tolerance": tolerance,
        "worst_delta": round(worst, 6),
        "size_delta": size_delta,
        "min_delta": min_delta,
        "max_delta": max_delta,
    }


if __name__ == "__main__":
    import json
    import sys

    for argument in sys.argv[1:]:
        print(json.dumps(world_bounds(argument), indent=2, ensure_ascii=False))
