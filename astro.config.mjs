// @ts-check
import { defineConfig } from 'astro/config';
import tailwindcss from '@tailwindcss/vite';
import sitemap from '@astrojs/sitemap';
import { writeFileSync, readFileSync, existsSync } from 'fs';
import { resolve } from 'path';

function resumeSavePlugin() {
  return {
    name: 'vite-plugin-resume-save',
    /** @param {import('vite').ViteDevServer} server */
    configureServer(server) {
      server.middlewares.use('/api/save-resume', async (/** @type {any} */ req, /** @type {any} */ res) => {
        if (req.method !== 'POST') {
          res.statusCode = 405;
          res.end(JSON.stringify({ error: 'Method Not Allowed' }));
          return;
        }

        const RESUME_FILE = resolve(process.cwd(), 'src/data/resume.ts');

        let body = '';
        req.on('data', (/** @type {any} */ chunk) => { body += chunk; });
        req.on('end', () => {
          try {
            const { edits } = JSON.parse(body);
            if (!edits || typeof edits !== 'object') {
              res.statusCode = 400;
              res.setHeader('Content-Type', 'application/json');
              res.end(JSON.stringify({ error: 'Invalid edits data' }));
              return;
            }

            if (!existsSync(RESUME_FILE)) {
              res.statusCode = 500;
              res.setHeader('Content-Type', 'application/json');
              res.end(JSON.stringify({ error: 'resume.ts not found', path: RESUME_FILE }));
              return;
            }

            let content = readFileSync(RESUME_FILE, 'utf-8');
            let savedCount = 0;

            Object.entries(edits).forEach(([field, value]) => {
              const v = String(value).replace(/'/g, "\\'");
              if (field === 'personal.name') {
                content = content.replace(/(\s*name:\s*')[^']*'/, `$1${v}'`);
                savedCount++;
              } else if (field === 'personal.title') {
                content = content.replace(/(\s*title:\s*')[^']*'/, `$1${v}'`);
                savedCount++;
              } else if (field === 'personal.email') {
                content = content.replace(/(\s*email:\s*')[^']*'/, `$1${v}'`);
                savedCount++;
              } else if (field === 'personal.github') {
                content = content.replace(/(\s*github:\s*')[^']*'/, `$1${v}'`);
                savedCount++;
              } else if (field === 'summary') {
                const escaped = String(value).replace(/\n/g, ' ').replace(/'/g, "\\'");
                content = content.replace(
                  /export const summary\s*=[\s\S]*?;/,
                  `export const summary =\n  '${escaped}';`,
                );
                savedCount++;
              }
            });

            writeFileSync(RESUME_FILE, content, 'utf-8');
            res.statusCode = 200;
            res.setHeader('Content-Type', 'application/json');
            res.end(JSON.stringify({ success: true, edits: savedCount, savedTo: RESUME_FILE }));
          } catch (err) {
            res.statusCode = 500;
            res.setHeader('Content-Type', 'application/json');
            res.end(JSON.stringify({ error: String(err) }));
          }
        });
      });
    },
  };
}

export default defineConfig({
  site: 'https://xotnekzz.github.io',
  vite: { plugins: [tailwindcss(), resumeSavePlugin()] },
  integrations: [
    sitemap({
      filter: (page) => page !== 'https://xotnekzz.github.io/portfolio/',
    }),
  ],
  markdown: {
    shikiConfig: { theme: 'github-dark' },
  },
});
