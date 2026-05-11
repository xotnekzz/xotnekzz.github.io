export interface TagInfo {
  name: string;
  count: number;
}

export interface Portfolio {
  title: string;
  description: string;
  date: string; // YYYY-MM-DD 형식
  tags: string[];
  featured?: boolean;
  draft?: boolean; // true일 때 프로덕션 빌드에서 제외
  category?: string; // 폴더명
  slug?: string; // URL-safe 슬러그
}
