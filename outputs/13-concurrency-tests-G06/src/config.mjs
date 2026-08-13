import 'dotenv/config';

export const databaseConfig = {
  server: process.env.DB_SERVER || 'localhost',
  database: process.env.DB_DATABASE || 'tempdb',
  username: process.env.DB_USERNAME || '',
  password: process.env.DB_PASSWORD || '',
  trustCertificate: String(process.env.SQLCMD_TRUST_CERTIFICATE || 'true').toLowerCase() === 'true',
};

if (databaseConfig.username && !databaseConfig.password) {
  throw new Error('DB_PASSWORD is required when DB_USERNAME is set.');
}

if (process.platform !== 'win32' && !databaseConfig.username) {
  throw new Error('Linux/macOS runs require DB_USERNAME and DB_PASSWORD; integrated authentication is Windows-only.');
}
