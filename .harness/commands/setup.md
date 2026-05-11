---
command: /setup
description: 프로젝트 컨텍스트 초기화 (최초 1회) — product/tech-stack/workflow 문서를 대화형으로 생성.
stage: one-time
---

# /setup

프로젝트 컨텍스트 문서 초기화. 대화형.

## 생성물

- `docs/product/overview.md` — 제품 요약 + 주 사용자
- `docs/tech-stack.md` — 언어, 프레임워크, 배포 타깃
- `docs/workflow.md` — 팀의 출시 방식 (브랜치, 리뷰, 출시 주기)

## 단계

1. 사용자에게 3개 질문, 하나씩:
   - 이 제품은 뭘 하나? 누가 쓰나?
   - 스택은? (언어, 프레임워크, 배포 타깃)
   - 어떻게 출시하나? (브랜치 전략, 리뷰 프로세스, 주기)
2. 3개 문서 작성
3. 누락 시 `AGENTS.md`의 섹션 1에 링크 추가
4. 확인 메시지: "설정 완료 — 다음: `/new-track <첫 기능>`"

## 규칙

- 가정으로 미리 채우지 않음. 질문하라.
- 각 문서 ≤ 50줄 유지
