const { app, BrowserWindow, Tray, dialog, ipcMain, Menu, nativeImage, screen } = require('electron');
const fs = require('fs');
const path = require('path');
const { pathToFileURL } = require('url');

let petWindow;
let settingsWindow;
let tray;
let state;
let dragState = null;
let dragTimer = null;

const APP_NAME = '桌面猫宠物';
const DEFAULT_SIZE = 320;
const MIN_SIZE = 96;
const MAX_SIZE = 720;
const iconPath = path.join(__dirname, '..', 'assets', 'icon.ico');

const defaultState = {
  media: [],
  currentIndex: -1,
  playbackMode: 'single',
  rotateSeconds: 60,
  size: DEFAULT_SIZE,
  speed: 1,
  alwaysOnTop: true,
  showFrame: true,
  lockPosition: false,
  crop: {
    enabled: false,
    zoom: 1,
    offsetX: 0,
    offsetY: 0
  }
};

const supportedFilters = [
  { name: '透明媒体', extensions: ['gif', 'png', 'apng', 'webm'] },
  { name: 'GIF', extensions: ['gif'] },
  { name: 'PNG/APNG', extensions: ['png', 'apng'] },
  { name: '透明 WebM', extensions: ['webm'] }
];

function statePath() {
  return path.join(app.getPath('userData'), 'pet-state.json');
}

function clamp(value, min, max, fallback) {
  const number = Number(value);
  if (!Number.isFinite(number)) return fallback;
  return Math.max(min, Math.min(max, number));
}

function normalizeCrop(crop = {}) {
  return {
    enabled: Boolean(crop.enabled),
    zoom: clamp(crop.zoom, 1, 6, 1),
    offsetX: clamp(crop.offsetX, -100, 100, 0),
    offsetY: clamp(crop.offsetY, -100, 100, 0)
  };
}

function normalizeMediaItem(item) {
  if (typeof item === 'string') return toMediaItem(item);
  if (!item || typeof item !== 'object' || !item.path) return null;
  return {
    path: item.path,
    name: item.name || path.basename(item.path),
    url: item.url || pathToFileURL(item.path).toString(),
    kind: item.kind || getMediaKind(item.path)
  };
}

function normalizeState(next = {}) {
  const media = Array.isArray(next.media) ? next.media.map(normalizeMediaItem).filter(Boolean) : [];
  const currentIndex = media.length === 0 ? -1 : clamp(next.currentIndex, 0, media.length - 1, 0);

  return {
    media,
    currentIndex,
    playbackMode: ['single', 'sequential', 'shuffle'].includes(next.playbackMode) ? next.playbackMode : defaultState.playbackMode,
    rotateSeconds: clamp(next.rotateSeconds, 5, 3600, defaultState.rotateSeconds),
    size: clamp(next.size, MIN_SIZE, MAX_SIZE, defaultState.size),
    speed: clamp(next.speed, 0.25, 2, defaultState.speed),
    alwaysOnTop: typeof next.alwaysOnTop === 'boolean' ? next.alwaysOnTop : defaultState.alwaysOnTop,
    showFrame: typeof next.showFrame === 'boolean' ? next.showFrame : defaultState.showFrame,
    lockPosition: typeof next.lockPosition === 'boolean' ? next.lockPosition : defaultState.lockPosition,
    crop: normalizeCrop(next.crop)
  };
}

function loadState() {
  try {
    const saved = JSON.parse(fs.readFileSync(statePath(), 'utf8'));
    state = normalizeState({ ...defaultState, ...saved, crop: { ...defaultState.crop, ...saved.crop } });
  } catch {
    state = normalizeState(defaultState);
  }
}

function saveState() {
  fs.mkdirSync(path.dirname(statePath()), { recursive: true });
  fs.writeFileSync(statePath(), JSON.stringify(state, null, 2));
}

function broadcastState() {
  for (const window of [petWindow, settingsWindow]) {
    if (window && !window.isDestroyed()) {
      window.webContents.send('state-updated', state);
    }
  }
}

function updateState(patch = {}) {
  const merged = {
    ...state,
    ...patch,
    crop: { ...state.crop, ...(patch.crop || {}) }
  };
  state = normalizeState(merged);
  if (state.lockPosition) stopWindowDrag();
  saveState();
  applyWindowState();
  broadcastState();
  return state;
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

function applyWindowState() {
  if (!petWindow || petWindow.isDestroyed()) return;
  const bounds = petWindow.getBounds();
  petWindow.setBounds({ ...bounds, width: state.size, height: state.size });
  petWindow.setAlwaysOnTop(Boolean(state.alwaysOnTop), 'screen-saver');
}

function placeSettingsWindow() {
  if (!petWindow || !settingsWindow || petWindow.isDestroyed() || settingsWindow.isDestroyed()) return;

  const petBounds = petWindow.getBounds();
  const settingsBounds = settingsWindow.getBounds();
  const display = screen.getDisplayMatching(petBounds);
  const workArea = display.workArea;
  const gap = 12;
  const rightX = petBounds.x + petBounds.width + gap;
  const leftX = petBounds.x - settingsBounds.width - gap;
  const x = rightX + settingsBounds.width <= workArea.x + workArea.width ? rightX : Math.max(workArea.x, leftX);
  const y = Math.max(workArea.y, Math.min(petBounds.y, workArea.y + workArea.height - settingsBounds.height));

  settingsWindow.setBounds({ ...settingsBounds, x, y });
}

function showSettings() {
  if (!settingsWindow || settingsWindow.isDestroyed()) {
    createSettingsWindow();
    return;
  }
  if (settingsWindow.isMinimized()) settingsWindow.restore();
  placeSettingsWindow();
  settingsWindow.setAlwaysOnTop(true, 'screen-saver');
  settingsWindow.show();
  settingsWindow.focus();
  settingsWindow.webContents.send('state-updated', state);
}

function stopWindowDrag() {
  if (dragTimer) clearInterval(dragTimer);
  dragTimer = null;
  dragState = null;
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

function createPetWindow() {
  const display = screen.getPrimaryDisplay();
  const { width, height } = display.workAreaSize;
  const size = state.size;

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
    resizable: false,
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

  petWindow.loadFile(path.join(__dirname, 'renderer.html'));
  petWindow.webContents.on('context-menu', (event) => {
    event.preventDefault();
    showSettings();
  });
  petWindow.on('resize', () => {
    const bounds = petWindow.getBounds();
    if (bounds.width !== state.size || bounds.height !== state.size) {
      petWindow.setBounds({ ...bounds, width: state.size, height: state.size });
    }
  });
  petWindow.once('ready-to-show', () => {
    applyWindowState();
    petWindow.show();
    broadcastState();
  });
}

function createSettingsWindow() {
  settingsWindow = new BrowserWindow({
    title: `${APP_NAME} 设置`,
    width: 420,
    height: 640,
    minWidth: 380,
    minHeight: 520,
    show: false,
    autoHideMenuBar: true,
    backgroundColor: '#f9f9f9',
    icon: iconPath,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true
    }
  });

  settingsWindow.loadFile(path.join(__dirname, 'settings.html'));
  settingsWindow.once('ready-to-show', () => {
    placeSettingsWindow();
    settingsWindow.setAlwaysOnTop(true, 'screen-saver');
    settingsWindow.show();
    settingsWindow.webContents.send('state-updated', state);
  });
  settingsWindow.on('closed', () => {
    settingsWindow = null;
  });
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
    loadState();
    createPetWindow();
    createTray();
  });

  app.on('second-instance', showSettings);

  app.on('window-all-closed', () => {
    app.quit();
  });
}

ipcMain.handle('get-state', async () => state);

ipcMain.handle('update-state', async (_event, patch) => updateState(patch));

ipcMain.handle('choose-media', async () => {
  showSettings();
  const result = await dialog.showOpenDialog(settingsWindow || petWindow, {
    title: '选择透明媒体',
    buttonLabel: '添加',
    properties: ['openFile', 'multiSelections'],
    filters: supportedFilters
  });
  if (result.canceled) return [];
  return result.filePaths.map(toMediaItem);
});

ipcMain.handle('open-settings', async () => {
  showSettings();
});

ipcMain.handle('start-window-drag', async () => {
  if (!petWindow || petWindow.isDestroyed()) return;
  if (state.lockPosition) return;
  const cursor = screen.getCursorScreenPoint();
  const bounds = petWindow.getBounds();

  stopWindowDrag();
  dragState = {
    cursor,
    bounds
  };
  dragTimer = setInterval(() => {
    if (!dragState || !petWindow || petWindow.isDestroyed()) {
      stopWindowDrag();
      return;
    }

    const nextCursor = screen.getCursorScreenPoint();
    petWindow.setPosition(
      dragState.bounds.x + nextCursor.x - dragState.cursor.x,
      dragState.bounds.y + nextCursor.y - dragState.cursor.y
    );
  }, 16);
});

ipcMain.handle('stop-window-drag', async () => {
  stopWindowDrag();
});

ipcMain.handle('quit-app', async () => {
  app.quit();
});
