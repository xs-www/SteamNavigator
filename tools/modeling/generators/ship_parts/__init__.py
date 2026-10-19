# -*- coding: utf-8 -*-
"""Steam Navigator 可复用船体部件库。

- `core`：Part / 向量 / 基本体 / 放样 / 镜像 / PartSpec
- `deck`：舱口、天窗、绞盘、起锚机、舵轮、罗经柜、钟、木桶、盘绳、缆柱、水桶、fife rail、短梯
- `bow`：艏斜桁 / jibboom / 雕刻艏饰
- `stern`：艉廊 / 艉窗 / 艉灯
- `assembly`：Blender 集合装配 / 材质 / 空物体 / 文字铭牌 / report

约定：1 unit = 1 m，+X 船首、+Y 左舷、+Z 向上；`Part` 只含几何与材质名，
不依赖 bpy；`assembly` 的 bpy 导入都在函数内部，干跑可安全加载生成器。
"""

from .core import Part, PartSpec, tri_count
from . import assembly, bow, deck, stern

__all__ = ["Part", "PartSpec", "tri_count", "assembly", "bow", "deck", "stern"]
