import sql from 'mssql';
import { databaseConfig } from './config.mjs';

let poolPromise;

export function pool() {
  if (!poolPromise) {
    poolPromise = new sql.ConnectionPool(databaseConfig).connect();
  }
  return poolPromise;
}

export async function databaseHealth() {
  const connection = await pool();
  const result = await connection.request().query('SELECT 1 AS healthy;');
  return result.recordset[0].healthy === 1;
}
