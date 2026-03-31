# 프로젝트 구조

```
blog/
├── public/
│   └── images/notion/       # 빌드 시 Notion 이미지가 다운로드되는 경로
├── src/
│   ├── components/          # Astro/HTML 컴포넌트
│   ├── layouts/             # 페이지 레이아웃
│   ├── lib/
│   │   ├── notion.ts        # Notion Client 초기화, 환경 변수 export
│   │   ├── types.ts         # BlogPost, TagInfo 타입 정의
│   │   ├── fetchPosts.ts    # 포스트 목록/단건 fetch 함수
│   │   └── notionToHtml.ts  # Notion → HTML 변환 (이미지 다운로드, 코드 하이라이팅 포함)
│   ├── pages/
│   │   ├── blog/
│   │   │   ├── index.astro       # 포스트 목록 페이지
│   │   │   └── [slug].astro      # 포스트 상세 페이지
│   │   └── ...
│   └── styles/
├── docs/                    # 프로젝트 문서 (이 폴더)
├── astro.config.mjs         # Astro 설정 (site URL, env schema, Vite 플러그인)
├── package.json
└── CLAUDE.md                # 문서 인덱스 (각 문서에 대한 설명)
```

## 주요 타입

```ts
interface BlogPost {
  id: string;
  slug: string;
  title: string;
  description: string;
  publishedDate: string; // ISO 8601
  tags: string[];
  coverImageUrl: string | null;
  featured: boolean;
  bodyHtml: string; // 상세 페이지에서만 채워짐
}
```
