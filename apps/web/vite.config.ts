import adapter from '@sveltejs/adapter-node';
import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';

export default defineConfig({
  plugins: [
    sveltekit({
      adapter: adapter(),
      compilerOptions: { runes: true },
      // From starter: SvelteKit adds nonces for its inline scripts. Browser errors go to
      // GlitchTip. New external sources (fonts, maps, APIs) go here.
      csp: {
        mode: 'auto',
        directives: {
          'default-src': ['self'],
          'script-src': ['self'],
          // The hash is that of an empty <style>: the feedback screenshot reads
          // web fonts through one. Content of any kind stays blocked.
          'style-src': ['self', 'sha256-47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU='],
          // Style attributes in app.html and in SvelteKit's route announcer
          'style-src-attr': ['unsafe-inline'],
          // Song covers come from the CDNs of every streaming service
          'img-src': ['self', 'data:', 'https:'],
          'connect-src': ['self', 'https://glitchtip.pleasance.org'],
          'frame-ancestors': ['none'],
          'base-uri': ['self'],
          'form-action': ['self'],
          'object-src': ['none'],
        },
      },
    }),
  ],
  // Vite finds these only when the first page runs hooks.client.ts and then reloads
  // every open page, which breaks browser tests on a cold dev server like in CI.
  optimizeDeps: { include: ['@sentry/browser'] },
  // In production hooks.server.ts forwards /api to the API service. API_INTERNAL_URL
  // moves the API in dev when another project holds port 3000.
  server: { proxy: { '/api': process.env.API_INTERNAL_URL || 'http://localhost:3000' } },
});
