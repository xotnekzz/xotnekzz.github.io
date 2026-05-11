/**
 * 콘텐츠 공개/비공개(draft) 제어 유틸.
 *
 * 규칙:
 * - 기본값 `draft: false` → 공개.
 * - `draft: true` 항목은 프로덕션 빌드에서 목록/상세/태그 집계에서 제외한다.
 * - 개발 모드(`import.meta.env.DEV`)에서는 draft 항목도 노출해 작성 중 미리보기를 허용한다.
 * - 단, RSS 는 어떤 환경에서도 draft 를 제외한다 (`isPublished` 사용).
 */

type DraftEntry = { data: { draft?: boolean } };

/**
 * 페이지/목록 필터에 사용. DEV 에서는 항상 true, 프로덕션에서는 draft 만 false.
 */
export function isVisible<T extends DraftEntry>(entry: T): boolean {
  if (import.meta.env.DEV) return true;
  return entry.data.draft !== true;
}

/**
 * RSS 등 "항상 프로덕션 피드"용 필터. DEV 여부와 무관하게 draft 제외.
 */
export function isPublished<T extends DraftEntry>(entry: T): boolean {
  return entry.data.draft !== true;
}

/**
 * 배지 렌더 판별용. 환경과 무관하게 원본 플래그만 본다.
 */
export function isDraft<T extends DraftEntry>(entry: T): boolean {
  return entry.data.draft === true;
}

/**
 * 컬렉션 배열을 `isVisible` 기준으로 필터링.
 */
export function filterVisible<T extends DraftEntry>(entries: T[]): T[] {
  return entries.filter(isVisible);
}
