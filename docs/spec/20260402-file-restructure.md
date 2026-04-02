# 스펙: 파일 구조 정리 (콘텐츠/설정 접근성 개선)

- **날짜**: 2026-04-02
- **사이클**: #7
- **작성자**: 기획 에이전트

---

## 목표 및 배경

메타데이터 파일(`site.ts`, `resume.ts`)이 분산되어 있고, 포스트 마크다운이 깊은 경로에 숨어있어 접근이 불편하다.
파일 구조를 정리하여:
1. 포스트를 프로젝트 루트 `posts/` 디렉토리로 이동 (가시성 향상)
2. 설정 파일을 `src/config/` 한 곳으로 통합 (일관성 향상)

---

## 변경 대상 파일 및 디렉토리

| 항목 | 작업 |
|------|------|
| `src/content/posts/` | 전체 이동 → 프로젝트 루트 `posts/` |
| `src/data/resume.ts` | 이동 → `src/config/resume.ts` |
| `src/content.config.ts` | 수정 — `base` 경로 변경 `./src/content/posts` → `./posts` |
| `src/pages/resume.astro` | 수정 — import 경로 변경 |
| `src/data/` | 삭제 (비우는 대로 자동 가비지 컬렉션) |

---

## 수용 기준 (Acceptance Criteria)

### 빌드 / 타입

- [ ] **AC-1**: `npm run build` 성공 (오류 없음, 페이지 수 유지 또는 증가)
- [ ] **AC-2**: `npx tsc --noEmit` 타입 오류 0건

### 파일 구조 변경

- [ ] **AC-3**: `posts/` 디렉토리가 프로젝트 루트에 존재하고 다음 파일/디렉토리 포함:
  - 루트 레벨 `.md` 파일 13개 (기존 `src/content/posts/` 의 마크다운 파일들)
  - `DataPlatform/` 서브디렉토리
  - `dev/` 서브디렉토리
  - `portfolio/` 서브디렉토리 (비어있어도 됨)
  
- [ ] **AC-4**: `src/content/posts/` 디렉토리가 **존재하지 않는다**
  (`.gitkeep` 파일도 포함해서 완전 삭제)

- [ ] **AC-5**: `src/config/resume.ts` 파일이 존재하고,
  내용이 기존 `src/data/resume.ts` 와 동일하다

- [ ] **AC-6**: `src/data/` 디렉토리가 **존재하지 않는다**

### 설정 파일 수정

- [ ] **AC-7**: `src/content.config.ts`에서 `loader` 설정의 `base`가 `'./posts'`로 변경됨
  ```ts
  loader: glob({ pattern: '**/*.md', base: './posts' })
  ```

- [ ] **AC-8**: `src/pages/resume.astro`의 import 문이 수정됨:
  ```ts
  import { resumeData } from '../config/resume';
  ```

### 콘텐츠 로드 검증

- [ ] **AC-9**: `/blog/` 페이지 빌드 결과물에서 포스트가 13개 로드됨
  (기존과 동일한 개수)

- [ ] **AC-10**: `/resume/` 페이지가 정상 로드되고,
  `resumeData`의 필드(경력, 기술스택 등)가 정상 표시됨

### 라우트 회귀

- [ ] **AC-11**: `/` (홈) 정상 로드
- [ ] **AC-12**: `/blog/` 정상 로드
- [ ] **AC-13**: `/resume/` 정상 로드
- [ ] **AC-14**: `/tags/` 정상 로드
- [ ] **AC-15**: `/rss.xml` 정상 로드

---

## 구현 상세

### 1. 포스트 디렉토리 이동

**이동할 파일:**
```
src/content/posts/  → posts/
```

Bash로 수행:
```bash
mkdir -p posts
cp -r src/content/posts/* posts/
rm -rf src/content/posts
```

현재 포함 파일 (콘텐츠 구조 참고):
```
posts/
├── AdTech AI Agent (Gemini CLI).md
├── AI를 활용한 파이썬 모듈 문서 자동화하기.md
├── ... (루트 .md 파일 13개)
├── DataPlatform/
│   └── astro-setup.md
├── dev/
│   └── test.md
└── portfolio/
```

### 2. `src/content.config.ts` 수정

파일: `/Users/tskim/Project/blog/src/content.config.ts`

변경 부분:
```ts
// 변경 전
const posts = defineCollection({
  loader: glob({ pattern: '**/*.md', base: './src/content/posts' }),
  ...
});

// 변경 후
const posts = defineCollection({
  loader: glob({ pattern: '**/*.md', base: './posts' }),
  ...
});
```

### 3. `src/data/resume.ts` → `src/config/resume.ts`

`src/data/resume.ts` 파일을 `src/config/resume.ts`로 이동:
```bash
mv src/data/resume.ts src/config/resume.ts
rmdir src/data   # 비우고 나면 삭제
```

파일 내용 변경 없음.

### 4. `src/pages/resume.astro` 수정

파일: `/Users/tskim/Project/blog/src/pages/resume.astro`

import 경로 변경:
```ts
// 변경 전
import { resumeData } from '../data/resume';

// 변경 후
import { resumeData } from '../config/resume';
```

---

## 테스트 시나리오

### 정상 케이스

1. **빌드 성공**
   - `npm run build` 실행 → 70개(또는 그 이상) 페이지 생성
   - 오류 메시지 0건

2. **포스트 로드**
   - `npm run dev` 후 `http://localhost:4321/blog/` 접속
   - 포스트 13개가 리스트에 표시됨 (기존과 동일)
   - 필터/검색 기능 정상 동작

3. **이력서 페이지**
   - `http://localhost:4321/resume/` 접속
   - 경력 정보, 기술스택, 학력 정상 표시
   - 페이지 레이아웃 깨지지 않음

4. **파일 구조 확인**
   - `posts/` 디렉토리가 프로젝트 루트에 존재
   - `src/content/posts/` 디렉토리 삭제됨
   - `src/config/resume.ts` 존재
   - `src/data/` 디렉토리 삭제됨

### 엣지 케이스

- 포스트 파일 이름에 특수문자/한글 포함 → 정상 로드
- 포스트 카테고리 (DataPlatform, dev) 필터 → 정상 동작

---

## 이번 사이클에서 하지 않는 것

- 포스트 frontmatter 스키마 변경 (기존 필드 유지)
- 포스트 내용(마크다운) 수정
- 다른 경로에서 `resume.ts`를 import하는 파일들 찾아 수정 (검색 후 필요하면 수정)
- TypeScript path alias 추가 (`tsconfig.json` 수정)
- `.gitignore` 수정

---

## 참고

- Astro Content Collections 공식 문서: v5 Content Layer API
- `src/content.config.ts`는 Astro v5 권장 위치 (v4의 `src/content/config.ts` 아님)
- 기존 `src/content/` 디렉토리는 config 파일만 남아있으므로 유지
