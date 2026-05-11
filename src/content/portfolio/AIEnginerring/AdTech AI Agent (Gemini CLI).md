---
title: AdTech AI Agent (Gemini CLI)
description: Gemini CLI 기반 AI 에이전트로 1,500개 마케팅 캠페인 자동화 — Human-in-the-loop 구조로 할루시네이션 리스크 제거
date: 2025-01-01
tags:
  - AI
  - Gemini
  - MCP
  - Python
  - AdTech
featured: true
draft: false
---

 **기간:** 2025
**역할:** AI Engineer (Gemini CLI 기반 에이전트 설계 및 개발)
**참여인원: 2명**
**기술 스택:** Gemini CLI, MCP (Model Context Protocol), MySQL, Python, Natural Language Prompting, Human-in-the-loop (HITL)

## 1. Background & Challenges

1,500여 개에 달하는 대규모 마케팅 캠페인을 수동으로 운영하는 데에는 물리적 한계가 존재했습니다. 기존의 SQL 기반 자동화 룰(Rule) 방식은 비즈니스 환경 변화에 유연하게 대응하기 어려웠으며, 마케터가 직접 룰을 수정하기 위해서는 기술적 장벽이 높았습니다. 또한 LLM을 도입할 때 발생할 수 있는 할루시네이션(Hallucination)으로 인한 오작동 리스크를 제어해야 했습니다.

## 2. Architecture: Human-in-the-loop AI Agent

에이전트는 Management API를 제공하는 Google Ads, Applsearchads, Meta Ads, Unity Ads, Applovin 총 5개 AdNetwork를 지원합니다.

Gemini CLI와 MCP 기술을 접목하여 마케터가 자연어로 제어하고, 실행 전 인간의 검증을 거치는 안정적인 에이전트 조를 설계했습니다.
![[marketing agent.svg|697]]
## 3. Solution & Technical Insights

1. **Gemini CLI 및 MCP를 활용한 실시간 데이터 주입**
- **[Issue]** LLM이 최신 마케팅 퍼포먼스 데이터를 실시간으로 파악하지 못하는 정보의 공백이 존재했습니다.
- **[Solution]** **MCP(Model Context Protocol)** 기술을 도입하여 Gemini CLI가 실시간 마케팅 DB(MySQL)에 접근하도록 구현했습니다. 이를 통해 "어제 ROAS가 가장 낮은 캠페인을 찾아줘"와 같은 실시간 데이터 기반의 의사결정을 가능하게 했습니다.
1. **Natural Language(Prompt) 기반의 룰 관리 전환**
- **[Issue]** SQL 기반 룰의 높은 수정 난이도로 인해 마케터의 운영 자율성이 저하되었습니다.
- **[Solution]** 룰 관리 방식을 **자연어 프롬프트**로 전환했습니다. 마케터는 별도의 코딩 지식 없이도 텍스트로 캠페인 운영 로직을 즉시 수정하고 배포할 수 있는 환경을 조성했습니다.
1. **Human-in-the-loop 구조를 통한 안정성 확보**
- **[Issue]** AI 에이전트의 단독 판단에 따른 대규모 캠페인 오작동 리스크가 있었습니다.
- **[Solution]** 에이전트가 즉각 액션을 실행하는 대신, 먼저 **Plan 파일(실행 계획)**을 생성하도록 설계했습니다. 운영자가 이를 검토하고 승인한 후에만 실제 액션이 실행되는 **Human-in-the-loop** 구조를 통해 할루시네이션 리스크를 원천 차단했습니다.
## 4. Impact & Result

- 🚀 **폭발적인 운영 생산성 향상:** 수 명의 운영 인력이 필요했던 1,500개 캠페인 관리를 **마케터 단 1명이 전담**할 수 있는 혁신적인 자동화 환경을 달성했습니다.
- 🦾 **마케터 주도형 자동화:** 기술 지원 없이 마케터가 직접 운영 룰을 튜닝하고 실험할 수 있는 "Self-service Operation" 체계를 구축했습니다.
- 💰 **비용 효율화 및 성과 개선:** 실시간 데이터 기반의 정교한 캠페인 조정을 통해 예산 낭비를 최소화하고 ROAS 성과를 극대화하는 데 기여했습니다.


