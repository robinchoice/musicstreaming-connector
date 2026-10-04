import './monitoring';
import { createApp } from './app';

export default { port: Number(process.env.PORT || 3000), idleTimeout: 30, fetch: createApp().fetch };
