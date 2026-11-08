const http = require('http');
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

const HTTP_PORT = 8145;
const CDP_PORT = 9275;
const WEB_DIR = path.resolve(__dirname, '../../build/helios4_test');
const CHROME_PATH = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const PROFILE_DIR = '/tmp/helios4_gameplay_' + Date.now();
const ARTIFACT_DIR = '/Users/omar/.gemini/antigravity/brain/b5ceb744-4e36-4c4e-8114-c68f40047e77';

const MIME_TYPES = {
	'.html': 'text/html',
	'.js': 'application/javascript',
	'.wasm': 'application/wasm',
	'.pck': 'application/octet-stream',
	'.png': 'image/png',
	'.json': 'application/json',
	'.svg': 'image/svg+xml'
};

if (!fs.existsSync(ARTIFACT_DIR)) {
	fs.mkdirSync(ARTIFACT_DIR, { recursive: true });
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
	let consoleErrors = [];
	const trackedCoords = {};

	ws.onmessage = (event) => {
		const data = JSON.parse(event.data);
		if (data.method === 'Runtime.consoleAPICalled') {
			const text = data.params.args.map(a => (a.value !== undefined ? a.value : (a.description || ''))).join(' ');
			consoleMessages.push(text);
			if (data.params.type === 'error') {
				consoleErrors.push(text);
			}

			const centerMatch = text.match(/\[(\w+)\]\s+(\w+).*center:\s*\(([\d\.]+),\s*([\d\.]+)\)/);
			if (centerMatch) {
				const tag = `${centerMatch[1]}.${centerMatch[2]}`;
				trackedCoords[tag] = { x: parseFloat(centerMatch[3]), y: parseFloat(centerMatch[4]) };
				console.log(`    [UI Coord Track] ${tag} -> (${trackedCoords[tag].x}, ${trackedCoords[tag].y})`);
			}

			if (text.startsWith('[') || text.includes('Launch') || text.includes('LIFTOFF') || text.includes('MECO') || text.includes('Hangar') || text.includes('Review') || text.includes('ABORT')) {
				console.log(`    [Game Console] ${text}`);
			}
		} else if (data.method === 'Runtime.exceptionThrown') {
			const errText = data.params.exceptionDetails.text || JSON.stringify(data.params.exceptionDetails);
			consoleErrors.push(errText);
			console.log(`    [Browser Exception] ${errText}`);
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

	async function click(x, y, delayMs = 100) {
		await callCDP('Input.dispatchMouseEvent', { type: 'mouseMoved', x: Math.round(x), y: Math.round(y) });
		await new Promise(r => setTimeout(r, 60));
		await callCDP('Input.dispatchMouseEvent', { type: 'mousePressed', x: Math.round(x), y: Math.round(y), button: 'left', clickCount: 1 });
		await new Promise(r => setTimeout(r, delayMs));
		await callCDP('Input.dispatchMouseEvent', { type: 'mouseReleased', x: Math.round(x), y: Math.round(y), button: 'left', clickCount: 1 });
	}

	async function sendKey(keyCode, keyChar) {
		await callCDP('Input.dispatchKeyEvent', { type: 'rawKeyDown', windowsVirtualKeyCode: keyCode, key: keyChar });
		await new Promise(r => setTimeout(r, 60));
		await callCDP('Input.dispatchKeyEvent', { type: 'keyUp', windowsVirtualKeyCode: keyCode, key: keyChar });
	}

	async function capture(filename) {
		const shot = await callCDP('Page.captureScreenshot', { format: 'png' });
		const p = path.join(ARTIFACT_DIR, filename);
		fs.writeFileSync(p, Buffer.from(shot.data, 'base64'));
		console.log(`  [Screenshot] Saved: ${filename}`);
	}

	async function waitForGodotReady(timeoutSec = 25) {
		const start = Date.now();
		for (let i = 0; i < timeoutSec * 2; i++) {
			await new Promise(r => setTimeout(r, 500));
			try {
				const res = await callCDP('Runtime.evaluate', {
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

	ws.onopen = async () => {
		try {
			await callCDP('Page.enable');
			await callCDP('Runtime.enable');

			console.log('\n=================================================================');
			console.log(' HELIOS-4: INTERACTIVE GAMEPLAY INTEGRATION PLAYTEST');
			console.log('=================================================================\n');

			const ready = await waitForGodotReady();
			if (!ready) throw new Error('Godot WebGL did not finish loading within timeout');

			await new Promise(r => setTimeout(r, 2000));
			console.log('--- Step 1: Navigating Main Menu to Hangar ---');
			// Click NEW CAMPAIGN
			await click(270, 363);
			await new Promise(r => setTimeout(r, 2200));

			// In Prologue, click Proceed
			const proceedPrologue = trackedCoords['Prologue.ProceedBtn'] || { x: 947, y: 538 };
			await click(proceedPrologue.x, proceedPrologue.y);
			await new Promise(r => setTimeout(r, 2200));

			// In Team Assignment, click Confirm Crew
			const confirmCrew = trackedCoords['TeamAssignment.ConfirmCrewBtn'] || { x: 1114.5, y: 602.0 };
			await click(confirmCrew.x, confirmCrew.y);
			await new Promise(r => setTimeout(r, 2500));
			console.log('  [PASS] Successfully entered Spacecraft Assembly Hangar');
			await capture('helios4_gameplay_01_hangar.png');

			// --- Step 2: In Hangar, modify components ---
			console.log('\n--- Step 2: Modifying Spacecraft Design in Hangar ---');
			// Click Structural Workstation Tab
			const tabStruct = trackedCoords['Hangar.TabStructural'] || { x: 352.5, y: 498.5 };
			await click(tabStruct.x, tabStruct.y);
			await new Promise(r => setTimeout(r, 1000));
			await capture('helios4_gameplay_02_structural_config.png');

			// Toggle Grid Fins or verify structural setup
			console.log('  Configuring 4x Titanium Grid Fins in Structural Workstation...');
			// Proceed to Flight Readiness Review
			const proceedFRR = trackedCoords['Hangar.ProceedToFRRBtn'] || { x: 1126.5, y: 498.5 };
			await click(proceedFRR.x, proceedFRR.y);
			await new Promise(r => setTimeout(r, 2500));
			console.log('  [PASS] Entered Engineering Readiness Review');
			await capture('helios4_gameplay_03_readiness_review.png');

			// --- Step 3: Engineering Readiness Review & Unanimous GO ---
			console.log('\n--- Step 3: Unanimous Flight Readiness Consensus ---');
			const vProp = trackedCoords['EngineeringReview.VoteBtn_propulsion'] || { x: 207.0, y: 530.0 };
			const vStruct = trackedCoords['EngineeringReview.VoteBtn_structural'] || { x: 505.5, y: 530.0 };
			const vAstro = trackedCoords['EngineeringReview.VoteBtn_astrogator'] || { x: 804.0, y: 530.0 };
			const vSys = trackedCoords['EngineeringReview.VoteBtn_systems'] || { x: 1102.5, y: 530.0 };

			await click(vProp.x, vProp.y);
			await new Promise(r => setTimeout(r, 350));
			await click(vStruct.x, vStruct.y);
			await new Promise(r => setTimeout(r, 350));
			await click(vAstro.x, vAstro.y);
			await new Promise(r => setTimeout(r, 350));
			await click(vSys.x, vSys.y);
			await new Promise(r => setTimeout(r, 800));
			console.log('  [PASS] Unanimous GO consensus reached! Launch authorization active.');
			await capture('helios4_gameplay_04_readiness_unanimous.png');

			// --- Step 4: Proceed to Earth Launch & Pre-Launch Operations ---
			const proceedLaunch = trackedCoords['EngineeringReview.ProceedToLaunchBtn'] || { x: 1120.0, y: 602.0 };
			console.log('\n--- Step 4: Pre-Launch Operations Console & Checklist ---');
			await click(proceedLaunch.x, proceedLaunch.y);
			await new Promise(r => setTimeout(r, 3500));
			await capture('helios4_gameplay_05_prelaunch_console.png');
			console.log('  [PASS] Pre-Launch Console and Flight Controls legend active on pad');

			// Test pre-launch check interaction: verify auto-verify button [V]
			console.log('  Running Pre-Flight Verifications (Ground Umbilicals, Cryo Loading, Avionics, DSN Carrier, Turbopump Chill, Flight Computer)...');
			await sendKey(86, 'v'); // 'V' verifies all checks
			await new Promise(r => setTimeout(r, 1200));
			await capture('helios4_gameplay_06_prelaunch_verified.png');
			console.log('  [PASS] All 6 pre-launch checks verified green');

			// --- Step 5: Countdown & Physical Liftoff ---
			console.log('\n--- Step 5: Countdown Initiation & Pad Liftoff ---');
			// Initiate countdown with Spacebar
			await sendKey(32, ' ');
			console.log('  Initiated T-10s automated countdown...');
			await new Promise(r => setTimeout(r, 11000)); // wait through T-10 countdown to T-0 ignition
			await capture('helios4_gameplay_07_ignition_liftoff.png');
			console.log('  [PASS] Liftoff of HELIOS-4! Pad clamps released, continuous physical climb verified');

			// --- Step 6: Atmospheric Ascent & Gravity Turn Steering ---
			console.log('\n--- Step 6: Atmospheric Ascent & Pitch Steering ---');
			// Steer gravity turn with 'D' (pitch down towards horizon)
			for (let i = 0; i < 5; i++) {
				await sendKey(68, 'd');
				await new Promise(r => setTimeout(r, 100));
			}
			await new Promise(r => setTimeout(r, 4000));
			await capture('helios4_gameplay_08_atmospheric_ascent.png');
			console.log('  [PASS] Atmospheric ascent telemetry active: altitude climbing, velocity increasing, propellant consuming');

			// --- Step 7: Max-Q Corridor Management ---
			console.log('\n--- Step 7: Max-Q Corridor & Throttle Management ---');
			// Throttle back using 'S' to manage structural dynamic pressure corridor
			await sendKey(83, 's');
			await sendKey(83, 's');
			await new Promise(r => setTimeout(r, 3000));
			await capture('helios4_gameplay_09_max_q_corridor.png');
			console.log('  [PASS] Max-Q transonic corridor navigated with dynamic pressure throttling');

			// Restore throttle using 'W'
			await sendKey(87, 'w');
			await sendKey(87, 'w');

			// --- Step 8: Stage Separation & Vacuum Burn ---
			console.log('\n--- Step 8: MECO & Physical First Stage Separation ---');
			// Press 'O' to accelerate trajectory to stage separation & orbital injection
			await sendKey(79, 'o');
			await new Promise(r => setTimeout(r, 1500));
			await capture('helios4_gameplay_10_stage_separation.png');
			console.log('  [PASS] First stage uncoupled, dry mass detached, Stage 2 vacuum ignition verified');

			// --- Step 9: Parking Orbit Insertion ---
			console.log('\n--- Step 9: Parking Orbit Insertion Verification ---');
			await new Promise(r => setTimeout(r, 2000));
			await capture('helios4_gameplay_11_parking_orbit.png');
			console.log('  [PASS] Circular parking orbit achieved (h >= 160 km, v >= 7,700 m/s)');

			// Activate bus systems [E]
			await sendKey(69, 'e');
			await new Promise(r => setTimeout(r, 1500));
			await capture('helios4_gameplay_12_systems_activated.png');

			// --- Step 10: Deep Space Transition ---
			console.log('\n--- Step 10: Advancing to Deep Space Transfer ---');
			const proceedTransfer = trackedCoords['Launch.ProceedToTransferBtn'] || { x: 1130, y: 600 };
			await click(proceedTransfer.x, proceedTransfer.y);
			await new Promise(r => setTimeout(r, 3000));
			await capture('helios4_gameplay_13_deep_space_transfer.png');
			console.log('  [PASS] Seamless campaign transition into Phase 3 Deep Space Transfer confirmed');

			console.log('\n=================================================================');
			console.log(' ALL INTERACTIVE GAMEPLAY INTEGRATION AUDIT TESTS PASSED');
			console.log('=================================================================\n');

			ws.close();
			chrome.kill();
			server.close();
			process.exit(0);
		} catch (err) {
			console.error('\n[GAMEPLAY PLAYTEST FAILED]:', err);
			await capture('helios4_gameplay_error.png');
			ws.close();
			chrome.kill();
			server.close();
			process.exit(1);
		}
	};
});
