import type { Portfolio } from './types';

/**
 * 파일 경로에서 카테고리명 추출
 * 예: "src/content/portfolio/DataEngineering/file.md" -> "DataEngineering"
 */
export function extractCategory(filePath: string): string {
  const match = filePath.match(/portfolio\/([^/]+)\//);
  return match ? match[1] : '기타';
}

/**
 * 파일 ID(경로) 또는 제목을 기반으로 URL-safe한 슬러그 생성
 * 파일명에서 확장자를 제거하고 정규화
 * 한글을 공백으로 대체하고, 남은 영문/숫자를 정규화
 * 예: "AIEnginerring/사내 통합 AI 에이전트 플랫폼 구축.md" -> "ai"
 * 예: "AIEnginerring/AdTech AI Agent (Gemini CLI).md" -> "adtech-ai-agent-gemini-cli"
 * 예: "AI를 활용한 파이썬 모듈 문서 자동화하기.md" -> "ai-python"
 */
export function generateSlug(titleOrId: string): string {
  // 파일 경로인 경우 파일명만 추출
  let slug = titleOrId.includes('/')
    ? titleOrId.split('/').pop() || titleOrId
    : titleOrId;

  // .md 확장자 제거
  slug = slug.replace(/\.md$/, '');

  slug = slug
    // 괄호와 그 안의 내용 제거
    .replace(/\s*\([^)]*\)\s*/g, ' ')
    // 한글을 공백으로 대체
    .replace(/[\uAC00-\uD7AF]/g, ' ')
    // 한글이 아닌 문자 중 영문, 숫자, 공백, 하이픈만 남김
    .replace(/[^\w\s\-]/g, '')
    // 연속된 공백을 단일 공백으로
    .replace(/\s+/g, ' ')
    // 양쪽 공백 제거
    .trim()
    // 공백으로 분리된 단어들을 하이픈으로 결합
    .split(/\s+/)
    .filter((word) => word.length > 0)
    .join('-')
    // 소문자로 변환
    .toLowerCase()
    // 연속된 하이픈 제거
    .replace(/-+/g, '-')
    // 시작/끝 하이픈 제거
    .replace(/^-+|-+$/g, '');

  // 빈 문자열인 경우 기본값 반환
  return slug || 'untitled';
}

/**
 * 포트폴리오 항목을 날짜 기준 내림차순(최신순) 정렬
 */
export function sortByDateDesc(items: Portfolio[]): Portfolio[] {
  return [...items].sort((a, b) => {
    const dateA = new Date(a.date).valueOf();
    const dateB = new Date(b.date).valueOf();
    return dateB - dateA;
  });
}

/**
 * 포트폴리오 항목을 카테고리별로 그룹화
 * 각 카테고리 내에서는 날짜 내림차순으로 정렬
 */
export function groupByCategory(
  items: Portfolio[]
): Record<string, Portfolio[]> {
  const grouped: Record<string, Portfolio[]> = {};

  items.forEach((item) => {
    const category = item.category || '기타';
    if (!grouped[category]) {
      grouped[category] = [];
    }
    grouped[category].push(item);
  });

  // 각 카테고리 내에서 날짜 기준 내림차순 정렬
  Object.keys(grouped).forEach((category) => {
    grouped[category] = sortByDateDesc(grouped[category]);
  });

  return grouped;
}

/**
 * 날짜를 "YYYY년 M월" 형식으로 포맷
 */
export function formatDateKorean(dateString: string): string {
  const date = new Date(dateString);
  const year = date.getFullYear();
  const month = date.getMonth() + 1;
  return `${year}년 ${month}월`;
}
