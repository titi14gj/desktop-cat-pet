const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('desktopPet', {
  chooseMedia: () => ipcRenderer.invoke('choose-media'),
  setWindowSize: (size) => ipcRenderer.invoke('set-window-size', size),
  setAlwaysOnTop: (enabled) => ipcRenderer.invoke('set-always-on-top', enabled),
  quit: () => ipcRenderer.invoke('quit-app')
});
