// See https://svelte.dev/docs/kit/types#app.d.ts
declare global {
  namespace App {
    interface PageData {
      // Link preview of a public page, see +layout.svelte. image is an absolute URL.
      meta?: { title?: string; description?: string; image?: string };
    }
  }
}

export {};
