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
    Object.entries(edits).forEach(([fieldPath, newValue]) => {
      const value = (newValue as string).replace(/'/g, "\\'");

      // fieldPath 형식: "personal.name", "personal.email", "summary", 등
      if (fieldPath === 'personal.name') {
        resumeContent = resumeContent.replace(
          /(\s*name:\s*')[^']*'/,
          `$1${value}'`,
        );
      } else if (fieldPath === 'personal.title') {
        resumeContent = resumeContent.replace(
          /(\s*title:\s*')[^']*'/,
          `$1${value}'`,
        );
      } else if (fieldPath === 'personal.email') {
        resumeContent = resumeContent.replace(
          /(\s*email:\s*')[^']*'/,
          `$1${value}'`,
        );
      } else if (fieldPath === 'personal.github') {
        resumeContent = resumeContent.replace(
          /(\s*github:\s*')[^']*'/,
          `$1${value}'`,
        );
      } else if (fieldPath === 'summary') {
        // summary 필드: 여러 줄 문자열을 한 줄로 통합
        const escapedValue = value.replace(/\n/g, ' ').replace(/'/g, "\\'");
        // summary = '...' + '...' + '...' 패턴을 찾아서 한 줄로 변경
        resumeContent = resumeContent.replace(
          /export const summary\s*=[\s\S]*?;/,
          `export const summary =\n  '${escapedValue}';`,
        );
      } else {
        // 다른 필드들은 현재 미지원
        console.log(`Unsupported field: ${fieldPath}`);
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
