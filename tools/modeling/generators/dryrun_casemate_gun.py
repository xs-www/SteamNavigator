# -*- coding: utf-8 -*-
# @static-doc
# 作用：casemate gun 模块（`SN_Weapon_CasemateGun`）的**纯 Python 干跑**——不进 Blender，
# 在写场景/导出前拦住几何、接口与“装上去对不对”的错误。
#
# 核对项：
# 1. 材质白名单 / 共享贴图库（`sn_weapon_materials` + `sn_shared_materials.texture_report()`）；
# 2. 几何：对象命名/父级、三角面预算、包围盒 = 模块 `envelope()`、闭合壳体（边界边/非流形/退化面）；
# 3. 轴心契约：`x < 0` 全部是门内隐藏段（炮尾 / 耳轴），且都落在 1.9×1.9 炮门开口内；
# 4. Pivot 链：Mount → Pitch（耳轴 x=-0.15）→ Recoil → Muzzle，Muzzle 落点在炮口端面中心；
# 5. **装到铁甲舰 12 个炮门上时与拆炮前的烘焙炮管逐顶点重合**（这是本批最关键的验收断言）；
# 6. 俯仰极限：±ELEV 时可见段仍在炮门开口内、隐藏段仍在门内（不会被看见）。
#
# 用法：`python tools/modeling/generators/dryrun_casemate_gun.py`
# 通过标准：打印 `ALL OK`；任何一项失败返回非 0 退出码。
# @end-static-doc

import importlib.util
import math
import os
import sys
import types
from collections import Counter

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

GUN_GEN = os.path.join(HERE, "sn_casemate_gun_generator.py")
IC_GEN = os.path.join(HERE, "sn_ironclad_generator.py")
COORD_TOL = 1e-6


def load_module(path, name):
    for stub in ("bpy", "bmesh", "mathutils"):
        sys.modules.setdefault(stub, types.ModuleType(stub))
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def tri_count(part):
    return sum(max(0, len(f) - 2) for f, _m in part.faces)


def edge_stats(part):
    counter = Counter()
    for face, _m in part.faces:
        for i in range(len(face)):
            a, b = face[i], face[(i + 1) % len(face)]
            counter[(min(a, b), max(a, b))] += 1
    return (sum(1 for c in counter.values() if c == 1),
            sum(1 for c in counter.values() if c > 2))


def round_pt(p, digits=6):
    return (round(p[0], digits), round(p[1], digits), round(p[2], digits))


def part_bbox(parts):
    xs, ys, zs = [], [], []
    for part, _parent in parts.values():
        xs.extend(v[0] for v in part.verts)
        ys.extend(v[1] for v in part.verts)
        zs.extend(v[2] for v in part.verts)
    return {"x": (min(xs), max(xs)), "y": (min(ys), max(ys)), "z": (min(zs), max(zs))}


def mount_transform(verts, pose):
    """把模块局部坐标（+X = 炮膛轴线）变换到船体局部坐标。"""
    a = math.radians(pose["rot_z_deg"])
    b = math.radians(pose["rot_y_deg"])
    ca, sa, cb, sb = math.cos(a), math.sin(a), math.cos(b), math.sin(b)
    cx, cy, cz = pose["center"]
    out = []
    for x, y, z in verts:
        x1 = cb * x + sb * z
        z1 = -sb * x + cb * z
        out.append((ca * x1 - sa * y + cx, sa * x1 + ca * y + cy, z1 + cz))
    return out


def pitch_transform(verts, degrees):
    """模块局部绕 Y（耳轴）俯仰；同时把耳轴平移到原点便于检查。"""
    th = math.radians(degrees)
    ct, st = math.cos(th), math.sin(th)
    return [(x * ct + z * st, y, -x * st + z * ct) for x, y, z in verts]


def baked_barrel_faces(ic, full, empty):
    """`build_guns(with_barrels=True/False)` 的面集合差 = 烘焙炮管 + 炮口箍的面。"""

    def key(part, face):
        return tuple(sorted(round_pt(part.verts[i]) for i in face))

    full_keys = Counter((m, key(full, f)) for f, m in full.faces)
    empty_keys = Counter((m, key(empty, f)) for f, m in empty.faces)
    return full_keys - empty_keys


def check(module, ic):
    failures = []
    ports = []
    for x in ic.GUN_X:
        for side in (1, -1):
            ports.append(ic.gun_port_pose(x, side))

    parts = module.build_geometry()
    cfg = module.build_config(origin=(0.0, 0.0, 0.0))
    materials = module.ASSET_MATERIALS[module.ASSET]

    # ---- 1. 材质 / 贴图 -----------------------------------------------------
    import sn_shared_materials as smat
    facts = smat.texture_report()
    if set(module.colors_for(module.ASSET)) != set(materials):
        failures.append("colors_for 与材质白名单不一致")
    for name in sorted(materials):
        if name not in facts or not facts[name]["exists"]:
            failures.append("共享贴图缺失：%s" % name)

    # ---- 2. 几何 -----------------------------------------------------------
    total = 0
    seen = set()
    used_mats = set()
    for name, (part, parent) in parts.items():
        if name in seen:
            failures.append("重复对象名 %s" % name)
        seen.add(name)
        if not name.startswith(module.PREFIX):
            failures.append("%s 前缀不符" % name)
        if parent not in ("MOUNT", "PITCH", "RECOIL"):
            failures.append("%s 父级 %s 非法" % (name, parent))
        tris = tri_count(part)
        total += tris
        boundary, nonman = edge_stats(part)
        used_mats.update(m for _f, m in part.faces)
        if boundary or nonman:
            failures.append("%s 非闭合 boundary=%d nonmanifold=%d" % (name, boundary, nonman))
        bad = {m for _f, m in part.faces} - materials
        if bad:
            failures.append("%s 未在白名单的材质 %s" % (name, sorted(bad)))
    if total > module.TRI_BUDGET:
        failures.append("三角面 %d 超预算 %d" % (total, module.TRI_BUDGET))

    bbox = part_bbox(parts)
    env = module.envelope()
    for axis in "xyz":
        for i in (0, 1):
            if abs(bbox[axis][i] - env[axis][i]) > COORD_TOL:
                failures.append("包围盒 %s[%d] %.4f != envelope %.4f"
                                % (axis, i, bbox[axis][i], env[axis][i]))

    # ---- 3. 轴心契约：门内隐藏段 -------------------------------------------
    barrel_part = parts[module.PREFIX + "Barrel"][0]
    breech_part = parts[module.PREFIX + "Breech"][0]
    if min(v[0] for v in barrel_part.verts) >= 0.0:
        failures.append("炮管没有伸进门内，后坐/俯仰会露缝")
    for v in breech_part.verts:
        if v[0] >= 0.0:
            failures.append("炮尾/耳轴有顶点跑出门外 x=%.3f" % v[0])
            break
        if abs(v[1]) > module.PORT_W / 2.0 or abs(v[2]) > module.PORT_H / 2.0:
            failures.append("隐藏段超出炮门开口 (%.2f, %.2f)" % (v[1], v[2]))
            break

    # ---- 4. Pivot 链 -------------------------------------------------------
    specs = {spec.key: spec for spec in cfg.pivots}
    for key in ("MOUNT", "PITCH", "RECOIL", "MUZZLE"):
        if key not in specs:
            failures.append("缺少 pivot %s" % key)
    if specs["PITCH"].parent != "MOUNT" or specs["RECOIL"].parent != "PITCH":
        failures.append("Pivot 链不是 Mount → Pitch → Recoil")
    if specs["MOUNT"].location != (0.0, 0.0, 0.0):
        failures.append("Mount 不在炮门平面原点")
    if abs(specs["PITCH"].location[0] - module.TRUNNION_X) > 1e-9:
        failures.append("Pitch 不在耳轴 x 位置")
    muzzle_world_x = specs["PITCH"].location[0] + specs["RECOIL"].location[0] \
        + specs["MUZZLE"].location[0]
    if abs(muzzle_world_x - module.BARREL_OUTBOARD) > 1e-9:
        failures.append("Muzzle 不在炮口端面 %.4f != %.4f"
                        % (muzzle_world_x, module.BARREL_OUTBOARD))
    for spec in cfg.pivots:
        if not spec.name.startswith("SN_"):
            failures.append("pivot 名 %s 前缀不符" % spec.name)

    # ---- 5. 与烘焙炮管逐顶点重合 ------------------------------------------
    full = ic.Part()
    ic.build_guns(full, with_barrels=True)
    empty = ic.Part()
    ic.build_guns(empty, with_barrels=False)
    baked = baked_barrel_faces(ic, full, empty)
    baked_barrel_count = sum(baked.values()) // len(ports)  # 12 门共用同一模块
    module_barrel_count = len(barrel_part.faces)
    if baked_barrel_count != module_barrel_count:
        failures.append("炮管面数 模块 %d != 烘焙 %d"
                        % (module_barrel_count, baked_barrel_count))

    baked_by_gun = {}
    for (mat, key), count in baked.items():
        cx = sum(p[0] for p in key) / len(key)
        cy = sum(p[1] for p in key) / len(key)
        index = min(range(len(ports)),
                    key=lambda i: abs(ports[i]["x"] - cx) + abs(ports[i]["center"][1] - cy))
        for _ in range(count):
            baked_by_gun.setdefault(index, []).append((mat, key))

    worst = 0.0
    for index, pose in enumerate(ports):
        mounted = mount_transform(barrel_part.verts, pose)
        got_verts = {round_pt(v) for v in mounted}
        want_verts = {point for _mat, key in baked_by_gun.get(index, [])
                      for point in key}
        only_got = sorted(got_verts - want_verts)
        only_want = sorted(want_verts - got_verts)
        if only_got or only_want:
            failures.append("炮门 %d（x=%.1f side=%+d）装上去与烘焙炮管不重合：多 %d 少 %d"
                            % (index + 1, pose["x"], pose["side"],
                               len(only_got), len(only_want)))
    # 逐门比对“变换后模块顶点”与“烘焙炮管顶点”的最大偏差
    for index, pose in enumerate(ports):
        mounted = mount_transform(barrel_part.verts, pose)
        want = sorted({point for _mat, key in baked_by_gun.get(index, [])
                       for point in key})
        if len(want) != len(mounted):
            failures.append("炮门 %d 顶点数 %d != 烘焙 %d"
                            % (index + 1, len(mounted), len(want)))
            continue
        for point in sorted(round_pt(v) for v in mounted):
            nearest = min(max(abs(point[i] - want_v[i]) for i in range(3))
                          for want_v in want)
            worst = max(worst, nearest)
        if worst > COORD_TOL:
            failures.append("炮门 %d 顶点偏差 %.2e > %.0e" % (index + 1, worst, COORD_TOL))

    # ---- 6. 俯仰极限 -------------------------------------------------------
    hidden = len(barrel_part.verts)
    all_verts = list(barrel_part.verts) + list(breech_part.verts)
    for degrees in (module.ELEV_MIN, module.ELEV_MAX):
        pitched = pitch_transform(all_verts, degrees)
        # 可见段（门外的炮管）必须在炮门开口内
        for x, y, z in pitched[:hidden]:
            if x > 0.0 and (abs(y) > module.PORT_W / 2.0 or abs(z) > module.PORT_H / 2.0):
                failures.append("俯仰 %.0f° 时炮管跑出炮门开口 (%.2f, %.2f)"
                                % (degrees, y, z))
                break
        # 隐藏段必须仍在门内（x < 0）
        for x, _y, _z in pitched[hidden:]:
            if x >= 0.0:
                failures.append("俯仰 %.0f° 时隐藏段露出炮门平面 x=%.3f" % (degrees, x))
                break

    # ---- 输出 --------------------------------------------------------------
    print("=" * 96)
    print("asset: %s  collection=%s  workbench=%s" % (module.ASSET, module.COLLECTION,
                                                     module.WORKBENCH_POS))
    print("%-34s %6s %-22s %-8s %s" % ("object", "tris", "size(x,y,z)", "parent", "materials"))
    print("-" * 96)
    for name, (part, parent) in parts.items():
        size = tuple(round(max(v[i] for v in part.verts) - min(v[i] for v in part.verts), 3)
                     for i in range(3))
        mats = sorted({m.replace("SN_Tex_", "") for _f, m in part.faces})
        print("%-34s %6d %-22s %-8s %s" % (name, tri_count(part),
                                           "%.2f,%.2f,%.2f" % size, parent, ",".join(mats)))
    print("-" * 96)
    print("tris = %d / %d" % (total, module.TRI_BUDGET))
    print("bbox = %.4f x %.4f x %.4f m" % (env["x"][1] - env["x"][0],
                                           env["y"][1] - env["y"][0],
                                           env["z"][1] - env["z"][0]))
    print("炮门平面偏移 = %.4f m（门内） / 门外外露 = %.4f m / 12 门总重合误差 = %.2e m"
          % (module.PLANE_OFFSET, module.BARREL_OUTBOARD, worst))
    print("俯仰极限 = %.0f° .. %.0f°；炮口箍 %d 顶点 / 炮管 %d 面"
          % (module.ELEV_MIN, module.ELEV_MAX,
             len(barrel_part.verts), module_barrel_count))

    if failures:
        print("\nFAILURES:")
        for item in failures:
            print("  - " + item)
        return False
    print("\nALL OK")
    return True


def main():
    module = load_module(GUN_GEN, "casemate_gun_under_test")
    ic = module.ironclad
    ok = check(module, ic)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
