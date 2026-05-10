# 桌面猫宠物

桌面宠物应用，支持 macOS 原生版和 Windows/Electron 版。当前版本不内置跳舞素材，需要在应用内添加本地透明媒体。

## 支持素材

- 透明 GIF
- PNG / APNG
- MOV / M4V with alpha，例如 ProRes 4444 或 HEVC with Alpha
- Windows/Electron 版额外推荐 WebM with alpha

普通 MP4 通常没有透明通道，不适合桌面透明窗口。

## macOS 版

源码：

```text
macos_app/
```

打包：

```bash
./build_macos_app.sh
```

输出：

```text
build/DesktopCatPet.app
```

## Windows 版

源码：

```text
electron_app/
```

在 Windows 上安装 Node.js LTS 后：

```bash
cd electron_app
npm install
npm run dist:win
```

输出：

```text
electron_app/dist/DesktopCatPet-1.0.0-win-x64-portable.exe
```

这是 portable 便携版，不需要安装。Windows 版已启用单实例、系统托盘、中文界面、ASAR 和最大压缩。

## 使用

- 右键桌面宠物窗口打开设置
- 在“素材库”中添加并选择本地透明素材
- 素材库支持预览
- “播放方式”支持单个播放、顺序轮播、随机轮播
- “轮播间隔”控制切换时间
- 可调窗口大小、播放速度和是否置顶
- 系统托盘菜单可打开设置或退出应用

## 图标

图标源文件：

```text
assets/icons/desktop_cat_icon.png
```

macOS 图标：

```text
assets/icons/DesktopCatPet.icns
```

Windows 图标：

```text
electron_app/assets/icon.ico
```

重新生成 macOS `.icns`：

```bash
./scripts/build_app_icon.sh
```
