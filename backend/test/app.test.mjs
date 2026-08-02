import assert from 'node:assert/strict';
import test from 'node:test';
import app from '../src/app.mjs';

const withServer = async (callback) => {
  const server = app.listen(0, '127.0.0.1');
  await new Promise((resolve) => server.once('listening', resolve));
  try {
    const { port } = server.address();
    await callback(`http://127.0.0.1:${port}`);
  } finally {
    await new Promise((resolve, reject) =>
      server.close((error) => (error ? reject(error) : resolve())));
  }
};

test('unknown routes return JSON 404', async () => {
  await withServer(async (baseUrl) => {
    const response = await fetch(`${baseUrl}/missing`);
    assert.equal(response.status, 404);
    assert.deepEqual(await response.json(), { error: 'Not found' });
  });
});

test('unconfigured procedure routes fail safely with 501', async () => {
  delete process.env.PROC_SUBMIT_BOOKING;
  await withServer(async (baseUrl) => {
    const response = await fetch(`${baseUrl}/api/bookings`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ booking_request_id: '00000001' }),
    });
    assert.equal(response.status, 501);
    const body = await response.json();
    assert.equal(body.error, 'AdapterNotConfiguredError');
  });
});
