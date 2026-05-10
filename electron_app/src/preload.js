const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('desktopPet', {
  getState: () => ipcRenderer.invoke('get-state'),
  updateState: (patch) => ipcRenderer.invoke('update-state', patch),
  chooseMedia: () => ipcRenderer.invoke('choose-media'),
  openSettings: () => ipcRenderer.invoke('open-settings'),
  startWindowDrag: () => ipcRenderer.invoke('start-window-drag'),
  stopWindowDrag: () => ipcRenderer.invoke('stop-window-drag'),
  quit: () => ipcRenderer.invoke('quit-app'),
  onStateUpdated: (callback) => {
    if (typeof callback !== 'function') return;
    ipcRenderer.on('state-updated', (_event, state) => callback(state));
  }
});
