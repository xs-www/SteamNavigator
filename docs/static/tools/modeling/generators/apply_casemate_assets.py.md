# `tools/modeling/generators/apply_casemate_assets.py`

> 作用：casemate gun 模块化的 **Blender 落盘脚本**（在已连 MCP 的活体 Blender 里跑一次）：

- 类型：项目配置/数据文件

1. 几何门禁：证明“现存 `SN_Ironclad` 网格 == 生成器 `with_barrels=True` 变体”
   （顶点按**索引**逐点比对 + 面按索引比顶点集合 / 材质），再按面索引删除 12 门炮管 +
   炮口箍（480 面 / 672 tri）；删完校验顶点/面/三角面、逐材质面数，且原炮管顶点一个都不剩
   （1 mm 容差哈希）。幂等：已经是空炮门则跳过；
2. 重建独立炮模块集合 `SN_Weapon_CasemateGun_Prototype`；
3. 重挂 4 个甲板武器 socket + 9 个帆索 socket（几何编辑后子空节点保留，这里做幂等补齐）；
4. 补齐 12 个 `SN_IC_Socket_GunPort_*` 炮门 socket 并实测门内纵深 / 舷外净空；
5. 只读复核三套 socket + 炮模块报告。

为什么用“按面索引删除”而不是整船重建：现存资产已经过 legacy UV 迁移 B（共享贴图 + UVMap）
和两批 socket，整船重建会把材质/UV/空节点全部丢掉；按索引只删炮管面能保证其余几何与材质
逐位不变。删除前先做生成器一致性门禁，避免在“资产与生成器已漂移”时盲删。

用法（Blender 内）：
    import runpy; runpy.run_path(<本文件>, run_name="__main__")

模块索引：[tools](../../README.md)
