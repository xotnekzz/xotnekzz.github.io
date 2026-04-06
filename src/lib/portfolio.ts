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
