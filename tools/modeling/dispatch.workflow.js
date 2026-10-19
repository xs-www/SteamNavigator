/*
 * Steam Navigator — 物品建模派发工作流（DSH workflow 工具脚本）
 * =============================================================
 *
 * 用法
 * ----
 * 把本文件内容作为 `workflow` 工具的 script 传入：
 *
 *   workflow({
 *     meta: {
 *       name: "sn-modeling-dispatch",
 *       description: "按工单派发建模子代理并自动质检",
 *       phases: [{ title: "派发" }, { title: "逐件建模与质检" }, { title: "汇总" }]
 *     },
 *     args: { briefs: [ <工单1>, <工单2>, ... ] },
 *     script: "<本文件内容>"
 *   })
 *
 * 设计约束
 * --------
 * 1. 串行：Blender 是单实例，同一时刻只能有一个写者，所以用 for + await，
 *    禁止 parallel / pipeline（它们会并发派发多个 Builder）。
 * 2. workflow 脚本无法向人提问：工单批准与成品验收必须在调用前后由 Lead 完成。
 * 3. 本脚本只负责「建模 + 自动质检」，不落盘；.blend / .glb 在人工验收后由 Lead 导出。
 * 4. 子代理不共享上下文：工单 JSON 原样塞进提示词，必须自包含。
 */

const CONVENTIONS = `你是 Steam Navigator 的建模子代理（Builder），运行在用户正在使用的 Blender 4.4 中，Blender MCP 已连接。

【绝对规则】
1. 只允许在工单指定的集合内创建对象；场景中已有对象一律不得删除或修改。
2. 工单给出的前缀 / 集合 / 材质 / 尺寸 / 面数预算是硬约束。
3. 几何必须由参数表（横剖面站、分段、尺寸数组）生成，便于以后改数值重建；
   不要手工摆点，不要用布尔运算。
4. 只写 Blender 场景：不保存 .blend、不导出 .glb、不新建相机或灯光。
5. 场景里可能已有其他资产（例如 SN_Ship_Prototype 的 36 个对象），不要碰。`;

const BUILD_SCHEMA = {
  type: "object",
  properties: {
    ok: { type: "boolean" },
    collection: { type: "string" },
    root: { type: "string" },
    objects: {
      type: "array",
      items: {
        type: "object",
        properties: {
          name: { type: "string" },
          type: { type: "string" }
        },
        required: ["name", "type"],
        additionalProperties: false
      }
    },
    tris: { type: "number" },
    bbox: { type: "array", items: { type: "number" } },
    materials: { type: "array", items: { type: "string" } },
    notes: { type: "string" }
  },
  required: ["ok", "collection", "root", "objects", "tris", "bbox", "materials", "notes"],
  additionalProperties: false
};

const QA_SCHEMA = {
  type: "object",
  properties: {
    passed: { type: "boolean" },
    failures: { type: "array", items: { type: "string" } },
    checks: {
      type: "array",
      items: {
        type: "object",
        properties: {
          name: { type: "string" },
          ok: { type: "boolean" }
        },
        required: ["name", "ok"],
        additionalProperties: false
      }
    },
    notes: { type: "string" }
  },
  required: ["passed", "failures", "checks", "notes"],
  additionalProperties: false
};

function briefJson(b) {
  return JSON.stringify(b, null, 2);
}

function buildPrompt(b) {
  const materials = (b.materials || []).join(" / ");
  return `${CONVENTIONS}

【工单】
${briefJson(b)}

【你的任务】
按工单在 Blender 里创建这个物品，并返回 JSON。

【执行步骤】
1. 调 mcp__blender__get_scene_info(fields=["location","details"], limit=100) 确认场景；
   需要看某个根物体的子级时，用 root="<根对象名>"。
2. 用 mcp__blender__execute_blender_code 运行一个参数化建模脚本：
   - 集合名：${b.naming.collection}
   - 对象前缀：${b.naming.prefix}
   - 材质只用：${materials}
   - 轴心：${b.transform.pivot}；前向 ${b.transform.forward}；向上 ${b.transform.up}；单位 ${b.transform.unit}
   - 低模 flat shading；三角面数 ≤ ${b.tri_budget}
   - 允许重跑：若集合已存在，只删除该集合内以 ${b.naming.prefix} 开头的对象
3. 在同一段脚本里只读自检并 print：对象清单 / 三角面数 / 包围盒 / 材质 /
   非流形边 / 退化面 / 孤立点 / 材质槽越界。
4. 按 schema 返回 JSON。

【禁止】
- 禁止删除或修改 Camera、Light 以及任何已有资产对象；
- 禁止新建灯光/相机；
- 禁止为了达标而修改工单里的尺寸或预算。`;
}

function verifyPrompt(b) {
  const dims = JSON.stringify(b.dimensions || {});
  const mats = JSON.stringify(b.materials || []);
  return `你是独立质检子代理（Verifier），只读，不得修改场景。

【工单】
${briefJson(b)}

【检查项】
1. 命名与集合：新增对象是否全部以 ${b.naming.prefix} 开头、位于 ${b.naming.collection}。
2. 几何：三角面 ≤ ${b.tri_budget}；无孤立点 / 退化面 / 材质槽越界；闭合件非流形边 = 0。
3. 尺寸：世界包围盒与 ${dims} 的误差 ≤ ${(b.dimensions && b.dimensions.tolerance) || 0.1} m。
4. 材质：与 ${mats} 一致；单层曲面（帆/布/板）必须双面。
5. 回归：Camera、Light、SN_Ship_Prototype 等原有对象的数量与名称未变。
6. 视觉：调用 mcp__blender__look(mode="angles", views=["three_quarter","front"],
   shading="material")，判断轮廓是否可辨认、比例是否合理。

【规则】
- 不允许任何创建 / 删除 / 修改操作；execute_blender_code 只允许只读语句。
- 不以"通过检查"为目标：发现问题写进 failures，并给出可执行的修正建议。

【返回 JSON】passed / failures / checks / notes`;
}

const briefs = (args && args.briefs) || [];
if (!briefs.length) {
  return { error: "args.briefs 为空：没有可派发的工单", total: 0, results: [] };
}

phase("派发");
log(`收到 ${briefs.length} 张工单，串行执行（Blender 单写者）`);

const results = [];

for (let i = 0; i < briefs.length; i++) {
  const b = briefs[i];
  const n = `${i + 1}/${briefs.length}`;

  phase("逐件建模与质检");
  log(`[${n}] 建模 ${b.id}`);

  // Builder：唯一写者
  const built = await agent(buildPrompt(b), {
    label: `build:${b.id}`,
    phase: "逐件建模与质检",
    schema: BUILD_SCHEMA
  });

  if (!built || built.ok !== true) {
    results.push({ id: b.id, status: "build_failed", builder: built || null });
    log(`[${n}] ✗ ${b.id} 建模失败，跳过质检`);
    continue;
  }

  // 质检必须在 Builder 完全结束之后
  log(`[${n}] 质检 ${b.id}`);
  const qa = await agent(verifyPrompt(b), {
    label: `qa:${b.id}`,
    phase: "逐件建模与质检",
    schema: QA_SCHEMA
  });

  const status = qa && qa.passed === true ? "ready_for_review" : "qa_failed";
  results.push({ id: b.id, status, builder: built, qa: qa || null });
  log(`[${n}] ${status === "ready_for_review" ? "✓" : "✗"} ${b.id} → ${status}`);
}

phase("汇总");
const ready = results.filter((r) => r.status === "ready_for_review");
log(`待人工验收：${ready.length}/${results.length}`);

return {
  total: results.length,
  ready_for_review: ready.length,
  failed: results.filter((r) => r.status !== "ready_for_review").map((r) => r.id),
  results
};
