import { vitePreprocess } from '@sveltejs/vite-plugin-svelte'

export default {
  // Use Vite's preprocessing pipeline instead of svelte-preprocess so Sass is
  // compiled through Vite's modern Sass API support.
  preprocess: vitePreprocess()
}
