# `SNModMaker/start.bat`

> 作用：Windows 双击启动 SNModMaker；缺少 Node.js 时先安装最新 LTS，再启动本地服务并打开浏览器。

- 类型：项目配置/数据文件

## 契约与约束

- 优先使用系统已有的 `node.exe`；缺失时先通过 winget 安装，失败或不可用时回退到 nodejs.org 官方 MSI。
- 服务保持在当前命令窗口前台运行，关闭窗口即停止服务。
- 设置 `PORT` 可覆盖默认端口 8099，脚本打开的地址与服务端口保持一致。
- 设置 `STEAM_NAVIGATOR_NO_BROWSER` 可跳过自动打开浏览器，供自动化验证使用。

模块索引：[SNModMaker](./README.md)
