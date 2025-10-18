// Window control functions
const minimizeWindow = async () => {
  if (window.electron?.windowControls) {
      await window.electron.windowControls.minimize();
  }
};

const maximizeWindow = async () => {
  if (window.electron?.windowControls) {
      await window.electron.windowControls.maximize();
  }
};

const closeWindow = async () => {
  if (window.electron?.windowControls) {
      await window.electron.windowControls.close();
  }
};

// Update window control styles and setup listeners
async function initializeAlwaysOnTop() {
  const toggle = document.getElementById('alwaysOnTopToggle');
  if (toggle && window.electron?.getAlwaysOnTop) {
      const isAlwaysOnTop = await window.electron.getAlwaysOnTop();
      toggle.checked = isAlwaysOnTop;
      
      toggle.addEventListener('change', async () => {
          await window.electron.toggleAlwaysOnTop();
      });
  }
}

document.addEventListener('DOMContentLoaded', () => {
  initializeAlwaysOnTop();
  const minimizeButton = document.querySelector('.rapeqwdqwd:nth-child(1)');
  const maximizeButton = document.querySelector('.rapeqwdqwd:nth-child(2)');
  const closeButton = document.querySelector('.rapeqwdqwd:nth-child(3)');

  minimizeButton?.addEventListener('click', minimizeWindow);
  maximizeButton?.addEventListener('click', maximizeWindow);
  closeButton?.addEventListener('click', closeWindow);

  // Listen for window state changes
  if (window.electron?.onWindowStateChange) {
      window.electron.onWindowStateChange((state) => {
          // Update UI based on window state if needed
          console.log('Window state changed:', state);
      });
  }

  // wire settings toggles to main process
  const redirectErrors = document.getElementById('redirectErrorsToggle');
  if (redirectErrors) {
    redirectErrors.addEventListener('change', () => {
      window.electron.setSetting('RedirectErrors', redirectErrors.checked);
      showToast('RedirectErrors set to ' + redirectErrors.checked, 2000);
    });
  }

  const wsToggle = document.getElementById('wsToggle');
  if (wsToggle) {
    wsToggle.addEventListener('change', () => {
      window.electron.setSetting('WSToggle', wsToggle.checked);
      showToast('WSToggle set to ' + wsToggle.checked, 2000);
    });
  }

  // ensure Execute button binding (uses id executeBtn)
  const execBtn = document.getElementById('executeBtn');
  if (execBtn) execBtn.addEventListener('click', executeCurrentScript);
});

// Add window control styles
const windowControlStyles = document.createElement('style');
windowControlStyles.textContent = `
  .window-controls {
      display: flex;
      gap: 0;
      -webkit-app-region: no-drag;
  }
  .rapeqwdqwd {
      width: 46px;
      height: 32px;
      font-size: 12px;
      display: flex;
      align-items: center;
      justify-content: center;
      background: transparent;
      border: none;
      outline: none;
      color: var(--text-secondary);
      cursor: pointer;
      transition: all 0.2s ease;
      -webkit-app-region: no-drag;
      user-select: none;
  }
  .rapeqwdqwd:hover {
      background-color: var(--bg-tab);
  }
  .rapeqwdqwd:last-child:hover {
      background-color: #e81123;
      color: white;
  }
  .controls {
      -webkit-app-region: no-drag;
  }
  .header {
      -webkit-app-region: drag;
  }
  .header .logo,
  .header button,
  .header .controls {
      -webkit-app-region: no-drag;
  }
`;
document.head.appendChild(windowControlStyles);

// Tauri helpers: if running under Tauri, use its fs and invoke APIs
async function tauriChangeSetting(setting, value) {
  try {
    const tauriFs = window.__TAURI__?.fs;
    const tauriPath = window.__TAURI__?.path;
    const tauriInvoke = window.__TAURI__?.invoke;
    if (!tauriFs || !tauriInvoke) throw new Error('Tauri APIs not available');

    const { exists, writeTextFile, readTextFile, BaseDirectory } = tauriFs;

    const settingsPath = 'Opiumware/modules/settings';
    const existsBool = await exists(settingsPath, { dir: BaseDirectory.Home });
    if (!existsBool) {
      const defaulting = 'RedirectErrors false\nWSToggle true';
      await writeTextFile(settingsPath, defaulting, { dir: BaseDirectory.Home });
    }

    const fileText = await readTextFile(settingsPath, { dir: BaseDirectory.Home });
    const existing = {};
    fileText.split('\n').forEach(line => {
      const [k, v] = line.split(' ');
      if (k) existing[k] = v;
    });
    existing[setting] = value ? 'true' : 'false';
    const allSettings = Object.entries(existing).map(([k, v]) => `${k} ${v}`).join('\n');
    await writeTextFile(settingsPath, allSettings, { dir: BaseDirectory.Home });
    return { success: true };
  } catch (e) {
    return { success: false, error: e && e.message ? e.message : String(e) };
  }
}

async function tauriExecuteScript(script, port = 'ALL') {
  try {
    const tauriInvoke = window.__TAURI__?.invoke;
    if (!tauriInvoke) throw new Error('Tauri invoke not available');
    // prepend OpiumwareScript if not present
    const code = script.startsWith('OpiumwareScript') ? script : `OpiumwareScript ${script}`;
    const res = await tauriInvoke('OpiumwareExecution', { code, port });
    return { success: true, result: res };
  } catch (e) {
    return { success: false, error: e && e.message ? e.message : String(e) };
  }
}

// Wrap setting call so UI toggles use Electron or Tauri depending on environment
async function setSettingBackend(key, value) {
  if (window.__TAURI__ && window.__TAURI__.invoke) {
    return await tauriChangeSetting(key, value);
  }
  if (window.electron && window.electron.setSetting) {
    return await window.electron.setSetting(key, value);
  }
  return { success: false, error: 'No backend available' };
}

async function executeCurrentScript() {
  console.log('executeCurrentScript called');
  try {
    showToast('Executing script...', 1000);

    const script = (typeof editor !== 'undefined' && editor) ? editor.getValue() : '';
    console.log('Script to send:', script.slice(0, 200));

    if (window.__TAURI__ && window.__TAURI__.invoke) {
      const res = await tauriExecuteScript(script, 'ALL');
      console.log('tauri execute response:', res);
      if (res && res.success && res.result) showToast(res.result, 4000);
      else if (res && res.error) showToast('Error: ' + res.error, 6000);
      else showToast('Execute completed', 3000);
      return;
    }

    if (!window.electron?.executeScript) {
      const msg = 'No backend execute API available in renderer';
      console.error(msg);
      showToast(msg, 5000);
      return;
    }

    const res = await window.electron.executeScript(script);
    console.log('executeScript response:', res);

    if (res && res.result) showToast(res.result, 4000);
    else if (res && res.error) showToast('Error: ' + res.error, 6000);
    else showToast('Execute completed', 3000);
  } catch (err) {
    console.error('executeCurrentScript error', err);
    showToast('Execution failed: ' + (err && err.message ? err.message : err), 6000);
  }
}

async function injectDll() {
  if (window.electron?.inject) {
      const res = await window.electron.inject();
      if (res && res.error) showToast('Inject error: ' + res.error, 4000);
      else showToast('Inject result: ' + JSON.stringify(res), 3000);
  }
}

async function killRoblox() {
  if (window.electron?.killRoblox) {
      const res = await window.electron.killRoblox();
      if (res && res.error) showToast('Kill error: ' + res.error, 4000);
      else showToast('Roblox killed', 2000);
  }
}

function saveSettings() {
  const settings = {
      alwaysOnTop: document.getElementById('alwaysOnTopToggle').checked,
      autoInject: document.getElementById('autoInjectToggle').checked,
      theme: document.getElementById('themeSelector').value,
  };
  localStorage.setItem('seleneSettings', JSON.stringify(settings));
}

function loadSettings() {
  const settings = JSON.parse(localStorage.getItem('seleneSettings')) || {};

  if (settings.alwaysOnTop !== undefined) {
      const toggle = document.getElementById('alwaysOnTopToggle');
      toggle.checked = settings.alwaysOnTop;
  }

  if (settings.autoInject !== undefined) {
      const autoInjectToggle = document.getElementById('autoInjectToggle');
      autoInjectToggle.checked = settings.autoInject;
  }

  if (settings.theme) {
      const themeSelector = document.getElementById('themeSelector');
      themeSelector.value = settings.theme;
      applyTheme(settings.theme);
  }
}


async function saveFile() {
  const { filePath, canceled } = await window.electron.showSaveDialog({
      title: 'Save File',
      defaultPath: 'untitled.lua',
      filters: [{ name: 'Lua Files', extensions: ['lua'] }]
  });

  if (!canceled && filePath) {
      const content = editor.getValue();
      await window.electron.saveFile(filePath, content);
      showToast(`File saved to ${filePath}`, 3000);
  }
}

async function openFile() {
  const { filePaths, canceled } = await window.electron.showOpenDialog({
      title: 'Open File',
      filters: [{ name: 'Lua Files', extensions: ['lua'] }],
      properties: ['openFile']
  });

  if (!canceled && filePaths && filePaths[0]) {
      const content = await window.electron.openFile(filePaths[0]);
      if (content) {
          editor.setValue(content);
          editor.clearSelection();
          showToast(`Opened ${filePaths[0]}`, 3000);
      }
  }
}

async function runExample() {
  try {
    if (window.execute) {
      const execRes = await window.execute("OpiumwareScript print('Hello!')", 'ALL');
      if (execRes && execRes.success) showToast(`Execute: ${execRes.message || 'OK'}`, 4000);
      else if (execRes && execRes.error) showToast(`Execute error: ${execRes.error}`, 5000);
    }

    if (window.setting) {
      const setRes = await window.setting('RedirectErrors', true);
      if (setRes && setRes.success) showToast('RedirectErrors set to true', 3000);
      else if (setRes && setRes.error) showToast(`Set error: ${setRes.error}`, 4000);
    }
  } catch (err) {
    console.error('runExample failed', err);
    showToast('runExample failed: ' + (err && err.message ? err.message : err), 5000);
  }
}

// ensure Execute button binding (uses id executeBtn)
const execBtn = document.getElementById('executeBtn');
if (execBtn) execBtn.removeEventListener('click', executeCurrentScript); // safe remove
if (execBtn) execBtn.addEventListener('click', executeCurrentScript);

// Expose functions to global window so inline onclick handlers work and add explicit binding for the Execute button
window.executeCurrentScript = executeCurrentScript;
window.injectDll = injectDll;
window.killRoblox = killRoblox;
window.saveFile = saveFile;
window.openFile = openFile;
window.runExample = runExample;
window.clearEditor = clearEditor;

// Expose electron-only API aliases for developer console and compatibility with the user's example API
window.execute = async (code, port = 'ALL') => {
  if (!window.electron || !window.electron.executeScript) throw new Error('Electron execute API unavailable');
  return await window.electron.executeScript(code, port);
};

window.setting = async (key, value) => {
  if (!window.electron || !window.electron.setSetting) throw new Error('Electron setting API unavailable');
  return await window.electron.setSetting(key, value);
};

// Override executeCurrentScript to use electron-only call (matches the user's API)
async function executeCurrentScript() {
  console.log('executeCurrentScript called (electron-only)');
  try {
    showToast('Executing script...', 1000);

    const script = (typeof editor !== 'undefined' && editor) ? editor.getValue() : '';
    console.log('Script to send:', script.slice(0, 200));

    if (!window.execute && !window.electron?.executeScript) {
      const msg = 'No backend execute API available in renderer';
      console.error(msg);
      showToast(msg, 5000);
      return;
    }

    // Prefer the exposed window.execute alias so callers can use execute(code, port)
    const res = await (window.execute ? window.execute(script, 'ALL') : window.electron.executeScript(script, 'ALL'));
    console.log('execute response:', res);

    // handle structured main.js response
    if (res && res.success) {
      showToast(res.message || `Sent to port ${res.port}`, 4000);
      console.log('Execution details:', res);
    } else if (res && res.error) {
      showToast('Error: ' + res.error, 6000);
      console.error('Execute error details:', res);
    } else {
      showToast('Execute completed', 3000);
    }
  } catch (err) {
    console.error('executeCurrentScript error', err);
    showToast('Execution failed: ' + (err && err.message ? err.message : err), 6000);
  }
}
