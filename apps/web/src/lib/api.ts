import { toastError } from './toast.svelte';

// The last failed calls, newest first. Feedback sends them along.
export const recentErrors: string[] = [];

function noteError(path: string, status: number | string) {
  recentErrors.unshift(`POST /api/v1${path} → ${status}`);
  recentErrors.length = Math.min(recentErrors.length, 5);
}

export class ApiError extends Error {
  constructor(message: string, public searchUrl?: string) {
    super(message);
  }
}

export const api = {
  async post<T>(path: string, body: unknown, signal?: AbortSignal): Promise<T> {
    try {
      const response = await fetch(`/api/v1${path}`, {
        method: 'POST', headers: { 'content-type': 'application/json' },
        body: JSON.stringify(body), signal,
      });
      if (!response.ok) {
        noteError(path, response.status);
        const body = await response.json().catch(() => null);
        throw new ApiError(body?.error || 'Der Dienst ist gerade nicht erreichbar.', body?.searchUrl);
      }
      return response.json();
    } catch (error) {
      if (signal?.aborted) throw error;
      if (error instanceof TypeError) noteError(path, 'offline');
      const failure = error instanceof ApiError ? error : new ApiError(error instanceof TypeError ? 'Keine Verbindung zum Server. Versuche es erneut.' : error instanceof Error ? error.message : 'Die Anfrage ist fehlgeschlagen.');
      toastError(failure.message);
      throw failure;
    }
  },
};
