# harness

**CLI-독립 에이전트 하네스 스켈레톤.** 한 번의 `harness init`으로 파일 기반 컨텍스트
시스템, 3-에이전트 파이프라인, 가드레일, 엔트로피 GC를 어떤 프로젝트에나 이식한다.
Claude Code · Codex · Gemini CLI 사이를 자유롭게 오간다.

> 에이전트 협업을 **채팅 로그**가 아니라 **git-versioned 마크다운**으로 관리하려는
> 팀을 위한 보일러플레이트.

---

## 왜 하네스인가

대부분의 에이전트 워크플로는 세션에 갇힌다 — 채팅을 닫으면 컨텍스트가 사라지고,
CLI를 바꾸면 지시를 다시 써야 한다. 하네스는 **에이전트가 읽고 쓰는 모든 것을
레포에 파일로 둔다**:

- 계획·진행 상황·평가 결과 → `.harness/tracks/<트랙>/`
- 제품 스펙·아키텍처 결정 → `docs/`
- 사용자 선호·재발 방지 교정 → `memory/`

훅과 린터가 **기계적으로 강제**한다 — "AGENTS.md 100줄 이하", "레이어 위반 금지"
같은 규칙을 문장으로 적지 않고 스크립트로 차단한다.

---

## 빠른 시작

### 1. 스켈레톤 설치 (1회)

```bash
git clone https://github.com/xotnekzz/harness.git ~/harness
bash ~/harness/install.sh --shell-init
source ~/.zshrc
```

확인:
```bash
harness help
harness where   # 스켈레톤 경로
```

### 2. 프로젝트에 이식 (한 줄)

```bash
cd ~/work/my-project
harness init
```

자동 감지:
- 프로젝트 이름 = 디렉터리명
- 모드 = 빈 디렉터리면 `pristine`, 기존 `AGENTS.md`/`src/` 있으면 `adopt`
- 사용할 CLI 어댑터 (claude / codex / gemini, 복수 선택 가능) — 감지된 CLI 기본 on

```
[harness] 사용할 에이전트 CLI를 선택하세요 (복수 선택 가능):
  1) claude  [detected]
  2) codex
  3) gemini  [detected]
Enter = 감지된 CLI / 예: "1,3" / 없음: "none"
> _
```

계획 프리뷰 후 `[Y/n]`. 생략: `-y` (감지된 CLI 사용) 또는 `--cli claude,codex`.

### 3. 첫 트랙 실행

에이전트 CLI에서:

```
/setup                              # 최초 1회: 제품/스택/워크플로 질문
/new-track 사용자 로그인 기능         # 스펙 + 플랜 생성
/implement user-login               # 체크박스 소화
```

또는 한 방에:
```
/autopilot 로그인 폼에 OTP 추가
```

자세한 단계: [docs/USAGE.md](docs/USAGE.md)

---

## 핵심 개념

- **파일이 곧 컨텍스트** — `.harness/` (기계), `docs/` (팀 공유), `memory/` (개인).
  파일 지도: [HARNESS_MAP.md](HARNESS_MAP.md)
- **3-에이전트 파이프라인** — Planner → Implementer → Evaluator. 수동(`/new-track`
  → 리뷰 → `/implement`) 또는 자동(`/autopilot`). 상세: [AGENTS.md §4](AGENTS.md)
- **가드레일(기계적 강제)** — 레이어 순서·문서 드리프트·AGENTS.md 크기·메모리
  스키마를 린터/훅으로 차단. 상세: [AGENTS.md §5](AGENTS.md)
- **엔트로피 GC** — `doc-gardener`가 주간 실행, 고아 문서·깨진 링크 청소
  ([.harness/agents/doc-gardener.md](.harness/agents/doc-gardener.md))

---

## 핵심 원칙

1. **컨텍스트는 파일이다** — 채팅 로그가 아니라 git-versioned 마크다운
2. **AGENTS.md는 목차** — 백과사전 아님 (≤100줄, 린터가 강제)
3. **점진 공개** — 에이전트는 필요한 순간에 필요한 문서만 읽는다
4. **모델 독립** — 지시문에 CLI/모델명이 박히지 않는다
5. **기계적 강제 우선** — 문장 규칙보다 린터/훅
6. **엔트로피 GC** — 드리프트를 자동 청소

배경: [docs/design-docs/core-beliefs.md](docs/design-docs/core-beliefs.md)

---

## CLI 호환성

Claude Code · Codex · Gemini CLI 지원. 어댑터 한 개로 새 CLI 추가 가능.
상세 매트릭스·훅 fallback·어댑터 규약: [docs/CLI_COMPAT.md](docs/CLI_COMPAT.md)

---

## `harness` CLI

```
harness init [옵션]     현재 디렉터리에 하네스 세팅 (스마트 디폴트)
harness sync            스켈레톤 변경 반영 + 활성 CLI 어댑터 재컴파일
harness upgrade         git pull + sync
harness adapt <cli>     특정 CLI 어댑터만 재컴파일
harness lint            모든 린터 실행
harness gc [--apply]    doc-gardener 스캔 (기본 dry-run)
harness run <트랙>      /autopilot 래퍼
harness where           스켈레톤 경로
harness help
```

---

## 요구사항

- macOS / Linux (Windows는 WSL 권장)
- `python3` ≥ 3.10, `bash`, `git`
- (선택) `pre-commit` — `pipx install pre-commit` 또는 `brew install pre-commit`
- (선택) `gh` CLI — doc-gardener가 이슈/PR을 열 때
- 에이전트 CLI: Claude Code / Codex / Gemini CLI 중 하나

---

## 기여

린터·어댑터·에이전트·스킬 추가 위치와 규약: [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md)

---

## 더 읽어보기

- [docs/USAGE.md](docs/USAGE.md) — 사용 매뉴얼 (5분 세팅 → 10분 첫 트랙, 외부 스킬 추가)
- [AGENTS.md](AGENTS.md) — 에이전트 목차 (점진 공개의 출발점)
- [ARCHITECTURE.md](ARCHITECTURE.md) — 레이어 규칙
- [HARNESS_MAP.md](HARNESS_MAP.md) — "이 파일은 누구 영역인가" 지도
- [docs/CLI_COMPAT.md](docs/CLI_COMPAT.md) — CLI 호환성·어댑터
- [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) — 기여 규약
- [docs/design-docs/core-beliefs.md](docs/design-docs/core-beliefs.md) — 설계 근거

---

## 라이선스

MIT — [LICENSE](LICENSE)
