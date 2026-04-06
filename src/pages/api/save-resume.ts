import type { APIRoute } from 'astro';
import { writeFileSync, readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const RESUME_FILE = join(__dirname, '../../../src/data/resume.ts');

export const POST: APIRoute = async ({ request }) => {
  // 개발 모드 확인
  if (!import.meta.env.DEV) {
    return new Response(JSON.stringify({ error: 'Only available in dev mode' }), { status: 403 });
  }

  try {
    const { edits } = await request.json();

    if (!edits || typeof edits !== 'object') {
      return new Response(JSON.stringify({ error: 'Invalid edits data' }), { status: 400 });
    }

    // 현재 resume.ts 파일 읽기
    let resumeContent = readFileSync(RESUME_FILE, 'utf-8');

    // 각 수정사항을 파일에 반영
    Object.entries(edits).forEach(([selector, newValue]) => {
      const value = newValue as string;

      // selector를 기반으로 정규식으로 값 찾기
      if (selector.includes('personal')) {
        // personal.name, personal.title 등
        const field = selector.split('.')[1] || selector.split("'")[1];
        const pattern = new RegExp(`(${field}\\s*:\\s*['\"])[^'"]*(['"])`, 'g');
        resumeContent = resumeContent.replace(pattern, `$1${value.replace(/"/g, '\\"')}$2`);
      } else if (selector.includes('summary') || selector.includes('Professional Summary')) {
        // summary 필드
        const pattern = /export const summary\s*=\s*(['"])[\s\S]*?\1(?=\s*;)/;
        resumeContent = resumeContent.replace(
          pattern,
          `export const summary =
  '${value.replace(/'/g, "\\'")}'`,
        );
      } else if (selector.includes('h1') || selector.includes('h2') || selector.includes('h3')) {
        // 다른 텍스트들은 정확한 매핑이 어려우므로 user에게 알림
        console.log(`Modified: ${selector} = "${value}"`);
      }
    });

    // 파일 저장
    writeFileSync(RESUME_FILE, resumeContent, 'utf-8');

    return new Response(
      JSON.stringify({
        success: true,
        message: 'resume.ts updated successfully',
        edits: Object.keys(edits).length,
      }),
      {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      },
    );
  } catch (error) {
    console.error('Error saving resume:', error);
    return new Response(
      JSON.stringify({
        error: 'Failed to save resume',
        details: error instanceof Error ? error.message : String(error),
      }),
      { status: 500 },
    );
  }
};
