// @static-doc
// 作用：在 SNBattleSim/user_data 中原子读写模拟器工程，作为浏览器 localStorage 之外的明确持久化副本。
//
// ## 契约与约束
// - 只读写固定文件 user_data/workspace.json，不接受客户端路径。
// - 工程必须是对象且 JSON 不超过 5 MB；写入经临时文件原子替换。
// @end-static-doc

import fs from "node:fs";
import path from "node:path";

const MAX_BYTES = 5_000_000;

export function readWorkspace(userDataRoot) {
  const target = path.join(userDataRoot, "workspace.json");
  if (!fs.existsSync(target)) return null;
  if (fs.statSync(target).size > MAX_BYTES) throw new Error("工程文件超过 5 MB");
  const value = JSON.parse(fs.readFileSync(target, "utf8"));
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error("工程文件必须是 JSON 对象");
  return value;
}

export function writeWorkspace(userDataRoot, value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error("工程数据必须是 JSON 对象");
  const serialized = `${JSON.stringify(value, null, 2)}\n`;
  if (Buffer.byteLength(serialized) > MAX_BYTES) throw new Error("工程数据超过 5 MB");
  fs.mkdirSync(userDataRoot, { recursive: true });
  const target = path.join(userDataRoot, "workspace.json"); const temporary = path.join(userDataRoot, "workspace.json.tmp");
  fs.writeFileSync(temporary, serialized, "utf8"); fs.renameSync(temporary, target);
  return target;
}
