---
track: content-visibility
---

## 핵심 학습

- **단일 유틸 집중화**: `src/lib/content-visibility.ts` 하나에 `isVisible / filterVisible / isDraft / isPublished`를 모아 7개 페이지·3개 컴포넌트가 재사용. 중복 조건문 제거로 회귀 위험 최소화.
- **DEV/PROD 분기 규칙 명확화**: 페이지/목록/상세는 DEV에서 draft 노출(+배지), RSS만 예외적으로 DEV에서도 draft 제외. 프로덕션 피드 오염을 원천 차단하면서도 로컬 작성 경험 보존.
- **기본값 = 공개**: `draft: z.boolean().default(false)` — frontmatter 미지정 기존 글은 모두 공개로 유지되어 마이그레이션 불필요.
- **Sitemap은 자동 처리**: `getStaticPaths`에서 draft 제외만으로 sitemap integration이 자동으로 누락. astro.config 수정 불필요.
- **검증 전략**: `grep -r "draft-sample" dist/`, `grep "DRAFT" dist/` 같은 빌드 산출물 grep은 정적 사이트에서 누출 테스트의 값싸고 확실한 수단.

## 다음에 활용할 패턴

1. 콘텐츠 스키마 필드 추가 시: schema 수정 → 유틸 함수화 → 페이지 루프에서 `.filter(util)` 삽입 → 샘플 파일로 grep 검증의 4단계.
2. DEV 가드(`import.meta.env.DEV`)가 필요한 UI는 컴포넌트 수준에서 분기하고, SSR 페이지에서는 props로 내려 공유.
