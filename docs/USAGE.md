# 사용 매뉴얼

이 하네스를 처음 쓰는 사람을 위한 단계별 가이드. **5분 세팅 → 10분 첫 트랙 실행**
이 목표.

---

## 0. 사전 준비

- macOS / Linux (Windows는 WSL 권장)
- `python3` ≥ 3.10, `bash`, `git`
- (선택) `pre-commit` — `pipx install pre-commit` 또는 `brew install pre-commit`
- (선택) `gh` CLI — doc-gardener 워크플로가 이슈/PR을 열 때 사용
- 에이전트 CLI 중 하나: Claude Code / Codex / Gemini CLI

---

## 1. 설치

### 1-1. 스켈레톤 받기 + 전역 명령 등록 (1회)

```bash
git clone <이-레포-URL> ~/harness
bash ~/harness/install.sh --shell-init
source ~/.zshrc   # 또는 새 셸 열기
```

확인:
```bash
harness help
harness where    # 스켈레톤 경로 출력
```

### 1-2. 프로젝트에 이식 — **한 줄**

```bash
cd ~/work/my-project
harness init
```

끝. 다음이 자동 감지된다:
- 프로젝트 이름 = 현재 디렉터리 이름
- 모드 = 빈 디렉터리면 `pristine`, 기존 `AGENTS.md`/`src/` 있으면 `adopt`
- 소스 = `harness` 명령 위치

또한 **사용할 CLI 어댑터를 묻는 프롬프트**가 뜬다 (claude / codex / gemini, 복수 선택
가능). `command -v`로 감지된 CLI는 기본 on. Enter로 감지 결과 수락, 숫자·이름 섞어
입력(`1,3` 또는 `claude gemini`), `none`으로 아무것도 안 쓰기도 가능.

계획이 출력되고 `[Y/n]` 확인 후 진행. 생략은 `--yes` 또는 `--cli <list>`.

### 1-3. 자주 쓰는 변형

```bash
harness init --dry-run              # 변경 없이 프리뷰
harness init -y                     # 확인 프롬프트 건너뛰기 (감지된 CLI 사용)
harness init --cli claude,codex -y  # 어댑터 명시 + 비대화식
harness init --cli none -y          # 어댑터 없이 엔진만 설치
harness init --mode adopt           # 모드 강제
harness init --lang python          # 언어 힌트
```

전체 옵션: `harness init --help`

### 1-4. 설치 확인

```bash
harness lint
```

### 1-5. (선택) pre-commit 연결

```bash
pre-commit install
```
이제 커밋 시 레이어/사이즈/메모리 린터가 자동으로 돈다.

### 1-6. 전역 등록 없이 1회성 사용

```bash
bash ~/harness/bin/harness init
```

### 1-7. 스켈레톤 업데이트 / 로컬 동기화

이미 설치된 프로젝트에 스켈레톤 변경(새 커맨드, 에이전트 프런트매터 등)을 반영:

```bash
harness sync        # .harness/ 동기화 + 활성 CLI 어댑터 전부 재컴파일
```

스켈레톤 자체도 git pull하면:
```bash
harness upgrade     # git pull + sync
```

### 1-8. 슬래시 커맨드가 Claude Code에 안 나올 때

`harness sync` 한 번이면 대부분 해결. 이미 최신인데 수동 재컴파일만 필요하면:

```bash
harness adapt claude
```

이 명령이:
- `.harness/commands/*.md` → `.claude/commands/*.md` 심볼릭 링크
- `.harness/agents/*.md` → `.claude/agents/*.md` 심볼릭 링크
- `.claude/settings.json`에 4개 훅 등록 (기존 파일 있으면 건드리지 않음)

이후 Claude Code를 **재시작**하면 `/new-track`, `/implement`, `/setup`,
`/lint-harness`, `/gc`가 노출된다.

기존 `.claude/settings.json`이 있었다면 훅을 수동 병합:
```bash
cat .harness/adapters/claude/settings.example.json
```

---

## 2. 첫 세팅 — `/setup`

에이전트 CLI에서 다음을 실행(또는 `.harness/commands/setup.md`를 직접 에이전트에
읽힌다):

```
/setup
```

에이전트가 3개 질문을 던진다:

1. 이 제품은 뭘 하나? 누가 쓰나?
2. 스택은? (언어, 프레임워크, 배포 타깃)
3. 어떻게 출시하나? (브랜치 전략, 리뷰, 주기)

답변 후 다음 3개 문서가 생성된다:
- `docs/product/overview.md`
- `docs/tech-stack.md`
- `docs/workflow.md`

> 💡 **CLI가 슬래시 커맨드를 모를 때**: 사람이 프롬프트로
> "`.harness/commands/setup.md` 파일을 읽고 지시대로 해줘"라고 말하면 된다.
> 워크플로가 **파일 기반**이므로 CLI 종류와 무관하다.

---

## 3. 첫 트랙 실행 — `/new-track` → `/implement`

### 3-1. 트랙 생성

```
/new-track 사용자 로그인 기능
```

에이전트가 수행:
1. 슬러그화: `사용자-로그인-기능` → (예) `user-login`
2. `docs/product-specs/user-login.md` — 스펙 (왜 / 비목표 / 수용 기준)
3. `.harness/tracks/active/user-login/plan.md` — 체크박스 기반 플랜
4. `.harness/tracks/active/user-login/sprint-contract.md` — 성공 기준 / Evaluator 체크

이 시점에서 **사람이 spec / plan을 리뷰**한다. 수정할 부분은 파일을 직접 편집.

### 3-2. 구현

```
/implement user-login
```

에이전트(Implementer 역할)가 plan의 체크박스를 하나씩 소화:
- 미체크 박스 수행 → verify 라인 실행 → 박스 체크 → `progress.md`에 기록
- 블로커 시 `progress.md`의 `### Blocked`에 기록하고 정지

모든 박스 완료 시 Evaluator가 `evaluation.md` 작성:
- `APPROVED` → `lessons-learned` 스킬 실행 → 트랙이 `completed/`로 이동
- `CHANGES_REQUESTED` → 실패 항목만 재실행

### 3-2-B. 자동 루프 — `/autopilot` (Ralph-style)

사람 리뷰 없이 **계획 → 개발 → 검증/테스트 → 보고**까지 자동 반복:

```
/autopilot 로그인 폼에 OTP 추가
```

또는 기존 트랙을 루프로 재개:
```
/autopilot user-login --max-iter 3
```

Evaluator가 `CHANGES_REQUESTED`를 내면 실패 항목을 `plan.md`에 새 체크박스로
**append**하고 Implementer를 다시 돌린다. APPROVED 또는 max-iter 도달 시 종료하며
`.harness/tracks/completed/<track>/report.md`(또는 active의 report.md)를 남긴다.

안전장치:
- `max-iter` (기본 5, `.harness/config.yaml`의 `loop.max_iter`)
- 회전문 수정 감지 (동일 파일 5회+ 연속 수정 시 `ABORTED_THRASHING`)
- 테스트 회귀 시 `ABORTED_REGRESSION`
- `--fail-fast` / `--no-plan-edit` / `--report-only` 플래그

`/implement`와의 차이: **사람 리뷰 지점 제거 + 자동 재시도 + `report.md`**. CI 친화.
사람 감독이 필요하면 `/new-track`+`/implement`를 쓰세요.

CLI 래퍼:
```bash
harness run user-login --max-iter 3
```

### 3-3. 중간 종료 / 모델 교체

세션 종료 시 `stop` 훅이 `handoff.md`를 자동 생성. 다른 CLI에서 다음만 프롬프트에
넣으면 재개 가능:

```
.harness/tracks/active/user-login/ 의 handoff.md, plan.md, sprint-contract.md를
읽고 다음 미체크 박스부터 이어가줘.
```

---

## 4. 일상 운영

### 4-1. 하네스 건강 검사

```
/lint-harness
```
또는 직접:
```bash
python3 .harness/linters/agents_md_size.py
python3 .harness/linters/memory_schema.py
python3 .harness/linters/arch_layers.py --dry-run
python3 .harness/linters/doc_gardener_scan.py
```

### 4-2. 수동 GC

```
/gc           # dry-run (기본)
/gc --apply   # 실제 PR 생성 (주당 5개 캡)
```

### 4-3. 메모리 관리

- **저장**: 에이전트에 "이 사실을 기억해줘" → `memory/<type>_<slug>.md` 생성
- **형식**: 프런트매터(`name`/`description`/`type`) + 본문(feedback/project는 Why/How to apply 구조)
- **색인 유지**: `memory/MEMORY.md`에 한 줄 링크 추가 (린터가 누락 감지)

타입 선택:
| 저장 내용 | 타입 | 파일명 |
|---|---|---|
| 사용자 역할/선호 | `user` | `user_*.md` |
| 재발 방지 교정 | `feedback` | `feedback_*.md` |
| 장기 프로젝트 상태 | `project` | `project_*.md` |
| 외부 시스템 포인터 | `reference` | `reference_*.md` |

### 4-4. 문서 업데이트 규칙

- `AGENTS.md`는 **목차**만. 100줄 초과 시 `docs/`로 추출 (린터가 차단)
- `docs/` 신규 문서는 해당 `index.md`에 링크 추가 (안 하면 doc-gardener가 고아로 감지)
- 도메인별 품질 등급이 바뀌면 `docs/QUALITY_SCORE.md` 갱신

### 4-5. 외부 스킬 추가

외부 저장소에서 가져온 스킬을 하네스에 포함하는 방법.

**프로젝트 전용**:
```bash
# 예: 외부 스킬 클론 후 프로젝트 스킬로 복사
git clone <url> /tmp/some-skill
cp -r /tmp/some-skill .harness/skills/<name>/
# SKILL.md에 frontmatter(name, description) 확인
```

**사용자 전역 (모든 프로젝트 공유)**:
```bash
cp -r <skill-dir> ~/.claude/skills/<name>/
```

**체크리스트**:
- `SKILL.md` 프런트매터가 규격(name, description, trigger)에 맞는지
- 의존 CLI/MCP는 `.harness/config.yaml`·`.harness/mcp/`에 등록
- 가드레일 린터와 충돌 없는지 → `harness lint`
- 프로젝트 스킬이면 `AGENTS.md` 또는 관련 MOC에 한 줄 등록

에이전트 추가는 [CONTRIBUTING.md](CONTRIBUTING.md) 참조.

---

## 5. CLI별 연결 방법

### Claude Code

- `AGENTS.md`와 동일 내용의 `CLAUDE.md`가 이미 링크됨
- 훅을 쓰려면 `~/.claude/settings.json`에 추가:
  ```json
  {
    "hooks": {
      "pre-tool-use":      [{"command": ".harness/hooks/pre-tool-use/enforce-arch.sh"}],
      "post-tool-use":     [{"command": ".harness/hooks/post-tool-use/capture-lesson.sh"}],
      "user-prompt-submit":[{"command": ".harness/hooks/user-prompt-submit/inject-moc.sh"}],
      "stop":              [{"command": ".harness/hooks/stop/handoff.sh"}]
    }
  }
  ```
- 슬래시 커맨드는 `.claude/commands/`로 심볼릭 링크하거나 `.harness/adapters/claude/compile.sh`(추후 구현) 사용

### Codex CLI

- `AGENTS.md`를 자동 로드
- `harness init`에서 선택(또는 `harness adapt codex`)하면 `.codex/commands/` 및
  `.codex/agents/`가 `.harness/`의 심볼릭 링크로 만들어짐
- 훅 미지원 → 선택 사항으로 `.harness/daemon/watcher.py` fallback:
  ```bash
  python3 .harness/daemon/watcher.py --interval 60 &
  ```
- 커맨드는 프롬프트에서 "`.codex/commands/<name>.md`를 읽고 지시대로 실행"으로 호출

### Gemini CLI

- `GEMINI.md`가 `AGENTS.md` 미러
- `harness init`에서 선택(또는 `harness adapt gemini`)하면 `.gemini/commands/`와
  `.gemini/agents/`가 생성됨 + `.gemini/README.harness.md` 사용법 메모
- Gemini 네이티브 커스텀 커맨드는 TOML이라 v1에선 슬래시 호출 대신 프롬프트 기반
  호출: "`.gemini/commands/<name>.md`를 읽고 실행"

---

## 6. 트러블슈팅

| 증상 | 원인 / 해결 |
|---|---|
| `error: AGENTS.md: N lines > 100` | 목차 초과. 섹션을 `docs/design-docs/<topic>.md`로 분리 후 AGENTS.md에는 링크만 남김 |
| `error: <file>: missing frontmatter` | `memory/*.md`에 `---`로 감싼 `name/description/type` 누락 |
| `error: layer 'types' imports from higher layer 'ui'` | types 레이어는 ui를 import할 수 없음. 타깃을 types 쪽으로 내리거나 인터페이스 반전 |
| `warn: ... not found in code` (doc_freshness) | 경고일 뿐 차단 아님. 코드 심볼 개명/삭제 후 문서 미갱신 시 발생 |
| adopt 모드인데 사이드카가 안 보임 | 원본이 존재해야 사이드카 생성됨. `ls *.harness.md` 확인 |
| init.sh가 "not in subpath" 에러 | `--source`를 하네스 스켈레톤 **루트**(`.harness/`의 부모)로 지정했는지 확인 |

---

## 7. 업데이트 (스켈레톤 갱신 반영)

```bash
cd ~/harness && git pull
cd ~/work/my-project
bash ~/harness/.harness/templates/init.sh \
  --project-name my-project --source ~/harness --mode adopt --dry-run
```
`--dry-run`으로 변경 사항 확인 후 `--mode adopt`로 실행. 매니페스트(`.harness/.manifest`)
로 사용자 수정 파일은 보존.

---

## 8. 더 읽어보기

- [AGENTS.md](../AGENTS.md) — 목차 자체
- [core-beliefs.md](design-docs/core-beliefs.md) — 왜 이렇게 설계했나
- [ARCHITECTURE.md](../ARCHITECTURE.md) — 레이어 규칙
- `.harness/agents/*.md` — 각 에이전트의 프롬프트
