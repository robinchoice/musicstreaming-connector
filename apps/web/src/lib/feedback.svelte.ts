import { type FeedbackContext, LIVE } from '@app/shared';
import { domToJpeg } from 'modern-screenshot';
import { browser } from '$app/environment';
import { api, recentErrors } from './api';

type Kind = 'bug' | 'idea';

// Bugs come from the floating button with a screenshot, ideas from the footer.
// The context is taken when the panel opens, as the tester saw the page.
export const feedback = $state({
  kind: null as Kind | null,
  screenshot: null as string | null,
  context: null as FeedbackContext | null,
});

const TEST_MODE_KEY = 'test-mode';

// Shows the bug button. On until MusicLink goes live as 1.0, then off until
// someone switches it on in the footer. The choice stays on this device.
const savedTestMode: boolean | null = browser ? JSON.parse(localStorage.getItem(TEST_MODE_KEY) ?? 'null') : null;
export const testMode = $state({ on: savedTestMode ?? !LIVE });

export function setTestMode(on: boolean) {
  testMode.on = on;
  localStorage.setItem(TEST_MODE_KEY, JSON.stringify(on));
}

export function openFeedback(kind: Kind, screenshot: string | null = null) {
  feedback.kind = kind;
  feedback.screenshot = screenshot;
  feedback.context = feedbackContext();
}

export function closeFeedback() {
  feedback.kind = null;
  feedback.screenshot = null;
  feedback.context = null;
}

// What the tester sees right now, without anything marked data-feedback-ignore.
// JPEG keeps a full screen at around 200 KB.
export function takeScreenshot() {
  return domToJpeg(document.documentElement, {
    width: innerWidth,
    height: innerHeight,
    scale: Math.min(devicePixelRatio, 2),
    quality: 0.85,
    backgroundColor: getComputedStyle(document.body).backgroundColor,
    style: { transform: `translate(${-scrollX}px, ${-scrollY}px)` },
    filter: node => !(node instanceof Element && node.hasAttribute('data-feedback-ignore')),
  });
}

export type Rect = { x: number; y: number; width: number; height: number };

// Draws the frame into the image, so the mail shows it too. The rect is
// relative to the image, from 0 to 1.
export async function markScreenshot(dataUrl: string, rect: Rect) {
  const image = new Image();
  image.src = dataUrl;
  await image.decode();
  const canvas = document.createElement('canvas');
  canvas.width = image.naturalWidth;
  canvas.height = image.naturalHeight;
  const ctx = canvas.getContext('2d')!;
  ctx.drawImage(image, 0, 0);
  ctx.strokeStyle = '#F2545B';
  ctx.lineWidth = Math.max(3, canvas.width / 200);
  ctx.strokeRect(rect.x * canvas.width, rect.y * canvas.height, rect.width * canvas.width, rect.height * canvas.height);
  return canvas.toDataURL('image/jpeg', 0.85);
}

function feedbackContext(): FeedbackContext {
  return {
    platform: 'web',
    // Without the query, which holds the shared link
    page: location.pathname,
    device: navigator.userAgent.slice(0, 300),
    viewport: `${innerWidth}×${innerHeight} @${devicePixelRatio}x`,
    errors: [...recentErrors],
  };
}

export function sendFeedback(message: string, email: string) {
  return api.post('/feedback', {
    kind: feedback.kind,
    message,
    email: email || undefined,
    screenshot: feedback.screenshot?.split(',')[1],
    context: feedback.context,
  });
}
