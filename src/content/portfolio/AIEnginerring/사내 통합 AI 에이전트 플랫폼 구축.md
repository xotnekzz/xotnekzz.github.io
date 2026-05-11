---
title: 사내 통합 AI 에이전트 플랫폼 구축
description: LibreChat + MCP + Milvus 기반 RAG 인프라로 전사 AI 플랫폼 구축 — 파편화된 PoC를 하나의 통합 플랫폼으로
date: 2025-04-01
tags:
  - LibreChat
  - MCP
  - Milvus
  - LangChain
  - Python
  - RAG
  - AI Platform
featured: true
draft: false
---

> **기간:** 2025.4 ~ 2024.6
**역할:** AI Platform Architect & Lead Developer (플랫폼 설계 및 RAG/MCP 인프라 구축 주도)
**기술 스택:** LibreChat, MCP (Model Context Protocol), Milvus, LangChain, Python, Streamlit, Gemini API, Local LLMs (LM Studio on Mac Studio)

## 1. Background & Challenges

초기 AI 도입 단계에서는 특정 비즈니스 문제를 빠르게 해결하기 위한 **파편화된 PoC(Proof of Concept)**가 주를 이루었습니다. 그러나 AI 활용 범위가 전사로 확대되면서 다음과 같은 문제에 직면했습니다:

- **확장성:** 개별 Streamlit 앱으로는 수백 명의 동시 접속자와 부서별 다양한 요구사항을 감당하기 어려움
- **접근성:** 비개발 직군이 스스로 에이전트를 생성하고 업무에 활용할 수 있는 직관적인 인터페이스 부재
- **연동성:** 고립된 RAG 시스템을 넘어 내부 ERP, DB 등 실무 데이터에 즉시 접근하여 작업을 수행하는 기능 필요
## 2. Evolution: From Prototyping to Enterprise Platform

### Phase 1: Rapid Prototyping (2024)

Streamlit과 LangChain을 활용하여 특정 백오피스 업무를 자동화하는 실무형 RAG 도구들을 개발했습니다.

- **Text-to-SQL 에이전트:** 비전문가가 자연어로 내부 데이터를 조회할 수 있는 환경 구축
- **유저 리뷰 분석기:** 대량의 고객 VOC를 테마별로 요약 및 감정 분석하여 리포트 자동 생성
- **성과:** AI의 실무 적용 가능성을 증명하고, 현업 부서의 강력한 도입 의지 확보

![image|625](/images/ai_platform.svg)

### Phase 2: Open-source Based Agent Platform (2025~)

**LibreChat**을 중심으로 로컬 LLM부터 다양한 상용 LLM 프로바이더를 자유롭게 선택하여 에이전트를 개발할 수 있는 통합 플랫폼으로 전환했습니다.

- **Self-service 에이전트:** 전사 직원이 복잡한 코딩 없이도 페르소나와 지식 베이스를 설정하여 본인만의 에이전트를 추가
- **하이브리드 AI 엔진:** 보안이 중요한 데이터는 Mac Studio에 LM Studio/Hugging Face를 통해 배포된 **로컬 LLM**으로, 고성능이 필요한 작업은 **Gemini/GPT** 등 외부 프로바이더를 선택적으로 활용하도록 설계
## 3. Core Strategy: Introduction of MCP (Model Context Protocol)

플랫폼의 확장성을 극대화하기 위해 **MCP**를 팀 내 최초로 제안하고 도입했습니다. 단순히 개별 기능을 구현하는 것을 넘어, **팀 동료들이 누구나 필요한 도구를 MCP로 만들어 플랫폼에 기여할 수 있는 표준화된 개발 환경**을 구축했습니다.

## 4. Impact & Result

- 🚀 **전사적 AI 확산:** 수백 명의 직원이 매일 활용하는 사내 표준 AI 플랫폼으로 자리매김하여 업무 효율을 크게 향상시켰습니다.
- 💰 **기술 부채 해소 및 비용 절감:** 산재해 있던 파편화된 AI 실험들을 하나의 플랫폼으로 통합하여 운영 비용을 최적화하고 관리 보안을 강화했습니다.
- 🎯 **지식 자산화:** 사내의 흩어져 있던 문서들을 벡터 DB화하여 검색 가능한 디지털 자산으로 전환했습니다.
## 5. Next Steps & Future Trends: From Platform to Decentralized Agents

단순한 도구 도입을 넘어, AI와 엔지니어가 공생하는 최적의 개발 및 업무 환경을 구축하기 위해 다음과 같은 방향으로 기술적 전환을 주도하고 있습니다.

- **중앙 집중형 플랫폼에서 탈점중심형 에이전트 도구로의 전환**: 모든 기능을 하나의 플랫폼(LibreChat)에 담는 방식에서 벗어나, **Gemini CLI, Claude Code, Antigravity**와 같은 전문화된 에이전트 활용 도구를 각자의 워크플로우에 직접 통합하는 추세로 발전시키고 있습니다.
- **Agent Skills 및 MCP 기반의 개별 에이전트 구축**: 공통 기능을 기다리는 것이 아니라, **Agent Skills**나 **오픈소스 MCP**를 활용하여 직무별/개인별로 필요한 에이전트 기능을 즉시 개발하고 커스터마이징하여 사용합니다.
- **GitLab을 통한 기술 자산화 및 전사 공유**: 개발된 Skills나 커스텀 MCP 커넥터들은 사내 **GitLab** 저장소에서 관리됩니다. 이를 통해 팀원들이 서로의 에이전트 기능을 검색하고 재사용하며, 전사적인 AI 역량을 상향 평준화하는 선순환 구조를 구축했습니다.
- **AI Engineering 표준 기술 학습 및 적용**: AI 에이전트 간의 협업과 기능 확장을 위한 최신 표준 기술들을 심도 있게 학습하고 실제 업무 아키텍처에 반영하고 있습니다.
