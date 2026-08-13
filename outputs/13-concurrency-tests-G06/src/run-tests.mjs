import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {callBookingProcedure, executeQuery, executeSqlFile, queryInteger} from './database.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const sql = path.join(root, 'sql');
const results = path.join(root, 'results');

const overlap = (space = 'S0001', start = '2026-09-01T09:00:00', end = '2026-09-01T10:00:00', advisoryAcknowledged = false) => ({
  space, start, end, advisoryAcknowledged,
});

async function resetFixtures() {
  await executeQuery(`
    DELETE FROM dbo.ConcurrencyTestAcknowledgement;
    DELETE FROM dbo.ConcurrencyTestBooking;
    DELETE FROM dbo.ConcurrencyTestMaintenance;
  `);
}

async function concurrentScenario(definition) {
  await resetFixtures();
  const started = Date.now();
  const calls = await Promise.allSettled([
    callBookingProcedure(definition.procedureA, `${definition.prefix}-A`, definition.a),
    callBookingProcedure(definition.procedureB, `${definition.prefix}-B`, definition.b),
  ]);
  const actual = await queryInteger(`
    SELECT COUNT(*)
    FROM dbo.ConcurrencyTestBooking
    WHERE space_id = '${definition.space}'
      AND start_time < '${definition.windowEnd}'
      AND end_time > '${definition.windowStart}';
  `);
  const fulfilled = calls.filter((call) => call.status === 'fulfilled').length;
  return {
    scenario: definition.name,
    procedures: [definition.procedureA, definition.procedureB],
    expectedApprovedCount: definition.expected,
    approvedCount: actual,
    elapsedMs: Date.now() - started,
    passed: actual === definition.expected && fulfilled === definition.expected,
    calls: calls.map((call) => ({
      status: call.status,
      error: call.status === 'rejected' ? call.reason.message : null,
    })),
  };
}

async function singleAttemptScenario(definition) {
  const started = Date.now();
  const [call] = await Promise.allSettled([
    callBookingProcedure(definition.procedure, definition.bookingId, definition.values),
  ]);
  const actual = await queryInteger(`
    SELECT COUNT(*) FROM dbo.ConcurrencyTestBooking WHERE booking_id = '${definition.bookingId}';
  `);
  const statusMatches = definition.expectRejected
    ? call.status === 'rejected'
    : call.status === 'fulfilled';
  return {
    scenario: definition.name,
    procedures: [definition.procedure],
    expectedApprovedCount: definition.expected,
    approvedCount: actual,
    elapsedMs: Date.now() - started,
    passed: actual === definition.expected && statusMatches,
    calls: [{
      status: call.status,
      error: call.status === 'rejected' ? call.reason.message : null,
    }],
  };
}

async function main() {
  await fs.mkdir(results, {recursive: true});
  await executeSqlFile(path.join(sql, 'setup.sql'));

  const instant = 'dbo.usp_ConcurrencyTest_InstantApprove';
  const staff = 'dbo.usp_ConcurrencyTest_StaffApprove';
  const unsafe = 'dbo.usp_ConcurrencyTest_Unsafe';
  const scenarios = [];

  for (const definition of [
    {name: 'instant-vs-instant', procedureA: instant, procedureB: instant, expected: 1, prefix: 'I_I'},
    {name: 'instant-vs-staff', procedureA: instant, procedureB: staff, expected: 1, prefix: 'I_S'},
    {name: 'staff-vs-staff', procedureA: staff, procedureB: staff, expected: 1, prefix: 'S_S'},
    {name: 'unsafe-isolated-race', procedureA: unsafe, procedureB: unsafe, expected: 2, prefix: 'UNSAFE'},
  ]) {
    scenarios.push(await concurrentScenario({
      ...definition,
      space: 'S0001',
      windowStart: '2026-09-01T09:00:00',
      windowEnd: '2026-09-01T10:00:00',
      a: overlap(),
      b: overlap(),
    }));
  }

  scenarios.push(await concurrentScenario({
    name: 'non-overlapping',
    procedureA: instant,
    procedureB: staff,
    expected: 2,
    prefix: 'NON_OVERLAP',
    space: 'S0001',
    windowStart: '2026-09-01T09:00:00',
    windowEnd: '2026-09-01T11:00:00',
    a: overlap('S0001', '2026-09-01T09:00:00', '2026-09-01T10:00:00'),
    b: overlap('S0001', '2026-09-01T10:15:00', '2026-09-01T11:00:00'),
  }));

  scenarios.push(await concurrentScenario({
    name: 'boundary-adjacent',
    procedureA: staff,
    procedureB: staff,
    expected: 2,
    prefix: 'BOUNDARY',
    space: 'S0001',
    windowStart: '2026-09-01T09:00:00',
    windowEnd: '2026-09-01T11:00:00',
    a: overlap('S0001', '2026-09-01T09:00:00', '2026-09-01T10:00:00'),
    b: overlap('S0001', '2026-09-01T10:00:00', '2026-09-01T11:00:00'),
  }));

  await resetFixtures();
  await executeQuery(`
    INSERT dbo.ConcurrencyTestMaintenance
        (maintenance_id, space_id, start_time, end_time, impact)
    VALUES
        ('M00001', 'S0001', '2026-09-01T09:00:00', '2026-09-01T10:00:00', 'ADVISORY'),
        ('M00002', 'S0001', '2026-09-01T11:00:00', '2026-09-01T12:00:00', 'OUT_OF_SERVICE');
  `);

  scenarios.push(await singleAttemptScenario({
    name: 'advisory-without-acknowledgement-rejected',
    procedure: staff,
    bookingId: 'ADV-NO-ACK',
    values: overlap('S0001', '2026-09-01T09:15:00', '2026-09-01T09:45:00', false),
    expected: 0,
    expectRejected: true,
  }));

  scenarios.push(await singleAttemptScenario({
    name: 'advisory-with-acknowledgement-approved',
    procedure: staff,
    bookingId: 'ADV-ACK',
    values: overlap('S0001', '2026-09-01T09:15:00', '2026-09-01T09:45:00', true),
    expected: 1,
    expectRejected: false,
  }));
  const acknowledgementCount = await queryInteger(`
    SELECT COUNT(*)
    FROM dbo.ConcurrencyTestAcknowledgement
    WHERE booking_id = 'ADV-ACK' AND maintenance_id = 'M00001';
  `);
  scenarios.at(-1).passed = scenarios.at(-1).passed && acknowledgementCount === 1;
  scenarios.at(-1).acknowledgementCount = acknowledgementCount;

  scenarios.push(await singleAttemptScenario({
    name: 'out-of-service-overlap-rejected',
    procedure: instant,
    bookingId: 'OOS-BLOCK',
    values: overlap('S0001', '2026-09-01T11:15:00', '2026-09-01T11:45:00', true),
    expected: 0,
    expectRejected: true,
  }));

  await resetFixtures();
  await callBookingProcedure(staff, 'ESC-BOOK', overlap('S0002', '2026-09-01T13:00:00', '2026-09-01T14:00:00'));
  await executeQuery(`
    INSERT dbo.ConcurrencyTestMaintenance
        (maintenance_id, space_id, start_time, end_time, impact)
    VALUES
        ('M00003', 'S0002', '2026-09-01T13:30:00', '2026-09-01T14:30:00', 'ADVISORY');
    UPDATE dbo.ConcurrencyTestMaintenance
    SET impact = 'OUT_OF_SERVICE'
    WHERE maintenance_id = 'M00003';
  `);
  const escalation = await queryInteger(`
    SELECT COUNT(*)
    FROM dbo.ConcurrencyTestBooking b
    INNER JOIN dbo.ConcurrencyTestMaintenance m
        ON m.space_id = b.space_id
       AND m.impact = 'OUT_OF_SERVICE'
       AND b.start_time < m.end_time
       AND b.end_time > m.start_time
    WHERE m.maintenance_id = 'M00003';
  `);
  scenarios.push({
    scenario: 'maintenance-escalation-identifies-approved-booking',
    procedures: [],
    expectedApprovedCount: 1,
    approvedCount: escalation,
    elapsedMs: 0,
    passed: escalation === 1,
    calls: [],
  });

  const report = {
    generatedAt: new Date().toISOString(),
    scaffoldOnly: true,
    environment: {
      node: process.version,
      platform: process.platform,
      server: process.env.DB_SERVER || 'localhost',
      database: process.env.DB_DATABASE || 'tempdb',
    },
    results: scenarios,
    passed: scenarios.every((scenario) => scenario.passed),
  };

  await fs.writeFile(path.join(results, 'latest.json'), `${JSON.stringify(report, null, 2)}\n`);
  await fs.writeFile(path.join(results, 'latest.md'), [
    '# G06 Concurrency Test Evidence',
    '',
    '| Scenario | Expected | Actual | Elapsed ms | Passed |',
    '|---|---:|---:|---:|---|',
    ...scenarios.map((scenario) => `| ${scenario.scenario} | ${scenario.expectedApprovedCount} | ${scenario.approvedCount} | ${scenario.elapsedMs} | ${scenario.passed ? 'yes' : 'no'} |`),
    '',
    'This evidence uses isolated tables until outputs 09-12 are approved.',
  ].join('\n'));

  console.log(JSON.stringify(report, null, 2));
  process.exitCode = report.passed ? 0 : 1;
}

try {
  await main();
} finally {
  if (String(process.env.KEEP_TEST_OBJECTS || 'false').toLowerCase() !== 'true') {
    await executeSqlFile(path.join(sql, 'cleanup.sql'));
  }
}
