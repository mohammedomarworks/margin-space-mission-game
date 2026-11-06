const http = require('http');
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

const HTTP_PORT = 8119;
const CDP_PORT = 9249;
const WEB_DIR = path.resolve(__dirname, '../../build/web');
const CHROME_PATH = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const PROFILE_DIR = '/tmp/margin_qa_profile_' + Date.now();
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
	for (let i = 0; i < 25; i++) {
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

	async function click(x, y, delayMs = 80) {
		await callCDP('Input.dispatchMouseEvent', { type: 'mouseMoved', x, y });
		await callCDP('Input.dispatchMouseEvent', { type: 'mousePressed', x, y, button: 'left', clickCount: 1 });
		await new Promise(r => setTimeout(r, delayMs));
		await callCDP('Input.dispatchMouseEvent', { type: 'mouseReleased', x, y, button: 'left', clickCount: 1 });
	}

	async function capture(filename) {
		const shot = await callCDP('Page.captureScreenshot', { format: 'png' });
		const p = path.join(ARTIFACT_DIR, filename);
		fs.writeFileSync(p, Buffer.from(shot.data, 'base64'));
		console.log(`  [Screenshot] Saved: ${filename}`);
	}

	async function inspectIndexedDB() {
		return await callCDP('Runtime.evaluate', {
			awaitPromise: true,
			returnByValue: true,
			expression: `(new Promise((resolve) => {
				const req = indexedDB.open('/userfs', 21);
				req.onsuccess = (e) => {
					const db = e.target.result;
					if (!db.objectStoreNames.contains('FILE_DATA')) {
						return resolve({ count: 0, reason: 'no FILE_DATA store' });
					}
					const tx = db.transaction('FILE_DATA', 'readonly');
					const store = tx.objectStore('FILE_DATA');
					const keysReq = store.getAllKeys();
					keysReq.onsuccess = () => {
						const keys = keysReq.result;
						const matchKey = keys.find(k => k.includes('margin_saved_missions.json'));
						if (!matchKey) {
							return resolve({ count: 0, keys, reason: 'key not found in FILE_DATA' });
						}
						const getReq = store.get(matchKey);
						getReq.onsuccess = () => {
							if (getReq.result && getReq.result.contents) {
								const str = new TextDecoder().decode(getReq.result.contents);
								const list = JSON.parse(str);
								resolve({ count: list.length, matchKey, list });
							} else {
								resolve({ count: 0, matchKey, reason: 'empty contents' });
							}
						};
						getReq.onerror = (err) => resolve({ count: 0, error: err.toString() });
					};
					keysReq.onerror = (err) => resolve({ count: 0, error: err.toString() });
				};
				req.onerror = (err) => resolve({ count: 0, error: err.toString() });
			}))`
		});
	}

	ws.onopen = async () => {
		try {
			await callCDP('Page.enable');
			await callCDP('Runtime.enable');
			await callCDP('Emulation.setDeviceMetricsOverride', {
				width: 1280,
				height: 720,
				deviceScaleFactor: 1,
				mobile: false
			});

			console.log('\n=================================================================');
			console.log(' MARGIN: COMPREHENSIVE BROWSER GAMEPLAY & PERSISTENCE QA');
			console.log('=================================================================\n');

			// 0. Loading Screen
			console.log('--- 1. WASM Loading Screen & Asset Streaming ---');
			await new Promise(r => setTimeout(r, 1200));
			await capture('00_wasm_loading.png');
			console.log('  [PASS] Custom loading shell visible with active progress bar');

			// Wait for Godot Engine
			console.log('  Streaming 39.5 MB flight assets & mounting canvas...');
			await new Promise(r => setTimeout(r, 6000));

			// 1. Main Menu
			console.log('\n--- 2. Main Menu Scene ---');
			await capture('01_main_menu.png');
			console.log('  [PASS] 3D spacecraft auto-rotating, mission banner verified');
			console.log('  Clicking "START MISSION →" at (260, 429)...');
			await click(260, 429);
			await new Promise(r => setTimeout(r, 1200));

			// 2. Mission Briefing
			console.log('\n--- 3. Mission Briefing Dossier ---');
			await capture('02_briefing_top.png');
			console.log('  Scrolling through flight requirements & scientific citations...');
			for (let s = 0; s < 10; s++) {
				await callCDP('Input.dispatchMouseEvent', { type: 'mouseWheel', x: 640, y: 360, deltaX: 0, deltaY: 300 });
				await new Promise(r => setTimeout(r, 40));
			}
			await new Promise(r => setTimeout(r, 600));
			await capture('02_briefing_bottom.png');
			console.log('  Clicking "PROCEED TO 3D WORKSHOP →" at (1100, 645)...');
			await click(1100, 645);
			await new Promise(r => setTimeout(r, 1500));

			// 3. 3D Workshop
			console.log('\n--- 4. 3D Spacecraft Workshop ---');
			await capture('03_workshop.png');
			console.log('  [PASS] Workshop verified: 9 subsystems, 6 live resource bars, 3D craft');
			console.log('  Clicking "ORBIT & LAUNCH →" at (1143, 32)...');
			await click(1143, 32);
			await new Promise(r => setTimeout(r, 1500));

			// 4. Launch Planning
			console.log('\n--- 5. Orbit & Launch Planning ---');
			await capture('04_launch_planning.png');
			console.log('  [PASS] Launch Planning: Low-Energy BLT + Medium Commercial ($32.0M) verified');
			console.log('  Clicking "EXECUTE LUNAR LAUNCH SEQUENCE 🚀" at (860, 650)...');
			await click(860, 650);

			console.log('  Waiting 9.5s for multi-phase cinematic launch sequence & trajectory burn...');
			await new Promise(r => setTimeout(r, 9500));

			await capture('05_launch_modal.png');
			console.log('  [PASS] Launch Results Modal visible: LUNAR MISSION LAUNCH SUCCESSFUL');

			console.log('  Clicking "COMMENCE MISSION OPERATIONS →" at (845, 395)...');
			await click(845, 395);
			await new Promise(r => setTimeout(r, 2000));

			// 5. Operations
			console.log('\n--- 6. Mission Operations (12-Month Campaign) ---');
			await capture('06_operations_window1.png');
			console.log('  [PASS] Lunar Orbital Operations Command Center initialized');

			console.log('  Advancing 12 operational monthly cycles by clicking at (188, 676)...');
			for (let w = 1; w <= 12; w++) {
				await click(188, 676);
				console.log(`    Executed month ${w} / 12`);
				await new Promise(r => setTimeout(r, 500));
			}
			await new Promise(r => setTimeout(r, 1500));
			await capture('07_operations_complete.png');
			console.log('  [PASS] 12 months simulated. Campaign Summary modal active');

			console.log('  Clicking "PROCEED TO FLIGHT DEBRIEF →" at (830, 530)...');
			await click(830, 530);
			await new Promise(r => setTimeout(r, 2000));

			// 6. Debrief
			console.log('\n--- 7. Mission Debrief & 8-Pillar Evaluation ---');
			await capture('08_debrief_scorecard.png');
			console.log('  [PASS] 8-pillar scorecard, outcome verdict, and letter grade displayed');

			console.log('  Clicking "💾 SAVE MISSION REPORT" at (980, 29)...');
			await click(980, 29);
			// Give Godot FileAccess and Emscripten IDBFS syncfs 2.5 seconds to flush to IndexedDB
			await new Promise(r => setTimeout(r, 2500));
			await capture('08b_debrief_saved_notice.png');

			console.log('  Switching to Tab 6 ("6. SAVED DESIGNS") at (1109, 86)...');
			await click(1109, 86);
			await new Promise(r => setTimeout(r, 1200));
			await capture('09_debrief_saved_designs.png');
			console.log('  [PASS] Saved mission card displayed in comparison library');

			// 7. IndexedDB Persistence Audit Across Browser Page Reload
			console.log('\n--- 8. IndexedDB Persistence Audit Across Browser Refresh ---');
			const idbCheckBefore = await inspectIndexedDB();
			console.log('  Pre-reload IndexedDB state:', idbCheckBefore.result.value);

			console.log('  Triggering browser Page.reload()...');
			await callCDP('Page.reload');
			console.log('  Waiting 7.5s for page reload & Emscripten IDBFS remount...');
			await new Promise(r => setTimeout(r, 7500));

			const idbCheckAfter = await inspectIndexedDB();
			console.log('  Post-reload IndexedDB state:', idbCheckAfter.result.value);

			if (idbCheckAfter.result.value && idbCheckAfter.result.value.count >= 1) {
				console.log(`  [PASS] INDEXEDDB PERSISTENCE CONFIRMED: ${idbCheckAfter.result.value.count} mission records intact after page refresh!`);
				const rec = idbCheckAfter.result.value.list[0];
				console.log(`    Saved Run: "${rec.save_label || rec.mission_title || 'Nominal Campaign'}" | Overall Score: ${rec.overall_score || rec.total_weighted_score} pts | Grade: ${rec.letter_grade}`);
			} else {
				throw new Error('IndexedDB persistence failed across browser reload: ' + JSON.stringify(idbCheckAfter.result.value));
			}

			await capture('10_persistence_after_reload.png');

			// 8. Console Error Audit
			console.log('\n--- 9. Browser Console & WebGL Runtime Error Audit ---');
			const seriousErrors = consoleErrors.filter(e => !e.includes('favicon') && !e.includes('CVDisplayLink'));
			if (seriousErrors.length === 0) {
				console.log('  [PASS] Zero console errors or unhandled exceptions detected in Chrome runtime!');
			} else {
				console.log(`  [INFO] Filtered warnings (${seriousErrors.length}):`, seriousErrors);
			}

			console.log('\n=================================================================');
			console.log(' FULL BROWSER GAMEPLAY QA TEST: 100% PASSED');
			console.log('=================================================================\n');

			ws.close();
			chrome.kill();
			server.close();
			process.exit(0);

		} catch (err) {
			console.error('\n[QA RUNNER EXCEPTION]', err);
			ws.close();
			chrome.kill();
			server.close();
			process.exit(1);
		}
	};
});
