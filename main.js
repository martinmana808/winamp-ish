const { app, BrowserWindow } = require('electron');
const path = require('path');

function createWindow() {
    const win = new BrowserWindow({
        width: 440,
        height: 600,
        resizable: true,
        frame: false, // Frameless for custom UI
        transparent: true,
        webPreferences: {
            nodeIntegration: true,
            contextIsolation: false, // Keeping it simple for this clone
        }
    });

    win.loadFile('index.html');

    // macOS vibrancy
    win.setVibrancy('under-window');
}

app.whenReady().then(() => {
    createWindow();

    app.on('activate', () => {
        if (BrowserWindow.getAllWindows().length === 0) {
            createWindow();
        }
    });
});

app.on('window-all-closed', () => {
    if (process.platform !== 'darwin') {
        app.quit();
    }
});
