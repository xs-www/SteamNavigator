# 静态文档源码注释约定

重要源码的静态文档写在源码前 120 行，不再向 `tools/static_docs_data.mjs` 添加逐文件条目。

GDScript 示例：

```gdscript
## @static-doc
## 作用：一句话说明文件职责。
##
## - 关键依赖：`Foo`、`Bar`
##
## ## 契约与约束
## - 第一条必须长期成立的约束。
## - 第二条约束。
##
## ## 重点逻辑
## ### `public_method(...)`
## - 说明为什么这样做，而不是逐行复述实现。
## @end-static-doc
```

JavaScript 使用 `//`，Python/PowerShell 使用 `#`；生成器会剥离这些行注释前缀。`作用：`（或 `role:`）是唯一必填字段，其余内容按 Markdown 原样拼入生成页。

JSON、`.tscn`、`.tres` 等不适合写注释的文件使用镜像 sidecar：

```text
docs/static_headers/<源码相对路径>.md
```

sidecar 不写 `@static-doc` 标记，直接以 `作用：...` 开头，后续同样是 Markdown。源码注释优先于 sidecar，sidecar 优先于旧 `FILE_DOCS`。

运行与检查：

```powershell
node tools/gen_static_docs.mjs
node tools/gen_static_docs.mjs --check
node tools/gen_static_docs.mjs --help
```

旧 `tools/static_docs_data.mjs` 暂时保留，供尚未迁移的文件和模块级说明使用。迁移某个文件时，把等价内容移入源码注释或 sidecar，再删除对应 `FILE_DOCS` 条目。
