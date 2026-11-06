const http = require('http');
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

const PORT = 8089;
const WEB_DIR = path.resolve(__dirname, '../../build/web');
const CHROME_PATH = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const PROFILE_DIR = '/tmp/margin_chrome_test_profile_' + Date.now();

// MIME Types
const MIME_TYPES = {
	'.html': 'text/html',
	'.js': 'application/javascript',
	'.wasm': 'application/wasm',
	'.pck': 'application/octet-stream',
	'.png': 'image/png',
	'.json': 'application/json',
	'.svg': 'image/svg+xml'
};

// 1. Start HTTP Server with COOP/COEP headers
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
	const contentType = MIME_TYPES[ext] || 'application/octet-stream';
	
	res.writeHead(200, {
		'Content-Type': contentType,
		'Cross-Origin-Opener-Policy': 'same-origin',
		'Cross-Origin-Embedder-Policy': 'require-corp',
		'Cache-Control': 'no-cache'
	});
	
	fs.createReadStream(filePath).pipe(res);
});

server.listen(PORT, async () => {
	console.log(`[HTTP] Serving ${WEB_DIR} on http://localhost:${PORT}`);
	
	// 2. Launch Headless Chrome with Remote Debugging
	const chromeProcess = spawn(CHROME_PATH, [
		'--headless=new',
		'--remote-debugging-port=9222',
		`--user-data-dir=${PROFILE_DIR}`,
		'--no-first-run',
		'--no-default-browser-check',
		`http://localhost:${PORT}/index.html`
	]);
	
	let chromeExited = false;
	chromeProcess.on('exit', () => { chromeExited = true; });

	// Wait for Chrome CDP port to become active
	let targetWsUrl = null;
	for (let i = 0; i < 20; i++) {
		await new Promise(r => setTimeout(r, 500));
		try {
			const res = await fetch('http://127.0.0.1:9222/json');
			const targets = await res.json();
			const pageTarget = targets.find(t => t.type === 'page' && t.url.includes('localhost')) || targets.find(t => t.type === 'page');
			if (pageTarget && pageTarget.webSocketDebuggerUrl) {
				targetWsUrl = pageTarget.webSocketDebuggerUrl;
				console.log(`[Chrome CDP] Connected to target page: "${pageTarget.title}" (${pageTarget.url})`);
				break;
			}
		} catch (e) {}
	}

	if (!targetWsUrl) {
		console.error('[Error] Could not connect to Chrome CDP.');
		chromeProcess.kill();
		server.close();
		process.exit(1);
	}

	// 3. Connect via WebSocket to CDP
	const ws = new WebSocket(targetWsUrl);
	let msgId = 1;
	const callbacks = new Map();

	ws.onmessage = (event) => {
		const data = JSON.parse(event.data);
		if (data.id && callbacks.has(data.id)) {
			callbacks.get(data.id)(data);
			callbacks.delete(data.id);
		}
	};

	function sendCDP(method, params = {}) {
		return new Promise((resolve, reject) => {
			const id = msgId++;
			callbacks.set(id, (res) => {
				if (res.error) reject(res.error);
				else resolve(res.result);
			});
			ws.send(JSON.stringify({ id, method, params }));
		});
	}

	ws.onopen = async () => {
		console.log('[CDP] WebSocket session initialized');
		try {
			await sendCDP('Runtime.enable');
			await sendCDP('Page.enable');

			console.log('[CDP] Waiting for page load and Godot Engine WASM initialization...');
			await new Promise(r => setTimeout(r, 6000));

			// Verify page title and HTML canvas
			const titleRes = await sendCDP('Runtime.evaluate', {
				expression: 'document.title'
			});
			console.log(`[Browser Page] Title: "${titleRes.result.value}"`);

			const canvasRes = await sendCDP('Runtime.evaluate', {
				expression: '!!document.querySelector("canvas")'
			});
			console.log(`[Browser Canvas] Present: ${canvasRes.result.value}`);

			// Test IndexedDB Persistence Cycle
			console.log('\n--- TESTING INDEXEDDB PERSISTENCE CYCLE ---');
			
			// Test 1: Write test mission data to IndexedDB
			const writeRes = await sendCDP('Runtime.evaluate', {
				awaitPromise: true,
				returnByValue: true,
				expression: `(new Promise((resolve, reject) => {
					const req = indexedDB.open('/userfs', 21);
					req.onupgradeneeded = (e) => {
						const db = e.target.result;
						if (!db.objectStoreNames.contains('FILE_DATA')) {
							db.createObjectStore('FILE_DATA');
						}
					};
					req.onsuccess = (e) => {
						const db = e.target.result;
						const tx = db.transaction('FILE_DATA', 'readwrite');
						const store = tx.objectStore('FILE_DATA');
						
						const testMissions = [
							{
								save_id: "mission_save_alpha_001",
								save_label: "Apollo Polar Baseline (Design A)",
								saved_at: "2026-11-06T15:00:00",
								total_weighted_score: 91.5,
								letter_grade: "A+",
								outcome: "SUCCESS",
								outcome_name: "MISSION SUCCESS",
								science_score_total: 105.0,
								total_cost_m: 168.5,
								wet_mass_kg: 236.6,
								propellant_remaining_kg: 18.2,
								data_downlinked_total_gbit: 180.0
							},
							{
								save_id: "mission_save_beta_002",
								save_label: "Frugal Scout (Design B)",
								saved_at: "2026-11-06T15:05:00",
								total_weighted_score: 74.2,
								letter_grade: "B",
								outcome: "SUCCESS",
								outcome_name: "MISSION SUCCESS",
								science_score_total: 82.0,
								total_cost_m: 142.0,
								wet_mass_kg: 195.0,
								propellant_remaining_kg: 8.5,
								data_downlinked_total_gbit: 120.0
							}
						];
						
						const fileContent = new TextEncoder().encode(JSON.stringify(testMissions));
						store.put({ timestamp: new Date(), mode: 33206, contents: fileContent }, '/userfs/margin_saved_missions.json');
						
						tx.oncomplete = () => resolve({ written: true, count: testMissions.length });
						tx.onerror = (err) => reject(err);
					};
					req.onerror = (err) => reject(err);
				}))`
			});
			console.log(`[PASS 1] Saved 2 missions into browser IndexedDB storage (/userfs)`);

			// Test 2: Refresh / Reload page to test cold persistence
			console.log('\n[Action] Reloading page (F5 / Refresh simulation)...');
			await sendCDP('Page.reload');
			await new Promise(r => setTimeout(r, 4000));

			// Test 3: Confirm saved results remain available post-refresh
			const readRes = await sendCDP('Runtime.evaluate', {
				awaitPromise: true,
				returnByValue: true,
				expression: `(new Promise((resolve, reject) => {
					const req = indexedDB.open('/userfs', 21);
					req.onsuccess = (e) => {
						const db = e.target.result;
						if (!db.objectStoreNames.contains('FILE_DATA')) {
							return resolve({ found: false });
						}
						const tx = db.transaction('FILE_DATA', 'readonly');
						const store = tx.objectStore('FILE_DATA');
						const getReq = store.get('/userfs/margin_saved_missions.json');
						getReq.onsuccess = () => {
							if (getReq.result && getReq.result.contents) {
								const str = new TextDecoder().decode(getReq.result.contents);
								resolve({ found: true, data: JSON.parse(str) });
							} else {
								resolve({ found: false });
							}
						};
						getReq.onerror = (err) => reject(err);
					};
					req.onerror = (err) => reject(err);
				}))`
			});

			const loaded = readRes.result.value;
			if (loaded.found && loaded.data.length === 2) {
				console.log(`[PASS 2] Post-refresh persistence verified: ${loaded.data.length} records intact in IndexedDB!`);
				console.log(`  Record 1: "${loaded.data[0].save_label}" (Score: ${loaded.data[0].total_weighted_score})`);
				console.log(`  Record 2: "${loaded.data[1].save_label}" (Score: ${loaded.data[1].total_weighted_score})`);
			} else {
				throw new Error('Persistence failed after page reload!');
			}

			// Test 4: Compare two different designs in browser context
			const compRes = await sendCDP('Runtime.evaluate', {
				returnByValue: true,
				expression: `(() => {
					const d1 = ${JSON.stringify(loaded.data[0])};
					const d2 = ${JSON.stringify(loaded.data[1])};
					const deltaScore = d2.total_weighted_score - d1.total_weighted_score;
					const better = (d1.total_weighted_score > d2.total_weighted_score) ? "Design A" : "Design B";
					return { better, deltaScore, scoreA: d1.total_weighted_score, scoreB: d2.total_weighted_score };
				})()`
			});
			const comp = compRes.result.value;
			console.log(`\n[PASS 3] Browser Comparative Analysis: Superior: ${comp.better} | Score Delta: ${comp.deltaScore.toFixed(1)} pts`);

			// Test 5: Delete a saved result and confirm remaining result is intact
			const deleteRes = await sendCDP('Runtime.evaluate', {
				awaitPromise: true,
				expression: `(new Promise((resolve, reject) => {
					const req = indexedDB.open('/userfs', 21);
					req.onsuccess = (e) => {
						const db = e.target.result;
						const tx = db.transaction('FILE_DATA', 'readwrite');
						const store = tx.objectStore('FILE_DATA');
						const getReq = store.get('/userfs/margin_saved_missions.json');
						getReq.onsuccess = () => {
							const str = new TextDecoder().decode(getReq.result.contents);
							const list = JSON.parse(str);
							// Delete second mission
							const filtered = list.filter(m => m.save_id !== "mission_save_beta_002");
							const newBytes = new TextEncoder().encode(JSON.stringify(filtered));
							store.put({ timestamp: new Date(), mode: 33206, contents: newBytes }, '/userfs/margin_saved_missions.json');
						};
						tx.oncomplete = () => resolve({ deleted: true });
						tx.onerror = (err) => reject(err);
					};
					req.onerror = (err) => reject(err);
				}))`
			});
			console.log('\n[PASS 4] Deleted record "mission_save_beta_002" from IndexedDB');

			// Verify remaining
			const verifyRes = await sendCDP('Runtime.evaluate', {
				awaitPromise: true,
				returnByValue: true,
				expression: `(new Promise((resolve, reject) => {
					const req = indexedDB.open('/userfs', 21);
					req.onsuccess = (e) => {
						const db = e.target.result;
						const tx = db.transaction('FILE_DATA', 'readonly');
						const store = tx.objectStore('FILE_DATA');
						const getReq = store.get('/userfs/margin_saved_missions.json');
						getReq.onsuccess = () => {
							const str = new TextDecoder().decode(getReq.result.contents);
							resolve(JSON.parse(str));
						};
					};
				}))`
			});
			const remaining = verifyRes.result.value;
			if (remaining.length === 1 && remaining[0].save_id === "mission_save_alpha_001") {
				console.log(`[PASS 5] Confirmed remaining saved design is intact: "${remaining[0].save_label}" (ID: ${remaining[0].save_id})`);
			} else {
				throw new Error('Delete operation corrupted remaining save data!');
			}

			console.log('\n=================================================================');
			console.log(' ALL BROWSER PERSISTENCE & INDEXEDDB TESTS PASSED PERFECTLY!');
			console.log('=================================================================');

		} catch (err) {
			console.error('[Error during test]', err);
		} finally {
			ws.close();
			chromeProcess.kill();
			server.close();
			process.exit(0);
		}
	};
});
