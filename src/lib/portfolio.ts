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
 * 포트폴리오 파일 경로를 기반으로 URL-safe한 슬러그 생성
 * 카테고리명 + 영문/숫자 부분 사용
 *
 * 예: "../content/portfolio/AIEnginerring/사내 통합 AI 에이전트 플랫폼 구축.md" -> "aienginerring-ai"
 * 예: "../content/portfolio/DataEngineering/Columstore To StarRocks 전환.md" -> "dataengineering-columstore-starrocks"
 * 예: "../content/portfolio/AIEnginerring/AdTech AI Agent (Gemini CLI).md" -> "aienginerring-adtech-ai-agent"
 */
export function generateSlug(filePath: string): string {
  // portfolio 폴더 이후의 부분만 추출
  // 예: "../content/portfolio/AIEnginerring/파일명.md" -> "AIEnginerring/파일명.md"
  const portfolioMatch = filePath.match(/portfolio\/(.+)$/);
  if (!portfolioMatch) return 'untitled';

  const restPath = portfolioMatch[1]; // "AIEnginerring/파일명.md"
  const parts = restPath.split('/');

  if (parts.length < 2) return 'untitled';

  const category = parts[0].toLowerCase();
  const filename = parts[1].replace(/\.md$/, '');

  // 파일명에서 영문, 숫자, 공백만 추출
  let titleSlug = filename
    // 괄호와 그 안의 내용 제거
    .replace(/\s*\([^)]*\)\s*/g, ' ')
    // 한글 제거
    .replace(/[\uAC00-\uD7AF]/g, ' ')
    // 특수문자 제거 (공백, 영문, 숫자, 하이픈만 유지)
    .replace(/[^\w\s\-]/g, ' ')
    // 연속된 공백을 단일 공백으로
    .replace(/\s+/g, ' ')
    // 양쪽 공백 제거
    .trim()
    // 공백으로 분리된 단어들을 하이픈으로 결합
    .split(/\s+/)
    .filter((word) => word.length > 0)
    .map((word) => word.toLowerCase())
    .join('-')
    // 연속된 하이픈 제거
    .replace(/-+/g, '-')
    // 시작/끝 하이픈 제거
    .replace(/^-+|-+$/g, '');

  // 카테고리 + 파일명 조합 (영문 부분이 없으면 카테고리만)
  const slug = titleSlug ? `${category}-${titleSlug}` : category;

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
