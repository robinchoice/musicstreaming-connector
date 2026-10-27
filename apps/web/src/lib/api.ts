import { z } from 'zod';
import { page } from '$app/state';
import { t } from './i18n';
import { toastError } from './toast.svelte';

const errorAnswer = z.object({ error: z.string().min(1) });

// The last failed calls, newest first. Feedback sends them along.
export const recentErrors: string[] = [];

function noteError(method: string, path: string, status: number | string) {
  recentErrors.unshift(`${method} /api/v1${path} → ${status}`);
  recentErrors.length = Math.min(recentErrors.length, 5);
}

export class ApiError extends Error {}

async function call<T>(method: 'GET' | 'POST', path: string, body: unknown, signal: AbortSignal | null = null): Promise<T> {
  try {
    // The API answers errors in the language sent here, the one chosen in the footer
    const language = { 'accept-language': page.data.locale };
    const response = await fetch(`/api/v1${path}`, method === 'GET' ? { headers: language, signal } : {
      method, headers: { ...language, 'content-type': 'application/json' },
      body: JSON.stringify(body), signal,
    });
    if (!response.ok) {
      noteError(method, path, response.status);
      const body = errorAnswer.safeParse(await response.json().catch(() => null)).data;
      throw new ApiError(body?.error || t().serviceDown);
    }
    return response.json();
  } catch (error) {
    if (signal?.aborted) throw error;
    if (error instanceof TypeError) noteError(method, path, 'offline');
    const failure = error instanceof ApiError ? error : new ApiError(error instanceof TypeError ? t().offline : error instanceof Error ? error.message : t().requestFailed);
    toastError(failure.message);
    throw failure;
  }
}

export const api = {
  post: <T>(path: string, body: unknown, signal?: AbortSignal) => call<T>('POST', path, body, signal),
  get: <T>(path: string, signal?: AbortSignal) => call<T>('GET', path, undefined, signal),
};
