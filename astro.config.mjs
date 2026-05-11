// @ts-check
import { defineConfig } from 'astro/config';
import tailwindcss from '@tailwindcss/vite';
import sitemap from '@astrojs/sitemap';
import { visit } from 'unist-util-visit';

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
    remarkPlugins: [remarkObsidianImagePath],
  },
});
