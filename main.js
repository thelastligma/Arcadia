const { app, BrowserWindow, ipcMain, dialog } = require('electron');
const fs = require("fs");
const path = require("path");
const net = require("net");
const zlib = require("zlib");
const os = require("os");
const { exec, execSync, spawn } = require('child_process');

const SettingsDirectory = path.join(os.homedir(), "Opiumware", "modules");
const SettingsFile = path.join(SettingsDirectory, "settings");

/**
 * @param {string} code - Code to execute
 * @param {string|number} [port="ALL"] - Port to connect to, or "ALL" to try all ports
 * @returns {Promise<string>} - Result message
 */
async function execute(code, port) {
    const Ports = ["8392", "8393", "8394", "8395", "8396", "8397"];
    let ConnectedPort = null, Stream = null;
    const attempts = [];

    // ensure we send OpiumwareScript-prefixed payload
    const payload = (typeof code === 'string' && code.trim().startsWith('OpiumwareScript')) ? code : `OpiumwareScript ${code}`;

    for (const P of (port === 'ALL' ? Ports : [String(port)])) {
        try {
            Stream = await new Promise((Resolve, Reject) => {
                const Socket = net.createConnection({ host: '127.0.0.1', port: parseInt(P) }, () => Resolve(Socket));
                Socket.on('error', Reject);
            });
            ConnectedPort = P;
            break;
        } catch (Err) {
            attempts.push({ port: P, error: Err && Err.message ? Err.message : String(Err) });
        }
    }

    if (!Stream) return { success: false, error: 'Failed to connect on all ports', attempts };

    try {
        const Compressed = await new Promise((Resolve, Reject) => {
            zlib.deflate(Buffer.from(payload, 'utf8'), (Err, result) => {
                if (Err) return Reject(Err);
                Resolve(result);
            });
        });

        await new Promise((Resolve, Reject) => {
            Stream.write(Compressed, (WriteErr) => {
                if (WriteErr) return Reject(WriteErr);
                Resolve();
            });
        });

        Stream.end();
        return { success: true, port: ConnectedPort, bytes: Compressed.length, message: `Script sent (${Compressed.length} bytes) to port ${ConnectedPort}` };
    } catch (Err) {
        try { Stream.destroy(); } catch (e) {}
        return { success: false, error: Err && Err.message ? Err.message : String(Err), port: ConnectedPort };
    }
}

/**
 * @param {string} key - Only "WSToggle" and "RedirectErrors" are supported
 * @param {boolean} value - true or false
 */
async function setting(key, value) {
    if (!fs.existsSync(SettingsDirectory)) {
        fs.mkdirSync(SettingsDirectory, { recursive: true });
    }

    let existing = {};

    if (fs.existsSync(SettingsFile)) {
        const lines = fs.readFileSync(SettingsFile, "utf8").split("\n");
        lines.forEach(line => {
            const [k, v] = line.split(" ");
            if (k) existing[k] = v;
        });
    } else {
        existing["WSToggle"] = "true";
        existing["RedirectErrors"] = "false";
    }

    existing[key] = value ? "true" : "false";
    fs.writeFileSync(SettingsFile, Object.entries(existing).map(([k, v]) => `${k} ${v}`).join("\n"), "utf8");
}

// --- Electron app/bootstrap ---
let mainWindow = null;

function createWindow() {
    mainWindow = new BrowserWindow({
        width: 1000,
        height: 700,
        show: true,
        frame: false,
        webPreferences: {
            preload: path.join(__dirname, 'preload.js'),
            nodeIntegration: false,
            contextIsolation: true
        }
    });

    mainWindow.loadFile(path.join(__dirname, 'index.html'));

    mainWindow.on('closed', () => {
        mainWindow = null;
    });
}

app.whenReady().then(createWindow);

app.on('window-all-closed', () => {
    if (process.platform !== 'darwin') app.quit();
});

app.on('activate', () => {
    if (mainWindow === null) createWindow();
});

// IPC handlers used by renderer
ipcMain.handle('execute-script', async (event, script, port) => {
    try {
        const usePort = port === undefined || port === null ? 'ALL' : port;
        const res = await execute(script, usePort);
        return res;
    } catch (e) {
        return { success: false, error: e && e.message ? e.message : String(e) };
    }
});

ipcMain.handle('set-setting', async (event, key, value) => {
    try {
        await setting(key, !!value);
        return { success: true };
    } catch (e) {
        return { success: false, error: e.message };
    }
});

ipcMain.handle('window-controls', (event, action) => {
    const win = BrowserWindow.fromWebContents(event.sender);
    if (!win) return;
    if (action === 'minimize') win.minimize();
    if (action === 'maximize') {
        if (win.isMaximized()) win.unmaximize(); else win.maximize();
    }
    if (action === 'close') win.close();
});

ipcMain.handle('toggle-always-on-top', (event) => {
    const win = BrowserWindow.fromWebContents(event.sender);
    if (!win) return false;
    const newState = !win.isAlwaysOnTop();
    win.setAlwaysOnTop(newState);
    return newState;
});

ipcMain.handle('get-always-on-top', (event) => {
    const win = BrowserWindow.fromWebContents(event.sender);
    if (!win) return false;
    return win.isAlwaysOnTop();
});

ipcMain.handle('show-save-dialog', async (event, options) => {
    const win = BrowserWindow.fromWebContents(event.sender);
    return await dialog.showSaveDialog(win, options);
});

ipcMain.handle('show-open-dialog', async (event, options) => {
    const win = BrowserWindow.fromWebContents(event.sender);
    return await dialog.showOpenDialog(win, options);
});

ipcMain.handle('save-file', async (event, filePath, content) => {
    try {
        fs.writeFileSync(filePath, content, 'utf8');
        return { success: true };
    } catch (e) {
        return { success: false, error: e.message };
    }
});

ipcMain.handle('open-file', async (event, filePath) => {
    try {
        const content = fs.readFileSync(filePath, 'utf8');
        return content;
    } catch (e) {
        return null;
    }
});

ipcMain.handle('inject', async (event, options) => {
    try {
        const platform = process.platform;
        // Candidate base paths: packaged resources, app path, __dirname and cwd
        const basePaths = [process.resourcesPath || '', app.getAppPath ? app.getAppPath() : '', __dirname, process.cwd()].filter(Boolean);

        // allow explicit path override
        if (options && options.path) {
            const p = options.path;
            if (fs.existsSync(p)) {
                // launch directly
                if (p.endsWith('.app') && platform === 'darwin') {
                    spawn('open', [p], { detached: true, stdio: 'ignore' }).unref();
                    return { success: true, path: p };
                } else {
                    fs.chmodSync(p, 0o755);
                    spawn(p, { detached: true, stdio: 'ignore' }).unref();
                    return { success: true, path: p };
                }
            } else {
                return { success: false, error: `Provided injector path not found: ${p}` };
            }
        }

        let candidates = [];
        if (platform === 'win32') {
            candidates = basePaths.map(p => path.join(p, 'Injector.exe'));
        } else if (platform === 'darwin') {
            for (const p of basePaths) {
                candidates.push(path.join(p, 'Injector.app'));
                candidates.push(path.join(p, 'Injector'));
                candidates.push(path.join(p, 'MacInjector', 'Injector'));
            }
        } else {
            candidates = basePaths.map(p => path.join(p, 'Injector'));
        }

        const found = candidates.find(fs.existsSync);
        if (!found) {
            return { success: false, error: 'Injector not found for this platform. Place Injector.app or Injector binary next to the app.', candidates };
        }

        if (platform === 'darwin' && found.endsWith('.app')) {
            spawn('open', [found], { detached: true, stdio: 'ignore' }).unref();
            return { success: true, path: found };
        }

        fs.chmodSync(found, 0o755);
        spawn(found, { detached: true, stdio: 'ignore' }).unref();
        return { success: true, path: found };
    } catch (e) {
        return { success: false, error: e && e.message ? e.message : String(e) };
    }
});

ipcMain.handle('select-injector', async (event) => {
    try {
        const win = BrowserWindow.fromWebContents(event.sender);
        const res = await dialog.showOpenDialog(win, {
            title: 'Select Injector (app or binary)',
            properties: ['openFile', 'openDirectory'],
            // allow selecting .app bundles or any binary
            filters: [{ name: 'Injector', extensions: ['app', ''] }]
        });

        if (res.canceled || !res.filePaths || !res.filePaths[0]) return { success: false, error: 'No file selected' };
        const selected = res.filePaths[0];

        // try to launch selected path
        if (selected.endsWith('.app')) {
            spawn('open', [selected], { detached: true, stdio: 'ignore' }).unref();
            return { success: true, path: selected };
        }

        fs.chmodSync(selected, 0o755);
        spawn(selected, { detached: true, stdio: 'ignore' }).unref();
        return { success: true, path: selected };
    } catch (e) {
        return { success: false, error: e && e.message ? e.message : String(e) };
    }
});

ipcMain.handle('kill-roblox', async () => {
    try {
        if (process.platform === 'win32') {
            // try common Roblox process names
            const candidates = ['RobloxPlayerBeta.exe', 'RobloxPlayer.exe', 'Roblox.exe'];
            let killedAny = false;
            let lastErr = null;
            for (const name of candidates) {
                try {
                    execSync(`taskkill /F /IM ${name}`, { stdio: 'ignore' });
                    killedAny = true;
                } catch (e) {
                    lastErr = e;
                }
            }
            if (killedAny) return { success: true, detail: 'Processes terminated' };
            return { success: false, error: lastErr ? lastErr.message : 'No matching Roblox process found' };
        } else if (process.platform === 'darwin' || process.platform === 'linux') {
            // Try pkill variations first
            const pkillCmds = [
                'pkill -f RobloxPlayerBeta',
                'pkill -f RobloxPlayer',
                'pkill -f Roblox',
                'pkill Roblox'
            ];
            for (const c of pkillCmds) {
                try {
                    execSync(c, { stdio: 'ignore' });
                } catch (e) {
                    // ignore individual failures
                }
            }

            // Check if any matching processes remain using pgrep, then kill them explicitly
            try {
                // pgrep -f may exit non-zero if none found; capture gracefully
                const out = execSync('pgrep -f Roblox || true', { encoding: 'utf8', shell: '/bin/bash' }).trim();
                if (!out) return { success: true, detail: 'No Roblox processes running' };
                // out may contain multiple PIDs separated by newlines
                const pids = out.split(/\s+/).filter(Boolean);
                for (const pid of pids) {
                    try {
                        process.kill(parseInt(pid), 'SIGKILL');
                    } catch (e) {
                        // last-resort: try kill -9
                        try { execSync(`kill -9 ${pid}`, { stdio: 'ignore' }); } catch (ee) {}
                    }
                }
                return { success: true, detail: `Killed PIDs: ${pids.join(',')}` };
            } catch (e) {
                return { success: false, error: e && e.message ? e.message : String(e) };
            }
        } else {
            return { success: false, error: 'Unsupported platform' };
        }
    } catch (e) {
        return { success: false, error: e && e.message ? e.message : String(e) };
    }
});

// expose nothing else