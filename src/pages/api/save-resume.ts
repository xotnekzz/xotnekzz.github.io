import type { APIRoute } from 'astro';
import { writeFileSync, readFileSync, existsSync } from 'fs';
import { resolve } from 'path';
import { fileURLToPath } from 'url';
import { dirname } from 'path';

// 현재 파일 기반으로 프로젝트 루트 찾기
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
// /src/pages/api/save-resume.ts → /src/pages → /src → /
const PROJECT_ROOT = resolve(__dirname, '../../../');
const RESUME_FILE = resolve(PROJECT_ROOT, 'src/data/resume.ts');

console.log('[API save-resume] PROJECT_ROOT:', PROJECT_ROOT);
console.log('[API save-resume] RESUME_FILE:', RESUME_FILE);

export const POST: APIRoute = async ({ request }) => {
  // 개발 모드 확인
  if (!import.meta.env.DEV) {
    return new Response(JSON.stringify({ error: 'Only available in dev mode' }), { status: 403 });
  }

  try {
    let parsedData;
    try {
      parsedData = await request.json();
    } catch (jsonError) {
      console.error('[API save-resume] JSON parse error:', jsonError);
      return new Response(
        JSON.stringify({
          error: 'Invalid JSON',
          details: jsonError instanceof Error ? jsonError.message : 'Failed to parse request body',
        }),
        {
          status: 400,
          headers: { 'Content-Type': 'application/json' },
        },
      );
    }

    const { edits } = parsedData;

    if (!edits || typeof edits !== 'object') {
      console.error('[API save-resume] Invalid edits data:', edits);
      return new Response(
        JSON.stringify({
          error: 'Invalid edits data',
          details: `edits must be an object, got: ${typeof edits}`,
        }),
        {
          status: 400,
          headers: { 'Content-Type': 'application/json' },
        },
      );
    }

    console.log('[API save-resume] Received edits:', edits);

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
    console.log('[API save-resume] Saving to:', RESUME_FILE);
    console.log('[API save-resume] File exists before:', existsSync(RESUME_FILE));

    writeFileSync(RESUME_FILE, resumeContent, 'utf-8');

    console.log('[API save-resume] File exists after:', existsSync(RESUME_FILE));
    console.log('[API save-resume] Successfully saved', Object.keys(edits).length, 'edits');

    return new Response(
      JSON.stringify({
        success: true,
        message: 'resume.ts updated successfully',
        edits: Object.keys(edits).length,
        savedTo: RESUME_FILE,
      }),
      {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      },
    );
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    const errorStack = error instanceof Error ? error.stack : '';

    console.error('[API save-resume] Error:', errorMessage);
    console.error('[API save-resume] Stack:', errorStack);

    return new Response(
      JSON.stringify({
        error: 'Failed to save resume',
        details: errorMessage,
        stack: errorStack,
      }),
      {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      },
    );
  }
};
