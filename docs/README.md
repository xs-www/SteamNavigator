# Steam Navigator 设计文档索引

| 状态 | 含义 | 目录 |
| --- | --- | --- |
| Active | 正在讨论或持续修改 | [docs/design/](design/) |
| Finalized | 已经定稿，仍然有效 | [docs/specs/](specs/) |
| Archived | 已被替代、废弃或仅供追溯 | [docs/archive/](archive/) |

- 新方案、进行中的讨论写 [docs/design/](design/README.md)，不要直接写进 specs 或 archive。
- 已经定稿且仍然生效的契约 / 规范写 [docs/specs/](specs/README.md)；实现和评审以 specs 为准。
- 被替代、已完成交付且只剩追溯价值的内容写 [docs/archive/](archive/README.md)，不要在其中记录新决定。
- 本地截图仍放在 `docs/design/screenshots/`（已忽略、不入库）；静态代码文档 [docs/static/](static/) 由 `tools/gen_static_docs.mjs` 生成，不手工编辑。
