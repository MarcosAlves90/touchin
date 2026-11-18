import assert from 'node:assert/strict';
import { extractInlineScripts } from './first_paint_smoke.mjs';

const script = "document.documentElement.dataset.theme = 'light';";
const html = `<HTML><HEAD><SCRIPT>${script}</SCRIPT></HEAD></HTML>`;
assert.deepEqual(extractInlineScripts(html), [script]);
console.log('PASS uppercase inline script tags preserve CSP extraction');
