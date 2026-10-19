# -*- coding: utf-8 -*-
"""Steam Navigator — SN_Ironclad 连通性检查（在 Blender 内只读运行）。

把 mesh 按共享顶点拆成连通岛（≈部件），用 BVH 求每个岛到其它岛的最近距离：
- 最近距离 > 0.05 m 的岛视为"完全脱开"（悬空）；
- 0.005–0.05 m 视为"松接触"（仅提示）；
用于拦截 revolved() 忘 translate、部件错位等 dryrun 查不出的问题。

用法（已连 Blender 的会话）：
    import runpy; runpy.run_path(<本文件>, run_name="__main__")
"""

import bpy
from mathutils.bvhtree import BVHTree

OBJECT = "SN_Ironclad"
FLOATING = 0.05
LOOSE = 0.005


def _find(parent, a):
    while parent[a] != a:
        parent[a] = parent[parent[a]]
        a = parent[a]
    return a


def _union(parent, a, b):
    ra, rb = _find(parent, a), _find(parent, b)
    if ra != rb:
        parent[rb] = ra


def _bbox_dist(a, b):
    dx = max(0.0, max(a[0] - b[3], b[0] - a[3]))
    dy = max(0.0, max(a[1] - b[4], b[1] - a[4]))
    dz = max(0.0, max(a[2] - b[5], b[2] - a[5]))
    return (dx * dx + dy * dy + dz * dz) ** 0.5


def check():
    obj = bpy.data.objects[OBJECT]
    me = obj.data
    n = len(me.vertices)
    parent = list(range(n))
    for e in me.edges:
        _union(parent, e.vertices[0], e.vertices[1])

    island_verts = {}
    for v in me.vertices:
        island_verts.setdefault(_find(parent, v.index), []).append(v.index)
    island_faces = {}
    for poly in me.polygons:
        island_faces.setdefault(_find(parent, poly.vertices[0]), []).append(list(poly.vertices))

    islands = []
    for root, vids in island_verts.items():
        local = {vid: i for i, vid in enumerate(vids)}
        verts = [me.vertices[vid].co.copy() for vid in vids]
        faces = [[local[i] for i in f] for f in island_faces.get(root, [])]
        if not faces:
            continue
        xs = [v.x for v in verts]
        ys = [v.y for v in verts]
        zs = [v.z for v in verts]
        bbox = (min(xs), min(ys), min(zs), max(xs), max(ys), max(zs))
        tree = BVHTree.FromPolygons(verts, faces, all_triangles=False, epsilon=0.0)
        stride = max(1, len(verts) // 16)
        samples = verts[::stride][:16]
        tris = sum(max(0, len(f) - 2) for f in faces)
        islands.append({
            "bbox": bbox,
            "tree": tree,
            "samples": samples,
            "tris": tris,
            "faces": len(faces),
        })

    for isl in islands:
        isl["min_dist"] = 1e18
        isl["nearest"] = None

    pairs = 0
    for i in range(len(islands)):
        a = islands[i]
        for j in range(i + 1, len(islands)):
            b = islands[j]
            if _bbox_dist(a["bbox"], b["bbox"]) > 0.30:
                continue
            pairs += 1
            # 先看两岛三角面是否真的相交（穿透/嵌套的都算连接）
            if a["tree"].overlap(b["tree"]):
                best = 0.0
            else:
                best = 1e18
                for p in a["samples"]:
                    hit = b["tree"].find_nearest(p)
                    if hit[0] is not None and hit[3] < best:
                        best = hit[3]
                for p in b["samples"]:
                    hit = a["tree"].find_nearest(p)
                    if hit[0] is not None and hit[3] < best:
                        best = hit[3]
            if best < a["min_dist"]:
                a["min_dist"], a["nearest"] = best, j
            if best < b["min_dist"]:
                b["min_dist"], b["nearest"] = best, i

    floating = []
    loose = []
    for idx, isl in enumerate(islands):
        center = tuple(round((isl["bbox"][k] + isl["bbox"][k + 3]) / 2.0, 2) for k in range(3))
        if isl["min_dist"] > FLOATING:
            floating.append({"center": center, "min_dist": round(isl["min_dist"], 3),
                             "tris": isl["tris"], "faces": isl["faces"]})
        elif isl["min_dist"] > LOOSE:
            loose.append({"center": center, "min_dist": round(isl["min_dist"], 3),
                          "tris": isl["tris"]})

    result = {
        "object": OBJECT,
        "islands": len(islands),
        "pairs_checked": pairs,
        "floating": floating,
        "loose": loose[:20],
        "floating_count": len(floating),
        "loose_count": len(loose),
    }
    print("IRONCLAD_CONNECTIVITY " + repr(result))
    return result


if __name__ == "__main__":
    check()
