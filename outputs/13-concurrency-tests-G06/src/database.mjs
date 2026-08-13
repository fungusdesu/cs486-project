import { spawn } from 'node:child_process';
import { databaseConfig } from './config.mjs';

const authenticationArguments = () => {
  if (databaseConfig.username) {
    return ['-U', databaseConfig.username, '-P', databaseConfig.password];
  }
  return ['-E'];
};

const baseArguments = () => [
  '-S', databaseConfig.server,
  '-d', databaseConfig.database,
  ...(databaseConfig.trustCertificate ? ['-C'] : []),
  ...authenticationArguments(),
  '-b',
];

export function runSqlcmd(extraArguments) {
  return new Promise((resolve, reject) => {
    const child = spawn('sqlcmd', [...baseArguments(), ...extraArguments], {
      windowsHide: true,
    });
    let stdout = '';
    let stderr = '';
    child.stdout.on('data', (chunk) => { stdout += chunk; });
    child.stderr.on('data', (chunk) => { stderr += chunk; });
    child.on('error', reject);
    child.on('close', (code) => {
      if (code === 0) resolve({ stdout, stderr });
      else reject(new Error((stderr || stdout || `sqlcmd exited ${code}`).trim()));
    });
  });
}

export function executeSqlFile(path) {
  return runSqlcmd(['-i', path]);
}

export async function executeQuery(query) {
  return runSqlcmd(['-Q', query]);
}

export async function queryInteger(query) {
  const { stdout } = await runSqlcmd(['-h', '-1', '-W', '-Q', `SET NOCOUNT ON; ${query}`]);
  const value = Number(stdout.trim().split(/\s+/).at(-1));
  if (!Number.isInteger(value)) throw new Error(`Expected integer query result, received: ${stdout}`);
  return value;
}

export function callBookingProcedure(procedure, bookingId, values = {}) {
  const space = values.space || 'S0001';
  const start = values.start || '2026-09-01T09:00:00';
  const end = values.end || '2026-09-01T10:00:00';
  const acknowledged = values.advisoryAcknowledged ? 1 : 0;
  const query = `EXEC ${procedure} @booking_id='${bookingId}', @space_id='${space}', @start_time='${start}', @end_time='${end}', @advisory_acknowledged=${acknowledged};`;
  return executeQuery(query);
}