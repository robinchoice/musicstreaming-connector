import adapter from '@sveltejs/adapter-node';

/** @type {import('@sveltejs/kit').Config} */
export default {
  compilerOptions: { runes: true },
  kit: {
    adapter: adapter(),
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
  },
};
