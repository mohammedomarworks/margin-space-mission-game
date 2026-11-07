const http = require('http');
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

const HTTP_PORT = 8145;
const CDP_PORT = 9275;
const WEB_DIR = path.resolve(__dirname, '../../build/helios4_test');
const CHROME_PATH = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const PROFILE_DIR = '/tmp/helios4_visual_' + Date.now();
const OUTPUT_DIR = path.resolve(__dirname, '../../artifacts/helios4_visual_rebuild');

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

	async function drag(startX, startY, endX, endY) {
		await send('Input.dispatchMouseEvent', { type: 'mousePressed', x: startX, y: startY, button: 'left', clickCount: 1 });
		const steps = 15;
		for (let i = 1; i <= steps; i++) {
			const curX = startX + (endX - startX) * (i / steps);
			const curY = startY + (endY - startY) * (i / steps);
			await send('Input.dispatchMouseEvent', { type: 'mouseMoved', x: curX, y: curY, button: 'left' });
			await new Promise(r => setTimeout(r, 25));
		}
		await send('Input.dispatchMouseEvent', { type: 'mouseReleased', x: endX, y: endY, button: 'left', clickCount: 1 });
	}

	async function capture(fileName) {
		const res = await send('Page.captureScreenshot', { format: 'png' });
		const buf = Buffer.from(res.data, 'base64');
		const outPath = path.join(OUTPUT_DIR, fileName);
		fs.writeFileSync(outPath, buf);
		console.log(`  [Screenshot] Saved: ${fileName} (${buf.length} bytes)`);
	}

	ws.onopen = async () => {
		try {
			await send('Runtime.enable');
			await send('Page.enable');

			console.log('\n=================================================================');
			console.log(' HELIOS-4: VISUAL REBUILD RENDER AUDIT');
			console.log('=================================================================\n');

			// Wait for Godot canvas to load
			await new Promise(r => setTimeout(r, 2200));

			// Step 1: Start New Campaign from Main Menu
			console.log('--- Step 1: Navigating from Main Menu to Hangar ---');
			const newCampBtn = trackedCoords['MainMenu.NewCampaignBtn'] || { x: 270, y: 363 };
			console.log(`  Clicking New Campaign at (${newCampBtn.x}, ${newCampBtn.y})...`);
			await click(newCampBtn.x, newCampBtn.y);
			await new Promise(r => setTimeout(r, 1200));

			// Step 2: Skip Prologue to Team Assignment
			const procPrologue = trackedCoords['Prologue.ProceedBtn'] || { x: 947, y: 538 };
			console.log(`  Clicking Proceed at (${procPrologue.x}, ${procPrologue.y})...`);
			await click(procPrologue.x, procPrologue.y);
			await new Promise(r => setTimeout(r, 1200));

			// Step 3: Confirm Crew to Enter Hangar
			const confirmCrew = trackedCoords['TeamAssignment.ConfirmCrewBtn'] || { x: 1114, y: 602 };
			console.log(`  Confirming crew at (${confirmCrew.x}, ${confirmCrew.y})...`);
			await click(confirmCrew.x, confirmCrew.y);
			await new Promise(r => setTimeout(r, 3000));

			console.log('\n--- Step 2: Inside 3D Hangar Assembly Facility ---');
			// Wait for 3D environment, gantry, lighting, and particles to settle
			await new Promise(r => setTimeout(r, 2500));

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

			// Restore 1280x720 base viewport for UI clicking
			await send('Emulation.clearDeviceMetricsOverride');
			await new Promise(r => setTimeout(r, 1000));

			// CAPTURE 3: Close-up of Spacecraft / Probe
			console.log('\n[EVIDENCE 3] Close-up of Spacecraft Probe & Upper Fairing...');
			const probeBtn = trackedCoords['Hangar.FocusProbeBtn'] || { x: 440, y: 26 };
			console.log(`  Clicking FocusProbeBtn at (${probeBtn.x}, ${probeBtn.y})...`);
			await click(probeBtn.x, probeBtn.y);
			await new Promise(r => setTimeout(r, 1800));
			await capture('03_hangar_rocket_closeup.png');

			// CAPTURE 4: Camera Orbit Drag Interaction
			console.log('\n[EVIDENCE 4] Camera Orbit Drag Interaction (Rotating 3D Scene)...');
			// Drag to orbit camera around rocket
			await drag(640, 360, 480, 320);
			await new Promise(r => setTimeout(r, 1400));
			await capture('04_hangar_camera_interaction.png');

			// CAPTURE 5: Selected Subsystem & Configuration Interface
			console.log('\n[EVIDENCE 5] Selected Subsystem (Stage 1 Engine / Propulsion HUD)...');
			const engBtn = trackedCoords['Hangar.InvBtn_stage1_engine'] || { x: 80, y: 200 };
			console.log(`  Clicking InvBtn_stage1_engine at (${engBtn.x}, ${engBtn.y})...`);
			await click(engBtn.x, engBtn.y);
			await new Promise(r => setTimeout(r, 1800));
			await capture('05_hangar_selected_subsystem.png');

			// CAPTURE 6: Structural Workstation & Radar Scope
			console.log('\n[EVIDENCE 6] Structural Workstation & Radar Scope...');
			const tabStruct = trackedCoords['Hangar.TabStructural'] || { x: 281, y: 598 };
			console.log(`  Clicking TabStructural at (${tabStruct.x}, ${tabStruct.y})...`);
			await click(tabStruct.x, tabStruct.y);
			await new Promise(r => setTimeout(r, 1600));
			await capture('06_hangar_structural_radar.png');

			console.log('\n=================================================================');
			console.log(' ALL VISUAL REBUILD SCREENSHOTS SUCCESSFULLY CAPTURED!');
			console.log(' Directory: artifacts/helios4_visual_rebuild/');
			console.log('=================================================================\n');

			ws.close();
			chrome.kill();
			server.close();
			process.exit(0);

		} catch (err) {
			console.error('\n[CAPTURE FAILED] Error during visual rebuild capture:', err);
			ws.close();
			chrome.kill();
			server.close();
			process.exit(1);
		}
	};
});
