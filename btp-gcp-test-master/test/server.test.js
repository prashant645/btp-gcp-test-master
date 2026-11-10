const { after, before, test } = require('node:test');
const assert = require('node:assert/strict');
const { createServer } = require('../server');

let server;
let baseUrl;

before(async () => {
  server = createServer();
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  baseUrl = `http://127.0.0.1:${server.address().port}`;
});

after(() => new Promise(resolve => server.close(resolve)));

test('GET / returns Hello World', async () => {
  const response = await fetch(`${baseUrl}/`);
  assert.equal(response.status, 200);
  assert.match(response.headers.get('content-type'), /^text\/plain/);
  assert.equal(await response.text(), 'Hello World');
});

test('GET /healthz returns OK', async () => {
  const response = await fetch(`${baseUrl}/healthz`);
  assert.equal(response.status, 200);
  assert.match(response.headers.get('content-type'), /^text\/plain/);
  assert.equal(await response.text(), 'OK');
});

test('GET /version returns APP_VERSION', async () => {
  process.env.APP_VERSION = 'abc123';
  const response = await fetch(`${baseUrl}/version`);
  assert.equal(response.status, 200);
  assert.equal(await response.text(), 'abc123');
});

test('GET /version falls back to unknown', async () => {
  delete process.env.APP_VERSION;
  const response = await fetch(`${baseUrl}/version`);
  assert.equal(await response.text(), 'unknown');
});

test('unknown path returns 404', async () => {
  const response = await fetch(`${baseUrl}/missing`);
  assert.equal(response.status, 404);
});
