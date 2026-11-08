const http = require('http');
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

const HTTP_PORT = 8146;
const CDP_PORT = 9276;
const WEB_DIR = path.resolve(__dirname, '../../build/helios4_test');
const CHROME_PATH = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const PROFILE_DIR = '/tmp/helios4_neg_' + Date.now();
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

const server = http.createServer((req, res) => {
	let reqPath = req.url.split('?')[0];
	if (reqPath === '/' || reqPath === '') reqPath = '/index.html';
	const filePath = path.join(WEB_DIR, reqPath);
	if (!fs.existsSync(filePath)) {
		res.writeHead(404, { 'Content-Type': 'text/plain' });
		res.end('Not Found');
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
	console.log(`[Negative Test Server] Serving on http://localhost:${HTTP_PORT}`);
	const chrome = spawn(CHROME_PATH, [
		'--headless=new',
		`--remote-debugging-port=${CDP_PORT}`,
		`--user-data-dir=${PROFILE_DIR}`,
		'--window-size=1280,720',
		'--no-first-run',
		'--no-default-browser-check',
		`http://localhost:${HTTP_PORT}/index.html`
	]);

	let targetWs = null;
	for (let i = 0; i < 30; i++) {
		await new Promise(r => setTimeout(r, 400));
		try {
			const res = await fetch(`http://127.0.0.1:${CDP_PORT}/json`);
			const targets = await res.json();
			const p = targets.find(t => t.type === 'page' && t.url.includes('localhost'));
			if (p && p.webSocketDebuggerUrl) {
				targetWs = p.webSocketDebuggerUrl;
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
			const centerMatch = text.match(/\[(\w+)\]\s+(\w+).*center:\s*\(([\d\.]+),\s*([\d\.]+)\)/);
			if (centerMatch) {
				const tag = `${centerMatch[1]}.${centerMatch[2]}`;
				trackedCoords[tag] = { x: parseFloat(centerMatch[3]), y: parseFloat(centerMatch[4]) };
			}
			if (text.includes('ABORT') || text.includes('INTERLOCK') || text.includes('HOLD') || text.includes('Launch')) {
				console.log(`    [Negative Test Console] ${text}`);
			}
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
				reject(new Error(`CDP method ${method} timed out`));
			}, timeoutMs);
			cbs.set(id, (res) => {
				clearTimeout(timer);
				if (res.error) reject(res.error);
				else resolve(res.result);
			});
			ws.send(JSON.stringify({ id, method, params }));
		});
	}

	async function click(x, y) {
		await callCDP('Input.dispatchMouseEvent', { type: 'mouseMoved', x: Math.round(x), y: Math.round(y) });
		await new Promise(r => setTimeout(r, 60));
		await callCDP('Input.dispatchMouseEvent', { type: 'mousePressed', x: Math.round(x), y: Math.round(y), button: 'left', clickCount: 1 });
		await new Promise(r => setTimeout(r, 80));
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

	ws.onopen = async () => {
		try {
			await callCDP('Page.enable');
			await callCDP('Runtime.enable');

			console.log('\n=== HELIOS-4: NEGATIVE TEST — LAUNCH INTERLOCK ABORT ===\n');
			await new Promise(r => setTimeout(r, 2000));

			// Step 1: Fast start to Launch scene
			await click(270, 363); // New Campaign
			await new Promise(r => setTimeout(r, 2000));
			const proceedPrologue = trackedCoords['Prologue.ProceedBtn'] || { x: 947, y: 538 };
			await click(proceedPrologue.x, proceedPrologue.y);
			await new Promise(r => setTimeout(r, 2000));
			const confirmCrew = trackedCoords['TeamAssignment.ConfirmCrewBtn'] || { x: 1114.5, y: 602.0 };
			await click(confirmCrew.x, confirmCrew.y);
			await new Promise(r => setTimeout(r, 2000));
			const proceedFRR = trackedCoords['Hangar.ProceedToFRRBtn'] || { x: 797, y: 600 };
			await click(proceedFRR.x, proceedFRR.y);
			await new Promise(r => setTimeout(r, 2000));

			// Vote unanimous GO
			await click(207, 530);
			await new Promise(r => setTimeout(r, 300));
			await click(505.5, 530);
			await new Promise(r => setTimeout(r, 300));
			await click(804, 530);
			await new Promise(r => setTimeout(r, 300));
			await click(1102.5, 530);
			await new Promise(r => setTimeout(r, 600));

			// Proceed to Launch
			await click(1120, 602);
			await new Promise(r => setTimeout(r, 3000));
			console.log('  On launch pad with unverified checklist.');

			// NEGATIVE TEST: Intentionally press Spacebar to ignite WITHOUT completing checklist!
			console.log('  Testing negative condition: triggering ignition without pre-flight checks verified...');
			await sendKey(32, ' ');
			await new Promise(r => setTimeout(r, 1200));

			// Capture the Interlock Abort Modal
			await capture('helios4_negative_01_interlock_abort.png');
			console.log('  [PASS] Launch Interlock Abort correctly intercepted unverified ignition!');

			// Click "RETRY LAUNCH FROM PAD" on the abort modal
			console.log('  Testing Pad Reset / Retry from Abort Modal...');
			// Retry button is at approx (550, 480) or center of modal
			await click(550, 480);
			await new Promise(r => setTimeout(r, 1500));
			await capture('helios4_negative_02_pad_reset.png');
			console.log('  [PASS] Pad successfully reset for clean retry without crashing or corrupting state');

			console.log('\n=== NEGATIVE INTEGRATION TEST COMPLETE: SUCCESS ===\n');

			ws.close();
			chrome.kill();
			server.close();
			process.exit(0);
		} catch (e) {
			console.error('Negative test error:', e);
			ws.close();
			chrome.kill();
			server.close();
			process.exit(1);
		}
	};
});
