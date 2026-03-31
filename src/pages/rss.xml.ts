import rss from '@astrojs/rss';
import type { APIContext } from 'astro';
import { fetchAllPosts } from '../lib/fetchPosts.js';

export async function GET(context: APIContext) {
  const posts = await fetchAllPosts();

  return rss({
    title: "tskim's dev blog",
    description: '데이터 엔지니어링, 백엔드 개발, 클라우드 인프라에 대한 개발 블로그입니다.',
    site: context.site!,
    items: posts.map((post) => ({
      title: post.title,
      pubDate: new Date(post.publishedDate),
      description: post.description,
      link: `/blog/${post.slug}/`,
      categories: post.tags,
    })),
    customData: '<language>ko</language>',
  });
}
