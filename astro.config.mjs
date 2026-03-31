// @ts-check
import { defineConfig, envField } from 'astro/config';

import tailwindcss from '@tailwindcss/vite';
import sitemap from '@astrojs/sitemap';

// https://astro.build/config
export default defineConfig({
  site: 'https://tskim.github.io',
  vite: {
    plugins: [tailwindcss()]
  },
  integrations: [sitemap()],
  env: {
    schema: {
      NOTION_API_KEY: envField.string({ context: 'server', access: 'secret' }),
      NOTION_DATABASE_ID: envField.string({ context: 'server', access: 'secret' }),
    }
  }
});