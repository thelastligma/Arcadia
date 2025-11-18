const { app, BrowserWindow, ipcMain } = require('electron');
const http = require('http');
const net = require('net');
const { URL } = require('url');
const { exec, execSync } = require('child_process');
const path = require('path');
const fs = require('fs');
const { spawn } = require('child_process');

function GetRobloxProcessId() {
  const processName = "RobloxPlayerBeta.exe";
  try {
      const output = execSync(`tasklist | findstr ${processName}`, { encoding: 'utf8' });
      const lines = output.split('\n');
      if (lines.length > 0) {
          const processDetails = lines[0].trim().split(/\s+/);
          return parseInt(processDetails[1]);
      }
  } catch (error) {

  }
  return null;
}

function GenerateRandomString(length) {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  let result = '';
  for (let i = 0; i < length; i++) {
      result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}

function ScheduleScript(mainPath, script, pid = 0) {
  if (!fs.existsSync(mainPath)) {
      return 1;
  }

  const schedulerPath = path.join(mainPath, "Scheduler");

  if (!fs.existsSync(schedulerPath)) {
      return 3;
  }

  const randomFileName = GenerateRandomString(10) + ".lua";
  const filePath = path.join(schedulerPath, `${randomFileName}_${pid}`);

  try {
      fs.writeFileSync(filePath, script + "\n@@DONE");
  } catch (error) {
      return 4;
  }

  return 0;
}

function createWindow() {
  const win = new BrowserWindow({
    width: 1024,
    height: 768,
    minWidth: 800,
    minHeight: 600,
    frame: false,
    transparent: true,
    backgroundColor: '#00000000',
    webPreferences: {
      devTools: false,
      nodeIntegration: false,
      contextIsolation: true,
      enableRemoteModule: false,
      preload: path.join(__dirname, 'preload.js')
    }
  });

  win.loadFile('index.html');

  // Start a small local API proxy server that exposes the functionality
  // from the `api` folder to the renderer via HTTP. We listen on port 0
  // (random free port) and expose the port via ipc `get-api-port`.
  let apiPort = null;
  const server = http.createServer(async (req, res) => {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') {
      res.writeHead(200);
      return res.end();
    }

    try {
      const parsedUrl = new URL(req.url, `http://127.0.0.1`);
      const pathname = parsedUrl.pathname;
      const qp = parsedUrl.searchParams;

      // Helper to proxy to ScriptBlox endpoints
      const proxyJson = async (target) => {
        const params = new URLSearchParams();
        for (const [k, v] of qp.entries()) params.set(k, v);
        const url = `${target}?${params.toString()}`;
        const response = await fetch(url);
        const text = await response.text();
        res.writeHead(response.status, { 'Content-Type': 'application/json' });
        return res.end(text);
      };

      if (pathname === '/api/search') {
        // support legacy filters: if filters=hot, call trending
        const filters = qp.get('filters') || qp.get('filters');
        if (filters === 'hot') {
          await proxyJson('https://scriptblox.com/api/script/trending');
        } else {
          await proxyJson('https://scriptblox.com/api/script/search');
        }
        return;
      }

      if (pathname === '/api/trending') {
        await proxyJson('https://scriptblox.com/api/script/trending');
        return;
      }

      if (pathname === '/api/fetch') {
        await proxyJson('https://scriptblox.com/api/script/fetch');
        return;
      }

      if (pathname === '/api/info') {
        const username = qp.get('username');
        if (!username) {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          return res.end(JSON.stringify({ error: 'username is required' }));
        }
        const url = `https://scriptblox.com/api/user/info/${encodeURIComponent(username)}`;
        const r = await fetch(url);
        const json = await r.text();
        res.writeHead(r.status, { 'Content-Type': 'application/json' });
        return res.end(json);
      }

      if (pathname === '/api/pfp') {
        const username = qp.get('username');
        if (!username) {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          return res.end(JSON.stringify({ error: 'username is required' }));
        }
        const infoUrl = `https://scriptblox.com/api/user/info/${encodeURIComponent(username)}`;
        const infoResp = await fetch(infoUrl);
        if (!infoResp.ok) {
          res.writeHead(infoResp.status, { 'Content-Type': 'application/json' });
          return res.end(await infoResp.text());
        }
        const info = await infoResp.json();
        const pfp = info.user?.profilePicture;
        if (!pfp) {
          res.writeHead(404, { 'Content-Type': 'application/json' });
          return res.end(JSON.stringify({ error: 'Profile picture not found' }));
        }
        const imageUrl = `https://scriptblox.com${pfp}`;
        const imgResp = await fetch(imageUrl);
        const buffer = await imgResp.arrayBuffer();
        const contentType = imgResp.headers.get('content-type') || 'image/png';
        res.writeHead(200, { 'Content-Type': contentType });
        return res.end(Buffer.from(buffer));
      }

      if (pathname === '/api/img') {
        const pathParam = qp.get('path') || qp.get('url');
        if (!pathParam) {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          return res.end(JSON.stringify({ error: 'path is required' }));
        }

        // If pathParam is already a full URL, use it; otherwise assume it's a ScriptBlox path.
        const imageUrl = pathParam.startsWith('http') ? pathParam : `https://scriptblox.com${pathParam}`;

        const imgResp = await fetch(imageUrl);
        if (!imgResp.ok) {
          res.writeHead(imgResp.status, { 'Content-Type': 'application/json' });
          return res.end(await imgResp.text());
        }

        const buffer = await imgResp.arrayBuffer();
        const contentType = imgResp.headers.get('content-type') || 'application/octet-stream';
        res.writeHead(200, { 'Content-Type': contentType });
        return res.end(Buffer.from(buffer));
      }

      // Default: 404
      res.writeHead(404, { 'Content-Type': 'application/json' });
      return res.end(JSON.stringify({ error: 'Not found' }));
    } catch (err) {
      console.error('Local API error:', err);
      res.writeHead(500, { 'Content-Type': 'application/json' });
      return res.end(JSON.stringify({ error: String(err) }));
    }
  });

  server.listen(0, '127.0.0.1', () => {
    const addr = server.address();
    apiPort = addr && addr.port;
    console.log('Local API server listening on port', apiPort);
  });

  ipcMain.handle('get-api-port', async () => apiPort);

  // `inject` handler removed per request (no external injector spawning).

  ipcMain.handle('execute-script', async (event, message) => {
    try {
      ScheduleScript( process.cwd(), message, GetRobloxProcessId( ) )
      return "Script has been scheduled";
    } catch (error) {
      console.error(`Failed to Schedule Script: ${error}`);
      throw error;
    }
  });

  // Scan local ports for a server that answers /secret with 0xdeadbeef
  ipcMain.handle('send-to-local-server', async (event, scriptContent, startPort = 6969, endPort = 7069) => {
    if (typeof fetch === 'undefined') {
      throw new Error('fetch is not available in this Electron runtime.');
    }

    const START_PORT = Number(startPort) || 6969;
    const END_PORT = Number(endPort) || 7069;
    let serverPort = null;
    let lastError = '';

    for (let port = START_PORT; port <= END_PORT; port++) {
      const url = `http://127.0.0.1:${port}/secret`;
      try {
        const res = await fetch(url, { method: 'GET' });
        if (res.ok) {
          const text = await res.text();
          if (text === '0xdeadbeef') {
            serverPort = port;
            console.log(`✅ Server found on port ${port}`);
            break;
          }
        }
      } catch (e) {
        lastError = e.message;
      }
    }

    if (!serverPort) {
      throw new Error(`Could not locate HTTP server on ports ${START_PORT}-${END_PORT}. Last error: ${lastError}`);
    }

    const postUrl = `http://127.0.0.1:${serverPort}/execute`;
    console.log(`Sending script to ${postUrl}`);

    const response = await fetch(postUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'text/plain' },
      body: scriptContent
    });

    const resultText = await response.text();
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${resultText}`);
    }

    // Do not open a new BrowserWindow automatically; just return the server response.
    return resultText;
  });

  // Send to MacSploit over the socket-based protocol (ports 5553-5562 per instance)
  // Renderer will call this with (scriptContent, port)
  ipcMain.handle('send-to-macsploit', async (event, scriptContent, port) => {
    const portNum = Number(port);
    if (!Number.isInteger(portNum) || portNum <= 0) {
      throw new Error('Invalid port provided for MacSploit IPC');
    }

    return await new Promise((resolve, reject) => {
      const client = net.createConnection({ host: '127.0.0.1', port: portNum }, () => {
        try {
          const len = Buffer.byteLength(scriptContent || '', 'utf8');
          const buf = Buffer.alloc(16 + len + 1);
          // IpcTypes.IPC_EXECUTE == 0
          buf.writeUInt8(0, 0);
          // length at offset 8 (32-bit little-endian)
          buf.writeInt32LE(len, 8);
          if (len > 0) buf.write(scriptContent, 16, 'utf8');
          client.write(buf);
        } catch (e) {
          client.destroy();
          return reject(e);
        }
      });

      let dataBuf = Buffer.alloc(0);
      let finished = false;

      client.on('data', (chunk) => {
        dataBuf = Buffer.concat([dataBuf, chunk]);
      });

      client.on('end', () => {
        finished = true;
        try {
          const type = dataBuf.readUInt8(0);
          const length = Number(dataBuf.subarray(8, 16).readBigUInt64LE());
          const message = dataBuf.subarray(16, 16 + length).toString('utf8');
          return resolve(message);
        } catch (e) {
          // If parsing fails, return raw buffer as fallback
          return resolve(dataBuf.toString('utf8') || 'OK');
        }
      });

      client.on('error', (err) => {
        if (!finished) return reject(err);
      });

      // Fallback timeout: if server doesn't respond in time, resolve with OK
      const timeout = setTimeout(() => {
        if (!finished) {
          client.destroy();
          return resolve('OK (no response)');
        }
      }, 1500);

      // Clear timeout once done
      const cleanup = () => clearTimeout(timeout);
      client.once('end', cleanup);
      client.once('error', cleanup);
    });
  });

  // Health check for Hydrogen: scan 6969-7069 for /secret returning 0xdeadbeef
  ipcMain.handle('check-hydrogen', async () => {
    try {
      const START = 6969;
      const END = 7069;
      for (let port = START; port <= END; port++) {
        try {
          const url = `http://127.0.0.1:${port}/secret`;
          const res = await fetch(url, { method: 'GET' });
          if (res.ok) {
            const text = await res.text();
            if (text === '0xdeadbeef') return port;
          }
        } catch (e) {
          // ignore and continue
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  });

  // Health check for MacSploit: attempt TCP connect to 5553-5562
  ipcMain.handle('check-macsploit', async () => {
    const START = 5553;
    const END = 5563;
    for (let port = START; port <= END; port++) {
      try {
        const ok = await new Promise((resolve) => {
          const sock = net.createConnection({ host: '127.0.0.1', port }, () => {
            sock.destroy();
            resolve(true);
          });
          sock.on('error', () => {
            resolve(false);
          });
          // short timeout so we move quickly
          sock.setTimeout(400, () => {
            sock.destroy();
            resolve(false);
          });
        });
        if (ok) return port;
      } catch (e) {
        // ignore and continue
      }
    }
    return null;
  });


  ipcMain.handle('kill-roblox', async () => {
    const platform = process.platform;

    try {
        exec('tasklist', (error, stdout, stderr) => {
            if (error) {
                console.error(`Error occured checking task list: ${error.message}`);
                throw error;
            }

            if (!stdout.includes('RobloxPlayerBeta.exe')) {
                console.log('Roblox not running');
                return 'Roblox process is not running';
            }

            exec('taskkill /F /IM RobloxPlayerBeta.exe', (killError, killStdout, killStderr) => {
                if (killError) {
                    console.error(`Failed to kill roblox -> ${killError.message}`);
                    throw killError;
                }
                console.log(`stdout: ${killStdout}`);
                console.error(`stderr: ${killStderr}`);
            });

            return 'Roblox process terminated successfully';
        });
    } catch (error) {
        console.error(error.message);
        throw error;
    }
});

  ipcMain.handle('toggle-always-on-top', async () => {
    const isAlwaysOnTop = win.isAlwaysOnTop();
    win.setAlwaysOnTop(!isAlwaysOnTop);
    return !isAlwaysOnTop;
  });

  ipcMain.handle('get-always-on-top', async () => {
    return win.isAlwaysOnTop();
  });

  ipcMain.handle('window-controls', async (event, action) => {
    switch (action) {
      case 'minimize':
        win.minimize();
        return 'minimized';
      
      case 'maximize':
        if (win.isMaximized()) {
          win.unmaximize();
          return 'unmaximized';
        } else {
          win.maximize();
          return 'maximized';
        }
      
      case 'close':
        win.close();
        return 'closed';
      
      case 'get-state':
        return {
          isMaximized: win.isMaximized(),
          isMinimized: win.isMinimized(),
          isNormal: !win.isMaximized() && !win.isMinimized()
        };
    }
  });

  win.on('maximize', () => {
    win.webContents.send('window-state-change', 'maximized');
  });

  win.on('unmaximize', () => {
    win.webContents.send('window-state-change', 'unmaximized');
  });
}

app.whenReady().then(createWindow);

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();

    // delete here sysgyat v2 so no one can steal REAL!
  }
});

app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) {
    createWindow();
  }
});
