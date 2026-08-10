import sql from 'mssql';
import { pool } from './database.mjs';

export class AdapterNotConfiguredError extends Error {
  constructor(environmentKey) {
    super(`Database procedure adapter ${environmentKey} is not configured.`);
    this.name = 'AdapterNotConfiguredError';
    this.statusCode = 501;
  }
}

export function safeProcedureName(name) {
  if (!/^(?:[A-Za-z_][A-Za-z0-9_]*\.)?[A-Za-z_][A-Za-z0-9_]*$/.test(name)) {
    throw new Error(`Unsafe SQL procedure name: ${name}`);
  }
  return name;
}

export async function executeJsonProcedure(environmentKey, payload) {
  const configured = process.env[environmentKey];
  if (!configured) throw new AdapterNotConfiguredError(environmentKey);
  const procedure = safeProcedureName(configured);
  const connection = await pool();
  const result = await connection
    .request()
    .input('payload_json', sql.NVarChar(sql.MAX), JSON.stringify(payload ?? {}))
    .execute(procedure);
  return result.recordset ?? [];
}
