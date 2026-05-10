# 桌面猫宠物 Windows 版

这是一个基于 Electron 的 Windows 便携版桌面宠物应用，支持透明窗口、置顶、拖动、本地素材库、预览、顺序轮播和随机轮播。

## 支持素材

- 透明 GIF
- PNG / APNG
- 带透明通道的 WebM

普通 MP4 通常没有透明通道，不建议用于桌面透明宠物效果。

## 开发运行

在 Windows 上安装 Node.js LTS 后执行：

```bash
cd electron_app
npm install
npm run start
```

右键桌面宠物窗口打开设置面板，也可以通过系统托盘菜单打开设置或退出应用。

## 打包便携版 exe

```bash
cd electron_app
npm install
npm run dist:win
```

输出文件：

```text
electron_app/dist/DesktopCatPet-1.0.0-win-x64-portable.exe
```

当前打包配置已启用 ASAR、最大压缩、仅保留简体中文 Electron 语言包，并排除源码映射和 Markdown 文件，以减小便携版体积。
