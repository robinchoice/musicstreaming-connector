import { type Database, feedback } from '@app/db';
import { type FeedbackContext, feedbackErrors, feedbackSchema } from '@app/shared';
import { Hono } from 'hono';
import { sendMail } from '../lib/mail';
import { clientIp, rateLimit } from '../lib/rate-limit';
import { captureException } from '../monitoring';

// No login, so the limit is per address
const reportsPerIp = rateLimit('feedback-per-ip', 10, 60 * 60 * 1000);

function imageType(bytes: Buffer) {
  if (bytes.subarray(0, 4).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47]))) return 'png';
  if (bytes.subarray(0, 3).equals(Buffer.from([0xff, 0xd8, 0xff]))) return 'jpg';
  return null;
}

const firstLine = (message: string) => {
  const line = message.split('\n')[0]!;
  return line.length > 60 ? `${line.slice(0, 60)}…` : line;
};

type Report = {
  id: string;
  kind: 'bug' | 'idea';
  message: string;
  email?: string;
  context: FeedbackContext & { api: string };
};

// Answering the mail reaches the tester, if they left an address.
function mail(report: Report, to: string, screenshot: Buffer | null) {
  const { context } = report;
  return {
    to,
    replyTo: report.email,
    subject: `${report.kind === 'bug' ? 'Bug' : 'Idea'}: ${firstLine(report.message)}`,
    text: [
      report.message,
      '--',
      `Tester: ${report.email ?? 'anonymous'}`,
      `Page: ${context.page}`,
      `Platform: ${context.platform} · api ${context.api}`,
      `Device: ${context.device}`,
      `Window: ${context.viewport}`,
      `Recent errors: ${context.errors.join(', ') || '–'}`,
      `Feedback: ${report.id}`,
    ].join('\n'),
    attachments: screenshot ? [{ filename: `screenshot.${imageType(screenshot)}`, content: screenshot }] : [],
  };
}

export const feedbackRoutes = (db: Database) =>
  new Hono()
    // Stored first, so a failing mail loses nothing
    .post('/', async (c) => {
      const parsed = feedbackSchema.safeParse(await c.req.json().catch(() => null));
      if (!parsed.success) {
        const message = parsed.error.issues[0]?.message as string;
        const known = (Object.values(feedbackErrors) as string[]).includes(message);
        return c.json({ error: known ? message : 'Die Meldung ist unvollständig.' }, 400);
      }
      if (!(await reportsPerIp.hit(db, clientIp(c)))) {
        return c.json({ error: 'Zu viele Meldungen. Versuche es später erneut.' }, 429);
      }
      const { kind, message, email, context, screenshot: base64 } = parsed.data;
      const screenshot = base64 ? Buffer.from(base64, 'base64') : null;
      if (screenshot && !imageType(screenshot)) return c.json({ error: 'Der Screenshot muss ein PNG oder JPEG sein.' }, 400);

      const fullContext = { ...context, api: process.env.APP_VERSION || 'dev' };
      const [row] = await db
        .insert(feedback)
        .values({ kind, message, email, screenshot, context: fullContext })
        .returning({ id: feedback.id });

      const to = process.env.FEEDBACK_EMAIL;
      try {
        if (to) await sendMail(mail({ id: row!.id, kind, message, email, context: fullContext }, to, screenshot));
      } catch (error) {
        console.error('Feedback mail failed:', error);
        captureException(error);
      }
      return c.json({ ok: true });
    });
