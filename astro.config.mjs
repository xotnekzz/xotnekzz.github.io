// @ts-check
import { defineConfig, envField } from 'astro/config';

import tailwindcss from '@tailwindcss/vite';
import sitemap from '@astrojs/sitemap';
import vercel from '@astrojs/vercel';

// https://astro.build/config
export default defineConfig({
  site: 'https://xotnekzz.github.io',
  output: 'server',
  adapter: vercel(),
  vite: {
    plugins: [tailwindcss()]
  },
  integrations: [sitemap()],
  markdown: {
    shikiConfig: {
      theme: 'github-dark',
    },
  },
  env: {
    schema: {
      ADMIN_PASSWORD: envField.string({ context: 'server', access: 'secret' }),
      ADMIN_SECRET: envField.string({ context: 'server', access: 'secret' }),
      GITHUB_TOKEN: envField.string({ context: 'server', access: 'secret' }),
      GITHUB_OWNER: envField.string({ context: 'server', access: 'secret' }),
      GITHUB_REPO: envField.string({ context: 'server', access: 'secret' }),
    },
  },
});
