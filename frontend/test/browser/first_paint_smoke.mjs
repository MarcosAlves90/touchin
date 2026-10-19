#!/usr/bin/env node
// Run from the repository root: node frontend/test/browser/first_paint_smoke.mjs
// No npm packages, external server, credentials, or backend are required.
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { createHash } from 'node:crypto';
import { createServer } from 'node:http';
import { mkdtemp, readFile, rm, stat } from 'node:fs/promises';
import { accessSync, constants, createReadStream } from 'node:fs';
import { tmpdir } from 'node:os';
import { delimiter, dirname, extname, isAbsolute, join, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const buildDir = resolve(process.env.TOUCHIN_BUILD_DIR ?? join(dirname(fileURLToPath(import.meta.url)), '../../build/web'));
const WIDTH = 1050;
const HEIGHT = 760;
const PIXEL_TOLERANCE = 8;
const BACKGROUND = { dark: [22, 22, 22], light: [250, 250, 247] };
const configFile = join(dirname(fileURLToPath(import.meta.url)), '../../vercel.json');
const mimeTypes = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.mjs': 'application/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.wasm': 'application/wasm',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.webp': 'image/webp',
};

const delay = (ms) => new Promise((done) => setTimeout(done, ms));

function executable(path) {
  try {
    accessSync(path, constants.X_OK);
    return true;
  } catch {
    return false;
  }
}

function findChromeExecutable() {
  const configured = process.env.TOUCHIN_CHROME?.trim();
  if (configured) {
    const choices = configured.includes(sep)
      ? [resolve(configured)]
      : (process.env.PATH ?? '').split(delimiter).map((dir) => join(dir, configured));
    const found = choices.find(executable);
    assert.ok(found, `TOUCHIN_CHROME=${JSON.stringify(configured)} is not executable`);
    return found;
  }
  const candidates = [
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    '/Applications/Chromium.app/Contents/MacOS/Chromium',
    '/usr/bin/google-chrome', '/usr/bin/google-chrome-stable',
    '/usr/bin/chromium', '/usr/bin/chromium-browser',
    '/opt/google/chrome/chrome', '/snap/bin/chromium',
  ];
  const found = candidates.find(executable);
  assert.ok(found, 'Chrome/Chromium was not found on this system; set TOUCHIN_CHROME to its executable path');
  return found;
}

async function waitFor(predicate, description, timeoutMs = 20000, intervalMs = 80) {
  const deadline = Date.now() + timeoutMs;
  let lastError;
  while (Date.now() < deadline) {
    try {
      const result = await predicate();
      if (result) return result;
    } catch (error) {
      lastError = error;
    }
    await delay(intervalMs);
  }
  throw new Error(`Timed out waiting for ${description}${lastError ? `: ${lastError.message}` : ''}`);
}

async function readCsp() {
  const config = JSON.parse(await readFile(configFile, 'utf8'));
  const csp = config.headers?.flatMap((rule) => rule.headers ?? [])
    .find((header) => header.key.toLowerCase() === 'content-security-policy')?.value;
  assert.ok(csp, 'Missing production Content-Security-Policy in frontend/vercel.json');
  const html = await readFile(join(buildDir, 'index.html'), 'utf8');
  const inlineScripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map((match) => match[1]);
  assert.equal(inlineScripts.length, 1, 'Expected exactly one synchronous inline theme bootstrap script');
  assert.ok(html.indexOf('<script>') < html.indexOf('</head>'), 'Theme bootstrap must run synchronously in <head>');
  assert.ok(!/theme_bootstrap\.js/i.test(html), 'Theme bootstrap must not be an external blocking request');
  const hash = createHash('sha256').update(inlineScripts[0]).digest('base64');
  assert.ok(csp.includes(`'sha256-${hash}'`), 'Production CSP script-src hash does not match built HTML');
  return csp;
}

async function serveBuild(csp) {
  const server = createServer(async (request, response) => {
    try {
      const url = new URL(request.url, 'http://localhost');
      const pathname = decodeURIComponent(url.pathname);
      const filename = resolve(buildDir, `.${pathname === '/' ? '/index.html' : pathname}`);
      const rel = relative(buildDir, filename);
      if (rel.startsWith(`..${sep}`) || rel === '..' || isAbsolute(rel)) {
        response.writeHead(403).end();
        return;
      }
      const details = await stat(filename);
      if (!details.isFile()) {
        response.writeHead(404).end();
        return;
      }
      response.writeHead(200, {
        'content-type': mimeTypes[extname(filename)] ?? 'application/octet-stream',
        'cache-control': 'no-store',
        'content-length': details.size,
        'content-security-policy': csp,
      });
      createReadStream(filename).pipe(response);
    } catch {
      response.writeHead(404).end();
    }
  });
  await new Promise((ok, fail) => {
    server.once('error', fail);
    server.listen(0, '127.0.0.1', ok);
  });
  return { server, url: `http://127.0.0.1:${server.address().port}/` };
}

async function startChrome(chromeExecutable) {
  const directory = await mkdtemp(join(tmpdir(), 'touchin-first-paint-'));
  const args = [
    '--headless=new', '--no-first-run', '--disable-gpu',
    '--remote-debugging-port=0', `--user-data-dir=${directory}`, 'about:blank',
  ];
  // GitHub-hosted Ubuntu runners restrict Chrome's user-namespace sandbox.
  // Only the isolated CI test browser may opt out; local Chrome keeps its
  // normal sandbox and the test server remains loopback-only.
  if (process.platform === 'linux' && process.env.TOUCHIN_CHROME_NO_SANDBOX === '1') {
    args.push('--no-sandbox');
  }
  const processHandle = spawn(chromeExecutable, args, {
    stdio: ['ignore', 'ignore', 'pipe'],
  });
  let errorLog = '';
  processHandle.stderr.on('data', (data) => {
    errorLog = (errorLog + data.toString()).slice(-3000);
  });
  let startupFailure;
  processHandle.once('error', (error) => { startupFailure = error; });
  processHandle.once('exit', (code, signal) => {
    startupFailure ??= new Error(`Chrome exited before connection (status ${code}, signal ${signal}); stderr: ${errorLog}`);
  });
  try {
    const portFile = await waitFor(async () => {
      if (startupFailure) throw startupFailure;
      try {
        const data = await readFile(join(directory, 'DevToolsActivePort'), 'utf8');
        const port = Number(data.split('\n')[0]);
        if (Number.isSafeInteger(port) && port > 0) return port;
      } catch { /* Chrome may still be starting. */ }
      return false;
    }, 'Chrome DevTools port', 20000);
    const tabs = await (await fetch(`http://127.0.0.1:${portFile}/json/list`)).json();
    const tab = tabs.find((item) => item.type === 'page');
    assert.ok(tab?.webSocketDebuggerUrl, 'Chrome did not expose the initial tab');
    return { processHandle, directory, tabUrl: tab.webSocketDebuggerUrl };
  } catch (error) {
    processHandle.kill('SIGTERM');
    await rm(directory, { recursive: true, force: true });
    throw error;
  }
}

class DevTools {
  constructor(url) {
    this.socket = new WebSocket(url);
    this.sequence = 0;
    this.pending = new Map();
    this.handlers = new Map();
    this.socket.addEventListener('message', (event) => {
      const message = JSON.parse(event.data.toString());
      if (message.id) {
        const waiting = this.pending.get(message.id);
        if (!waiting) return;
        this.pending.delete(message.id);
        if (message.error) waiting.reject(new Error(`${waiting.method}: ${message.error.message}`));
        else waiting.resolve(message.result ?? {});
      } else if (message.method) {
        for (const handler of this.handlers.get(message.method) ?? []) handler(message.params ?? {});
      }
    });
    this.socket.addEventListener('close', () => {
      for (const waiting of this.pending.values()) waiting.reject(new Error('Chrome CDP connection closed'));
      this.pending.clear();
    });
  }

  async connect() {
    if (this.socket.readyState === WebSocket.OPEN) return;
    await new Promise((ok, fail) => {
      this.socket.addEventListener('open', ok, { once: true });
      this.socket.addEventListener('error', fail, { once: true });
    });
    await Promise.all([
      this.send('Page.enable'),
      this.send('Runtime.enable'),
      this.send('Network.enable'),
    ]);
    await this.send('Emulation.setDeviceMetricsOverride', {
      width: WIDTH, height: HEIGHT, deviceScaleFactor: 1, mobile: false,
    });
  }

  send(method, params = {}) {
    const id = ++this.sequence;
    return new Promise((resolve, reject) => {
      this.pending.set(id, { method, resolve, reject });
      this.socket.send(JSON.stringify({ id, method, params }));
    });
  }

  on(event, handler) {
    if (!this.handlers.has(event)) this.handlers.set(event, new Set());
    this.handlers.get(event).add(handler);
    return () => this.handlers.get(event).delete(handler);
  }

  async evaluate(expression) {
    const result = await this.send('Runtime.evaluate', {
      expression, awaitPromise: true, returnByValue: true,
    });
    if (result.exceptionDetails) {
      throw new Error(`Browser evaluation: ${result.exceptionDetails.text} ${result.exceptionDetails.exception?.description ?? ''}`);
    }
    return result.result?.value;
  }

  async media(mode) {
    await this.send('Emulation.setEmulatedMedia', {
      features: [{ name: 'prefers-color-scheme', value: mode }],
    });
  }

  async screenshot() {
    const result = await this.send('Page.captureScreenshot', {
      format: 'png', captureBeyondViewport: false, fromSurface: true,
    });
    assert.ok(result.data, 'Chrome returned no screenshot');
    return result.data;
  }

  // The sampled pixels are decoded from a *real Chrome framebuffer screenshot*,
  // not DOM/CSS values. Decoding into canvas runs in Chrome itself, avoiding any
  // PNG parser or image dependency in Node.
  async inspectPixels(screenshot, format = 'png') {
    assert.ok(format === 'png' || format === 'jpeg', 'Unsupported screenshot format');
    return this.evaluate(`(async () => {
      const picture = new Image();
      picture.src = 'data:image/${format};base64,${screenshot}';
      await picture.decode();
      const canvas = document.createElement('canvas');
      canvas.width = picture.naturalWidth;
      canvas.height = picture.naturalHeight;
      const ctx = canvas.getContext('2d', {willReadFrequently: true});
      ctx.drawImage(picture, 0, 0);
      const {data, width, height} = ctx.getImageData(0, 0, canvas.width, canvas.height);
      let white = 0;
      let dark = 0;
      let nearLight = 0;
      let nearDark = 0;
      let red = 0;
      const samples = width * height;
      for (let i = 0; i < data.length; i += 4) {
        const r = data[i], g = data[i+1], b = data[i+2];
        if (r >= 253 && g >= 253 && b >= 253) white++;
        if (r <= 35 && g <= 35 && b <= 35) dark++;
        if (Math.abs(r-250) <= ${PIXEL_TOLERANCE} && Math.abs(g-250) <= ${PIXEL_TOLERANCE} && Math.abs(b-247) <= ${PIXEL_TOLERANCE}) nearLight++;
        if (Math.abs(r-22) <= ${PIXEL_TOLERANCE} && Math.abs(g-22) <= ${PIXEL_TOLERANCE} && Math.abs(b-22) <= ${PIXEL_TOLERANCE}) nearDark++;
        if (r > 200 && g < 50 && b < 50) red++;
      }
      const get = (x,y) => [...data.slice((y*width+x)*4,(y*width+x)*4+3)];
      return {width, height, total: samples, whiteRatio:white/samples,
        darkRatio: dark/samples, lightBackgroundRatio:nearLight/samples,
        darkBackgroundRatio:nearDark/samples, redRatio:red/samples,
        corners:[get(2,2),get(width-3,2),get(2,height-3),get(width-3,height-3)],
        center:get(Math.floor(width/2),Math.floor(height/2))};
    })()`);
  }

  async frame(label) {
    const pixels = await this.inspectPixels(await this.screenshot());
    assert.equal(pixels.width, WIDTH, `${label}: screenshot width`);
    assert.equal(pixels.height, HEIGHT, `${label}: screenshot height`);
    // A nearly white screenshot used to pass the old 96% threshold. The UI's
    // expected light background is #fafaf7, never pure white.
    assert.ok(pixels.whiteRatio < 0.10, `${label}: more than 10% pure-white pixels (${(pixels.whiteRatio * 100).toFixed(2)}%)`);
    return pixels;
  }

  async resetStorage() {
    await this.evaluate(`(() => { localStorage.clear(); sessionStorage.clear(); return true; })()`);
  }

  async close() {
    this.socket.close();
  }
}

// Screencast frames are emitted by Chrome as surfaces are presented. Keep a
// bounded sample spanning the start, middle and end of each transition. The
// protocol may drop or coalesce frames; this detects sampled white frames and
// does not claim that every display refresh was captured.
class FrameFilmstrip {
  constructor(cdp, label) {
    this.cdp = cdp;
    this.label = label;
    this.observed = 0;
    this.first = [];
    this.interval = [];
    this.recent = [];
    this.acks = new Set();
    this.ackError = null;
    this.removeListener = null;
  }

  async start() {
    this.removeListener = this.cdp.on('Page.screencastFrame', ({ data, sessionId }) => {
      const index = ++this.observed;
      const frame = { index, data };
      if (this.first.length < 6) this.first.push(frame);
      if (index % 4 === 0) {
        this.interval.push(frame);
        if (this.interval.length > 20) this.interval.shift();
      }
      this.recent.push(frame);
      if (this.recent.length > 12) this.recent.shift();
      const ack = this.cdp.send('Page.screencastFrameAck', { sessionId });
      this.acks.add(ack);
      void ack.catch((error) => { this.ackError ??= error; })
        .finally(() => this.acks.delete(ack));
    });
    try {
      await this.cdp.send('Page.startScreencast', {
        format: 'jpeg', quality: 85, maxWidth: WIDTH, maxHeight: HEIGHT,
        everyNthFrame: 1,
      });
    } catch (error) {
      this.removeListener();
      this.removeListener = null;
      throw error;
    }
  }

  async stopAndVerify() {
    try {
      await this.cdp.send('Page.stopScreencast');
      await Promise.allSettled([...this.acks]);
    } finally {
      this.removeListener?.();
      this.removeListener = null;
    }
    if (this.ackError) throw new Error(`${this.label}: screencast acknowledgement failed: ${this.ackError.message}`);
    const frames = [...new Map([...this.first, ...this.interval, ...this.recent]
      .map((frame) => [frame.index, frame])).values()]
      .sort((a, b) => a.index - b.index);
    assert.ok(frames.length > 0, `${this.label}: Chrome emitted no screencast frame`);
    for (const { index, data } of frames) {
      const pixels = await this.cdp.inspectPixels(data, 'jpeg');
      assert.ok(pixels.width >= 400 && pixels.height >= 300,
        `${this.label} frame ${index}: unexpected screencast size`);
      assert.ok(pixels.whiteRatio < 0.10,
        `${this.label} frame ${index}: ${(100 * pixels.whiteRatio).toFixed(2)}% pure-white pixels`);
    }
    console.log(`  PASS ${this.label}: ${frames.length}/${this.observed} compositor frames pixel-checked (bounded, sampled)`);
  }
}

function isClose(actual, expected) {
  return actual.every((value, index) => Math.abs(value - expected[index]) <= PIXEL_TOLERANCE);
}

function verifyBackground(pixels, theme, label) {
  const expected = BACKGROUND[theme];
  assert.ok(pixels.corners.every((corner) => isClose(corner, expected)),
    `${label}: actual screenshot corners ${JSON.stringify(pixels.corners)} != ${theme} ${JSON.stringify(expected)}`);
  const ratio = theme === 'light' ? pixels.lightBackgroundRatio : pixels.darkBackgroundRatio;
  assert.ok(ratio > 0.97, `${label}: expected uniform ${theme} initial paint, only ${(ratio * 100).toFixed(1)}% matched`);
}

async function documentState(cdp) {
  return cdp.evaluate(`(() => {
    let stored = null;
    let storageBlocked = false;
    try { stored = localStorage.getItem('touchin.themeMode'); }
    catch (_) { storageBlocked = true; }
    return {
      ready: document.readyState,
      mode: document.documentElement.getAttribute('data-touchin-theme'),
      background: getComputedStyle(document.body).backgroundColor,
      rootBackground: getComputedStyle(document.documentElement).backgroundColor,
      stored, storageBlocked,
      flutterView: !!document.querySelector('flutter-view'),
      semantics: document.querySelectorAll('flt-semantics').length,
    };
  })()`);
}

async function expectPreFlutter(cdp, mode, expected, label) {
  const state = await waitFor(async () => {
    const now = await documentState(cdp);
    return now.mode === mode && now.ready !== 'loading' && now;
  }, `${label}: theme bootstrap`, 12000);
  assert.equal(state.flutterView, false, `${label}: Flutter rendered before delayed JavaScript was released`);
  assert.equal(state.stored, mode, `${label}: bootstrap hint persistence`);
  const pixels = await cdp.frame(label);
  verifyBackground(pixels, expected, label);
  console.log(`  PASS ${label} — screenshot pixels ${(100 * (expected === 'light' ? pixels.lightBackgroundRatio : pixels.darkBackgroundRatio)).toFixed(1)}% ${expected}`);
}

async function navigateSuspended(cdp, url) {
  const waiting = new Set();
  let released = false;
  const stopListening = cdp.on('Fetch.requestPaused', ({ requestId, request }) => {
    if (!released && /\/(?:flutter_bootstrap|main\.dart)\.js(?:\?|$)/.test(request.url)) {
      waiting.add(requestId);
    } else {
      void cdp.send('Fetch.continueRequest', { requestId });
    }
  });
  await cdp.send('Fetch.enable', { patterns: [
    { urlPattern: '*flutter_bootstrap.js*', requestStage: 'Request' },
    { urlPattern: '*main.dart.js*', requestStage: 'Request' },
  ] });
  await cdp.send('Page.navigate', { url });
  await waitFor(async () => waiting.size > 0, 'held Flutter bootstrap request');
  return async () => {
    released = true;
    for (const id of waiting) await cdp.send('Fetch.continueRequest', { requestId: id });
    // Subsequent main.dart.js fetches are automatically released by the
    // event handler. The caller disables interception once Flutter is live.
    return async () => {
      await cdp.send('Fetch.disable');
      stopListening();
    };
  };
}

async function waitForFlutter(cdp, label) {
  await waitFor(async () => (await documentState(cdp)).flutterView, `${label}: Flutter view`, 30000);
  await waitFor(async () => {
    const result = await cdp.evaluate(`document.querySelector('flutter-view')?.querySelector('canvas, flt-glass-pane, flt-scene-host') !== null`);
    return result;
  }, `${label}: Flutter renderer`, 30000);
  await delay(300);
  const pixels = await cdp.frame(`${label}: rendered`);
  console.log(`  PASS ${label}: Flutter rendered; white pixels ${(pixels.whiteRatio * 100).toFixed(2)}%`);
}

async function installHint(cdp, value) {
  await cdp.evaluate(`localStorage.${value === null ? "removeItem('touchin.themeMode')" : `setItem('touchin.themeMode', ${JSON.stringify(value)})`}`);
}

async function releaseAndObserveFlutter({ cdp }, release, label) {
  const filmstrip = new FrameFilmstrip(cdp, label);
  await filmstrip.start();
  try {
    const disableInterception = await release();
    try {
      await waitForFlutter(cdp, label);
    } finally {
      await disableInterception();
    }
  } finally {
    await filmstrip.stopAndVerify();
  }
}

async function checkScreenshotDifference(cdp, before, after, label) {
  const contrast = await cdp.evaluate(`(async () => {
    const read = async (base64) => {
      const picture = new Image();
      picture.src = 'data:image/png;base64,' + base64;
      await picture.decode();
      const canvas = document.createElement('canvas');
      canvas.width = picture.naturalWidth;
      canvas.height = picture.naturalHeight;
      const ctx = canvas.getContext('2d');
      ctx.drawImage(picture, 0, 0);
      return ctx.getImageData(0, 0, canvas.width, canvas.height).data;
    };
    const a = await read(${JSON.stringify(before)});
    const b = await read(${JSON.stringify(after)});
    if (a.length !== b.length) throw new Error('Screenshots have different dimensions');
    let changed = 0;
    let measured = 0;
    for (let i = 0; i < a.length; i += 4 * 8) {
      measured++;
      if (Math.abs(a[i]-b[i]) + Math.abs(a[i+1]-b[i+1]) + Math.abs(a[i+2]-b[i+2]) >= 45) changed++;
    }
    return changed / measured;
  })()`);
  assert.ok(contrast >= 0.01, `${label}: screenshot content changed in only ${(contrast * 100).toFixed(2)}% of sampled pixels`);
  console.log(`  PASS ${label}: visible screenshot difference ${(contrast * 100).toFixed(2)}%`);
}

async function scenarioColdBoot(ctx) {
  const { cdp, url } = ctx;
  await cdp.media('dark');
  const release = await navigateSuspended(cdp, url);
  await expectPreFlutter(cdp, 'dark', 'dark', 'cold default dark');
  await releaseAndObserveFlutter(ctx, release, 'cold boot');
}

async function scenarioThemeReloads(ctx) {
  const { cdp, url } = ctx;
  const cases = [
    { hint: 'dark', media: 'light', expected: 'dark' },
    { hint: 'light', media: 'dark', expected: 'light' },
    { hint: 'system', media: 'light', expected: 'light' },
    { hint: 'system', media: 'dark', expected: 'dark' },
  ];
  for (const scenario of cases) {
    await installHint(cdp, scenario.hint);
    await cdp.media(scenario.media);
    const release = await navigateSuspended(cdp, url);
    await expectPreFlutter(cdp, scenario.hint, scenario.expected,
      `reload hint=${scenario.hint} media=${scenario.media}`);
    if (scenario.hint === 'system' && scenario.media === 'light') {
      await cdp.media('dark');
      verifyBackground(await cdp.frame('system: live switch to dark before Flutter'),
        'dark', 'system: live switch to dark before Flutter');
      await cdp.media('light');
      verifyBackground(await cdp.frame('system: live switch back to light before Flutter'),
        'light', 'system: live switch back to light before Flutter');
      console.log('  PASS suspended-boot system theme tracks live OS media changes pixel-by-pixel');
    }
    await releaseAndObserveFlutter(ctx, release, `reload hint=${scenario.hint}`);
    await waitFor(async () => (await documentState(cdp)).mode === 'dark',
      'secure-storage theme reconciliation', 15000);
  }
}

async function scenarioStaleHint(ctx) {
  const { cdp, url } = ctx;
  await installHint(cdp, 'light');
  await cdp.media('dark');
  const release = await navigateSuspended(cdp, url);
  await expectPreFlutter(cdp, 'light', 'light', 'legacy mismatched hint before Flutter');
  await releaseAndObserveFlutter(ctx, release, 'legacy hint boot');
  await waitFor(async () => (await documentState(cdp)).mode === 'dark', 'legacy hint reconciliation');
  const corrected = await cdp.frame('legacy hint reconciled');
  assert.ok(corrected.darkRatio > 0.05, 'legacy hint: dark Flutter scene not visible');
  console.log('  PASS legacy hint reconciled to authoritative dark preference');
}

async function scenarioLiveSystemAndPreviewAPI(ctx) {
  const { cdp, url } = ctx;
  assert.equal((await documentState(cdp)).stored, 'dark');
  await cdp.evaluate(`window.touchinSetThemeMode('system', false)`);
  await cdp.media('light');
  assert.equal((await documentState(cdp)).mode, 'system');
  assert.equal((await documentState(cdp)).background, 'rgb(250, 250, 247)');
  assert.equal((await documentState(cdp)).stored, 'dark', 'Theme preview wrote to storage');
  await cdp.media('dark');
  assert.equal((await documentState(cdp)).background, 'rgb(22, 22, 22)');
  // An immediate reload while secure storage is still pending must begin
  // with the last committed hint, not the optimistic theme preview.
  const release = await navigateSuspended(cdp, url);
  await expectPreFlutter(cdp, 'dark', 'dark', 'reload during uncommitted theme preview');
  await releaseAndObserveFlutter(ctx, release, 'reload after uncommitted preview');
  assert.equal((await documentState(cdp)).stored, 'dark');
  await cdp.evaluate(`window.touchinSetThemeMode('system', false)`);
  await cdp.evaluate(`window.touchinPersistThemeMode('light')`);
  assert.equal((await documentState(cdp)).mode, 'system', 'Theme commit changed the preview');
  assert.equal((await documentState(cdp)).stored, 'light', 'Theme commit did not persist hint');
  await cdp.evaluate(`window.touchinPersistThemeMode('dark'); window.touchinSetThemeMode('dark', false)`);
  console.log('  PASS live system preference, preview-only theme change and storage-only commit');
}

async function getButton(cdp, label) {
  return cdp.evaluate(`(() => {
    const matching = [...document.querySelectorAll('flt-semantics[role="button"]')].filter((element) =>
      (element.getAttribute('aria-label') || element.textContent || '').trim() === ${JSON.stringify(label)});
    const element = matching.find((node) => {
      const rect = node.getBoundingClientRect();
      return rect.width > 3 && rect.height > 3 && rect.top >= 0 && rect.bottom <= innerHeight;
    });
    if (!element) return null;
    const r = element.getBoundingClientRect();
    return {x: Math.round((r.left+r.right)/2), y: Math.round((r.top+r.bottom)/2)};
  })()`);
}

async function hasVisibleText(cdp, label) {
  return cdp.evaluate(`(() => [...document.querySelectorAll('flt-semantics')]
    .some((element) => {
      if ((element.textContent || '').trim() !== ${JSON.stringify(label)}) return false;
      const r = element.getBoundingClientRect();
      return r.width > 3 && r.height > 3 && r.bottom > 0 && r.top < innerHeight;
    }))()`);
}

async function clickButton(cdp, label) {
  const target = await waitFor(() => getButton(cdp, label), `accessible ${label}`, 10000);
  await cdp.send('Input.dispatchMouseEvent', { type: 'mouseMoved', ...target });
  await cdp.send('Input.dispatchMouseEvent', {
    type: 'mousePressed', ...target, button: 'left', clickCount: 1,
  });
  await cdp.send('Input.dispatchMouseEvent', {
    type: 'mouseReleased', ...target, button: 'left', clickCount: 1,
  });
}

async function scenarioRouteNavigation(ctx) {
  const { cdp } = ctx;
  const enabled = await cdp.evaluate(`(() => {
    const placeholder = document.querySelector('flt-semantics-placeholder');
    if (placeholder) placeholder.click();
    return !!placeholder;
  })()`);
  assert.ok(enabled, 'Flutter accessibility placeholder unavailable');
  await waitFor(async () => (await documentState(cdp)).semantics > 0,
    'Flutter accessibility semantics', 10000);
  console.log('  PASS Flutter semantics enabled');

  const loginScreenshot = await cdp.screenshot();
  const toRegistration = new FrameFilmstrip(cdp, 'login → registration transition');
  await toRegistration.start();
  try {
    await clickButton(cdp, 'Cadastrar empresa');
    await cdp.frame('login to registration: first frame');
    await waitFor(() => hasVisibleText(cdp, 'Sua operação começa aqui.'),
      'registration brand heading', 12000);
    await delay(160);
  } finally {
    await toRegistration.stopAndVerify();
  }
  const registrationScreenshot = await cdp.screenshot();
  await checkScreenshotDifference(cdp, loginScreenshot, registrationScreenshot, 'login → registration');
  await waitFor(async () => {
    const target = await getButton(cdp, 'Voltar para login');
    if (target) return target;
    await cdp.send('Input.dispatchMouseEvent', {
      type: 'mouseWheel', x: WIDTH * 0.77, y: HEIGHT * 0.65,
      deltaX: 0, deltaY: 520,
    });
    return null;
  }, 'registration page return button', 12000, 200);

  const backToLogin = new FrameFilmstrip(cdp, 'registration → login transition');
  await backToLogin.start();
  try {
    await clickButton(cdp, 'Voltar para login');
    await cdp.frame('registration to login: first frame');
    await waitFor(() => getButton(cdp, 'Esqueci a senha'), 'login page', 12000);
    await waitFor(() => hasVisibleText(cdp, 'O núcleo operacional da sua empresa.'),
      'login brand heading', 12000);
    await delay(160);
  } finally {
    await backToLogin.stopAndVerify();
  }
  await checkScreenshotDifference(cdp, registrationScreenshot, await cdp.screenshot(),
    'registration → login');
  console.log('  PASS login → registration → login with verified rendered route changes');
}

async function scenarioEncryptedLegacyMigration(ctx) {
  const { cdp, url } = ctx;
  // flutter_secure_storage_web uses a 256-bit AES-GCM key and a split base64
  // IV/ciphertext value. This reproduces the plugin's actual storage encoding.
  const legacySeed = await cdp.evaluate(`(async () => {
    const key = await crypto.subtle.generateKey({name:'AES-GCM', length:256}, true, ['encrypt','decrypt']);
    const toBase64 = (bytes) => btoa(String.fromCharCode(...new Uint8Array(bytes)));
    const iv = crypto.getRandomValues(new Uint8Array(12));
    const ciphertext = await crypto.subtle.encrypt({name:'AES-GCM', iv}, key, new TextEncoder().encode('light'));
    localStorage.setItem('FlutterSecureStorage', toBase64(await crypto.subtle.exportKey('raw',key)));
    localStorage.setItem('FlutterSecureStorage.theme_mode', toBase64(iv) + '.' + toBase64(ciphertext));
    localStorage.removeItem('touchin.themeMode');
    return {keyPresent:!!localStorage.getItem('FlutterSecureStorage'),
      encryptedPreferencePresent:!!localStorage.getItem('FlutterSecureStorage.theme_mode'),
      hintMissing:localStorage.getItem('touchin.themeMode') === null};
  })()`);
  assert.deepEqual(legacySeed, {keyPresent:true, encryptedPreferencePresent:true, hintMissing:true});
  await cdp.media('light');
  let release = await navigateSuspended(cdp, url);
  await expectPreFlutter(cdp, 'dark', 'dark', 'encrypted legacy light: unavailable during synchronous first paint');
  await releaseAndObserveFlutter(ctx, release, 'encrypted legacy light: Flutter boot');
  await waitFor(async () => {
    const state = await documentState(cdp);
    return state.mode === 'light' && state.stored === 'light';
  }, 'encrypted legacy light: secure preference reconciled', 15000);
  await cdp.frame('encrypted legacy light: reconciled');
  console.log('  PASS encrypted legacy light storage reconciled after Flutter boot');
  release = await navigateSuspended(cdp, url);
  await expectPreFlutter(cdp, 'light', 'light', 'encrypted legacy light: second load');
  await releaseAndObserveFlutter(ctx, release, 'encrypted legacy light: second Flutter boot');
  assert.equal((await documentState(cdp)).mode, 'light', 'Encrypted legacy light was not preserved on reload');
}

async function scenarioBlockedLocalStorage(ctx) {
  const { cdp, url } = ctx;
  const secretMarker = 'INTERNAL_STORAGE_EXCEPTION_DETAIL_NEVER_LOG';
  const consoleWarnings = [];
  const offConsole = cdp.on('Runtime.consoleAPICalled', ({ type, args }) => {
    if (type === 'warning') {
      consoleWarnings.push(args.map((arg) => String(arg.value ?? arg.description ?? '')).join(' '));
    }
  });
  const { identifier } = await cdp.send('Page.addScriptToEvaluateOnNewDocument', {
    source: `Object.defineProperty(window, 'localStorage', {
      configurable: true,
      get() { throw new DOMException(${JSON.stringify(secretMarker)}, 'SecurityError'); }
    });`,
  });
  try {
    await cdp.media('dark');
    const release = await navigateSuspended(cdp, url);
    await waitFor(() => cdp.evaluate(`document.readyState !== 'loading' &&
      document.documentElement.getAttribute('data-touchin-theme') === 'dark'`),
    'dark fallback when storage access is blocked', 12000);
    verifyBackground(await cdp.frame('blocked localStorage dark fallback'),
      'dark', 'blocked localStorage dark fallback');
    const inaccessible = await cdp.evaluate(`(() => {
      try { localStorage.getItem('touchin.themeMode'); return false; }
      catch (error) { return error.name === 'SecurityError'; }
    })()`);
    assert.ok(inaccessible, 'localStorage access was not blocked for the test');
    assert.ok(consoleWarnings.length >= 2,
      `Expected warnings for blocked theme storage read/write, observed ${consoleWarnings.length}`);
    for (const entry of consoleWarnings) {
      assert.ok(/storage|armazenamento|theme|tema/i.test(entry), 'Storage warning is not generic and identifiable');
      assert.ok(!entry.includes(secretMarker), 'Sensitive exception details leaked through console warning');
      assert.ok(!/FlutterSecureStorage|touchin\.themeMode|[A-Za-z0-9+/]{40,}={0,2}/.test(entry),
        'Storage warning leaked a key or potentially encoded value');
    }
    // Keep localStorage blocked while the real Flutter engine boots. The HTML
    // fallback alone is not sufficient: a storage exception must not prevent
    // the user from reaching a functional unauthenticated interface.
    await releaseAndObserveFlutter(ctx, release, 'blocked localStorage: Flutter boot');
    const semanticsEnabled = await cdp.evaluate(`(() => {
      const placeholder = document.querySelector('flt-semantics-placeholder');
      if (placeholder) placeholder.click();
      return !!placeholder || document.querySelectorAll('flt-semantics').length > 0;
    })()`);
    assert.ok(semanticsEnabled, 'Blocked storage: Flutter accessibility semantics unavailable');
    await waitFor(() => hasVisibleText(cdp, 'O núcleo operacional da sua empresa.'),
      'login interface after blocked storage', 15000);
    await waitFor(() => getButton(cdp, 'Cadastrar empresa'),
      'functional login controls after blocked storage', 15000);
    assert.ok(await cdp.evaluate(`(() => {
      try { localStorage.getItem('touchin.themeMode'); return false; }
      catch (error) { return error.name === 'SecurityError'; }
    })()`), 'Blocked storage was re-enabled before Flutter became functional');
    await cdp.frame('blocked localStorage: functional login page');
    console.log(`  PASS blocked localStorage: dark fallback, Flutter login mounted, ${consoleWarnings.length} sanitized warnings`);
  } finally {
    offConsole();
    await cdp.send('Page.removeScriptToEvaluateOnNewDocument', { identifier });
  }
}

async function scenarioCsp(ctx) {
  const { cdp, getBootstrapRequests } = ctx;
  assert.equal(getBootstrapRequests(), 0, 'Browser fetched external theme_bootstrap.js');
  const violations = await cdp.evaluate('window.__touchinCspViolations');
  assert.deepEqual((violations ?? []).filter((item) => /script-src/.test(item.directive)), [],
    `Browser reported CSP script violations: ${JSON.stringify(violations)}`);
  console.log('  PASS production CSP enforced, inline bootstrap hash valid; no external theme request');
}

async function smoke() {
  const chromeExecutable = findChromeExecutable();
  await stat(join(buildDir, 'index.html'));
  await stat(join(buildDir, 'flutter_bootstrap.js'));
  const csp = await readCsp();
  const { server, url } = await serveBuild(csp);
  let chrome;
  let cdp;
  try {
    chrome = await startChrome(chromeExecutable);
    cdp = new DevTools(chrome.tabUrl);
    await cdp.connect();
    let bootstrapRequests = 0;
    cdp.on('Network.requestWillBeSent', ({ request }) => {
      if (/theme_bootstrap\.js(?:\?|$)/.test(request.url)) bootstrapRequests++;
    });
    await cdp.send('Page.addScriptToEvaluateOnNewDocument', { source: `
      window.__touchinCspViolations = [];
      document.addEventListener('securitypolicyviolation', (event) => {
        window.__touchinCspViolations.push({directive: event.violatedDirective, blocked: event.blockedURI});
      });
    ` });
    console.log(`Browser: ${chromeExecutable}; build: ${buildDir}`);
    const context = { cdp, url, getBootstrapRequests: () => bootstrapRequests };
    await scenarioColdBoot(context);
    await scenarioThemeReloads(context);
    await scenarioStaleHint(context);
    await scenarioLiveSystemAndPreviewAPI(context);
    await scenarioRouteNavigation(context);
    await scenarioEncryptedLegacyMigration(context);
    await scenarioCsp(context);
    await scenarioBlockedLocalStorage(context);
    console.log('PASS first_paint_smoke');
  } finally {
    await cdp?.close();
    if (chrome) {
      chrome.processHandle.kill('SIGTERM');
      await waitFor(() => chrome.processHandle.exitCode !== null || chrome.processHandle.signalCode !== null,
        'Chrome exit', 4000).catch(() => chrome.processHandle.kill('SIGKILL'));
      await rm(chrome.directory, { recursive: true, force: true, maxRetries: 4, retryDelay: 100 });
    }
    await new Promise((done) => server.close(done));
  }
}

// Reuse the exact production-build server and Chrome transport in the
// authenticated browser navigation regression without external npm packages.
export { findChromeExecutable, waitFor, readCsp, serveBuild, startChrome, DevTools,
  getButton, hasVisibleText, clickButton };

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  smoke().catch((error) => {
    console.error(`FAIL first_paint_smoke: ${error.stack ?? error}`);
    process.exitCode = 1;
  });
}
