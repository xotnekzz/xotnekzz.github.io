export interface BlogPost {
  id: string;
  slug: string;
  title: string;
  description: string;
  publishedDate: string; // ISO 8601
  tags: string[];
  coverImageUrl: string | null;
  featured: boolean;
  bodyHtml: string; // populated only on detail page fetch
}

export interface TagInfo {
  name: string;
  count: number;
}
