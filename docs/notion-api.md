# Notion API 사용 가이드

## 데이터베이스 쿼리

`@notionhq/client` v2.x 기준으로 `notion.databases.query`를 사용한다.

```ts
const response = await notion.databases.query({
  database_id: NOTION_DATABASE_ID,
  filter: { property: 'Status', select: { equals: 'Published' } },
  sorts: [{ property: 'PublishedDate', direction: 'descending' }],
  start_cursor: cursor,
  page_size: 100,
});
```

> **주의**: 메모리에 v5 breaking change(`dataSources.query`) 메모가 있으나, 현재 프로젝트는 v2.3.0을 사용하므로 `databases.query`가 올바른 호출이다.

## Notion 데이터베이스 프로퍼티 스키마

| 프로퍼티명 | 타입 | 설명 |
| --- | --- | --- |
| `Title` | title | 포스트 제목 |
| `Slug` | rich_text | URL 경로 (`/blog/<slug>`) |
| `Description` | rich_text | 요약 |
| `PublishedDate` | date | 발행일 (ISO 8601) |
| `Tags` | multi_select | 태그 목록 |
| `Cover` | files | 커버 이미지 |
| `Featured` | checkbox | 메인 노출 여부 |
| `Status` | select | `Published`인 경우만 조회 |

## 이미지 처리

- Notion 이미지 URL은 만료되므로 빌드 시 `public/images/notion/` 에 로컬 다운로드
- 파일명: `<blockId>-<urlMD5(8자)>.<ext>`
- 관련 코드: `src/lib/notionToHtml.ts` — `downloadImage()`

## 콘텐츠 변환 파이프라인

```
Notion 블록
  → notion-to-md (Markdown)
  → unified / remark-parse
  → remark-rehype
  → rehype-slug + rehype-autolink-headings
  → rehype-stringify (HTML)
  → Shiki 코드 하이라이팅
```

커스텀 블록 변환:
- `callout` → `<aside class="callout">` HTML
- `image` → 로컬 경로로 대체된 `![caption](path)` Markdown
