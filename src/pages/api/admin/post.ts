export const prerender = false;

import type { APIRoute } from 'astro';
import { GITHUB_TOKEN, GITHUB_OWNER, GITHUB_REPO } from 'astro:env/server';

function toSlug(title: string): string {
  return title
    .toLowerCase()
    .replace(/[^a-z0-9\s-]/g, '')
    .trim()
    .replace(/\s+/g, '-')
    .replace(/-+/g, '-');
}

export const POST: APIRoute = async ({ request }) => {
  let body: Record<string, string>;
  try {
    body = await request.json();
  } catch {
    return new Response(JSON.stringify({ ok: false, error: 'Invalid JSON' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const { title, description, date, tags, category, cover, featured, content } = body;

  if (!title || !description || !date || !category || !content) {
    return new Response(
      JSON.stringify({ ok: false, error: '필수 항목이 누락되었습니다.' }),
      { status: 400, headers: { 'Content-Type': 'application/json' } }
    );
  }

  const slug = toSlug(title) || `post-${Date.now()}`;

  const tagList = tags
    ? tags
        .split(',')
        .map((t) => t.trim())
        .filter(Boolean)
    : [];

  const frontmatter = [
    '---',
    `title: "${title.replace(/"/g, '\\"')}"`,
    `description: "${description.replace(/"/g, '\\"')}"`,
    `date: ${date}`,
    `tags: [${tagList.map((t) => `"${t}"`).join(', ')}]`,
    cover ? `cover: "${cover}"` : null,
    `featured: ${featured === 'true' ? 'true' : 'false'}`,
    '---',
  ]
    .filter((line) => line !== null)
    .join('\n');

  const fileContent = `${frontmatter}\n\n${content}`;
  const filePath = `src/content/posts/${category}/${slug}.md`;

  const apiUrl = `https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/contents/${filePath}`;

  const githubResponse = await fetch(apiUrl, {
    method: 'PUT',
    headers: {
      Authorization: `Bearer ${GITHUB_TOKEN}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      message: `post: ${title}`,
      content: btoa(unescape(encodeURIComponent(fileContent))),
    }),
  });

  if (!githubResponse.ok) {
    const errorText = await githubResponse.text();
    return new Response(
      JSON.stringify({ ok: false, error: `GitHub API 오류: ${errorText}` }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }

  const result = await githubResponse.json();
  const fileUrl = result?.content?.html_url ?? apiUrl;

  return new Response(JSON.stringify({ ok: true, url: fileUrl }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  });
};
