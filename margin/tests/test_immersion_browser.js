const http = require('http');
const fs = require('fs');
const path = require('path');
const { spawn, execSync } = require('child_process');

const HTTP_PORT = 8166;
const CDP_PORT = 9286;
const WEB_DIR = path.resolve(__dirname, '../../build/helios4_test');
const CHROME_PATH = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const PROFILE_DIR = '/tmp/helios4_immersion_' + Date.now();
const LOCAL_ARTIFACT_DIR = path.resolve(__dirname, '../../artifacts/helios4_spaceflight_immersion');
const BRAIN_ARTIFACT_DIR = '/Users/omar/.gemini/antigravity/brain/b5ceb744-4e36-4c4e-8114-c68f40047e77';
const FRAMES_DIR = path.join(LOCAL_ARTIFACT_DIR, 'frames');

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
if (!fs.existsSync(FRAMES_DIR)) fs.mkdirSync(FRAMES_DIR, { recursive: true });

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
		await new Promise(r => setTimeout(r, 60));
		await callCDP('Input.dispatchMouseEvent', { type: 'mousePressed', x, y, button: 'left', clickCount: 1 });
		await new Promise(r => setTimeout(r, 100));
		await callCDP('Input.dispatchMouseEvent', { type: 'mouseReleased', x, y, button: 'left', clickCount: 1 });
		await new Promise(r => setTimeout(r, 250));
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

	let frameCounter = 1;
	async function recordFrame() {
		const res = await callCDP('Page.captureScreenshot', { format: 'png' });
		const buffer = Buffer.from(res.data, 'base64');
		const fName = `frame_${String(frameCounter++).padStart(3, '0')}.png`;
		fs.writeFileSync(path.join(FRAMES_DIR, fName), buffer);
	}

	await new Promise(resolve => ws.onopen = resolve);
	await callCDP('Runtime.enable');
	await callCDP('Page.enable');

	console.log('\n=================================================================');
	console.log(' HELIOS-4: FULL POST-LAUNCH SPACEFLIGHT IMMERSION PLAYTEST');
	console.log('=================================================================\n');

	for (let i = 0; i < 40; i++) {
		await new Promise(r => setTimeout(r, 500));
		const evalRes = await callCDP('Runtime.evaluate', { expression: 'document.querySelector("canvas") !== null' });
		if (evalRes && evalRes.result && evalRes.result.value) {
			console.log(`  [CDP] Godot WebGL Canvas ready in ${(i * 0.5).toFixed(1)}s`);
			break;
		}
	}
	await new Promise(r => setTimeout(r, 1500));

	// --- Step 1: Launch Campaign to Parking Orbit ---
	console.log('\n--- Stage 1: Starting Campaign -> Hangar -> Launch Ascent to Parking Orbit ---');
	await click(270, 363); // Main menu: New Campaign
	await new Promise(r => setTimeout(r, 800));
	await click(947, 538); // Prologue: Proceed
	await new Promise(r => setTimeout(r, 800));
	await click(1114, 602); // Team: Confirm
	await new Promise(r => setTimeout(r, 1200));
	await click(797, 600); // Hangar: Proceed to Review
	await new Promise(r => setTimeout(r, 1200));

	// Unanimous GO votes in Review
	await click(207.0, 530.0);
	await new Promise(r => setTimeout(r, 150));
	await click(505.5, 530.0);
	await new Promise(r => setTimeout(r, 150));
	await click(804.0, 530.0);
	await new Promise(r => setTimeout(r, 150));
	await click(1102.5, 530.0);
	await new Promise(r => setTimeout(r, 400));
	await click(1120, 602); // Proceed to Launch
	await new Promise(r => setTimeout(r, 2000));

	// Pre-launch verify & launch
	await sendKey(86, 'v');
	await new Promise(r => setTimeout(r, 400));
	await sendKey(32, ' ');
	await new Promise(r => setTimeout(r, 11500)); // Liftoff & Ascent
	await sendKey(79, 'o'); // Orbit insertion [O]
	await new Promise(r => setTimeout(r, 1000));
	await sendKey(74, 'j'); // Fairing jettison [J]
	await new Promise(r => setTimeout(r, 600));
	await sendKey(69, 'e'); // Systems activate [E]
	await new Promise(r => setTimeout(r, 1200));

	// Transition to Deep Space Transfer
	console.log('\n--- Stage 2: Entering Deep Space Earth Parking Orbit ---');
	await sendKey(13, 'Enter');
	await new Promise(r => setTimeout(r, 2500));

	// Capture Milestone 1: Parking Orbit
	await saveScreenshot('01_earth_parking_orbit_and_spacecraft.png');
	for (let f = 0; f < 6; f++) {
		await recordFrame();
		await new Promise(r => setTimeout(r, 180));
	}

	// Milestone 2: Execute TLI Injection Burn
	console.log('\n--- Stage 3: Executing Trans-L1 Injection Burn (TLI) ---');
	await sendKey(32, ' '); // Trigger TLI burn
	await new Promise(r => setTimeout(r, 1500));
	await saveScreenshot('02_tli_hyperbolic_burn_departure.png');
	for (let f = 0; f < 8; f++) {
		await recordFrame();
		await new Promise(r => setTimeout(r, 200));
	}
	await new Promise(r => setTimeout(r, 2500)); // Burn finishes, enters CRUISE_EARLY

	// Milestone 3: Interplanetary Transfer & Earth Receding
	console.log('\n--- Stage 4: Interplanetary Cruise & Receding Earth ---');
	await sendKey(52, '4'); // Key 4: Earth Dish View
	await new Promise(r => setTimeout(r, 1200));
	await saveScreenshot('03_interplanetary_transfer_earth_receding.png');
	for (let f = 0; f < 6; f++) {
		await recordFrame();
		await new Promise(r => setTimeout(r, 200));
	}

	// Milestone 4: Interactive Camera Orbit (Mouse Drag & Arrow Keys)
	console.log('\n--- Stage 5: Testing Interactive 3D Orbit Camera ---');
	await sendKey(49, '1'); // Return to Chase Cam
	await new Promise(r => setTimeout(r, 600));
	await mouseDrag(640, 360, 420, 280, 15); // Mouse orbit drag
	await new Promise(r => setTimeout(r, 800));
	await saveScreenshot('04_camera_interactive_orbit_yaw_pitch.png');
	for (let f = 0; f < 6; f++) {
		await recordFrame();
		await new Promise(r => setTimeout(r, 150));
	}

	// Milestone 5: High Time Warp & Space Dust Streaking
	console.log('\n--- Stage 6: High Warp Space Dust Velocity Streaks ---');
	await sendKey(66, 'b'); // Key B: 1000x Warp
	await new Promise(r => setTimeout(r, 2000));
	await saveScreenshot('05_high_warp_space_dust_streaking.png');
	for (let f = 0; f < 8; f++) {
		await recordFrame();
		await new Promise(r => setTimeout(r, 180));
	}

	// Handle MCC-1 Burn if present
	console.log('  [DeepSpace] Checking for MCC-1 correction...');
	await sendKey(32, ' ');
	await new Promise(r => setTimeout(r, 2500));
	await sendKey(66, 'b'); // Re-engage 1000x warp to reach crisis
	await new Promise(r => setTimeout(r, 3500));

	// Milestone 6: Solar Crisis & Storm Propagation
	console.log('\n--- Stage 7: Precursor Solar Particle Event Crisis ---');
	await saveScreenshot('06_solar_crisis_storm_propagation.png');
	for (let f = 0; f < 6; f++) {
		await recordFrame();
		await new Promise(r => setTimeout(r, 200));
	}

	// Commit crisis tactics & execute recovery
	console.log('  [DeepSpace] Committing crisis tactics and completing recovery...');
	await sendKey(32, ' '); // Commit crisis choices
	await new Promise(r => setTimeout(r, 4500));
	// Recovery steps 0, 1, 2, 3
	await sendKey(32, ' ');
	await new Promise(r => setTimeout(r, 600));
	await sendKey(32, ' ');
	await new Promise(r => setTimeout(r, 600));
	await sendKey(32, ' ');
	await new Promise(r => setTimeout(r, 600));
	await sendKey(32, ' ');
	await new Promise(r => setTimeout(r, 1000));

	// Warp 1000x to reach L1 Approach
	await sendKey(66, 'b');
	await new Promise(r => setTimeout(r, 3500));

	// Transition to Part 4: L1 Arrival & Commissioning
	console.log('\n--- Stage 8: Sun-Earth L1 Arrival & Approach Corridor ---');
	await sendKey(32, ' '); // Advance to Part 4
	await new Promise(r => setTimeout(r, 3000));

	// Milestone 7: L1 Arrival Approach
	await saveScreenshot('07_sun_earth_l1_arrival_approach.png');
	for (let f = 0; f < 6; f++) {
		await recordFrame();
		await new Promise(r => setTimeout(r, 200));
	}

	// Execute approach trim burn
	await sendKey(32, ' ');
	await new Promise(r => setTimeout(r, 1500));

	// Execute HOI burn to capture into halo orbit
	console.log('\n--- Stage 9: Executing Halo-Orbit Insertion (HOI) Burn ---');
	await sendKey(32, ' ');
	await new Promise(r => setTimeout(r, 6000)); // Main engine burns and captures

	// Execute Stationkeeping trim burn
	await sendKey(32, ' ');
	await new Promise(r => setTimeout(r, 1500));

	// Milestone 8: 3D Periodic Halo Orbit Continuous Flight
	console.log('\n--- Stage 10: Periodic 3D Halo Orbit Flight ---');
	await sendKey(51, '3'); // Key 3: Halo Orbit Mode
	await new Promise(r => setTimeout(r, 1200));
	await saveScreenshot('08_l1_halo_orbit_continuous_flight.png');
	for (let f = 0; f < 8; f++) {
		await recordFrame();
		await new Promise(r => setTimeout(r, 220));
	}

	// Milestone 9: Mechanical Deployments (Magnetometer Boom & Faraday Cup)
	console.log('\n--- Stage 11: Instrument Commissioning & Animated Deployments ---');
	await sendKey(52, '4'); // Key 4: Close up on Magnetometer Boom
	await new Promise(r => setTimeout(r, 800));
	await sendKey(32, ' '); // Trigger boom deployment tween
	await new Promise(r => setTimeout(r, 2600)); // Wait for 2.2s extension + settle oscillation
	
	await sendKey(53, '5'); // Key 5: Close up on Faraday Cup
	await new Promise(r => setTimeout(r, 800));
	await sendKey(32, ' '); // Trigger Faraday Cup cover release tween
	await new Promise(r => setTimeout(r, 1800));
	await saveScreenshot('09_magnetometer_boom_and_faraday_deployment.png');
	for (let f = 0; f < 6; f++) {
		await recordFrame();
		await new Promise(r => setTimeout(r, 200));
	}

	// Verify systems
	await sendKey(32, ' ');
	await new Promise(r => setTimeout(r, 1200));

	// Live scientific observation session
	console.log('  [L1Arrival] Performing live solar wind observation...');
	await sendKey(32, ' '); // Trigger CME detection
	await new Promise(r => setTimeout(r, 1500));

	// Milestone 10: Earth Comm Lock & Warning Transmission
	console.log('\n--- Stage 12: Earth DSN Communication Lock & Warning Transmission ---');
	await sendKey(54, '6'); // Key 6: Earth Dish View
	await new Promise(r => setTimeout(r, 800));
	await sendKey(32, ' '); // Trigger Earth dish slew tween
	await new Promise(r => setTimeout(r, 2200));
	await sendKey(32, ' '); // Transmit Early-Warning Data Packet
	await new Promise(r => setTimeout(r, 1800));
	await saveScreenshot('10_earth_lock_and_warning_transmission.png');
	for (let f = 0; f < 6; f++) {
		await recordFrame();
		await new Promise(r => setTimeout(r, 200));
	}

	console.log(`\n[Frames] Captured total ${frameCounter - 1} frames across entire mission.`);

	// Compile frame sequence into MP4 video with ffmpeg
	console.log('\n--- Assembling Video Footage with ffmpeg ---');
	const mp4OutLocal = path.join(LOCAL_ARTIFACT_DIR, 'spaceflight_immersion_gameplay.mp4');
	const mp4OutBrain = path.join(BRAIN_ARTIFACT_DIR, 'spaceflight_immersion_gameplay.mp4');
	const gifOutLocal = path.join(LOCAL_ARTIFACT_DIR, 'spaceflight_immersion_gameplay.gif');
	const gifOutBrain = path.join(BRAIN_ARTIFACT_DIR, 'spaceflight_immersion_gameplay.gif');

	try {
		const ffmpegCmd = `/opt/homebrew/bin/ffmpeg -y -framerate 6 -i "${FRAMES_DIR}/frame_%03d.png" -c:v libx264 -pix_fmt yuv420p "${mp4OutLocal}"`;
		execSync(ffmpegCmd);
		fs.copyFileSync(mp4OutLocal, mp4OutBrain);
		console.log(`  [Video] Generated MP4: ${mp4OutLocal} (${(fs.statSync(mp4OutLocal).size / 1024).toFixed(1)} KB)`);

		// Also generate animated GIF for inline artifact preview
		const gifCmd = `/opt/homebrew/bin/ffmpeg -y -framerate 6 -i "${FRAMES_DIR}/frame_%03d.png" -vf "scale=640:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=128[p];[s1][p]paletteuse=dither=bayer" "${gifOutLocal}"`;
		execSync(gifCmd);
		fs.copyFileSync(gifOutLocal, gifOutBrain);
		console.log(`  [GIF] Generated GIF: ${gifOutLocal} (${(fs.statSync(gifOutLocal).size / 1024).toFixed(1)} KB)`);
	} catch (e) {
		console.error('  [ffmpeg error]', e.message);
	}

	console.log('\n=================================================================');
	console.log(' SPACEFLIGHT IMMERSION PLAYTEST COMPLETED SUCCESSFULLY!');
	console.log('=================================================================\n');

	chrome.kill();
	server.close();
	process.exit(0);
});
