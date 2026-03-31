import { NotionToMarkdown } from 'notion-to-md';
import { unified } from 'unified';
import remarkParse from 'remark-parse';
import remarkRehype from 'remark-rehype';
import rehypeSlug from 'rehype-slug';
import rehypeAutolinkHeadings from 'rehype-autolink-headings';
import rehypeStringify from 'rehype-stringify';
import { createHighlighter, type Highlighter } from 'shiki';
import { notion } from './notion.js';
import path from 'path';
import fs from 'fs';
import https from 'https';
import http from 'http';
import crypto from 'crypto';

const n2m = new NotionToMarkdown({ notionClient: notion });

// Singleton Shiki highlighter
let highlighter: Highlighter | null = null;
async function getHighlighter(): Promise<Highlighter> {
  if (!highlighter) {
    highlighter = await createHighlighter({
      themes: ['github-light', 'github-dark'],
      langs: [
        'javascript', 'typescript', 'python', 'bash', 'shell',
        'sql', 'yaml', 'json', 'go', 'rust', 'java', 'html', 'css',
        'markdown', 'dockerfile', 'toml', 'xml',
      ],
    });
  }
  return highlighter;
}

// Download Notion image to public/images/notion/<blockId>.<ext>
async function downloadImage(url: string, blockId: string): Promise<string> {
  const imagesDir = path.join(process.cwd(), 'public', 'images', 'notion');
  if (!fs.existsSync(imagesDir)) {
    fs.mkdirSync(imagesDir, { recursive: true });
  }

  // Use a hash of the URL to detect changes, but blockId as filename base
  const urlHash = crypto.createHash('md5').update(url).digest('hex').slice(0, 8);
  const ext = url.split('?')[0].split('.').pop()?.toLowerCase() ?? 'jpg';
  const safeExt = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg'].includes(ext) ? ext : 'jpg';
  const filename = `${blockId.replace(/-/g, '')}-${urlHash}.${safeExt}`;
  const localPath = path.join(imagesDir, filename);

  if (!fs.existsSync(localPath)) {
    await new Promise<void>((resolve, reject) => {
      const file = fs.createWriteStream(localPath);
      const client = url.startsWith('https') ? https : http;
      client.get(url, (res) => {
        res.pipe(file);
        file.on('finish', () => { file.close(); resolve(); });
      }).on('error', (err) => {
        fs.unlink(localPath, () => {});
        reject(err);
      });
    });
  }

  return `/images/notion/${filename}`;
}

// Custom transformer: callout blocks
n2m.setCustomTransformer('callout', async (block) => {
  const calloutBlock = block as {
    callout?: { rich_text: { plain_text: string }[]; icon?: { emoji?: string } };
  };
  const text = calloutBlock.callout?.rich_text.map((t) => t.plain_text).join('') ?? '';
  const icon = calloutBlock.callout?.icon?.emoji ?? '';
  return `<aside class="callout">${icon ? `<span class="callout-icon">${icon}</span>` : ''}<div class="callout-text">${text}</div></aside>`;
});

// Custom transformer: image blocks (download to local)
n2m.setCustomTransformer('image', async (block) => {
  const imageBlock = block as {
    id: string;
    image?: {
      type: string;
      file?: { url: string };
      external?: { url: string };
      caption?: { plain_text: string }[];
    };
  };
  const image = imageBlock.image;
  if (!image) return '';

  const url = image.file?.url ?? image.external?.url ?? '';
  if (!url) return '';

  let localPath = url;
  try {
    localPath = await downloadImage(url, imageBlock.id);
  } catch (e) {
    console.warn(`Failed to download image ${url}:`, e);
  }

  const caption = image.caption?.map((t) => t.plain_text).join('') ?? '';
  return `![${caption}](${localPath})`;
});

// Post-process HTML: syntax highlight fenced code blocks
async function highlightCodeBlocks(html: string): Promise<string> {
  const sh = await getHighlighter();
  // Match <pre><code class="language-xxx">...</code></pre>
  const codeBlockRegex = /<pre><code(?:\s+class="language-([^"]*)")?>([\s\S]*?)<\/code><\/pre>/g;

  const matches: { match: string; lang: string; code: string }[] = [];
  let m;
  while ((m = codeBlockRegex.exec(html)) !== null) {
    matches.push({ match: m[0], lang: m[1] ?? 'text', code: m[2] });
  }

  let result = html;
  for (const { match, lang, code } of matches) {
    const decodedCode = code
      .replace(/&amp;/g, '&')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&quot;/g, '"')
      .replace(/&#39;/g, "'");

    try {
      const highlighted = sh.codeToHtml(decodedCode, {
        lang: lang || 'text',
        themes: { light: 'github-light', dark: 'github-dark' },
      });
      result = result.replace(match, highlighted);
    } catch {
      // Unknown language — leave as-is
    }
  }
  return result;
}

export async function fetchPostBody(pageId: string): Promise<string> {
  const mdBlocks = await n2m.pageToMarkdown(pageId);
  const mdString = n2m.toMarkdownString(mdBlocks);

  const file = await unified()
    .use(remarkParse)
    .use(remarkRehype, { allowDangerousHtml: true })
    .use(rehypeSlug)
    .use(rehypeAutolinkHeadings, { behavior: 'wrap' })
    .use(rehypeStringify, { allowDangerousHtml: true })
    .process(mdString.parent ?? '');

  const html = String(file);
  return highlightCodeBlocks(html);
}
