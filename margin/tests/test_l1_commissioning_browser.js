const http = require('http');
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

const HTTP_PORT = 8153;
const CDP_PORT = 9283;
const WEB_DIR = path.resolve(__dirname, '../../build/helios4_test');
const CHROME_PATH = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const PROFILE_DIR = '/tmp/helios4_l1comm_' + Date.now();
const LOCAL_ARTIFACT_DIR = path.resolve(__dirname, '../../artifacts/helios4_l1_commissioning');
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

	ws.onmessage = (event) => {
		const data = JSON.parse(event.data);
		if (data.method === 'Runtime.consoleAPICalled') {
			const text = data.params.args.map(a => (a.value !== undefined ? a.value : (a.description || ''))).join(' ');
			consoleMessages.push(text);
			if (text.includes('[L1Arrival]') || text.includes('[DeepSpace]') || text.includes('[Launch]') || text.includes('[Debrief]')) {
				console.log(`    [GameLog] ${text}`);
			}
		}
		if (data.id && cbs.has(data.id)) {
			const cb = cbs.get(data.id);
			cbs.delete(data.id);
			cb(data.result);
		}
	};

	function callCDP(method, params = {}) {
		return new Promise((resolve) => {
			const id = msgId++;
			cbs.set(id, resolve);
			ws.send(JSON.stringify({ id, method, params }));
		});
	}

	async function click(x, y) {
		await callCDP('Input.dispatchMouseEvent', { type: 'mouseMoved', x, y });
		await new Promise(r => setTimeout(r, 80));
		await callCDP('Input.dispatchMouseEvent', { type: 'mousePressed', x, y, button: 'left', clickCount: 1 });
		await new Promise(r => setTimeout(r, 120));
		await callCDP('Input.dispatchMouseEvent', { type: 'mouseReleased', x, y, button: 'left', clickCount: 1 });
		await new Promise(r => setTimeout(r, 300));
	}

	async function sendKey(keyCode, keyChar) {
		await callCDP('Input.dispatchKeyEvent', { type: 'rawKeyDown', windowsVirtualKeyCode: keyCode, key: keyChar });
		await new Promise(r => setTimeout(r, 80));
		await callCDP('Input.dispatchKeyEvent', { type: 'keyUp', windowsVirtualKeyCode: keyCode, key: keyChar });
		await new Promise(r => setTimeout(r, 200));
	}

	async function saveScreenshot(filename) {
		const res = await callCDP('Page.captureScreenshot', { format: 'png' });
		const buffer = Buffer.from(res.data, 'base64');
		const localPath = path.join(LOCAL_ARTIFACT_DIR, filename);
		const brainPath = path.join(BRAIN_ARTIFACT_DIR, filename);
		fs.writeFileSync(localPath, buffer);
		fs.writeFileSync(brainPath, buffer);
		console.log(`  [Screenshot] Saved: ${filename} (${(buffer.length / 1024).toFixed(1)} KB)`);
	}

	await new Promise(resolve => ws.onopen = resolve);
	await callCDP('Runtime.enable');
	await callCDP('Page.enable');

	console.log('\n=================================================================');
	console.log(' HELIOS-4: PART 4 L1 HALO INSERTION & COMMISSIONING PLAYTEST');
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

	// --- Step 1: Navigate from Main Menu through Launch & Deep Space to L1 ---
	console.log('--- Step 1: Navigating Campaign through Launch & Deep Space to L1 ---');

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
	await new Promise(r => setTimeout(r, 200));
	await click(505.5, 530.0);
	await new Promise(r => setTimeout(r, 200));
	await click(804.0, 530.0);
	await new Promise(r => setTimeout(r, 200));
	await click(1102.5, 530.0);
	await new Promise(r => setTimeout(r, 500));

	// Click FRR Proceed to Launch
	await click(1120, 602);
	await new Promise(r => setTimeout(r, 2000));

	// Trigger Launch Preflight Verify [V] & Countdown [Space]
	console.log('  [Launch] Performing pre-flight check and countdown...');
	await sendKey(86, 'v');
	await new Promise(r => setTimeout(r, 500));
	await sendKey(32, ' ');
	await new Promise(r => setTimeout(r, 11500)); // Liftoff

	// Fast orbital insertion: Press [O] to jump to orbit
	console.log('  [Launch] Fast-forwarding ascent to parking orbit insertion [O]...');
	await sendKey(79, 'o');
	await new Promise(r => setTimeout(r, 1500));

	// Jettison fairing [J]
	await sendKey(74, 'j');
	await new Promise(r => setTimeout(r, 800));

	// Activate systems [E]
	await sendKey(69, 'e');
	await new Promise(r => setTimeout(r, 1500));

	// Proceed to Transfer [Enter]
	console.log('  [Launch] Transitioning to Deep Space Transfer [Enter]...');
	await sendKey(13, 'Enter');
	await new Promise(r => setTimeout(r, 2500));

	// In Deep Space Transfer:
	// Execute TLI Burn [Space]
	console.log('  [DeepSpace] Executing TLI burn...');
	await sendKey(32, ' ');
	await new Promise(r => setTimeout(r, 5000));

	// Warp 1000x [4] to fast forward cruise
	await sendKey(52, '4');
	await new Promise(r => setTimeout(r, 4500));

	// Execute MCC-1 correction [Space]
	console.log('  [DeepSpace] Executing MCC-1 correction burn...');
	await sendKey(32, ' ');
	await new Promise(r => setTimeout(r, 2500));

	// Continue warp 1000x to reach Solar Crisis Alert
	await sendKey(52, '4');
	await new Promise(r => setTimeout(r, 4500));

	// In Solar Crisis: Commit Tactical Decisions [Space]
	console.log('  [DeepSpace] Committing tactical storm response...');
	await sendKey(32, ' ');
	await new Promise(r => setTimeout(r, 4500));

	// In Recovery: Step 0 Diagnostics, Step 1 Instruments, Step 2 Comms, Step 3 Attitude
	console.log('  [DeepSpace] Executing recovery steps...');
	await sendKey(32, ' ');
	await new Promise(r => setTimeout(r, 800));
	await sendKey(32, ' ');
	await new Promise(r => setTimeout(r, 800));
	await sendKey(32, ' ');
	await new Promise(r => setTimeout(r, 800));
	await sendKey(32, ' ');
	await new Promise(r => setTimeout(r, 1200));

	// Warp 1000x to reach L1 Approach
	await sendKey(52, '4');
	await new Promise(r => setTimeout(r, 4000));

	// Now in L1_APPROACH_READY! Press [Space] or [Enter] to advance to Part 4 L1 Arrival
	console.log('  [DeepSpace] Reached L1 Approach! Transitioning to Part 4: L1 Arrival [Enter]...');
	await sendKey(13, 'Enter');
	await new Promise(r => setTimeout(r, 3000));

	// --- Step 2: Part 4 Gameplay Execution & Screenshot Capture ---
	console.log('\n--- Step 2: Executing Part 4 Gameplay & Capturing Screenshots ---');

	// SCREENSHOT 1: Wide Sun-Earth-Spacecraft Environment [Key 2]
	console.log('  [Camera] Switching to WIDE Sun-Earth-Spacecraft view [Key 2]...');
	await sendKey(50, '2');
	await new Promise(r => setTimeout(r, 1000));
	await saveScreenshot('01_sun_earth_spacecraft_wide_environment.png');

	// SCREENSHOT 2: L1 Target and 3D Halo Orbit Trajectory [Key 3]
	console.log('  [Camera] Switching to HALO ORBIT VIEW [Key 3]...');
	await sendKey(51, '3');
	await new Promise(r => setTimeout(r, 1000));
	await saveScreenshot('02_l1_target_and_halo_trajectory.png');

	// Return to Chase View [Key 1]
	await sendKey(49, '1');
	await new Promise(r => setTimeout(r, 600));

	// Execute Approach Navigation Trim Burn [Space]
	console.log('  [Action] Executing Approach Trim Burn [Space]...');
	await sendKey(32, ' ');
	await new Promise(r => setTimeout(r, 1500));

	// Now in STAGE_B_HOI_PLANNING:
	// SCREENSHOT 3: Insertion Maneuver Planning
	console.log('  [Action] Maneuver planning active. Capturing HOI planning interface...');
	await saveScreenshot('03_insertion_maneuver_planning.png');

	// Execute HOI Insertion Burn [Space]
	console.log('  [Action] Igniting main engine for Halo-Orbit Insertion Burn [Space]...');
	await sendKey(32, ' ');
	await new Promise(r => setTimeout(r, 6000)); // Wait for 5s burn execution to complete

	// Now in STAGE_C_STATIONKEEPING:
	// SCREENSHOT 4: Orbit Capture and Stabilization
	console.log('  [Action] Captured into Halo Orbit! Capturing orbit stabilization...');
	await saveScreenshot('04_orbit_capture_and_stabilization.png');

	// Execute Stationkeeping Trim Burn [Space]
	console.log('  [Action] Executing stationkeeping trim burn [Space]...');
	await sendKey(32, ' ');
	await new Promise(r => setTimeout(r, 1500));

	// Now in STAGE_D_COMMISSION_MAG:
	// Switch to Magnetometer Close-Up [Key 4]
	console.log('  [Camera] Switching to Magnetometer Close-Up [Key 4]...');
	await sendKey(52, '4');
	await new Promise(r => setTimeout(r, 800));

	// Deploy and calibrate 3.8m magnetometer boom [Space]
	console.log('  [Action] Deploying and calibrating 3.8m magnetometer boom [Space]...');
	await sendKey(32, ' ');
	await new Promise(r => setTimeout(r, 1200));

	// SCREENSHOT 5: Magnetometer Commissioning
	await saveScreenshot('05_magnetometer_commissioning.png');

	// Now in STAGE_D_COMMISSION_FARADAY:
	// Switch to Faraday Cup Close-Up [Key 5]
	console.log('  [Camera] Switching to Faraday Cup Close-Up [Key 5]...');
	await sendKey(53, '5');
	await new Promise(r => setTimeout(r, 800));

	// Activate and calibrate Faraday Cup [Space]
	console.log('  [Action] Activating Faraday Cup plasma analyzer [Space]...');
	await sendKey(32, ' ');
	await new Promise(r => setTimeout(r, 1200));

	// SCREENSHOT 6: Faraday Cup Commissioning
	await saveScreenshot('06_faraday_cup_commissioning.png');

	// In STAGE_D_SYSTEMS_VERIFY:
	// Verify support systems [Space]
	console.log('  [Action] Verifying spacecraft support systems [Space]...');
	await sendKey(32, ' ');
	await new Promise(r => setTimeout(r, 1200));

	// Now in STAGE_E_SCIENTIFIC_OBSERVATION:
	// Switch to Chase View [Key 1]
	await sendKey(49, '1');
	await new Promise(r => setTimeout(r, 1000));

	// Detect CME Shock from AR-4890 & Compile Packet [Space]
	console.log('  [Action] Detecting CME shockwave and compiling early-warning data packet [Space]...');
	await sendKey(32, ' ');
	await new Promise(r => setTimeout(r, 1500));

	// SCREENSHOT 7: Scientific Observation Display
	await saveScreenshot('07_scientific_observation_display.png');

	// Now in STAGE_F_EARTH_COMM_LOCK:
	// Switch to Earth Dish Boresight View [Key 6]
	console.log('  [Camera] Switching to Earth Communication Dish Boresight [Key 6]...');
	await sendKey(54, '6');
	await new Promise(r => setTimeout(r, 800));

	// Lock high-gain dish on Earth DSN [Space]
	console.log('  [Action] Locking high-gain dish on Earth DSN complexes [Space]...');
	await sendKey(32, ' ');
	await new Promise(r => setTimeout(r, 1200));

	// SCREENSHOT 8: Earth Communication Lock
	await saveScreenshot('08_earth_communication_lock.png');

	// Now in STAGE_F_TRANSMIT_WARNING:
	// Authorize transmission of early-warning packet [Space]
	console.log('  [Action] Authorizing early-warning packet transmission [Space]...');
	await sendKey(32, ' ');
	await new Promise(r => setTimeout(r, 4500)); // Wait for transmission progress to reach 100%

	// SCREENSHOT 9: Early-Warning Packet Transmission & Success Confirmation
	await saveScreenshot('09_early_warning_packet_transmission.png');

	// Now in MISSION_SUCCESS_DEBRIEF:
	// Click Proceed to Debrief
	console.log('  [Action] Advancing to Mission Debrief [Enter]...');
	await sendKey(13, 'Enter');
	await new Promise(r => setTimeout(r, 3000));

	// SCREENSHOT 10: Final Mission Complete Debrief Scorecard
	console.log('  [Debrief] Capturing final mission debrief scorecard...');
	await saveScreenshot('10_final_mission_complete_debrief.png');

	console.log('\n=================================================================');
	console.log(' PLAYTEST COMPLETE: ALL 10 VERIFICATION SCREENSHOTS CAPTURED');
	console.log('=================================================================\n');

	chrome.kill();
	server.close();
	process.exit(0);
});
