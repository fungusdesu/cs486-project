import 'dotenv/config';
import {createApp} from './app.mjs';
import {createDatabase} from './database.mjs';

const port = Number(process.env.PORT || 3000);
const app = createApp({db: createDatabase()});
app.listen(port, '0.0.0.0', () => console.log(`G06 backend listening on http://localhost:${port}`));