# Desktop Cat Pet

一个零依赖的 macOS/desktop 小猫桌宠原型。它会显示一个置顶、可拖动、可调整大小的宠物窗口，并支持按运行时长自动退出。

## 运行

推荐使用已打包的 macOS 原生 app：

```text
build/DesktopCatPet.app
```

也可以运行旧的 Python/Tk 原型：

```bash
python3 desktop_pet.py
```

如果 macOS 透明窗口没有显示，先用普通可见背景启动来确认程序窗口：

```bash
python3 desktop_pet.py --solid
```

## Windows 绿色版

Windows/Electron 版本在：

```text
electron_app/
```

在 Windows 上安装 Node.js LTS 后：

```bash
cd electron_app
npm install
npm run dist:win
```

会生成绿色免安装 exe：

```text
electron_app/dist/DesktopCatPet-1.0.0-portable.exe
```

## 使用你的猫咪动画

把生成好的猫咪跳舞 GIF 放到：

```text
assets/cat.gif
```

再次运行 Python 原型后会自动播放这段动画。如果没有这个文件，原型会显示内置的简笔跳舞猫。

当前已经生成了几段基于你猫咪照片的动画素材：

- `assets/cat.gif`：默认 AI 跳舞动画
- `assets/animations/ai_cat_dance/`：历史生成素材，不再打包进 app
- `assets/animations/realistic_slow_dance/`：历史生成素材，因绿边问题不再打包进 app
- `assets/spritesheets/realistic_slow_dance.png`：历史生成帧图，不再内置
- `assets/ai_cat_dance.gif`：AI 生成的猫咪跳舞 GIF
- `assets/ai_cat_dance.webp`：AI 生成的猫咪跳舞 WebP
- `assets/ai_cat_dance_spritesheet.png`：AI 生成的 4x4 跳舞帧图
- `assets/ai_cat_dance_frames/`：切好的透明 PNG 帧
- `assets/cat_dance_combo.gif`：左右摇摆 + 小弹跳
- `assets/cat_sway.gif`：左右摇摆
- `assets/cat_bounce.gif`：原地小跳
- `assets/cat_head_bop.gif`：点头律动
- `assets/cat_cutout.png`：猫咪主体抠图

想切换默认动画时，把喜欢的 GIF 覆盖成 `assets/cat.gif`，或者重新运行素材脚本：

```bash
/Users/titi14gj/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 scripts/generate_cat_animations.py
```

AI 跳舞素材来自 `assets/ai_cat_dance_spritesheet.png`，可以重新切帧导出：

```bash
/Users/titi14gj/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 scripts/build_ai_dance_from_spritesheet.py
```

## 操作

- 拖动猫咪窗口：按住猫咪拖动
- 打开设置：右键猫咪
- 选择素材：设置里点 `Media Library...`，添加并选择本地透明素材
- 预览素材：媒体库右侧会显示选中素材的预览图或视频首帧
- 添加本地素材：媒体库里点 `Add Local...`，支持透明 GIF、PNG/APNG、MOV、M4V
- 轮流播放：设置里的 `Playback` 支持 `Single`、`Sequential`、`Shuffle`
- 轮播间隔：设置里的 `Rotate sec` 控制多久切换一次素材
- 视频格式限制：MOV/M4V 必须是真正带 alpha 的视频，例如 ProRes 4444 或 HEVC with Alpha；普通 MP4 不支持透明，app 不再允许选择
- 当前版本不再内置跳舞动画，需要在媒体库中添加本地透明素材
- 调整速度：设置里的 `Frame delay`，数值越大越慢；视频会按比例降速或加速
- 退出：设置面板里点 `Quit`，或从菜单退出
- 设置项：本地素材、动画选择、播放速度、宠物大小、运行时间、是否置顶

## 后续素材流程

你把宠物猫照片发来后，我可以帮你生成几段适合桌宠循环播放的跳舞动画素材，例如：

- 轻轻左右摇摆
- 原地小跳舞
- 挥爪打招呼
- 工作陪伴待机动作

建议导出为透明背景 GIF 或 WebP，再转成 `assets/cat.gif` 使用。
