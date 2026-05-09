# Desktop Cat Pet for Windows

Electron 绿色免安装版桌宠。支持透明窗口、置顶、拖动、本地媒体库、预览、顺序/随机轮播。

## 支持素材

- 透明 GIF
- PNG / APNG
- WebM with alpha

普通 MP4 通常没有透明通道，不建议用于桌宠透明效果。

## 开发运行

在 Windows 上安装 Node.js LTS 后：

```bash
cd electron_app
npm install
npm run start
```

右键桌宠窗口打开设置面板。

## 打包绿色 exe

```bash
cd electron_app
npm install
npm run dist:win
```

输出文件：

```text
electron_app/dist/DesktopCatPet-1.0.0-portable.exe
```

这个 exe 是 portable 绿色版，不需要安装。
