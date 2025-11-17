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

  // Refresh executor status on load and every 5 seconds
  if (window.electron?.checkHydrogen && window.electron?.checkMacsploit) {
    refreshStatus();
    setInterval(refreshStatus, 5000);
  }
});

// Update status dots based on health checks
async function refreshStatus() {
  try {
    const hydroPort = await window.electron.checkHydrogen();
    const macPort = await window.electron.checkMacsploit();

    const statusDot = document.getElementById('status-dot');

    // Decide which executor is currently selected
    const executorEl = document.getElementById('executorSelector');
    const executor = executorEl ? executorEl.value : (localStorage.getItem('seleneSettings') ? JSON.parse(localStorage.getItem('seleneSettings')).executor : 'hydrogen');

    if (executor === 'hydrogen') {
      // show just executor + port in bar; dot color indicates status
      if (hydroPort) {
        statusDot.classList.remove('red');
        statusDot.classList.add('green');
      } else {
        statusDot.classList.remove('green');
        statusDot.classList.add('red');
      }
    } else if (executor === 'macsploit') {
      if (macPort) {
        statusDot.classList.remove('red');
        statusDot.classList.add('green');
      } else {
        statusDot.classList.remove('green');
        statusDot.classList.add('red');
      }
    } else {
      // fallback: show hydrogen info
      if (hydroPort) {
        statusDot.classList.remove('red');
        statusDot.classList.add('green');
      } else {
        statusDot.classList.remove('green');
        statusDot.classList.add('red');
      }
    }
  } catch (e) {
    console.error('Status refresh failed:', e);
  }
}

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

// Port ranges
const HYDROGEN_START = 6969;
const HYDROGEN_END = 7069;
const MACSPLOIT_START = 5553;
const MACSPLOIT_END = 5562;

// Selected ports (persisted in localStorage)
let selectedHydrogenPort = Number(localStorage.getItem('selectedHydrogenPort')) || HYDROGEN_START;
let selectedMacsploitPort = Number(localStorage.getItem('selectedMacsploitPort')) || MACSPLOIT_START;

function updateExecutorPortBar() {
  const barExecutor = document.getElementById('bar-executor');
  const barPort = document.getElementById('bar-port');
  if (!barExecutor || !barPort) return;
  const executorEl = document.getElementById('executorSelector');
  const executor = executorEl ? executorEl.value : (localStorage.getItem('seleneSettings') ? JSON.parse(localStorage.getItem('seleneSettings')).executor : 'hydrogen');
  if (executor === 'macsploit') {
    barExecutor.textContent = 'MacSploit';
    barPort.textContent = String(selectedMacsploitPort);
  } else {
    barExecutor.textContent = 'Hydrogen';
    barPort.textContent = String(selectedHydrogenPort);
  }
}

document.addEventListener('DOMContentLoaded', () => {
  // When executor selection changes, refresh status and update bar
  const execSel = document.getElementById('executorSelector');
  if (execSel) {
    execSel.addEventListener('change', () => {
      refreshStatus();
      updateExecutorPortBar();
      saveSettings();
    });
  }

  // Click on the top bar cycles the port for the selected executor
  const bar = document.getElementById('executor-port-bar');
  if (bar) {
    bar.addEventListener('click', (e) => {
      const executorEl = document.getElementById('executorSelector');
      const executor = executorEl ? executorEl.value : (localStorage.getItem('seleneSettings') ? JSON.parse(localStorage.getItem('seleneSettings')).executor : 'hydrogen');
      if (executor === 'macsploit') {
        selectedMacsploitPort++;
        if (selectedMacsploitPort > MACSPLOIT_END) selectedMacsploitPort = MACSPLOIT_START;
        localStorage.setItem('selectedMacsploitPort', String(selectedMacsploitPort));
      } else {
        selectedHydrogenPort++;
        if (selectedHydrogenPort > HYDROGEN_END) selectedHydrogenPort = HYDROGEN_START;
        localStorage.setItem('selectedHydrogenPort', String(selectedHydrogenPort));
      }
      updateExecutorPortBar();
    });
  }

  // initialize bar
  updateExecutorPortBar();
});

async function executeCurrentScript() {
  if (window.electron?.executeScript) {
      const script = editor.getValue();
      await window.electron.executeScript(script);
  }
}

// Send the current editor content to a local HTTP server (scans ports and POSTs)
async function sendToServer() {
  const script = editor.getValue();
  const executorEl = document.getElementById('executorSelector');
  const executor = executorEl ? executorEl.value : (localStorage.getItem('seleneSettings') ? JSON.parse(localStorage.getItem('seleneSettings')).executor : 'hydrogen');

  try {
    // Fixed port ranges: Hydrogen 6969-7069, MacSploit 5553-5562
    const HYDROGEN_START = 6969;
    const HYDROGEN_END = 7069;
    const MACSPLOIT_START = 5553;
    const MACSPLOIT_END = 5562;

    if (!window.electron?.sendToLocalServer) {
      showToast('Local executor API not available.', 3000);
      return;
    }

    if (executor === 'hydrogen') {
      showToast('Searching for Hydrogen local servers...', 3000);
      const result = await window.electron.sendToLocalServer(script, HYDROGEN_START, HYDROGEN_END);
      showToast('Script sent to Hydrogen successfully.', 4000);
      console.log('Hydrogen response:', result);
    } else if (executor === 'macsploit') {
      // Try each default MacSploit port by posting directly to that host:port
      showToast('Searching for MacSploit servers on local ports...', 3000);
      let success = false;
      let lastErr = null;
      for (let port = MACSPLOIT_START; port <= MACSPLOIT_END; port++) {
        try {
          const result = await window.electron.sendToMacsploit(script, port);
          showToast(`Script sent to MacSploit on port ${port}`, 4000);
          console.log('MacSploit response (port ' + port + '):', result);
          success = true;
          break;
        } catch (e) {
          lastErr = e;
          // continue to next port
        }
      }

      if (!success) {
        console.error('MacSploit send failed:', lastErr);
        showToast('Could not reach MacSploit on ports ' + MACSPLOIT_START + '-' + MACSPLOIT_END, 5000);
      }
    } else {
      showToast('Unknown executor selected.', 3000);
    }
  } catch (err) {
    console.error('Failed to send script:', err);
    showToast('Failed to send script: ' + (err?.message || err), 6000);
  }
}

async function injectDll() {
  // Inject functionality removed.
}

async function killRoblox() {
  if (window.electron?.killRoblox) {
      await window.electron.killRoblox();
  }
}

function saveSettings() {
  const settings = {
      alwaysOnTop: document.getElementById('alwaysOnTopToggle').checked,
      autoInject: document.getElementById('autoInjectToggle').checked,
      theme: document.getElementById('themeSelector').value,
      executor: document.getElementById('executorSelector') ? document.getElementById('executorSelector').value : 'hydrogen',
      selectedHydrogenPort: String(selectedHydrogenPort),
      selectedMacsploitPort: String(selectedMacsploitPort)
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

    if (settings.executor) {
      const executorSelector = document.getElementById('executorSelector');
      if (executorSelector) executorSelector.value = settings.executor;
    }
    // Port ranges are fixed and not editable in the UI.
      if (settings.selectedHydrogenPort) {
        selectedHydrogenPort = Number(settings.selectedHydrogenPort) || selectedHydrogenPort;
        localStorage.setItem('selectedHydrogenPort', String(selectedHydrogenPort));
      }

      if (settings.selectedMacsploitPort) {
        selectedMacsploitPort = Number(settings.selectedMacsploitPort) || selectedMacsploitPort;
        localStorage.setItem('selectedMacsploitPort', String(selectedMacsploitPort));
      }

      // Port ranges are fixed and changeable via the top bar click.
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
  const { filePath, canceled } = await window.electron.showOpenDialog({
      title: 'Open File',
      filters: [{ name: 'Lua Files', extensions: ['lua'] }],
      properties: ['openFile']
  });

  if (!canceled && filePath) {
      const content = await window.electron.openFile(filePath);
      editor.setValue(content);
      editor.clearSelection();
      showToast(`Opened ${filePath}`, 3000);
  }
}
