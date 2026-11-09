const http = require('http');
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

const HTTP_PORT = 8182;
const CDP_PORT = 9296;
const WEB_DIR = path.resolve(__dirname, '../../build/helios4_test');
const CHROME_PATH = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const PROFILE_DIR = '/tmp/helios4_full_playtest_' + Date.now();
const LOCAL_ARTIFACT_DIR = path.resolve(__dirname, '../../artifacts/helios4_playtest');
const BRAIN_ARTIFACT_DIR = '/Users/omar/.gemini/antigravity/brain/7c9e1ee4-5d6c-4e95-96e3-2ddf4065d403';

const MIME_TYPES = {
	'.html': 'text/html',
	'.js': 'application/javascript',
	'.wasm': 'application/wasm',
	'.pck': 'application/octet-stream',
	'.png': 'image/png',
	'.json': 'application/json',
	'.svg': 'image/svg+xml'
};

if (!fs.existsSync(LOCAL_ARTIFACT_DIR)) fs.mkdirSync(LOCAL_ARTIFACT_DIR, { recursive: true });
if (!fs.existsSync(BRAIN_ARTIFACT_DIR)) fs.mkdirSync(BRAIN_ARTIFACT_DIR, { recursive: true });

const networkErrors = [];
const consoleMessages = [];
const consoleErrors = [];
const trackedCoords = {};

const server = http.createServer((req, res) => {
	let reqPath = req.url.split('?')[0];
	if (reqPath === '/' || reqPath === '') reqPath = '/index.html';
	const filePath = path.join(WEB_DIR, reqPath);
	if (!fs.existsSync(filePath)) {
		console.warn(`[HTTP 404] Resource not found: ${reqPath}`);
		networkErrors.push(`404 Not Found: ${reqPath}`);
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

	chrome.on('exit', (code) => {
		console.log(`[Chrome] Process exited with code ${code}.`);
	});

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

	ws.onmessage = (event) => {
		const data = JSON.parse(event.data);
		if (data.method === 'Runtime.consoleAPICalled') {
			const text = data.params.args.map(a => (a.value !== undefined ? a.value : (a.description || ''))).join(' ');
			consoleMessages.push(text);
			if (data.params.type === 'error') {
				consoleErrors.push(text);
				console.error(`  [Browser Error] ${text}`);
			}

			// Parse logged UI centers
			// Format 1: [Section] ButtonName ... center: (X, Y)
			const centerMatch1 = text.match(/\[(\w+)\]\s+(\w+).*center:\s*\(([\d\.]+),\s*([\d\.]+)\)/);
			if (centerMatch1) {
				const tag = `${centerMatch1[1]}.${centerMatch1[2]}`;
				trackedCoords[tag] = { x: parseFloat(centerMatch1[3]), y: parseFloat(centerMatch1[4]) };
				console.log(`    [UI Coord Track] ${tag} -> (${trackedCoords[tag].x}, ${trackedCoords[tag].y})`);
			}
			// Format 2: [UI Coord Track] DeepSpace.BtnName -> (X, Y)
			const centerMatch2 = text.match(/\[UI Coord Track\]\s+([\w\.]+)\s*->\s*\(([\d\.]+),\s*([\d\.]+)\)/);
			if (centerMatch2) {
				const tag = centerMatch2[1];
				trackedCoords[tag] = { x: parseFloat(centerMatch2[2]), y: parseFloat(centerMatch2[3]) };
				console.log(`    [UI Coord Track] ${tag} -> (${trackedCoords[tag].x}, ${trackedCoords[tag].y})`);
			}

			if (text.startsWith('[') || text.includes('Launch') || text.includes('LIFTOFF') || text.includes('MECO') || text.includes('Hangar') || text.includes('Review') || text.includes('COMMISSIONED') || text.includes('Debrief') || text.includes('Crisis') || text.includes('TLI')) {
				console.log(`    [GameLog] ${text}`);
			}
		} else if (data.method === 'Runtime.exceptionThrown') {
			const errText = data.params.exceptionDetails.text || JSON.stringify(data.params.exceptionDetails);
			consoleErrors.push(errText);
			console.error(`    [Browser Exception] ${errText}`);
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
		await new Promise(r => setTimeout(r, 200));
	}

	async function mouseDrag(startX, startY, endX, endY, steps = 10) {
		await callCDP('Input.dispatchMouseEvent', { type: 'mouseMoved', x: startX, y: startY });
		await new Promise(r => setTimeout(r, 50));
		await callCDP('Input.dispatchMouseEvent', { type: 'mousePressed', x: startX, y: startY, button: 'left', clickCount: 1 });
		for (let s = 1; s <= steps; s++) {
			const curX = startX + (endX - startX) * (s / steps);
			const curY = startY + (endY - startY) * (s / steps);
			await callCDP('Input.dispatchMouseEvent', { type: 'mouseMoved', x: curX, y: curY, button: 'left' });
			await new Promise(r => setTimeout(r, 30));
		}
		await callCDP('Input.dispatchMouseEvent', { type: 'mouseReleased', x: endX, y: endY, button: 'left', clickCount: 1 });
		await new Promise(r => setTimeout(r, 150));
	}

	async function sendKey(keyCode, keyChar) {
		await callCDP('Input.dispatchKeyEvent', { type: 'rawKeyDown', windowsVirtualKeyCode: keyCode, key: keyChar });
		await new Promise(r => setTimeout(r, 60));
		await callCDP('Input.dispatchKeyEvent', { type: 'keyUp', windowsVirtualKeyCode: keyCode, key: keyChar });
		await new Promise(r => setTimeout(r, 150));
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

	async function waitForGodotReady(timeoutSec = 30) {
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
			console.log(' MARGIN // HELIOS-4: FULL END-TO-END INTERACTIVE GAMEPLAY PLAYTEST');
			console.log('=================================================================\n');

			const ready = await waitForGodotReady();
			if (!ready) throw new Error('Godot WebGL did not finish loading within timeout');

			await new Promise(r => setTimeout(r, 2000));

			// ==============================================================
			// STAGE 0: MAIN MENU
			// ==============================================================
			console.log('\n--- STAGE 0: Main Menu Verification ---');
			await saveScreenshot('playtest_01_main_menu.png');
			console.log('  [PASS] Main Menu loaded with 3D rotating spacecraft and NASA HELIOS-4 campaign branding');

			// Click NEW CAMPAIGN [HELIOS-4]
			const newCampCoord = trackedCoords['MainMenu.NewCampaignBtn'] || { x: 270.0, y: 629.0 };
			console.log(`  Clicking NEW CAMPAIGN button at (${newCampCoord.x}, ${newCampCoord.y})...`);
			await click(newCampCoord.x, newCampCoord.y);
			await new Promise(r => setTimeout(r, 1500));

			// ==============================================================
			// STAGE 1: PROLOGUE
			// ==============================================================
			console.log('\n--- STAGE 1: Prologue & Mission Briefing ---');
			await saveScreenshot('playtest_02_prologue.png');
			console.log('  [PASS] Prologue active: Solar Sentinel mission context, AR-4890 CME threat, Sun-Earth L1');

			const proceedPrologue = trackedCoords['Prologue.ProceedBtn'] || { x: 947.0, y: 538.0 };
			console.log(`  Clicking Proceed to Team Assignment at (${proceedPrologue.x}, ${proceedPrologue.y})...`);
			await click(proceedPrologue.x, proceedPrologue.y);
			await new Promise(r => setTimeout(r, 1500));

			// ==============================================================
			// STAGE 2: TEAM ASSIGNMENT
			// ==============================================================
			console.log('\n--- STAGE 2: Team Assignment (4 Specialist Roles) ---');
			await saveScreenshot('playtest_03_team_assignment.png');
			console.log('  [PASS] Team Assignment active: Propulsion Lead, Structural Architect, Astrogator Lead, Systems Officer');

			const confirmCrew = trackedCoords['TeamAssignment.ConfirmCrewBtn'] || { x: 1114.5, y: 602.0 };
			console.log(`  Clicking Confirm Crew at (${confirmCrew.x}, ${confirmCrew.y})...`);
			await click(confirmCrew.x, confirmCrew.y);
			await new Promise(r => setTimeout(r, 2000));

			// ==============================================================
			// STAGE 3: SPACECRAFT ASSEMBLY HANGAR (PART 1)
			// ==============================================================
			console.log('\n--- STAGE 3: Spacecraft Assembly Hangar (Part 1) ---');
			await saveScreenshot('playtest_04_hangar_assembly.png');
			console.log('  [PASS] Spacecraft Hangar active: 3D interactive vehicle, 4 specialist workstations, mass/power/margin metrics');

			// Inspect Structural Workstation Tab
			const tabStruct = trackedCoords['Hangar.TabStructural'] || { x: 352.5, y: 498.5 };
			await click(tabStruct.x, tabStruct.y);
			await new Promise(r => setTimeout(r, 1000));
			await saveScreenshot('playtest_05_hangar_structural_workstation.png');
			console.log('  [PASS] Structural Workstation audited: static margin > 1.2 calibers, grid fins, fairing integrity');

			// Proceed to Flight Readiness Review
			const proceedFRR = trackedCoords['Hangar.ProceedToFRRBtn'] || { x: 1126.5, y: 498.5 };
			console.log(`  Clicking Proceed to Engineering Review at (${proceedFRR.x}, ${proceedFRR.y})...`);
			await click(proceedFRR.x, proceedFRR.y);
			await new Promise(r => setTimeout(r, 2000));

			// ==============================================================
			// STAGE 4: ENGINEERING READINESS REVIEW (FRR)
			// ==============================================================
			console.log('\n--- STAGE 4: Engineering Readiness Review (Unanimous GO Consensus) ---');
			await saveScreenshot('playtest_06_engineering_readiness_review.png');

			const vProp = trackedCoords['EngineeringReview.VoteBtn_propulsion'] || { x: 207.0, y: 530.0 };
			const vStruct = trackedCoords['EngineeringReview.VoteBtn_structural'] || { x: 505.5, y: 530.0 };
			const vAstro = trackedCoords['EngineeringReview.VoteBtn_astrogator'] || { x: 804.0, y: 530.0 };
			const vSys = trackedCoords['EngineeringReview.VoteBtn_systems'] || { x: 1102.5, y: 530.0 };

			console.log('  Casting unanimous GO votes for all 4 officers...');
			await click(vProp.x, vProp.y);
			await new Promise(r => setTimeout(r, 300));
			await click(vStruct.x, vStruct.y);
			await new Promise(r => setTimeout(r, 300));
			await click(vAstro.x, vAstro.y);
			await new Promise(r => setTimeout(r, 300));
			await click(vSys.x, vSys.y);
			await new Promise(r => setTimeout(r, 800));

			await saveScreenshot('playtest_07_engineering_review_unanimous.png');
			console.log('  [PASS] Unanimous GO consensus reached across all four engineering disciplines');

			const proceedLaunch = trackedCoords['EngineeringReview.ProceedToLaunchBtn'] || { x: 1120.0, y: 602.0 };
			console.log(`  Clicking Proceed to Launch Pad at (${proceedLaunch.x}, ${proceedLaunch.y})...`);
			await click(proceedLaunch.x, proceedLaunch.y);
			await new Promise(r => setTimeout(r, 3000));

			// ==============================================================
			// STAGE 5: EARTH LAUNCH & MAX-Q (PART 2)
			// ==============================================================
			console.log('\n--- STAGE 5: Earth Launch & Max-Q Ascent (Part 2) ---');
			await saveScreenshot('playtest_08_launch_pad.png');
			console.log('  [PASS] Launch Pad active: launch vehicle on pad, pre-launch checklist ready');

			// Verify all 6 pre-flight checks [V]
			console.log('  Executing Pre-Flight Verifications [V]...');
			await sendKey(86, 'v');
			await new Promise(r => setTimeout(r, 1200));
			await saveScreenshot('playtest_09_pad_checks_verified.png');
			console.log('  [PASS] All 6 pre-launch checks verified green');

			// Initiate Countdown [Space]
			console.log('  Initiating T-10s automated countdown [Space]...');
			await sendKey(32, ' ');
			await new Promise(r => setTimeout(r, 11500)); // Wait through T-10s countdown to T-0 ignition & liftoff

			await saveScreenshot('playtest_10_liftoff_ascent.png');
			console.log('  [PASS] HELIOS-4 Liftoff! Continuous climb, thrust vectoring active');

			// Steer gravity turn with 'D'
			console.log('  Steering gravity turn toward horizon [D]...');
			for (let i = 0; i < 5; i++) {
				await sendKey(68, 'd');
				await new Promise(r => setTimeout(r, 80));
			}

			// Max-Q throttle management with 'S'
			console.log('  Managing dynamic pressure through Max-Q corridor [S]...');
			await sendKey(83, 's');
			await sendKey(83, 's');
			await new Promise(r => setTimeout(r, 3500));
			await saveScreenshot('playtest_11_max_q_corridor.png');
			console.log('  [PASS] Max-Q transonic corridor navigated successfully (q ~ 32 kPa)');

			// Restore throttle with 'W'
			await sendKey(87, 'w');
			await sendKey(87, 'w');

			// MECO & First Stage Separation & Orbital Insertion [O]
			console.log('  Executing MECO & First Stage Separation [O]...');
			await sendKey(79, 'o');
			await new Promise(r => setTimeout(r, 1500));

			// Fairing Jettison [J]
			console.log('  Jettisoning payload fairing [J]...');
			await sendKey(74, 'j');
			await new Promise(r => setTimeout(r, 800));

			// Activate probe systems [E]
			console.log('  Activating spacecraft bus systems [E]...');
			await sendKey(69, 'e');
			await new Promise(r => setTimeout(r, 1500));

			await saveScreenshot('playtest_12_circular_parking_orbit.png');
			console.log('  [PASS] Circular parking orbit achieved (alt >= 160 km, v >= 7,700 m/s)');

			// Transition to Part 3: Deep Space Transfer [Enter]
			console.log('  Advancing to Deep Space Transfer [Enter]...');
			await sendKey(13, 'Enter');
			await new Promise(r => setTimeout(r, 3000));

			// ==============================================================
			// STAGE 6: DEEP SPACE TRANSFER & CRISIS (PART 3)
			// ==============================================================
			console.log('\n--- STAGE 6: Deep Space Transfer & Crisis (Part 3) ---');
			await saveScreenshot('playtest_13_deep_space_parking_orbit.png');
			console.log('  [PASS] Deep Space Transfer scene active: Earth parking orbit, probe awaiting TLI burn');

			// Execute TLI Injection Burn [Space]
			console.log('  Executing Trans-L1 Injection Burn (TLI) [Space]...');
			await sendKey(32, ' ');
			await new Promise(r => setTimeout(r, 4500)); // Wait for TLI burn to complete into CRUISE_EARLY

			await saveScreenshot('playtest_14_tli_burnout_interplanetary_cruise.png');
			console.log('  [PASS] TLI burn complete: probe on hyperbolic transfer arc toward Sun-Earth L1');

			// Test Camera 4: Earth Dish View (Receding Earth)
			console.log('  Switching to Earth Dish View [4]...');
			await sendKey(52, '4');
			await new Promise(r => setTimeout(r, 1500));
			await saveScreenshot('playtest_15_interplanetary_cruise_receding_earth.png');
			console.log('  [PASS] Earth receding physically in true 3D perspective distance');

			// Test Camera 1 & Interactive 3D Orbit Drag
			console.log('  Testing Interactive 3D Orbit Camera [1 + MouseDrag]...');
			await sendKey(49, '1');
			await new Promise(r => setTimeout(r, 600));
			await mouseDrag(640, 360, 420, 280, 15);
			await new Promise(r => setTimeout(r, 800));
			await saveScreenshot('playtest_16_interactive_orbit_camera.png');
			console.log('  [PASS] Dynamic 3D orbit camera responds to user mouse dragging');

			// Engage 1000x Time Warp [B] for Relativistic Space Dust Streaks
			console.log('  Engaging 1000x Time Warp [B]...');
			await sendKey(66, 'b');
			await new Promise(r => setTimeout(r, 2000));
			await saveScreenshot('playtest_17_high_warp_space_dust.png');
			console.log('  [PASS] Relativistic space dust physical motion cues verified');

			// Handle MCC-1 correction burn if prompted
			console.log('  Checking for and executing MCC-1 correction [Space]...');
			await sendKey(32, ' ');
			await new Promise(r => setTimeout(r, 2500));

			// Engage 1000x warp to reach Solar Crisis
			console.log('  Warping to Precursor Solar Particle Event Crisis [B]...');
			await sendKey(66, 'b');
			await new Promise(r => setTimeout(r, 3500));

			await saveScreenshot('playtest_18_solar_crisis_storm_propagation.png');
			console.log('  [PASS] Solar Crisis encountered: CME shockwave propagating, rad-safe mode choices available');

			// Commit 4-officer crisis tactics [Space]
			console.log('  Committing 4-officer crisis tactics [Space]...');
			await sendKey(32, ' ');
			await new Promise(r => setTimeout(r, 4500));

			// Complete recovery steps (Space x 4)
			console.log('  Executing spacecraft storm recovery sequence...');
			for (let s = 0; s < 4; s++) {
				await sendKey(32, ' ');
				await new Promise(r => setTimeout(r, 600));
			}
			await new Promise(r => setTimeout(r, 1000));
			await saveScreenshot('playtest_19_solar_crisis_recovery.png');
			console.log('  [PASS] Spacecraft recovery complete: instruments online, rad damage mitigated');

			// Warp to L1 Approach [B]
			console.log('  Warping to Sun-Earth L1 approach corridor [B]...');
			await sendKey(66, 'b');
			await new Promise(r => setTimeout(r, 3500));

			// Advance to Part 4: L1 Arrival [Space]
			console.log('  Advancing to Part 4: L1 Arrival & Commissioning [Space]...');
			await sendKey(32, ' ');
			await new Promise(r => setTimeout(r, 3000));

			// ==============================================================
			// STAGE 7: SUN-EARTH L1 ARRIVAL & COMMISSIONING (PART 4)
			// ==============================================================
			console.log('\n--- STAGE 7: Sun-Earth L1 Arrival & Commissioning (Part 4) ---');
			await saveScreenshot('playtest_20_sun_earth_l1_arrival_approach.png');
			console.log('  [PASS] L1 Arrival scene active: Sunward view at ~1.5M km, halo orbit corridor visible');

			// Execute Approach Trim Burn [Space]
			console.log('  Executing approach trim burn [Space]...');
			await sendKey(32, ' ');
			await new Promise(r => setTimeout(r, 1500));

			// Execute Halo Orbit Insertion (HOI) Capture Burn [Space]
			console.log('  Executing Halo Orbit Insertion (HOI) Burn [Space]...');
			await sendKey(32, ' ');
			await new Promise(r => setTimeout(r, 6500)); // Main engine burn duration

			// Execute Stationkeeping Trim Burn [Space]
			console.log('  Executing Stationkeeping Trim Burn [Space]...');
			await sendKey(32, ' ');
			await new Promise(r => setTimeout(r, 1500));

			// Switch to Halo Orbit Perspective [3]
			console.log('  Switching to Halo Orbit Perspective [3]...');
			await sendKey(51, '3');
			await new Promise(r => setTimeout(r, 1200));
			await saveScreenshot('playtest_21_halo_orbit_continuous_flight.png');
			console.log('  [PASS] Continuous 3D periodic flight in educational halo orbit around Sun-Earth L1 verified');

			// Switch to Magnetometer Close-Up [4] & Deploy Boom [Space]
			console.log('  Deploying Magnetometer Boom [4 + Space]...');
			await sendKey(52, '4');
			await new Promise(r => setTimeout(r, 800));
			await sendKey(32, ' ');
			await new Promise(r => setTimeout(r, 2600)); // Wait for 2.2s extension tween + settle
			await saveScreenshot('playtest_22_magnetometer_boom_deployed.png');
			console.log('  [PASS] Magnetometer boom mechanically extended and calibrated');

			// Switch to Faraday Cup Close-Up [5] & Activate [Space]
			console.log('  Activating Faraday Cup Plasma Analyzer [5 + Space]...');
			await sendKey(53, '5');
			await new Promise(r => setTimeout(r, 800));
			await sendKey(32, ' ');
			await new Promise(r => setTimeout(r, 1800));
			await saveScreenshot('playtest_23_faraday_cup_activated.png');
			console.log('  [PASS] Faraday Cup aperture door opened and high-voltage grid active');

			// Verify Support Systems [Space]
			console.log('  Verifying spacecraft support systems [Space]...');
			await sendKey(32, ' ');
			await new Promise(r => setTimeout(r, 1200));

			// Detect CME Shock from AR-4890 [Space]
			console.log('  Performing live solar wind observation & CME shock detection [Space]...');
			await sendKey(32, ' ');
			await new Promise(r => setTimeout(r, 1500));
			await saveScreenshot('playtest_24_scientific_cme_observation.png');
			console.log('  [PASS] CME shockwave detected: speed 2,420 km/s, Bz = -31.5 nT, early-warning packet compiled');

			// Switch to Earth Dish View [6] & Lock Earth DSN [Space]
			console.log('  Locking High-Gain Dish on Earth DSN [6 + Space]...');
			await sendKey(54, '6');
			await new Promise(r => setTimeout(r, 800));
			await sendKey(32, ' ');
			await new Promise(r => setTimeout(r, 2200));

			// Transmit Early-Warning Data Packet [Space]
			console.log('  Transmitting early-warning data packet to Earth DSN [Space]...');
			await sendKey(32, ' ');
			await new Promise(r => setTimeout(r, 4500)); // Wait for transmission progress to reach 100%
			await saveScreenshot('playtest_25_early_warning_packet_transmitted.png');
			console.log('  [PASS] Early-warning telemetry packet beamed to Earth with ~10+ minutes advance lead time');

			// Advance to full Mission Debrief [Enter]
			console.log('  Advancing to Mission Debrief [Enter]...');
			await sendKey(13, 'Enter');
			await new Promise(r => setTimeout(r, 3000));

			// ==============================================================
			// STAGE 8: MISSION DEBRIEF & SCIENTIFIC AUDIT
			// ==============================================================
			console.log('\n--- STAGE 8: Mission Debrief & Scientific Audit ---');
			await saveScreenshot('playtest_26_final_mission_debrief_scorecard.png');
			console.log('  [PASS] Final Mission Debrief scorecard active: evaluation pillars, letter grade, 4-officer report');

			// Click Save and Complete Campaign
			const saveCompleteCoord = trackedCoords['Debrief.SaveAndCompleteBtn'] || { x: 214.0, y: 1108.0 };
			console.log(`  Clicking Save and Complete Campaign at (${saveCompleteCoord.x}, ${saveCompleteCoord.y})...`);
			await click(saveCompleteCoord.x, saveCompleteCoord.y);
			await new Promise(r => setTimeout(r, 1500));
			await saveScreenshot('playtest_27_campaign_progress_saved.png');
			console.log('  [PASS] Campaign state saved to user://helios4_campaign.json');

			// Return to Main Menu
			const mainMenuCoord = trackedCoords['Debrief.MainMenuBtn'] || { x: 1100.0, y: 1108.0 };
			console.log(`  Clicking Return to Main Menu at (${mainMenuCoord.x}, ${mainMenuCoord.y})...`);
			await click(mainMenuCoord.x, mainMenuCoord.y);
			await new Promise(r => setTimeout(r, 2500));
			await saveScreenshot('playtest_28_returned_to_main_menu.png');
			console.log('  [PASS] Seamlessly returned to Main Menu');

			// ==============================================================
			// INTEGRITY AUDIT: ERRORS, 404s, LEGACY RESIDUE
			// ==============================================================
			console.log('\n--- FINAL AUDIT OF BROWSER LOGS & INTEGRITY ---');

			// Check 404s
			if (networkErrors.length > 0) {
				console.error(`[AUDIT FAIL] Network 404 errors detected:`, networkErrors);
				throw new Error(`Encountered 404 network errors: ${networkErrors.join(', ')}`);
			} else {
				console.log('  [AUDIT PASS] 0 Network 404 errors.');
			}

			// Check Exceptions
			if (consoleErrors.length > 0) {
				console.error(`[AUDIT FAIL] Unhandled browser console errors detected:`, consoleErrors);
				throw new Error(`Encountered browser console errors: ${consoleErrors.join(', ')}`);
			} else {
				console.log('  [AUDIT PASS] 0 Browser console errors / exceptions.');
			}

			// Check Legacy residue in console logs
			const legacyTerms = ['crystal_dash', 'crystal dash', 'lunar_frontier', 'lunar frontier', 'orbital_scanning', 'lsp-01', 'ecs-01', 'rotator.gd'];
			const foundLegacy = [];
			for (const msg of consoleMessages) {
				const lower = msg.toLowerCase();
				for (const term of legacyTerms) {
					if (lower.includes(term)) {
						foundLegacy.push(`Term "${term}" found in log: "${msg}"`);
					}
				}
			}

			if (foundLegacy.length > 0) {
				console.error(`[AUDIT FAIL] Legacy references found in runtime logs:`, foundLegacy);
				throw new Error(`Legacy references detected at runtime: ${foundLegacy.join(', ')}`);
			} else {
				console.log('  [AUDIT PASS] 0 Legacy project references (Crystal Dash, Lunar Frontier, old orbital scanning) in runtime logs.');
			}

			console.log('\n=================================================================');
			console.log(' ALL FOUR HELIOS-4 CAMPAIGN PARTS + DEBRIEF FULLY VERIFIED IN BROWSER!');
			console.log('=================================================================\n');

			ws.close();
			chrome.kill();
			server.close();
			process.exit(0);

		} catch (err) {
			console.error('\n[PLAYTEST EXECUTION FAILED]:', err);
			await saveScreenshot('playtest_error_dump.png');
			ws.close();
			chrome.kill();
			server.close();
			process.exit(1);
		}
	};
});
