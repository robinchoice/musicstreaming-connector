import './monitoring';
import { createDb, migrateDb } from '@app/db';
import { createApp } from './app';

// A failed migration aborts the boot.
await migrateDb(process.env.DATABASE_URL!);
const db = createDb(process.env.DATABASE_URL!);

export default { port: Number(process.env.PORT || 3000), idleTimeout: 30, fetch: createApp(undefined, db).fetch };
