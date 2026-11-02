import { defineEnvVars } from '@sveltejs/kit/env';
import { z } from 'zod';

// Read when the server starts. Public ones reach the browser via $app/env/public.
export const variables = defineEnvVars({
  PUBLIC_SENTRY_DSN: { public: true, schema: z.string().optional() },
  PUBLIC_SENTRY_ENVIRONMENT: { public: true, schema: z.string().optional() },
});
