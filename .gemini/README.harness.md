# Harness × Gemini CLI

이 디렉터리는 하네스가 Gemini CLI용으로 컴파일한 결과입니다.

## 중요: 네이티브 슬래시 커맨드는 아직 미지원

Gemini CLI의 네이티브 커스텀 커맨드는 TOML 형식인 반면 하네스는 마크다운 기반입니다.
v1 어댑터는 파일을 심볼릭 링크만 합니다. 슬래시 커맨드로 직접 호출되지 않습니다.

## 사용 방법 (프롬프트 기반)

Gemini CLI에 다음과 같이 입력하세요:

> `.gemini/commands/new-track.md` 파일을 읽고 인자 `"사용자 로그인"`으로 지시대로 실행해줘.

`GEMINI.md`(루트)가 에이전트 목차와 워크플로 규칙을 이미 로드합니다.

## 참고

- 에이전트: `.gemini/agents/*.md`
- 커맨드: `.gemini/commands/*.md`
- 원본: `.harness/commands/`, `.harness/agents/`
