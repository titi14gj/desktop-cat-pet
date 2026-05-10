const { app, BrowserWindow, Tray, dialog, ipcMain, Menu, nativeImage, screen } = require('electron');
const path = require('path');
const { pathToFileURL } = require('url');

let petWindow;
let tray;

const APP_NAME = '桌面猫宠物';
const DEFAULT_SIZE = 320;
const MIN_SIZE = 96;
const MAX_SIZE = 720;
const iconPath = path.join(__dirname, '..', 'assets', 'icon.ico');

const supportedFilters = [
  { name: '透明媒体', extensions: ['gif', 'png', 'apng', 'webm'] },
  { name: 'GIF', extensions: ['gif'] },
  { name: 'PNG/APNG', extensions: ['png', 'apng'] },
  { name: '透明 WebM', extensions: ['webm'] }
];

function clampSize(size) {
  return Math.max(MIN_SIZE, Math.min(MAX_SIZE, Number(size) || DEFAULT_SIZE));
}

function getMediaKind(filePath) {
  return path.extname(filePath).toLowerCase() === '.webm' ? 'video' : 'image';
}

function toMediaItem(filePath) {
  return {
    path: filePath,
    name: path.basename(filePath),
    url: pathToFileURL(filePath).toString(),
    kind: getMediaKind(filePath)
  };
}

function showSettings() {
  if (!petWindow) return;
  if (petWindow.isMinimized()) petWindow.restore();
  petWindow.show();
  petWindow.webContents.send('show-settings');
}

function createTray() {
  if (tray) return;

  const icon = nativeImage.createFromPath(iconPath);
  tray = new Tray(icon);
  tray.setToolTip(APP_NAME);
  tray.setContextMenu(Menu.buildFromTemplate([
    { label: '打开设置', click: showSettings },
    { label: '退出', click: () => app.quit() }
  ]));
  tray.on('click', showSettings);
}

function createWindow() {
  const display = screen.getPrimaryDisplay();
  const { width, height } = display.workAreaSize;
  const size = DEFAULT_SIZE;

  petWindow = new BrowserWindow({
    title: APP_NAME,
    width: size,
    height: size,
    minWidth: MIN_SIZE,
    minHeight: MIN_SIZE,
    x: Math.round(width / 2 - size / 2),
    y: Math.round(height / 2 - size / 2),
    transparent: true,
    frame: false,
    resizable: true,
    show: false,
    hasShadow: false,
    alwaysOnTop: true,
    skipTaskbar: false,
    autoHideMenuBar: true,
    backgroundColor: '#00000000',
    icon: iconPath,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true
    }
  });

  petWindow.setAlwaysOnTop(true, 'screen-saver');
  petWindow.loadFile(path.join(__dirname, 'renderer.html'));
  petWindow.once('ready-to-show', () => petWindow.show());
}

const gotLock = app.requestSingleInstanceLock();
if (!gotLock) {
  app.quit();
} else {
  if (process.platform === 'win32') {
    app.setAppUserModelId('com.titi14gj.desktopcatpet.windows');
  }

  app.setName(APP_NAME);

  app.whenReady().then(() => {
    Menu.setApplicationMenu(null);
    createWindow();
    createTray();
  });

  app.on('second-instance', showSettings);

  app.on('window-all-closed', () => {
    app.quit();
  });
}

ipcMain.handle('choose-media', async () => {
  const result = await dialog.showOpenDialog(petWindow, {
    title: '选择透明媒体',
    buttonLabel: '添加',
    properties: ['openFile', 'multiSelections'],
    filters: supportedFilters
  });
  if (result.canceled) return [];
  return result.filePaths.map(toMediaItem);
});

ipcMain.handle('set-window-size', async (_event, size) => {
  if (!petWindow) return;
  const next = clampSize(size);
  const bounds = petWindow.getBounds();
  petWindow.setBounds({ ...bounds, width: next, height: next });
});

ipcMain.handle('set-always-on-top', async (_event, enabled) => {
  if (!petWindow) return;
  petWindow.setAlwaysOnTop(Boolean(enabled), 'screen-saver');
});

ipcMain.handle('quit-app', async () => {
  app.quit();
});
