# Desktop Cat Pet

桌面宠物应用，支持 macOS 原生版和 Windows/Electron 绿色版。当前版本不内置跳舞素材，需要在应用内添加本地透明媒体。

## 支持素材

- 透明 GIF
- PNG / APNG
- MOV / M4V with alpha，例如 ProRes 4444 或 HEVC with Alpha
- Windows/Electron 版额外推荐 WebM with alpha

普通 MP4 通常没有透明通道，不适合桌宠透明窗口。

## macOS 版

源码在：

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

## Windows 绿色版

源码在：

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
electron_app/dist/DesktopCatPet-1.0.0-portable.exe
```

这是 portable 绿色版，不需要安装。

## 使用

- 右键桌宠窗口打开设置
- 在 `Media Library...` 中添加并选择本地透明素材
- 媒体库支持预览
- `Playback` 支持 `Single`、`Sequential`、`Shuffle`
- `Rotate sec` 控制轮播间隔
- 可调整窗口大小、播放速度和是否置顶

## 图标

图标源文件在：

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
