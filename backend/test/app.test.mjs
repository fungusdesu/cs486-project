import assert from 'node:assert/strict';
import test from 'node:test';
import {createApp} from '../src/app.mjs';
import {createDatabase} from '../src/database.mjs';
import {createServer} from 'node:http';

const withServer = async (callback) => {
  const server = createServer(createApp({db: createDatabase({DB_MODE: 'mock'})}));
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  try { await callback(`http://127.0.0.1:${server.address().port}`); }
  finally { await new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve())); }
};

test('health returns service and mode', async () => {
  await withServer(async (baseUrl) => {
    const response = await fetch(`${baseUrl}/api/health`);
    assert.equal(response.status, 200);
    const body = await response.json();
    assert.equal(body.ok, true);
    assert.equal(body.mode, 'mock');
  });
});

test('booking validation rejects missing fields', async () => {
  await withServer(async (baseUrl) => {
    const response = await fetch(`${baseUrl}/api/bookings`, {method: 'POST', headers: {'content-type': 'application/json'}, body: JSON.stringify({booking_request_id: '00000001'})});
    assert.equal(response.status, 400);
    assert.deepEqual((await response.json()).error, 'missing_fields');
  });
});

test('mock booking can be created and approved', async () => {
  await withServer(async (baseUrl) => {
    const booking = {booking_request_id: '00000001', user_id: '00000051', space_id: 'S0001', requested_start_time: '2026-09-01T09:00:00Z', requested_end_time: '2026-09-01T10:00:00Z'};
    const created = await fetch(`${baseUrl}/api/bookings`, {method: 'POST', headers: {'content-type': 'application/json'}, body: JSON.stringify(booking)});
    assert.equal(created.status, 201);
    const approved = await fetch(`${baseUrl}/api/bookings/00000001/approve`, {method: 'POST', headers: {'content-type': 'application/json'}, body: '{}'});
    assert.equal((await approved.json()).state, 'APPROVED');
  });
});

test('unknown routes return stable JSON 404', async () => {
  await withServer(async (baseUrl) => {
    const response = await fetch(`${baseUrl}/missing`);
    assert.equal(response.status, 404);
    assert.deepEqual(await response.json(), {error: 'not_found'});
  });
});