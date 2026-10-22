import { z } from 'zod';

const unset = z.literal('');
const port = z.string().regex(/^\d+$/).refine(value => Number(value) <= 65535);
const envSchema = z.object({
  DATABASE_URL: z.url({ protocol: /^postgres(ql)?$/ }),
  APP_URL: z.url(),
  PORT: port.or(unset).exactOptional(),
  SMTP_PORT: port.or(unset).exactOptional(),
  MIN_BUILD_IOS: z.string().regex(/^\d*$/).exactOptional(),
  MIN_BUILD_ANDROID: z.string().regex(/^\d*$/).exactOptional(),
  SENTRY_DSN: z.url().or(unset).exactOptional(),
  FEEDBACK_EMAIL: z.email().or(unset).exactOptional(),
});

declare module 'bun' {
  interface Env extends z.infer<typeof envSchema> {}
}

const result = envSchema.safeParse(process.env);
if (!result.success) throw new Error(`Invalid environment:\n${z.prettifyError(result.error)}`);
