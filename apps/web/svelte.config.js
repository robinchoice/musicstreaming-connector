import adapter from '@sveltejs/adapter-node';

/** @type {import('@sveltejs/kit').Config} */
export default {
  compilerOptions: { runes: true },
  kit: { adapter: adapter() },
};
