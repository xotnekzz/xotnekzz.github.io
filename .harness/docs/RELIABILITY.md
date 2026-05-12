# 신뢰성

## 로깅

- 구조화 로깅만 사용 (JSON-ish key/value). 프로덕션 경로에 `print` / `console.log` 금지
- 포함 필드: `event`, `correlation_id`, `layer`, 관련 도메인 ID
- `.harness/linters/`로 강제 (언어 플러그인 TODO)

## 관찰성 훅

- 서비스 레이어 경계에서 메트릭 방출
- 이상을 최초 감지한 경계에서 로그; 재-raise 시 이중 로그 금지

## 실패 모드

- **재시도 가능**(네트워크, 5xx)과 **종결적**(검증, 4xx) 구분
- 종결적 실패는 사용자에게 즉시 표면화
