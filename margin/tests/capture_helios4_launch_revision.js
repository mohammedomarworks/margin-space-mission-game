const http = require('http');
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

const HTTP_PORT = 8150;
const CDP_PORT = 9280;
const WEB_DIR = path.resolve(__dirname, '../../build/helios4_test');
const CHROME_PATH = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const PROFILE_DIR = '/tmp/helios4_launch_rev_' + Date.now();
const OUTPUT_DIR = path.resolve(__dirname, '../../artifacts/helios4_launch_revision');

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
			console.log(`    [Browser Console] ${text}`);
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
		if (data.method === 'Runtime.exceptionThrown') {
			console.error(`    [Browser Exception]`, JSON.stringify(data.params.exceptionDetails));
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

	async function sendKey(keyCode, keyName) {
		await send('Input.dispatchKeyEvent', { type: 'keyDown', windowsVirtualKeyCode: keyCode, code: keyName, key: keyName });
		await new Promise(r => setTimeout(r, 50));
		await send('Input.dispatchKeyEvent', { type: 'keyUp', windowsVirtualKeyCode: keyCode, code: keyName, key: keyName });
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
			await send('Page.enable');
			await send('Runtime.enable');

			console.log('\n--- Waiting for Godot Engine WebGL to load ---');
			const ready = await waitForGodotReady(30);
			if (!ready) {
				console.error('Godot engine failed to load in time.');
				process.exit(1);
			}
			await new Promise(r => setTimeout(r, 2000));

			// Step 1: Main Menu -> Prologue
			console.log('\n--- Step 1: Navigating to Prologue ---');
			await clickUntil(270, 363, 'Prologue.ProceedBtn', 5);
			await new Promise(r => setTimeout(r, 1200));

			// Step 2: Prologue -> Team Assignment
			console.log('\n--- Step 2: Navigating to Team Assignment ---');
			const proceedPrologue = trackedCoords['Prologue.ProceedBtn'] || { x: 947, y: 538 };
			await clickUntil(proceedPrologue.x, proceedPrologue.y, 'TeamAssignment.ConfirmCrewBtn', 5);
			await new Promise(r => setTimeout(r, 1200));

			// Step 3: Team Assignment -> Hangar
			console.log('\n--- Step 3: Navigating to 3D Hangar ---');
			const confirmCrew = trackedCoords['TeamAssignment.ConfirmCrewBtn'] || { x: 1114.5, y: 602.0 };
			await clickUntil(confirmCrew.x, confirmCrew.y, 'Hangar.ProceedToFRRBtn', 5);
			await new Promise(r => setTimeout(r, 1500));

			// Step 4: Hangar -> Engineering Readiness Review
			console.log('\n--- Step 4: Navigating to Engineering Review ---');
			const proceedFRR = trackedCoords['Hangar.ProceedToFRRBtn'] || { x: 1126.5, y: 498.5 };
			await clickUntil(proceedFRR.x, proceedFRR.y, 'EngineeringReview.VoteBtn_propulsion', 5);
			await new Promise(r => setTimeout(r, 1500));

			// Cast 4 specialist GO votes
			console.log('\n--- Casting 4 Specialist GO Votes ---');
			const vProp = trackedCoords['EngineeringReview.VoteBtn_propulsion'] || { x: 207.0, y: 530.0 };
			const vStruct = trackedCoords['EngineeringReview.VoteBtn_structural'] || { x: 505.5, y: 530.0 };
			const vAstro = trackedCoords['EngineeringReview.VoteBtn_astrogator'] || { x: 804.0, y: 530.0 };
			const vSys = trackedCoords['EngineeringReview.VoteBtn_systems'] || { x: 1102.5, y: 530.0 };

			await click(vProp.x, vProp.y);
			await new Promise(r => setTimeout(r, 300));
			await click(vStruct.x, vStruct.y);
			await new Promise(r => setTimeout(r, 300));
			await click(vAstro.x, vAstro.y);
			await new Promise(r => setTimeout(r, 300));
			await click(vSys.x, vSys.y);
			await new Promise(r => setTimeout(r, 800));

			// Step 5: Proceed to Earth Launch Scene
			console.log('\n--- Step 5: Launching into Phase 2: Earth Launch ---');
			const proceedLaunch = trackedCoords['EngineeringReview.ProceedToLaunchBtn'] || { x: 1120.0, y: 602.0 };
			await click(proceedLaunch.x, proceedLaunch.y);
			await new Promise(r => setTimeout(r, 2000));

			// =========================================================================
			// CAPTURE 1: 01_launch_pad_preignition.png
			// Pre-ignition pad camera view establishing launch complex, tower, clamps & vehicle standing tall
			// =========================================================================
			console.log('\n--- CAPTURING 1: Pre-Ignition Launch Complex (Pad Camera) ---');
			const btnPad = trackedCoords['Launch.CamBtn_Pad'] || { x: 337, y: 62 };
			await click(btnPad.x, btnPad.y);
			await new Promise(r => setTimeout(r, 600));
			await capture('01_launch_pad_preignition.png');

			// =========================================================================
			// CAPTURE 2: 02_launch_ignition_liftoff.png
			// Wait for countdown to expire -> Ignition, pad steam billows, clamps release, liftoff!
			// =========================================================================
			console.log('\n--- Waiting for Ignition and Liftoff (T-0 to T+2s) ---');
			await new Promise(r => setTimeout(r, 3400)); // Countdown is 3s
			const btnEngine = trackedCoords['Launch.CamBtn_Engine'] || { x: 410, y: 62 };
			await click(btnEngine.x, btnEngine.y);
			await new Promise(r => setTimeout(r, 800));
			await capture('02_launch_ignition_liftoff.png');

			// =========================================================================
			// CAPTURE 3: 03_launch_chase_ascent.png
			// Chase camera looking along blazing rocket exhaust plumes climbing through low atmosphere
			// =========================================================================
			console.log('\n--- CAPTURING 3: Chase Camera Atmospheric Ascent ---');
			const btnChase = trackedCoords['Launch.CamBtn_Chase'] || { x: 485, y: 62 };
			await click(btnChase.x, btnChase.y);
			await new Promise(r => setTimeout(r, 2200));
			await capture('03_launch_chase_ascent.png');

			// =========================================================================
			// CAPTURE 4: 04_launch_max_q.png
			// THE SIGNATURE VIEW (matching 02_helios4_launch_maxq.png):
			// Transonic Max-Q corridor (34.2km, 1480 m/s), vapor cone condensation active,
			// CameraMode.MAX_Q, dynamic Max-Q arc widget with warning & Q magnifier
			// =========================================================================
			console.log('\n--- CAPTURING 4: Max-Q Transonic Corridor (Matching Reference 02) ---');
			const btnMaxQ = trackedCoords['Launch.CamBtn_MaxQ'] || { x: 699, y: 62 };
			await click(btnMaxQ.x, btnMaxQ.y);
			await new Promise(r => setTimeout(r, 1200));
			await capture('04_launch_max_q.png');

			// =========================================================================
			// CAPTURE 5: 05_launch_stage_separation.png
			// Stage 1 booster separation: Detached booster drifting backwards while Stage 2 ignites
			// =========================================================================
			console.log('\n--- CAPTURING 5: Stage 1 Separation & Stage 2 Vacuum Ignition ---');
			const btnSep = trackedCoords['Launch.CamBtn_Sep'] || { x: 720, y: 62 };
			await click(btnSep.x, btnSep.y);
			await new Promise(r => setTimeout(r, 1200));
			await capture('05_launch_stage_separation.png');

			// =========================================================================
			// CAPTURE 6: 06_launch_orbital_insertion.png
			// Upper-stage orbital insertion above Earth with fairing jettisoned and probe exposed
			// =========================================================================
			console.log('\n--- CAPTURING 6: Orbital Insertion & Systems Activation ---');
			const btnOrbit = trackedCoords['Launch.CamBtn_Orbit'] || { x: 810, y: 62 };
			await click(btnOrbit.x, btnOrbit.y);
			await new Promise(r => setTimeout(r, 800));

			const btnSysAct = trackedCoords['Launch.BtnSystemsActivate'] || { x: 1165, y: 176 };
			await click(btnSysAct.x, btnSysAct.y);
			await new Promise(r => setTimeout(r, 1200));
			await capture('06_launch_orbital_insertion.png');

			console.log('\n==================================================');
			console.log('  ALL 6 LAUNCH MILESTONE CAPTURES COMPLETED!');
			console.log('==================================================');

		} catch (err) {
			console.error('[Error during capture sequence]', err);
		} finally {
			chrome.kill();
			server.close();
			process.exit(0);
		}
	};
});
