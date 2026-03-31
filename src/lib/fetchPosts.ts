import type { PageObjectResponse, RichTextItemResponse } from '@notionhq/client/build/src/api-endpoints.js';
import { notion, NOTION_DATABASE_ID } from './notion.js';
import { fetchPostBody } from './notionToHtml.js';
import type { BlogPost } from './types.js';

function getRichText(prop: { rich_text: RichTextItemResponse[] } | undefined): string {
  return prop?.rich_text.map((t) => t.plain_text).join('') ?? '';
}

function generateSlug(title: string, pageId: string): string {
  const slug = title
    .toLowerCase()
    .replace(/[^a-z0-9\s-]/g, '')
    .trim()
    .replace(/\s+/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-|-$/g, '');
  return slug || pageId.replace(/-/g, '').slice(0, 16);
}

function mapPageToPost(page: PageObjectResponse): BlogPost {
  const props = page.properties as Record<string, unknown>;

  const titleProp = props['Title'] as { title: RichTextItemResponse[] } | undefined;
  const title = titleProp?.title.map((t) => t.plain_text).join('') ?? 'Untitled';

  const slug = getRichText(props['Slug'] as { rich_text: RichTextItemResponse[] } | undefined)
    || generateSlug(title, page.id);

  const descProp = props['Description'] as { rich_text: RichTextItemResponse[] } | undefined;
  const description = getRichText(descProp);

  const dateProp = props['PublishedDate'] as { date: { start: string } | null } | undefined;
  const publishedDate = dateProp?.date?.start ?? new Date().toISOString().split('T')[0];

  const tagsProp = props['Tags'] as { multi_select: { name: string }[] } | undefined;
  const tags = tagsProp?.multi_select.map((t) => t.name) ?? [];

  const coverProp = props['Cover'] as
    | { files: { type: string; file?: { url: string }; external?: { url: string } }[] }
    | undefined;
  let coverImageUrl: string | null = null;
  if (coverProp?.files && coverProp.files.length > 0) {
    const file = coverProp.files[0];
    coverImageUrl = file.file?.url ?? file.external?.url ?? null;
  }

  const featuredProp = props['Featured'] as { checkbox: boolean } | undefined;
  const featured = featuredProp?.checkbox ?? false;

  return {
    id: page.id,
    slug,
    title,
    description,
    publishedDate,
    tags,
    coverImageUrl,
    featured,
    bodyHtml: '',
  };
}

export async function fetchAllPosts(): Promise<BlogPost[]> {
  const pages: PageObjectResponse[] = [];
  let cursor: string | undefined = undefined;

  do {
    const response = await notion.databases.query({
      database_id: NOTION_DATABASE_ID,
      filter: {
        property: 'Status',
        select: { equals: 'Published' },
      },
      sorts: [{ property: 'PublishedDate', direction: 'descending' }],
      start_cursor: cursor,
      page_size: 100,
    });

    pages.push(...(response.results as PageObjectResponse[]));
    cursor = response.has_more ? (response.next_cursor ?? undefined) : undefined;
  } while (cursor);

  return pages.map(mapPageToPost);
}

export async function fetchPostWithBody(slug: string): Promise<BlogPost | null> {
  const posts = await fetchAllPosts();
  const post = posts.find((p) => p.slug === slug);
  if (!post) return null;

  const bodyHtml = await fetchPostBody(post.id);
  return { ...post, bodyHtml };
}
