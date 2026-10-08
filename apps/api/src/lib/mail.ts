import { APP_NAME } from '@app/shared';
import nodemailer from 'nodemailer';

const port = Number(process.env.SMTP_PORT || 587);

// Without SMTP_HOST mails go to the log, so local dev needs no mail account.
const transport = process.env.SMTP_HOST
  ? nodemailer.createTransport({
      host: process.env.SMTP_HOST,
      port,
      secure: port === 465,
      auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS },
    })
  : null;

const from = process.env.EMAIL_FROM || `${APP_NAME} <noreply@localhost>`;

type Mail = {
  to: string;
  subject: string;
  text: string;
  replyTo?: string;
  attachments?: { filename: string; content: Buffer }[];
};

export async function sendMail({ to, subject, text, replyTo, attachments }: Mail) {
  if (!transport) {
    console.log(`[mail] To ${to}: ${subject}\n${text}`);
    return;
  }
  await transport.sendMail({ from, to, subject, text, replyTo, attachments });
}
