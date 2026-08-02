import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  callBookingProcedure,
  executeQuery,
  executeSqlFile,
  queryInteger,
} from './database.mjs';

const directory = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(directory, '..');
const sqlDirectory = path.join(root, 'sql');
const resultDirectory = path.join(root, 'results');

async function runScenario(definition) {
  await executeQuery('DELETE FROM dbo.ConcurrencyTestBooking;');
  const startedAt = new Date();
  const outcomes = await Promise.allSettled([
    callBookingProcedure(definition.procedure, `${definition.prefix}-A`),
    callBookingProcedure(definition.procedure, `${definition.prefix}-B`),
  ]);
  const approvedCount = await queryInteger(`
    SELECT COUNT(*) AS approved_count
    FROM dbo.ConcurrencyTestBooking
    WHERE space_id = 'S0001'
      AND start_time < '2026-09-01T10:00:00'
      AND end_time > '2026-09-01T09:00:00';
  `);
  return {
    scenario: definition.name,
    procedure: definition.procedure,
    expectedApprovedCount: definition.expectedApprovedCount,
    approvedCount,
    passed: approvedCount === definition.expectedApprovedCount,
    elapsedMs: Date.now() - startedAt.getTime(),
    calls: outcomes.map((outcome) => ({
      status: outcome.status,
      error: outcome.status === 'rejected' ? outcome.reason.message : null,
    })),
  };
}

async function main() {
  await fs.mkdir(resultDirectory, { recursive: true });
  try {
    await executeSqlFile(path.join(sqlDirectory, 'setup.sql'));
    const definitions = [
      {
        name: 'unsafe check-then-insert race',
        procedure: 'dbo.usp_ConcurrencyTest_Unsafe',
        prefix: 'UNSAFE',
        expectedApprovedCount: 2,
      },
      {
        name: 'protected per-space transaction lock',
        procedure: 'dbo.usp_ConcurrencyTest_Safe',
        prefix: 'SAFE',
        expectedApprovedCount: 1,
      },
    ];
    const results = [];
    for (const definition of definitions) {
      results.push(await runScenario(definition));
    }
    const report = {
      generatedAt: new Date().toISOString(),
      scaffoldOnly: true,
      results,
      passed: results.every((result) => result.passed),
    };
    await fs.writeFile(
      path.join(resultDirectory, 'latest.json'),
      `${JSON.stringify(report, null, 2)}\n`,
      'utf8',
    );
    const markdown = [
      '# G06 Concurrency Scaffold Results',
      '',
      '| Scenario | Expected approved | Actual approved | Passed |',
      '|---|---:|---:|---|',
      ...results.map((result) =>
        `| ${result.scenario} | ${result.expectedApprovedCount} | ${result.approvedCount} | ${result.passed ? 'yes' : 'no'} |`),
      '',
      '> Replace the isolated lab procedures with the approved step 12 production procedures before marking step 13 done.',
      '',
    ].join('\n');
    await fs.writeFile(path.join(resultDirectory, 'latest.md'), markdown, 'utf8');
    console.log(JSON.stringify(report, null, 2));
    process.exitCode = report.passed ? 0 : 1;
  } finally {
    if (String(process.env.KEEP_TEST_OBJECTS || 'false').toLowerCase() !== 'true') {
      await executeSqlFile(path.join(sqlDirectory, 'cleanup.sql'));
    }
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
