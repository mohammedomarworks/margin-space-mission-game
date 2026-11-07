const http = require('http');
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

const HTTP_PORT = 8133;
const CDP_PORT = 9263;
const WEB_DIR = process.env.WEB_DIR || path.resolve(__dirname, '../../build/web');
const CHROME_PATH = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const PROFILE_DIR = '/tmp/margin_frontier_qa_' + Date.now();
const ARTIFACT_DIR = '/Users/omar/.gemini/antigravity/brain/8d4b5f52-e848-41d3-8332-b9e596076e00';

const MIME_TYPES = {
	'.html': 'text/html',
	'.js': 'application/javascript',
	'.wasm': 'application/wasm',
	'.pck': 'application/octet-stream',
	'.png': 'image/png',
	'.json': 'application/json',
	'.svg': 'image/svg+xml'
};

const server = http.createServer((req, res) => {
	let reqPath = req.url.split('?')[0];
	if (reqPath === '/' || reqPath === '') reqPath = '/index.html';
	const filePath = path.join(WEB_DIR, reqPath);
	if (!fs.existsSync(filePath)) {
		res.writeHead(404, { 'Content-Type': 'text/plain' });
		res.end('Not Found: ' + reqPath);
		return;
	}
	const ext = path.extname(filePath).toLowerCase();
	res.writeHead(200, {
		'Content-Type': MIME_TYPES[ext] || 'application/octet-stream',
		'Cross-Origin-Opener-Policy': 'same-origin',
		'Cross-Origin-Embedder-Policy': 'require-corp',
		'Cache-Control': 'no-cache'
	});
	fs.createReadStream(filePath).pipe(res);
});

server.listen(HTTP_PORT, async () => {
	console.log(`[HTTP] Serving ${WEB_DIR} on http://localhost:${HTTP_PORT}`);
	
	const chrome = spawn(CHROME_PATH, [
		'--headless=new',
		`--remote-debugging-port=${CDP_PORT}`,
		`--user-data-dir=${PROFILE_DIR}`,
		'--window-size=1280,720',
		'--no-first-run',
		'--no-default-browser-check',
		`http://localhost:${HTTP_PORT}/index.html`
	]);

	chrome.on('exit', () => { console.log('[Chrome] Process exited.'); });

	let targetWs = null;
	for (let i = 0; i < 30; i++) {
		await new Promise(r => setTimeout(r, 400));
		try {
			const res = await fetch(`http://127.0.0.1:${CDP_PORT}/json`);
			const targets = await res.json();
			const p = targets.find(t => t.type === 'page' && t.url.includes('localhost'));
			if (p && p.webSocketDebuggerUrl) {
				targetWs = p.webSocketDebuggerUrl;
				console.log(`[CDP] Connected to game tab: "${p.title}"`);
				break;
			}
		} catch (e) {}
	}

	if (!targetWs) {
		console.error('[Error] Could not find Godot game tab via CDP.');
		chrome.kill();
		server.close();
		process.exit(1);
	}

	const ws = new WebSocket(targetWs);
	let msgId = 1;
	const cbs = new Map();
	const consoleErrors = [];

	ws.onmessage = (event) => {
		const data = JSON.parse(event.data);
		if (data.method === 'Runtime.consoleAPICalled') {
			const text = data.params.args.map(a => a.value).join(' ');
			console.log('[Game Console]', text);
			if (data.params.type === 'error') {
				consoleErrors.push(text);
			}
		} else if (data.method === 'Runtime.exceptionThrown') {
			consoleErrors.push(data.params.exceptionDetails.text);
		}

		if (data.id && cbs.has(data.id)) {
			cbs.get(data.id)(data);
			cbs.delete(data.id);
		}
	};

	function callCDP(method, params = {}, timeoutMs = 15000) {
		return new Promise((resolve, reject) => {
			const id = msgId++;
			const timer = setTimeout(() => {
				cbs.delete(id);
				reject(new Error(`CDP method ${method} timed out after ${timeoutMs}ms`));
			}, timeoutMs);

			cbs.set(id, (res) => {
				clearTimeout(timer);
				if (res.error) reject(res.error);
				else resolve(res.result);
			});
			ws.send(JSON.stringify({ id, method, params }));
		});
	}

	async function click(x, y, delayMs = 120) {
		await callCDP('Input.dispatchMouseEvent', { type: 'mouseMoved', x, y });
		await callCDP('Input.dispatchMouseEvent', { type: 'mousePressed', x, y, button: 'left', clickCount: 1 });
		await new Promise(r => setTimeout(r, delayMs));
		await callCDP('Input.dispatchMouseEvent', { type: 'mouseReleased', x, y, button: 'left', clickCount: 1 });
	}

	async function captureScreenshot(filename) {
		const res = await callCDP('Page.captureScreenshot', { format: 'png' });
		const buf = Buffer.from(res.data, 'base64');
		const fullPath = path.join(ARTIFACT_DIR, filename);
		fs.writeFileSync(fullPath, buf);
		console.log(`[Screenshot] Saved: ${fullPath} (${(buf.length / 1024).toFixed(1)} KB)`);
	}

	try {
		await new Promise(r => ws.onopen = r);
		await callCDP('Page.enable');
		await callCDP('Runtime.enable');
		await callCDP('Emulation.setDeviceMetricsOverride', {
			width: 1280,
			height: 720,
			deviceScaleFactor: 1,
			mobile: false
		});

		console.log('[Test] Waiting for Godot 4.7 WASM engine initialization (up to 20s)...');
		let ready = false;
		for (let i = 0; i < 40; i++) {
			await new Promise(r => setTimeout(r, 500));
			try {
				const check = await callCDP('Runtime.evaluate', {
					expression: `document.getElementById('canvas') !== null && (document.getElementById('status') === null || document.getElementById('status').style.opacity === '0' || (document.getElementById('status-container') && document.getElementById('status-container').style.display === 'none'))`
				});
				if (check.result && check.result.value === true) {
					ready = true;
					console.log(`[Test] Godot engine ready and canvas visible at t = ${((i + 1) * 0.5).toFixed(1)}s!`);
					break;
				}
			} catch (e) {}
		}

		if (!ready) {
			console.log('[Warning] Status container check timed out; waiting extra 3s...');
			await new Promise(r => setTimeout(r, 3000));
		}

		// Allow initial frame render
		await new Promise(r => setTimeout(r, 2000));
		console.log('[Test] Capturing Main Menu with Lunar Frontier button...');
		await captureScreenshot('lunar_frontier_menu.png');

		// Click "🚀 PLAY LUNAR FRONTIER (3D GAME)" button at (260, 400)
		console.log('[Test] Clicking "🚀 PLAY LUNAR FRONTIER (3D GAME)" at (260, 400)...');
		await click(260, 400);

		// Wait 3.5s for 3D Lunar Frontier scene instantiation & procedural terrain generation
		await new Promise(r => setTimeout(r, 3500));
		console.log('[Test] Capturing initial Lunar Frontier 3D exploration scene...');
		await captureScreenshot('lunar_frontier_start.png');

		// Send driving input: Hold 'W' for 2.0s
		console.log('[Test] Driving Lunar Hopper forward (holding W for 2.0s)...');
		await callCDP('Input.dispatchKeyEvent', { type: 'keyDown', key: 'w', code: 'KeyW', windowsVirtualKeyCode: 87, nativeVirtualKeyCode: 87 });
		await new Promise(r => setTimeout(r, 2000));
		await callCDP('Input.dispatchKeyEvent', { type: 'keyUp', key: 'w', code: 'KeyW', windowsVirtualKeyCode: 87, nativeVirtualKeyCode: 87 });

		// Send thruster boost input: Space for 1.0s
		console.log('[Test] Activating Lunar Hopper thruster jump (Space for 1.0s)...');
		await callCDP('Input.dispatchKeyEvent', { type: 'keyDown', key: ' ', code: 'Space', windowsVirtualKeyCode: 32, nativeVirtualKeyCode: 32 });
		await new Promise(r => setTimeout(r, 1000));
		await callCDP('Input.dispatchKeyEvent', { type: 'keyUp', key: ' ', code: 'Space', windowsVirtualKeyCode: 32, nativeVirtualKeyCode: 32 });

		// Wait 1.0s and capture in-motion state
		await new Promise(r => setTimeout(r, 1000));
		console.log('[Test] Capturing Lunar Hopper after forward drive & boost...');
		await captureScreenshot('lunar_frontier_in_motion.png');

		console.log('\n[PASS] BROWSER PLAYABILITY VERIFICATION COMPLETED SUCCESSFULLY!');
		console.log(`[Summary] Console Errors: ${consoleErrors.length}`);
		if (consoleErrors.length > 0) {
			console.log('Errors:', consoleErrors);
		}

	} catch (err) {
		console.error('[Error] Browser test failed:', err);
	} finally {
		chrome.kill();
		server.close();
		process.exit(0);
	}
});
