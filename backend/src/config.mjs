import 'dotenv/config';

const asBoolean = (value, fallback) =>
  value === undefined ? fallback : String(value).toLowerCase() === 'true';

export const port = Number(process.env.PORT || 3000);

export const databaseConfig = {
  server: process.env.DB_SERVER || 'localhost',
  database: process.env.DB_DATABASE || 'School',
  port: Number(process.env.DB_PORT || 1433),
  user: process.env.DB_USERNAME || undefined,
  password: process.env.DB_PASSWORD || undefined,
  options: {
    encrypt: asBoolean(process.env.DB_ENCRYPT, false),
    trustServerCertificate: asBoolean(process.env.DB_TRUST_SERVER_CERTIFICATE, true),
    trustedConnection: !process.env.DB_USERNAME,
  },
  pool: { min: 0, max: 10, idleTimeoutMillis: 30_000 },
};
