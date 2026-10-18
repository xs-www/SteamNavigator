# 磁盘工作区

启动本地服务后，Mod Maker 会把当前项目写入这里：

```text
mods/<mod_id>/
├── .snmodproj.json     编辑器项目（含本地化、资源附件与 UI 元数据）
├── manifest.json
├── content/*.json
├── localization/*.json
└── assets/...
```

- 这个目录本身可以直接作为松散模组目录使用；`.snmodproj.json` 不会被 `manifest.content` 引用。
- 服务保存时会重建 `<mod_id>/` 目录；不要把手工维护、但未同步进项目的文件放在这里。
- 目录内容默认被 `.gitignore` 忽略，避免把个人制作中的内容提交进仓库。
- 只通过 `node SNModMaker/tools/serve.mjs` 提供 API 时才会写入；纯静态托管时改用 IndexedDB。
