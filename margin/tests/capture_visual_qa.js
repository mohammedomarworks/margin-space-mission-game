const http = require('http');
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

const PORT = 8092;
const WEB_DIR = path.resolve(__dirname, '../../build/web');
const CHROME_PATH = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const ARTIFACT_DIR = '/Users/omar/.gemini/antigravity/brain/8d4b5f52-e848-41d3-8332-b9e596076e00';
const SCREENSHOT_PATH = path.join(ARTIFACT_DIR, 'gameplay_main_menu.png');

const MIME_TYPES = {
	'.html': 'text/html',
	'.js': 'application/javascript',
	'.wasm': 'application/wasm',
	'.pck': 'application/octet-stream',
	'.png': 'image/png',
	'.svg': 'image/svg+xml'
};

const server = http.createServer((req, res) => {
	let reqPath = req.url.split('?')[0];
	if (reqPath === '/' || reqPath === '') reqPath = '/index.html';
	const filePath = path.join(WEB_DIR, reqPath);
	if (!fs.existsSync(filePath)) {
		res.writeHead(404);
		res.end();
		return;
	}
	const ext = path.extname(filePath).toLowerCase();
	res.writeHead(200, {
		'Content-Type': MIME_TYPES[ext] || 'application/octet-stream',
		'Cross-Origin-Opener-Policy': 'same-origin',
		'Cross-Origin-Embedder-Policy': 'require-corp'
	});
	fs.createReadStream(filePath).pipe(res);
});

server.listen(PORT, async () => {
	const chrome = spawn(CHROME_PATH, [
		'--headless=new',
		'--remote-debugging-port=9223',
		'--window-size=1280,720',
		'--no-first-run',
		'--no-default-browser-check',
		`http://localhost:${PORT}/index.html`
	]);

	let targetWs = null;
	for (let i = 0; i < 20; i++) {
		await new Promise(r => setTimeout(r, 500));
		try {
			const res = await fetch('http://127.0.0.1:9223/json');
			const list = await res.json();
			const p = list.find(t => t.type === 'page' && t.url.includes('localhost'));
			if (p && p.webSocketDebuggerUrl) {
				targetWs = p.webSocketDebuggerUrl;
				break;
			}
		} catch (e) {}
	}

	if (!targetWs) {
		chrome.kill();
		server.close();
		process.exit(1);
	}

	const ws = new WebSocket(targetWs);
	let id = 1;
	const cbs = new Map();
	ws.onmessage = (e) => {
		const d = JSON.parse(e.data);
		if (d.id && cbs.has(d.id)) {
			cbs.get(d.id)(d);
			cbs.delete(d.id);
		}
	};
	function call(method, params = {}) {
		return new Promise((resolve) => {
			const mid = id++;
			cbs.set(mid, (res) => resolve(res.result));
			ws.send(JSON.stringify({ id: mid, method, params }));
		});
	}

	ws.onopen = async () => {
		await call('Page.enable');
		// Wait for Godot to load and display main menu
		await new Promise(r => setTimeout(r, 6000));
		const shot = await call('Page.captureScreenshot', { format: 'png' });
		if (shot && shot.data) {
			fs.writeFileSync(SCREENSHOT_PATH, Buffer.from(shot.data, 'base64'));
			console.log(`[Screenshot Captured] Saved to ${SCREENSHOT_PATH}`);
		}
		ws.close();
		chrome.kill();
		server.close();
		process.exit(0);
	};
});
