const { app, BrowserWindow, dialog, ipcMain, Menu, screen } = require('electron');
const path = require('path');

let petWindow;

const supportedFilters = [
  { name: 'Transparent media', extensions: ['gif', 'png', 'apng', 'webm'] },
  { name: 'GIF', extensions: ['gif'] },
  { name: 'PNG/APNG', extensions: ['png', 'apng'] },
  { name: 'WebM with Alpha', extensions: ['webm'] }
];

function createWindow() {
  const display = screen.getPrimaryDisplay();
  const { width, height } = display.workAreaSize;
  const size = 320;

  petWindow = new BrowserWindow({
    width: size,
    height: size,
    x: Math.round(width / 2 - size / 2),
    y: Math.round(height / 2 - size / 2),
    transparent: true,
    frame: false,
    resizable: true,
    hasShadow: false,
    alwaysOnTop: true,
    skipTaskbar: false,
    backgroundColor: '#00000000',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false
    }
  });

  petWindow.setAlwaysOnTop(true, 'screen-saver');
  petWindow.loadFile(path.join(__dirname, 'renderer.html'));
}

app.whenReady().then(() => {
  Menu.setApplicationMenu(null);
  createWindow();
});

app.on('window-all-closed', () => {
  app.quit();
});

ipcMain.handle('choose-media', async () => {
  const result = await dialog.showOpenDialog(petWindow, {
    title: 'Choose transparent media',
    properties: ['openFile', 'multiSelections'],
    filters: supportedFilters
  });
  if (result.canceled) return [];
  return result.filePaths;
});

ipcMain.handle('set-window-size', async (_event, size) => {
  if (!petWindow) return;
  const next = Math.max(96, Math.min(720, Number(size) || 320));
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
