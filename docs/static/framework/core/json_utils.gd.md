# `framework/core/json_utils.gd`

> 作用：JSON 解析、规范化序列化、JSON Pointer 读写与深比较辅助。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `JsonUtils` | L1 |
| `NULL_VALUE` | L5 |
| `parse(text: String) -> Dictionary` | L8 |
| `parse_file(path: String) -> Dictionary` | L21 |
| `read_text(path: String) -> String` | L30 |
| `canonical_stringify(value: Variant, indent: String = "") -> String` | L39 |
| `pointer_escape(segment: String) -> String` | L71 |
| `pointer_unescape(segment: String) -> String` | L75 |
| `pointer_segments(pointer: String) -> PackedStringArray` | L79 |
| `pointer_get(root: Variant, pointer: String) -> Dictionary` | L89 |
| `pointer_apply(root: Variant, pointer: String, mode: String, value: Variant = null) -> Dictionary` | L111 |
| `format_pointer(segments: Array) -> String` | L168 |

## 契约与约束

- `canonical_stringify()` 排序键并把浮点量化到 1e-9，保证存档/加载指纹一致。
- `pointer_apply()` 支持 add/replace/remove；数组 `-` 仅用于末尾 add。
- JSON Pointer 对 `~` 与 `/` 做 RFC 6901 转义。

## 重点逻辑

### `canonical_stringify(value, indent)`

- 递归转换字典键为 String、StringName 为 String、PackedStringArray 为 Array。
- 整数值的浮点（含 JSON 往返产生的 1.0）归一化为 int；其余浮点四舍五入到 1e-9。
- 使用 `JSON.stringify(..., sort_keys=true, full_precision=true)`；这是状态哈希与存档共用的确定性表示。

### `pointer_apply(root, pointer, mode, value)`

- 禁止替换根指针；逐段下钻并在最后一层执行操作。
- 对象 replace 要求键已存在；remove 要求目标存在；数组 add 允许 index == size。
- 失败返回 `{ok:false,error}`，成功原地修改容器并返回 `{ok:true}`。

模块索引：[framework/core](./README.md)
