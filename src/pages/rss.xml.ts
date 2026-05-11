import rss from '@astrojs/rss';
import type { APIContext } from 'astro';
import { getCollection } from 'astro:content';
import { isPublished } from '../lib/content-visibility';

export async function GET(context: APIContext) {
  const posts = (await getCollection('posts'))
    .filter(isPublished)
    .sort((a, b) => b.data.date.valueOf() - a.data.date.valueOf());

  return rss({
    title: "tskim's dev blog",
    description: '데이터 엔지니어링, 백엔드 개발, 클라우드 인프라에 대한 개발 블로그입니다.',
    site: context.site!,
    items: posts.map((post) => ({
      title: post.data.title,
      pubDate: post.data.date,
      description: post.data.description,
      link: `/blog/${post.id}/`,
      categories: post.data.tags,
    })),
    customData: '<language>ko</language>',
  });
}
