import 'dotenv/config';

export const databaseConfig = {
  server: process.env.DB_SERVER || 'localhost',
  database: process.env.DB_DATABASE || 'tempdb',
  username: process.env.DB_USERNAME || '',
  password: process.env.DB_PASSWORD || '',
  trustCertificate: String(process.env.SQLCMD_TRUST_CERTIFICATE || 'true').toLowerCase() === 'true',
};
