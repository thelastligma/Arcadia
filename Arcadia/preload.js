const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('electron', {
  windowControls: {
    minimize: () => ipcRenderer.invoke('window-controls', 'minimize'),
    maximize: () => ipcRenderer.invoke('window-controls', 'maximize'),
    close: () => ipcRenderer.invoke('window-controls', 'close')
  },
  executeScript: (script) => ipcRenderer.invoke('execute-script', script),
  // Sends script content to a local HTTP server by scanning ports and POSTing to /execute
  sendToLocalServer: (script, startPort = 6969, endPort = 7069) => ipcRenderer.invoke('send-to-local-server', script, startPort, endPort),
  // Send script to a user-provided MacSploit API URL (POST to /execute)
  sendToMacsploit: (script, url) => ipcRenderer.invoke('send-to-macsploit', script, url),
  // (openLocalServer removed)
  checkHydrogen: () => ipcRenderer.invoke('check-hydrogen'),
  checkMacsploit: () => ipcRenderer.invoke('check-macsploit'),
  toggleAlwaysOnTop: () => ipcRenderer.invoke('toggle-always-on-top'),
  killRoblox: () => ipcRenderer.invoke('kill-roblox'),
  getAlwaysOnTop: () => ipcRenderer.invoke('get-always-on-top'),
  showSaveDialog: async (options) => ipcRenderer.invoke('show-save-dialog', options),
  showOpenDialog: async (options) => ipcRenderer.invoke('show-open-dialog', options),
  saveFile: async (filePath, content) => ipcRenderer.invoke('save-file', filePath, content),
  openFile: async (filePath) => ipcRenderer.invoke('open-file', filePath),
  // Returns the port number where the bundled local API server is listening
  getApiPort: () => ipcRenderer.invoke('get-api-port')
});