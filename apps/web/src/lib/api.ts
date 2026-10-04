import { toastError } from './toast.svelte';

export const api = {
  async post<T>(path: string, body: unknown, signal?: AbortSignal): Promise<T> {
    try {
      const response = await fetch(`/api/v1${path}`, {
        method: 'POST', headers: { 'content-type': 'application/json' },
        body: JSON.stringify(body), signal,
      });
      if (!response.ok) {
        const body = await response.json().catch(() => null);
        throw new Error(body?.error || 'Der Dienst ist gerade nicht erreichbar.');
      }
      return response.json();
    } catch (error) {
      if (signal?.aborted) throw error;
      const message = error instanceof TypeError ? 'Keine Verbindung zum Server. Versuche es erneut.' : error instanceof Error ? error.message : 'Die Anfrage ist fehlgeschlagen.';
      toastError(message);
      throw new Error(message);
    }
  },
};
