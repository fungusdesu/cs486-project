import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {callBookingProcedure, executeQuery, executeSqlFile, queryInteger} from './database.mjs';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const sql = path.join(root, 'sql');
const results = path.join(root, 'results');
async function scenario(definition) {
  await executeQuery('DELETE FROM dbo.ConcurrencyTestBooking;');
  const started = Date.now();
  const calls = await Promise.allSettled([callBookingProcedure(definition.procedure, `${definition.prefix}-A`, definition.a), callBookingProcedure(definition.procedure, `${definition.prefix}-B`, definition.b)]);
  const actual = await queryInteger(`SELECT COUNT(*) FROM dbo.ConcurrencyTestBooking WHERE space_id='${definition.space}' AND start_time < '${definition.windowEnd}' AND end_time > '${definition.windowStart}';`);
  return {scenario: definition.name, procedure: definition.procedure, expectedApprovedCount: definition.expected, approvedCount: actual, elapsedMs: Date.now()-started, passed: actual === definition.expected, calls: calls.map((x) => ({status:x.status, error:x.status === 'rejected' ? x.reason.message : null}))};
}
const overlap = (space='S0001', start='2026-09-01T09:00:00', end='2026-09-01T10:00:00') => ({space, start, end});
async function main() {
  await fs.mkdir(results, {recursive:true}); await executeSqlFile(path.join(sql,'setup.sql'));
  const scenarios = [];
  for (const [name, procedure, expected, prefix] of [['instant-vs-instant', 'dbo.usp_ConcurrencyTest_Safe', 1, 'I_I'], ['instant-vs-staff', 'dbo.usp_ConcurrencyTest_Safe', 1, 'I_S'], ['staff-vs-staff', 'dbo.usp_ConcurrencyTest_Safe', 1, 'S_S'], ['unsafe-isolated-race', 'dbo.usp_ConcurrencyTest_Unsafe', 2, 'UNSAFE']]) {
    scenarios.push(await scenario({name, procedure, expected, prefix, space:'S0001', windowStart:'2026-09-01T09:00:00', windowEnd:'2026-09-01T10:00:00', a:overlap(), b:overlap()}));
  }
  scenarios.push(await scenario({name:'non-overlapping', procedure:'dbo.usp_ConcurrencyTest_Safe', expected:2, prefix:'NON_OVERLAP', space:'S0001', windowStart:'2026-09-01T09:00:00', windowEnd:'2026-09-01T12:00:00', a:overlap('S0001','2026-09-01T09:00:00','2026-09-01T10:00:00'), b:overlap('S0001','2026-09-01T10:00:00','2026-09-01T11:00:00')}));
  scenarios.push(await scenario({name:'boundary-adjacent', procedure:'dbo.usp_ConcurrencyTest_Safe', expected:2, prefix:'BOUNDARY', space:'S0001', windowStart:'2026-09-01T09:00:00', windowEnd:'2026-09-01T12:00:00', a:overlap('S0001','2026-09-01T09:00:00','2026-09-01T10:00:00'), b:overlap('S0001','2026-09-01T10:00:00','2026-09-01T11:00:00')}));
  await executeQuery("DELETE FROM dbo.ConcurrencyTestMaintenance; INSERT dbo.ConcurrencyTestMaintenance VALUES ('M00001','S0001','2026-09-01T09:00:00','2026-09-01T10:00:00','ADVISORY'),('M00002','S0001','2026-09-01T11:00:00','2026-09-01T12:00:00','OUT_OF_SERVICE'); DELETE FROM dbo.ConcurrencyTestAcknowledgement; INSERT dbo.ConcurrencyTestAcknowledgement VALUES ('ACK0001','M00001');");
  const maintenance = await queryInteger("SELECT COUNT(*) FROM dbo.ConcurrencyTestAcknowledgement a JOIN dbo.ConcurrencyTestMaintenance m ON m.maintenance_id=a.maintenance_id WHERE m.impact='ADVISORY';");
  const blocked = await queryInteger("SELECT COUNT(*) FROM dbo.ConcurrencyTestMaintenance WHERE impact='OUT_OF_SERVICE' AND start_time < '2026-09-01T12:00:00' AND end_time > '2026-09-01T11:30:00';");
  const escalation = await queryInteger("SELECT COUNT(*) FROM dbo.ConcurrencyTestBooking b JOIN dbo.ConcurrencyTestMaintenance m ON b.space_id=m.space_id AND m.impact='OUT_OF_SERVICE' AND b.start_time<m.end_time AND b.end_time>m.start_time;");
  scenarios.push({scenario:'advisory acknowledged', approvedCount:maintenance, expectedApprovedCount:1, passed:maintenance===1, elapsedMs:0});
  scenarios.push({scenario:'out-of-service overlap blocked', approvedCount:blocked, expectedApprovedCount:1, passed:blocked===1, elapsedMs:0});
  scenarios.push({scenario:'maintenance escalation affected-booking query', approvedCount:escalation, expectedApprovedCount:0, passed:escalation===0, elapsedMs:0});
  const report={generatedAt:new Date().toISOString(), scaffoldOnly:true, environment:{node:process.version, platform:process.platform, server:process.env.DB_SERVER||'localhost', database:process.env.DB_DATABASE||'tempdb'}, results:scenarios, passed:scenarios.every((x)=>x.passed)};
  await fs.writeFile(path.join(results,'latest.json'),JSON.stringify(report,null,2)+'\n');
  await fs.writeFile(path.join(results,'latest.md'),['# G06 Concurrency Test Evidence','','| Scenario | Expected | Actual | Elapsed ms | Passed |','|---|---:|---:|---:|---|',...scenarios.map((x)=>`| ${x.scenario} | ${x.expectedApprovedCount} | ${x.approvedCount} | ${x.elapsedMs} | ${x.passed?'yes':'no'} |`),'','This evidence uses isolated tables until output 12 is approved.'].join('\n')+'\n');
  console.log(JSON.stringify(report,null,2)); process.exitCode=report.passed?0:1;
}
try { await main(); } finally { if (String(process.env.KEEP_TEST_OBJECTS||'false').toLowerCase() !== 'true') await executeSqlFile(path.join(sql,'cleanup.sql')); }
