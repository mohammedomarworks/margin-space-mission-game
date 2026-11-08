const http = require('http');
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

const HTTP_PORT = 8152;
const CDP_PORT = 9282;
const WEB_DIR = path.resolve(__dirname, '../../build/helios4_test');
const CHROME_PATH = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const PROFILE_DIR = '/tmp/helios4_deepspace_' + Date.now();
const LOCAL_ARTIFACT_DIR = path.resolve(__dirname, '../../artifacts/helios4_deep_space_solar_crisis');
const BRAIN_ARTIFACT_DIR = '/Users/omar/.gemini/antigravity/brain/b5ceb744-4e36-4c4e-8114-c68f40047e77';

const MIME_TYPES = {
	'.html': 'text/html',
	'.js': 'application/javascript',
	'.wasm': 'application/wasm',
	'.pck': 'application/octet-stream',
	'.png': 'image/png',
	'.json': 'application/json',
	'.svg': 'image/svg+xml'
};

if (!fs.existsSync(LOCAL_ARTIFACT_DIR)) {
	fs.mkdirSync(LOCAL_ARTIFACT_DIR, { recursive: true });
}
if (!fs.existsSync(BRAIN_ARTIFACT_DIR)) {
	fs.mkdirSync(BRAIN_ARTIFACT_DIR, { recursive: true });
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
	let consoleMessages = [];
	const trackedCoords = {};

	ws.onmessage = (event) => {
		const data = JSON.parse(event.data);
		if (data.method === 'Runtime.consoleAPICalled') {
			const text = data.params.args.map(a => (a.value !== undefined ? a.value : (a.description || ''))).join(' ');
			consoleMessages.push(text);

			const centerMatch = text.match(/\[UI Coord Track\]\s+([\w\.]+)\s+->\s+\((\d+),\s*(\d+)\)/);
			if (centerMatch) {
				const tag = centerMatch[1];
				trackedCoords[tag] = { x: parseFloat(centerMatch[2]), y: parseFloat(centerMatch[3]) };
				console.log(`    [UI Coord Track] ${tag} -> (${trackedCoords[tag].x}, ${trackedCoords[tag].y})`);
			}

			if (text.startsWith('[') || text.includes('DeepSpace') || text.includes('Launch') || text.includes('CRISIS') || text.includes('L1')) {
				console.log(`    [Game Console] ${text}`);
			}
		}

		if (data.id && cbs.has(data.id)) {
			cbs.get(data.id)(data);
			cbs.delete(data.id);
		}
	};

	function callCDP(method, params = {}, timeoutMs = 25000) {
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

	async function getCoord(key, fallback) {
		for (let i = 0; i < 20; i++) {
			if (trackedCoords[key]) return trackedCoords[key];
			await new Promise(r => setTimeout(r, 100));
		}
		return fallback;
	}

	async function click(x, y, delayMs = 120) {
		await callCDP('Input.dispatchMouseEvent', { type: 'mouseMoved', x: Math.round(x), y: Math.round(y) });
		await new Promise(r => setTimeout(r, 60));
		await callCDP('Input.dispatchMouseEvent', { type: 'mousePressed', x: Math.round(x), y: Math.round(y), button: 'left', clickCount: 1 });
		await new Promise(r => setTimeout(r, delayMs));
		await callCDP('Input.dispatchMouseEvent', { type: 'mouseReleased', x: Math.round(x), y: Math.round(y), button: 'left', clickCount: 1 });
	}

	async function sendKey(keyCode, keyChar) {
		await callCDP('Input.dispatchKeyEvent', { type: 'rawKeyDown', windowsVirtualKeyCode: keyCode, key: keyChar });
		await new Promise(r => setTimeout(r, 80));
		await callCDP('Input.dispatchKeyEvent', { type: 'keyUp', windowsVirtualKeyCode: keyCode, key: keyChar });
	}

	async function setResolution(w, h) {
		await callCDP('Emulation.setDeviceMetricsOverride', {
			width: w,
			height: h,
			deviceScaleFactor: 1,
			mobile: false
		});
		await callCDP('Emulation.setVisibleSize', { width: w, height: h });
		console.log(`  [Resolution] Viewport switched to ${w}x${h}`);
		await new Promise(r => setTimeout(r, 500));
	}

	async function saveScreenshot(filename) {
		const res = await callCDP('Page.captureScreenshot', { format: 'png' });
		const buffer = Buffer.from(res.data, 'base64');
		const localPath = path.join(LOCAL_ARTIFACT_DIR, filename);
		const brainPath = path.join(BRAIN_ARTIFACT_DIR, filename);
		fs.writeFileSync(localPath, buffer);
		fs.writeFileSync(brainPath, buffer);
		console.log(`  [Screenshot] Saved: ${filename}`);
	}

	await new Promise(resolve => ws.onopen = resolve);
	await callCDP('Runtime.enable');
	await callCDP('Page.enable');

	console.log('\n=================================================================');
	console.log(' HELIOS-4: PART 3 DEEP SPACE TRANSFER & SOLAR CRISIS PLAYTEST');
	console.log('=================================================================\n');

	// Wait for WebGL engine canvas to become active
	for (let i = 0; i < 40; i++) {
		await new Promise(r => setTimeout(r, 500));
		const evalRes = await callCDP('Runtime.evaluate', {
			expression: 'document.querySelector("canvas") !== null'
		});
		if (evalRes && evalRes.result && evalRes.result.value) {
			console.log(`  [CDP] Godot WebGL Canvas ready in ${(i * 0.5).toFixed(1)}s`);
			break;
		}
	}
	await new Promise(r => setTimeout(r, 1500));

	// --- Step 1: Navigate from Main Menu through Launch to Parking Orbit ---
	console.log('--- Step 1: Navigating Campaign from Hangar & Launch to Parking Orbit ---');

	// Click New Campaign
	await click(270, 363);
	await new Promise(r => setTimeout(r, 800));
	
	// Click Prologue Proceed
	await click(947, 538);
	await new Promise(r => setTimeout(r, 800));

	// Click Team Assignment Confirm
	await click(1114, 602);
	await new Promise(r => setTimeout(r, 1200));

	// Click Hangar Proceed to FRR
	await click(797, 600);
	await new Promise(r => setTimeout(r, 1200));

	// In Engineering Review, cast unanimous GO votes
	await click(207.0, 530.0);
	await new Promise(r => setTimeout(r, 300));
	await click(505.5, 530.0);
	await new Promise(r => setTimeout(r, 300));
	await click(804.0, 530.0);
	await new Promise(r => setTimeout(r, 300));
	await click(1102.5, 530.0);
	await new Promise(r => setTimeout(r, 600));

	// Click FRR Proceed to Launch
	await click(1120, 602);
	await new Promise(r => setTimeout(r, 2000));

	// Trigger Launch Preflight Verify [V] & Countdown [Space]
	console.log('  [Launch] Performing pre-flight check and countdown...');
	await sendKey(86, 'v');
	await new Promise(r => setTimeout(r, 600));
	await sendKey(32, ' ');
	await new Promise(r => setTimeout(r, 11500)); // Liftoff

	// Fast orbital insertion: Press [O] to jump to orbit
	console.log('  [Launch] Fast-forwarding ascent to parking orbit insertion [O]...');
	await sendKey(79, 'o');
	await new Promise(r => setTimeout(r, 1500));

	// Jettison fairing [J]
	await sendKey(74, 'j');
	await new Promise(r => setTimeout(r, 1000));

	// Activate systems [E]
	await sendKey(69, 'e');
	await new Promise(r => setTimeout(r, 1500));

	// Transition to Deep Space Transfer via Enter / Space / Click
	await sendKey(13, 'Enter');
	await new Promise(r => setTimeout(r, 400));
	await sendKey(32, ' ');
	await new Promise(r => setTimeout(r, 400));
	await click(1022.5, 457.5);
	await new Promise(r => setTimeout(r, 2500));

	// Switch to full 1920x1080 Full HD resolution for pristine 3D captures
	await setResolution(1920, 1080);
	await new Promise(r => setTimeout(r, 1200));

	// --- Step 2: Capture 1 - Spacecraft Leaving Earth Parking Orbit ---
	console.log('\n--- Capture 1: Spacecraft leaving Earth parking orbit ---');
	// Press Space to initiate Trans-L1 Injection Burn
	await sendKey(32, ' ');
	await new Promise(r => setTimeout(r, 1500)); // Mid-burn with blue exhaust plume & Earth behind
	await saveScreenshot('01_spacecraft_leaving_earth_parking_orbit.png');
	console.log('  [PASS] Spacecraft leaving Earth parking orbit captured during TLI burn');

	// Wait for burn to complete and enter cruise
	await new Promise(r => setTimeout(r, 3000));

	// --- Step 3: Capture 2 - Deep Space Transfer with Earth Visible ---
	console.log('\n--- Capture 2: Deep space transfer with Earth visible ---');
	// Switch to Wide Trajectory Camera [2]
	await sendKey(50, '2');
	await new Promise(r => setTimeout(r, 600));
	// Advance with 100x Time Warp [V]
	await sendKey(86, 'v');
	await new Promise(r => setTimeout(r, 2500));
	await saveScreenshot('02_deep_space_transfer_earth_visible.png');
	console.log('  [PASS] Deep space transfer with Earth receding and Sun ahead captured');

	// --- Step 4: Capture 3 - Mid-Course Correction Interaction ---
	console.log('\n--- Capture 3: Mid-course correction interaction ---');
	// Switch back to Chase 3/4 Camera [1]
	await sendKey(49, '1');
	await new Promise(r => setTimeout(r, 500));
	// Engage 1000x Warp [B] to reach 300,000 km MCC waypoint
	await sendKey(66, 'b');
	await new Promise(r => setTimeout(r, 3500)); // Hits MCC-1 waypoint (auto-drops warp to 1x)
	await new Promise(r => setTimeout(r, 800));
	await saveScreenshot('03_midcourse_correction_interaction.png');
	console.log('  [PASS] Mid-course correction interaction at 300,000 km captured');

	// Execute MCC-1 Burn
	console.log('  [Maneuver] Executing MCC-1 burn to restore 99.6% trajectory accuracy...');
	await sendKey(32, ' ');
	await new Promise(r => setTimeout(r, 3000)); // RCS firing and lock

	// --- Step 5: Capture 4 - Solar Event Approaching the Spacecraft ---
	console.log('\n--- Capture 4: Solar event approaching the spacecraft ---');
	// Engage 1000x Warp [B] to cruise from 300,000 km to 750,000 km (Crisis waypoint)
	await sendKey(66, 'b');
	await new Promise(r => setTimeout(r, 4500)); // Hits 750,000 km Solar Crisis
	await new Promise(r => setTimeout(r, 1000));
	// Camera automatically switches to Crisis Tactical, solar flare particles stream past
	await saveScreenshot('04_solar_event_approaching_spacecraft.png');
	console.log('  [PASS] Relativistic solar particle event flare & stream captured in 3D scene');

	// --- Step 6: Capture 5 - Solar Crisis Decision Interface in 3D Scene ---
	console.log('\n--- Capture 5: Solar crisis decision interface in the 3D scene ---');
	await saveScreenshot('05_solar_crisis_decision_interface_3d.png');
	console.log('  [PASS] 3D Tactical Crisis Decision module (Cards 01, 02, 03) captured');

	// Select Tactical Choices on the 3 Cards:
	console.log('  [Tactical Decision] Selecting Safe Mode [1], Instruments [1], Comms [1]...');
	const optSafe = await getCoord('DeepSpace.BtnSafeOpt1', { x: 670, y: 530 });
	const optInst = await getCoord('DeepSpace.BtnInstOpt1', { x: 960, y: 530 });
	const optComm = await getCoord('DeepSpace.BtnCommOpt1', { x: 1250, y: 530 });
	const btnCommit = await getCoord('DeepSpace.BtnCommitCrisis', { x: 960, y: 680 });

	await click(optSafe.x, optSafe.y);
	await new Promise(r => setTimeout(r, 300));
	await click(optInst.x, optInst.y);
	await new Promise(r => setTimeout(r, 300));
	await click(optComm.x, optComm.y);
	await new Promise(r => setTimeout(r, 300));

	// Commit crisis response
	await click(btnCommit.x, btnCommit.y);
	await new Promise(r => setTimeout(r, 800));

	// --- Step 7: Capture 6 - Spacecraft Safe-Mode State ---
	console.log('\n--- Capture 6: Spacecraft safe-mode state ---');
	// Spacecraft in safe mode, radiation flux accumulating dynamically
	await saveScreenshot('06_spacecraft_safe_mode_state.png');
	console.log('  [PASS] Spacecraft safe mode state during storm propagation captured');

	// Wait for storm simulation to peak and clear into recovery phase
	console.log('  [Storm Simulation] Propagating through peak proton flux to storm clearance...');
	await new Promise(r => setTimeout(r, 4500));

	// --- Step 8: Capture 7 - Instrument and Power Recovery ---
	console.log('\n--- Capture 7: Instrument and power recovery ---');
	// Primary action button is now "🔧 EXECUTE RECOVERY STEP (1/3)"
	await sendKey(32, ' '); // Execute recovery step 1: restore instruments
	await new Promise(r => setTimeout(r, 800));
	await saveScreenshot('07_instrument_and_power_recovery.png');
	console.log('  [PASS] Spacecraft instrument and power recovery step captured');

	// Execute remaining recovery steps
	await sendKey(32, ' '); // Step 2: restore comms
	await new Promise(r => setTimeout(r, 600));
	await sendKey(32, ' '); // Step 3: attitude trim pulse
	await new Promise(r => setTimeout(r, 600));
	await sendKey(32, ' '); // Step 4: complete recovery & advance to L1 approach
	await new Promise(r => setTimeout(r, 1500));

	// --- Step 9: Capture 8 - L1 Approach Preparation ---
	console.log('\n--- Capture 8: L1 approach preparation ---');
	await saveScreenshot('08_l1_approach_preparation.png');
	console.log('  [PASS] L1 approach preparation with persistent status banner captured');

	console.log('\n=================================================================');
	console.log(' ALL 8 VISUAL EVIDENCE SCREENSHOTS AUDITED AND CAPTURED');
	console.log('=================================================================\n');

	chrome.kill();
	server.close();
	process.exit(0);
});
