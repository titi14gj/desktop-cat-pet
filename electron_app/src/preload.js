const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('desktopPet', {
  chooseMedia: () => ipcRenderer.invoke('choose-media'),
  setWindowSize: (size) => ipcRenderer.invoke('set-window-size', size),
  setAlwaysOnTop: (enabled) => ipcRenderer.invoke('set-always-on-top', enabled),
  quit: () => ipcRenderer.invoke('quit-app'),
  onShowSettings: (callback) => {
    if (typeof callback !== 'function') return;
    ipcRenderer.on('show-settings', callback);
  }
});
