# 설계 컨벤션

스택 독립 스타일 규칙. 초기화 시 스택별 섹션은 따로 채운다.

## 네이밍

- 파일/모듈: `snake_case.py`, `kebab-case.ts`, `snake_case.go`
- 클래스/타입: `PascalCase`
- 함수/변수: `snake_case` (Python/Go), `camelCase` (TS/JS)
- 상수: `UPPER_SNAKE_CASE`

## 공개 API

- 타입은 `types` 레이어에서 정의; 모듈 `__init__` / `index.ts`로 재-export
- 서비스에서 원시값을 반환하지 않음; 도메인 타입 사용

## 에러

- 경계에서 빠르게 실패; 외부 입력 검증
- 에러를 무음으로 삼키지 않음 — 전파하거나 구조화 컨텍스트와 함께 로그
