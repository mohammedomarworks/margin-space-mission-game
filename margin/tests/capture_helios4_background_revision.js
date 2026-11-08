const http = require('http');
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

const HTTP_PORT = 8147;
const CDP_PORT = 9277;
const WEB_DIR = path.resolve(__dirname, '../../build/helios4_test');
const CHROME_PATH = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const PROFILE_DIR = '/tmp/helios4_bg_rev_' + Date.now();
const OUTPUT_DIR = path.resolve(__dirname, '../../artifacts/helios4_background_revision');

const MIME_TYPES = {
	'.html': 'text/html',
	'.js': 'application/javascript',
	'.wasm': 'application/wasm',
	'.pck': 'application/octet-stream',
	'.png': 'image/png',
	'.json': 'application/json',
	'.svg': 'image/svg+xml'
};

if (!fs.existsSync(OUTPUT_DIR)) {
	fs.mkdirSync(OUTPUT_DIR, { recursive: true });
}

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
	console.log(`[HTTP Server] Serving ${WEB_DIR} on http://localhost:${HTTP_PORT}`);

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
	for (let i = 0; i < 35; i++) {
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
	const trackedCoords = {};

	ws.onmessage = (event) => {
		const data = JSON.parse(event.data);
		if (data.method === 'Runtime.consoleAPICalled') {
			const text = data.params.args.map(a => (a.value !== undefined ? a.value : (a.description || ''))).join(' ');
			if (text.includes('[Hangar]') || text.includes('[MainMenu]') || text.includes('[Prologue]') || text.includes('[TeamAssignment]')) {
				console.log(`    [Browser Console] ${text}`);
			}
			const match = text.match(/\[(\w+)\]\s+(\w+) global_rect:\s+\[P:\s+\(([\d.]+),\s+([\d.]+)\),\s+S:\s+\(([\d.]+),\s+([\d.]+)\)\]\s+center:\s+\(([\d.]+),\s+([\d.]+)\)/);
			if (match) {
				const [_, scene, name, px, py, sx, sy, cx, cy] = match;
				trackedCoords[`${scene}.${name}`] = { x: parseFloat(cx), y: parseFloat(cy), width: parseFloat(sx), height: parseFloat(sy) };
			}
			const matchSimple = text.match(/\[(\w+)\]\s+(\w+) center:\s+\(([\d.]+),\s+([\d.]+)\)/);
			if (matchSimple) {
				const [_, scene, name, cx, cy] = matchSimple;
				trackedCoords[`${scene}.${name}`] = { x: parseFloat(cx), y: parseFloat(cy) };
			}
		}
		if (data.id && cbs.has(data.id)) {
			const cb = cbs.get(data.id);
			cbs.delete(data.id);
			cb(data.result);
		}
	};

	function send(method, params = {}) {
		return new Promise((resolve) => {
			const id = msgId++;
			cbs.set(id, resolve);
			ws.send(JSON.stringify({ id, method, params }));
		});
	}

	async function click(x, y) {
		await send('Input.dispatchMouseEvent', { type: 'mousePressed', x, y, button: 'left', clickCount: 1 });
		await new Promise(r => setTimeout(r, 60));
		await send('Input.dispatchMouseEvent', { type: 'mouseReleased', x, y, button: 'left', clickCount: 1 });
	}

	async function drag(startX, startY, endX, endY, button = 'left', steps = 20, delayMs = 25) {
		await send('Input.dispatchMouseEvent', { type: 'mousePressed', x: startX, y: startY, button: button, clickCount: 1 });
		for (let i = 1; i <= steps; i++) {
			const curX = startX + (endX - startX) * (i / steps);
			const curY = startY + (endY - startY) * (i / steps);
			await send('Input.dispatchMouseEvent', { type: 'mouseMoved', x: curX, y: curY, button: button });
			await new Promise(r => setTimeout(r, delayMs));
		}
		await send('Input.dispatchMouseEvent', { type: 'mouseReleased', x: endX, y: endY, button: button, clickCount: 1 });
	}

	async function capture(fileName) {
		const res = await send('Page.captureScreenshot', { format: 'png' });
		const buf = Buffer.from(res.data, 'base64');
		const outPath = path.join(OUTPUT_DIR, fileName);
		fs.writeFileSync(outPath, buf);
		console.log(`  [Screenshot] Saved: ${fileName} (${buf.length} bytes)`);
	}

	async function waitForGodotReady(timeoutSec = 30) {
		const start = Date.now();
		for (let i = 0; i < timeoutSec * 2; i++) {
			await new Promise(r => setTimeout(r, 500));
			try {
				const res = await send('Runtime.evaluate', {
					expression: "document.getElementById('status') === null && document.getElementById('canvas') !== null"
				});
				if (res && res.result && res.result.value === true) {
					console.log(`  [CDP] Godot WebGL Canvas ready in ${((Date.now() - start)/1000).toFixed(1)}s`);
					return true;
				}
			} catch (e) {}
		}
		return false;
	}

	async function waitForCoord(key, timeoutMs = 10000) {
		const start = Date.now();
		while (Date.now() - start < timeoutMs) {
			if (trackedCoords[key]) return trackedCoords[key];
			await new Promise(r => setTimeout(r, 200));
		}
		return trackedCoords[key];
	}

	async function clickUntil(clickX, clickY, targetKey, maxAttempts = 6) {
		for (let i = 0; i < maxAttempts; i++) {
			if (trackedCoords[targetKey]) return true;
			console.log(`    [Attempt ${i+1}/${maxAttempts}] Clicking (${clickX}, ${clickY}) waiting for ${targetKey}...`);
			await click(clickX, clickY);
			await new Promise(r => setTimeout(r, 800));
			if (trackedCoords[targetKey]) return true;
		}
		return !!trackedCoords[targetKey];
	}

	ws.onopen = async () => {
		try {
			await send('Runtime.enable');
			await send('Page.enable');

			console.log('\n=================================================================');
			console.log(' HELIOS-4: HANGAR ENVIRONMENT ART PASS CAPTURE');
			console.log('=================================================================\n');

			const ready = await waitForGodotReady();
			if (!ready) throw new Error('Godot WebGL did not finish loading within timeout');

			// Extra wait for scene initialization & focus canvas
			await new Promise(r => setTimeout(r, 2000));
			await send('Runtime.evaluate', { expression: "const c = document.getElementById('canvas'); if(c) c.focus();" });

			// Step 1: Start New Campaign from Main Menu
			console.log('\n--- Step 1: Navigating from Main Menu to Prologue ---');
			const newCampCoord = await waitForCoord('MainMenu.NewCampaignBtn') || { x: 270, y: 363 };
			const reachedPrologue = await clickUntil(newCampCoord.x, newCampCoord.y, 'Prologue.ProceedBtn');
			if (!reachedPrologue) console.warn('Warning: ProceedBtn not logged yet, trying anyway...');

			// Step 2: Skip Prologue to Team Assignment
			console.log('\n--- Step 2: Navigating from Prologue to Team Assignment ---');
			const procCoord = trackedCoords['Prologue.ProceedBtn'] || { x: 947, y: 538 };
			const reachedTeam = await clickUntil(procCoord.x, procCoord.y, 'TeamAssignment.ConfirmCrewBtn');
			if (!reachedTeam) console.warn('Warning: ConfirmCrewBtn not logged yet, trying anyway...');

			// Step 3: Confirm Crew to Enter Hangar
			console.log('\n--- Step 3: Confirming Crew to Enter Hangar ---');
			const confirmCoord = trackedCoords['TeamAssignment.ConfirmCrewBtn'] || { x: 1114.5, y: 602.0 };
			const reachedHangar = await clickUntil(confirmCoord.x, confirmCoord.y, 'Hangar.ProceedToFRRBtn', 8);
			if (!reachedHangar) console.warn('Warning: ProceedToFRRBtn not logged yet, waiting...');

			console.log('\n--- Step 4: Inside 3D Hangar Assembly Facility ---');
			// Wait for 3D environment, gantry, lighting, and particles to settle
			await new Promise(r => setTimeout(r, 3000));

			// CAPTURE 1: Full Hangar Scene at 1920x1080
			console.log('\n[EVIDENCE 1] Rendering Full Hangar Scene at 1920x1080...');
			await send('Emulation.setDeviceMetricsOverride', {
				width: 1920,
				height: 1080,
				deviceScaleFactor: 1,
				mobile: false
			});
			await new Promise(r => setTimeout(r, 2000));
			await capture('01_hangar_full_1920x1080.png');

			// CAPTURE 2: Hangar Scene at 1365x768
			console.log('\n[EVIDENCE 2] Rendering Hangar Scene at 1365x768...');
			await send('Emulation.setDeviceMetricsOverride', {
				width: 1365,
				height: 768,
				deviceScaleFactor: 1,
				mobile: false
			});
			await new Promise(r => setTimeout(r, 1500));
			await capture('02_hangar_full_1365x768.png');

			// Restore 1280x720 base viewport for camera adjustments
			await send('Emulation.clearDeviceMetricsOverride');
			await new Promise(r => setTimeout(r, 1000));

			// CAPTURE 3: Wide environment view showing the facility's architectural depth
			console.log('\n[EVIDENCE 3] Capturing Wide Environment View (Facility Architectural Depth)...');
			// Drag right-mouse down from 300 to 520 to zoom out distance from 17.5m to ~28-30m
			await drag(640, 300, 640, 520, 'right', 25, 25);
			await new Promise(r => setTimeout(r, 1500));
			await capture('03_hangar_wide_environment.png');

			// CAPTURE 4: Rocket with the new environment visible around it
			console.log('\n[EVIDENCE 4] Capturing Rocket with Surrounding Environment Visible...');
			// Drag right-mouse back up to restore camera distance to ~18m
			await drag(640, 500, 640, 370, 'right', 20, 25);
			await new Promise(r => setTimeout(r, 1500));
			await capture('04_hangar_rocket_environment.png');

			// CAPTURE 5: Camera orbit view showing that the surrounding environment is fully constructed
			console.log('\n[EVIDENCE 5] Capturing Camera Orbit View (360 Facility Construction)...');
			// Drag left-mouse across screen to orbit camera yaw by ~70 degrees
			await drag(750, 360, 420, 340, 'left', 30, 25);
			await new Promise(r => setTimeout(r, 1800));
			await capture('05_hangar_camera_orbit_depth.png');

			console.log('\n=================================================================');
			console.log(' ALL BACKGROUND REVISION SCREENSHOTS SUCCESSFULLY CAPTURED!');
			console.log(' Directory: artifacts/helios4_background_revision/');
			console.log('=================================================================\n');

			ws.close();
			chrome.kill();
			server.close();
			process.exit(0);

		} catch (err) {
			console.error('\n[CAPTURE FAILED] Error during background revision capture:', err);
			ws.close();
			chrome.kill();
			server.close();
			process.exit(1);
		}
	};
});
