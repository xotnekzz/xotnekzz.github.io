# 기술 스택

## 프레임워크 및 도구

| 역할 | 패키지 | 버전 |
| --- | --- | --- |
| 정적 사이트 생성 | astro | ^6.1.2 |
| CSS | tailwindcss (Vite 플러그인) | ^4.2.2 |
| Notion API 클라이언트 | @notionhq/client | ^2.3.0 |
| Notion → Markdown 변환 | notion-to-md | ^3.1.9 |
| 코드 하이라이팅 | shiki | ^4.0.2 |
| Sitemap 생성 | @astrojs/sitemap | ^3.7.2 |
| RSS | @astrojs/rss | ^4.0.18 |
| Markdown → HTML 파이프라인 | unified + remark + rehype | — |

## 환경 변수 (astro:env/server)

| 변수명 | 설명 |
| --- | --- |
| `NOTION_API_KEY` | Notion Integration 토큰 |
| `NOTION_DATABASE_ID` | 포스트 목록을 담는 Notion 데이터베이스 ID |

## 배포

- **호스팅**: GitHub Pages (`https://xotnekzz.github.io`)
- **배포 방식**: GitHub Actions (빌드 후 정적 파일 배포)
- **Node**: >=22.12.0
