import { Client } from '@notionhq/client';
import { NOTION_API_KEY, NOTION_DATABASE_ID } from 'astro:env/server';

export const notion = new Client({ auth: NOTION_API_KEY });
export { NOTION_DATABASE_ID };
