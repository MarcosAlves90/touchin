#!/usr/bin/env node
// Real Chrome regression against the production Flutter web build.
// Uses a synthetic in-memory API and session; no backend or credentials.
import assert from 'node:assert/strict';
import { rm } from 'node:fs/promises';
import {
  findChromeExecutable, waitFor, readCsp, serveBuild, startChrome, DevTools,
  getButton, clickButton,
} from './first_paint_smoke.mjs';

const session = {
  accessToken: 'browser-history-fixture',
  tokenType: 'bearer',
  expiresAt: '2099-01-01T00:00:00.000Z',
  mustChangePassword: false,
  company: {
    id: 'history-company', legalName: 'Empresa Teste', tradeName: 'TouchIn',
    cnpjMasked: '12.***.***/****-90', emailMasked: 'te***@touchin.com',
    phoneMasked: '11*****0000',
  },
  user: { id: 'history-user', email: 'tester@touchin.com', role: 'super_admin' },
};

async function mockBackend(cdp) {
  const handled = [];
  const handler = ({ requestId, request }) => {
    const path = new URL(request.url).pathname;
    const method = request.method;
    handled.push(`${method} ${path}`);
    const payload = path.endsWith('/auth/me')
      ? { company: session.company, user: session.user }
      : path.endsWith('/auth/login') ? session : [];
    const response = JSON.stringify(payload);
    void cdp.send('Fetch.fulfillRequest', {
      requestId,
      responseCode: 200,
      responseHeaders: [
        { name: 'Access-Control-Allow-Origin', value: '*' },
        { name: 'Access-Control-Allow-Headers', value: 'Authorization, Content-Type' },
        { name: 'Access-Control-Allow-Methods', value: 'GET, POST, OPTIONS' },
        { name: 'Content-Type', value: 'application/json' },
      ],
      body: Buffer.from(method === 'OPTIONS' ? '' : response).toString('base64'),
    }).catch((error) => { console.error(error); process.exitCode = 1; });
  };
  const off = cdp.on('Fetch.requestPaused', handler);
  await cdp.send('Fetch.enable', { patterns: [
    { urlPattern: '*localhost:8071/api/v1/*', requestStage: 'Request' },
  ] });
  return async () => {
    await cdp.send('Fetch.disable');
    off();
    assert.ok(handled.some((request) => request.endsWith('/auth/me')),
      'Authenticated boot never reached /auth/me');
  };
}

async function seedSession(cdp) {
  // Same AES-GCM encoding and localStorage keys as flutter_secure_storage_web.
  await cdp.evaluate(`(async () => {
    const key = await crypto.subtle.generateKey(
      {name:'AES-GCM',length:256}, true, ['encrypt','decrypt']);
    const b64 = (bytes) => btoa(String.fromCharCode(...new Uint8Array(bytes)));
    localStorage.setItem('FlutterSecureStorage',
      b64(await crypto.subtle.exportKey('raw', key)));
    for (const [name, value] of Object.entries({
      access_token: ${JSON.stringify(session.accessToken)},
      auth_session: JSON.stringify(${JSON.stringify(session)}),
    })) {
      const iv = crypto.getRandomValues(new Uint8Array(12));
      const encrypted = await crypto.subtle.encrypt({name:'AES-GCM',iv},
        key, new TextEncoder().encode(value));
      localStorage.setItem('FlutterSecureStorage.' + name,
        b64(iv) + '.' + b64(encrypted));
    }
    return true;
  })()`);
}

const routes = {
  '/admin/employees': 'Administrar equipe',
  '/projects': 'Administrar projetos',
  '/settings': 'Tema da interface',
  '/kanban': 'Nenhum projeto disponível',
};

async function expectRoute(cdp, route) {
  const browserRoute = 'location.hash.startsWith("#/") ? location.hash.slice(1) : location.pathname';
  const hasRouteText = async () => cdp.evaluate(`(() => [...document.querySelectorAll('flt-semantics')]
    .some((element) => {
      if (!(element.textContent || '').includes(${JSON.stringify(routes[route])})) return false;
      const rect = element.getBoundingClientRect();
      return rect.width > 3 && rect.height > 3 && rect.bottom > 0 && rect.top < innerHeight;
    }))()`);
  try {
    await waitFor(async () => {
      const pathname = await cdp.evaluate(browserRoute);
      return pathname === route && await hasRouteText();
    }, `URL and visible content for ${route}`, 20000);
  } catch (error) {
    const state = await cdp.evaluate(`({
      url:location.href,
      historyState:history.state,
      labels:[...document.querySelectorAll('flt-semantics')].map(e => e.textContent?.trim()).filter(Boolean).slice(0,8),
      placeholders:document.querySelectorAll('flt-semantics-placeholder').length,
      storageKeys:Object.keys(localStorage).filter(k=>k.startsWith('FlutterSecureStorage')).sort(),
    })`);
    console.error(`Browser state at ${route}: ${JSON.stringify(state)}`);
    throw error;
  }
  const actual = await cdp.evaluate(browserRoute);
  assert.equal(actual, route);
  assert.ok(await hasRouteText(), `${route}: content mismatch`);
}

async function navigateViaDrawer(cdp, label, path) {
  await clickButton(cdp, 'Abrir menu');
  await clickButton(cdp, label);
  await expectRoute(cdp, path);
}

async function smoke() {
  const { server, url } = await serveBuild(await readCsp());
  let chrome;
  let cdp;
  try {
    chrome = await startChrome(findChromeExecutable());
    cdp = new DevTools(chrome.tabUrl);
    await cdp.connect();
    // Wide header exposes the consistently labelled workspace menu control.
    await cdp.send('Emulation.setDeviceMetricsOverride', {
      width: 1366, height: 900, deviceScaleFactor: 1, mobile: false,
    });
    const stopMock = await mockBackend(cdp);
    try {
      await cdp.send('Page.navigate', { url });
      await waitFor(() => cdp.evaluate('document.readyState === "complete"'),
        'initial document load', 30000);
      await seedSession(cdp);
      const historyLengthBeforeAuthenticatedReload = await cdp.evaluate('history.length');
      await cdp.send('Page.reload', { ignoreCache: true });
      await waitFor(() => cdp.evaluate(`(() => {
        const placeholder = document.querySelector('flt-semantics-placeholder');
        if (placeholder) placeholder.click();
        return !!placeholder || document.querySelectorAll('flt-semantics').length > 0;
      })()`), 'Flutter semantics', 30000);
      await expectRoute(cdp, '/admin/employees');
      assert.equal(await cdp.evaluate('history.length'),
        historyLengthBeforeAuthenticatedReload,
        'Authenticated canonical redirect must replace its browser entry');
      await navigateViaDrawer(cdp, 'Projetos e tarefas', '/projects');
      await cdp.send('Page.reload', { ignoreCache: true });
      await waitFor(() => cdp.evaluate(`(() => {
        const placeholder = document.querySelector('flt-semantics-placeholder');
        if (placeholder) placeholder.click();
        return !!placeholder || document.querySelectorAll('flt-semantics').length > 0;
      })()`), 'Flutter semantics after route reload', 30000);
      await expectRoute(cdp, '/projects');
      const visitedEntry = await cdp.evaluate('history.state?.state');
      assert.ok(visitedEntry, 'Reloaded route needs a browser entry identity');
      await navigateViaDrawer(cdp, 'Configurações', '/settings');
      assert.notEqual(await cdp.evaluate('history.state?.state'), visitedEntry,
        'Navigation after reload must create a distinct entry identity');
      await cdp.evaluate('history.back()');
      await expectRoute(cdp, '/projects');
      assert.equal(await cdp.evaluate('history.state?.state'), visitedEntry);
      await cdp.evaluate('history.forward()');
      await expectRoute(cdp, '/settings');
      await cdp.evaluate('history.back()');
      await expectRoute(cdp, '/projects');
      await navigateViaDrawer(cdp, 'Configurações', '/settings');

      for (const path of ['/projects', '/admin/employees']) {
        await cdp.evaluate('history.back()');
        await expectRoute(cdp, path);
      }
      for (const path of ['/projects', '/settings']) {
        await cdp.evaluate('history.forward()');
        await expectRoute(cdp, path);
      }
      // Reselecting the active route must not create an extra Back entry.
      await navigateViaDrawer(cdp, 'Configurações', '/settings');
      await cdp.evaluate('history.back()');
      await expectRoute(cdp, '/projects');
      await navigateViaDrawer(cdp, 'Kanban', '/kanban');
      await cdp.evaluate('history.forward()');
      await new Promise((resolve) => setTimeout(resolve, 300));
      await expectRoute(cdp, '/kanban');
      await cdp.evaluate('history.back()');
      await expectRoute(cdp, '/projects');
      // A and A2 have the same URL but different browser entry identities.
      await navigateViaDrawer(cdp, 'Administrar Equipe', '/admin/employees');
      await navigateViaDrawer(cdp, 'Configurações', '/settings');
      await navigateViaDrawer(cdp, 'Administrar Equipe', '/admin/employees');
      await cdp.evaluate('history.back()');
      await expectRoute(cdp, '/settings');
      await cdp.evaluate('history.forward()');
      await expectRoute(cdp, '/admin/employees');
      await cdp.evaluate('history.back()');
      await expectRoute(cdp, '/settings');
      console.log('PASS navigation_history_smoke: URL and content, Back/Forward, repeated URLs, deduplication, branch replacement');
    } finally {
      await stopMock();
    }
  } finally {
    await cdp?.close();
    if (chrome) {
      chrome.processHandle.kill('SIGTERM');
      await waitFor(() => chrome.processHandle.exitCode !== null ||
        chrome.processHandle.signalCode !== null, 'Chrome exit', 4000)
        .catch(() => chrome.processHandle.kill('SIGKILL'));
      await rm(chrome.directory, { recursive: true, force: true, maxRetries: 8,
        retryDelay: 300 }).catch((error) => {
        console.warn(`Chrome temporary profile cleanup: ${error.message}`);
      });
      chrome.processHandle.stderr?.destroy();
    }
    server.closeAllConnections();
    await new Promise((resolve) => server.close(resolve));
  }
}

smoke().catch((error) => {
  console.error(`FAIL navigation_history_smoke: ${error.stack ?? error}`);
  process.exitCode = 1;
});
