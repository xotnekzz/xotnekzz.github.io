// @ts-check
import { defineConfig } from 'astro/config';
import tailwindcss from '@tailwindcss/vite';
import sitemap from '@astrojs/sitemap';

export default defineConfig({
  site: 'https://xotnekzz.github.io',
  vite: { plugins: [tailwindcss()] },
  integrations: [
    sitemap({
      filter: (page) => page !== 'https://xotnekzz.github.io/portfolio/',
    }),
  ],
  markdown: {
    shikiConfig: { theme: 'github-dark' },
  },
});
