// @ts-check
import { defineConfig } from 'astro/config';
import tailwindcss from '@tailwindcss/vite';
import sitemap from '@astrojs/sitemap';
import { visit } from 'unist-util-visit';
import path from 'node:path';

// Obsidian에서 vault-root-relative 경로(images/foo.svg)로 작성한 이미지를
// 웹 절대 경로(/images/foo.svg)로 변환한다.
function remarkObsidianImagePath() {
  return (tree) => {
    visit(tree, 'image', (node) => {
      if (node.url && /^images\//.test(node.url)) {
        node.url = '/' + node.url;
      }
    });
  };
}

// 상대 경로 .md 링크를 웹 URL로 변환한다.
// Obsidian: [이전 글](./de-lab-2.md) → 파일로 이동
// 웹:       → /blog/dataengineering/de-lab-2
function remarkMdLinks() {
  return (tree, file) => {
    visit(tree, 'link', (node) => {
      if (!node.url || !node.url.endsWith('.md') || node.url.startsWith('http')) return;

      const sourcePath = (file.path || '').replace(/\\/g, '/');
      const marker = 'src/content/posts/';
      const idx = sourcePath.indexOf(marker);
      if (idx === -1) return;

      const sourceDir = path.posix.dirname(sourcePath.slice(idx + marker.length));
      const resolved = path.posix.normalize(path.posix.join(sourceDir, node.url)).replace(/\.md$/, '');
      node.url = '/blog/' + resolved.toLowerCase();
    });
  };
}

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
    remarkPlugins: [remarkObsidianImagePath, remarkMdLinks],
  },
});
