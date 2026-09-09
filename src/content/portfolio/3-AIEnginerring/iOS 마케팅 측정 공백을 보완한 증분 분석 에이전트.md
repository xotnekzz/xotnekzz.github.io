---
title: iOS 마케팅 증분 분석 에이전트
description: LinearSVR·RANSAC 기반 증분 분석 모델과 Gemini·MCP를 결합해 ATT 이후 iOS 마케팅 성과 측정과 예산 판단을 지원
date: 2025-09-01
tags:
  - AI Agent
  - Marketing Analytics
  - Incrementality Modeling
  - LinearSVR
  - RANSAC
  - MCP
  - Gemini
featured: false
draft: true
---
> **기간:** 2025.09 ~ 2025.09
> **참여인원:**
> **역할:** AI Data Scientist & Engineer (증분 분석 모델 설계 및 에이전트 개발)
> **기술 스택:** Python, Scikit-learn, LinearSVR, RANSAC, MCP (Model Context Protocol), Gemini API, Marketing Mix Modeling (MMM)
> **소속:** BitMango
> **프로젝트:** Marketing Analysis Agent

## 1. Background & Challenges

Apple의 **ATT(App Tracking Transparency)** 정책 도입 이후 iOS 마케팅 추적 거부 유저가 증가했습니다. 이로 인해 기존의 개별 유저 단위 **ROAS(Return on Ad Spend)** 측정만으로는 캠페인 성과를 충분히 파악하기 어려운 측정 공백이 발생했습니다. 특히 매출 비중이 높은 iOS 캠페인에서 광고비를 증액하거나 최적화하는 의사결정이 병목이 됐습니다.

목표는 매체 지출과 Organic 유입·매출의 관계를 분석해 기존 성과 지표를 보완하고, 경영진이 거시적인 마케팅 효과를 검토하며 예산 배분과 확장을 판단할 수 있는 환경을 구축하는 것이었습니다.

## 2. Architecture: Incrementality Analysis Loop

### AS-IS: 개별 유저 단위 측정에 의존

1. 매체별 캠페인에 광고비를 집행합니다.
2. 개별 유저의 광고 유입과 매출을 연결해 ROAS를 측정합니다.
3. 추적을 거부한 iOS 유저의 성과를 연결하기 어려워 측정 공백이 발생합니다.
4. 관측 가능한 성과만으로는 캠페인 효과를 충분히 설명하기 어려워 예산 확장 판단이 지연됩니다.

### TO-BE: 증분 분석 모델과 LLM 에이전트 결합

![마케터와 경영진의 요청을 Gemini Agent와 MCP 서버가 처리하고, Marketing Database의 Spend·Organic 시계열 데이터를 LinearSVR와 RANSAC으로 분석해 차트와 자연어 인사이트를 제공하는 흐름](/images/ios-marketing-incrementality-agent.svg)

1. 마케터나 경영진이 Gemini Agent에 iOS 매체의 증분 효과 분석을 요청합니다.
2. 에이전트가 MCP 서버의 분석 도구를 호출합니다.
3. MCP 서버가 Marketing Database에서 매체별 Spend와 Organic 설치·매출 시계열 데이터를 조회합니다.
4. LinearSVR와 RANSAC을 결합한 회귀 모델이 계수와 영향도를 계산합니다.
5. MCP 서버가 JSON 분석 결과와 생성된 차트 이미지를 에이전트에 반환합니다.
6. 에이전트가 원본 데이터와 차트를 함께 해석해 자연어 인사이트와 예산 전략을 제시합니다.

## 3. Solution & Technical Insights

### 3.1 선형회귀 기반 증분 분석 모델

- **[Issue]** 개별 유저를 추적할 수 없는 상황에서 매체별 기여도를 거시적으로 파악해야 했습니다. 시계열 데이터의 급격한 변동과 이상치는 회귀 결과를 왜곡할 수 있었습니다.
- **[Solution]** 매체별 Spend 변화가 Organic 설치와 매출 변화에 미치는 관계를 분석하는 **MMM(Marketing Mix Modeling) 유사 모델**을 개발했습니다. Scikit-learn의 **LinearSVR**와 **RANSAC**을 결합해 이상치의 영향을 줄이고, 각 매체의 Organic 견인력을 회귀계수와 영향도로 수치화했습니다.

### 3.2 iOS 성과 측정 공백을 보완하는 Proxy 지표

- **[Issue]** 추적을 거부한 유저의 광고 유입과 성과를 직접 연결할 수 없어 iOS 캠페인의 효율을 설명할 근거가 부족했습니다.
- **[Solution]** 특정 매체의 광고 집행과 전체 설치·매출 변동을 통계적으로 분석해 추적 거부 유저의 기여도를 간접 추정하는 **Proxy 지표**를 마련했습니다. 이를 기존 ROAS와 함께 검토해 iOS 캠페인의 성과와 예산 확장 가능성을 판단하도록 구성했습니다.

### 3.3 MCP와 Gemini를 결합한 분석 에이전트

- **[Issue]** 통계 모델의 계수와 시계열 결과만으로는 비전문가인 경영진과 마케터가 추세와 의미를 빠르게 파악하기 어려웠습니다.
- **[Solution]** 분석 모델을 **MCP 서버**의 도구로 제공하고 **Gemini API**와 결합했습니다. 에이전트가 분석 결과를 JSON으로 받아 시각화 차트를 생성하고, 차트 이미지와 원본 데이터를 함께 해석하는 **멀티모달 분석**을 수행하도록 구현했습니다. 이를 통해 광고비 증감에 따른 Organic 매출의 탄력도와 같은 인사이트를 자연어로 설명하고 예산 최적화 전략을 제안할 수 있게 했습니다.

### 3.4 분석 결과의 해석 범위

이 모델은 관측 데이터의 상관관계를 이용해 증분 효과를 간접 추정합니다. 회귀 결과만으로 광고 집행과 추가 설치·매출 사이의 인과관계를 확정할 수는 없으므로, 결과를 실험 기반 인과 효과와 동일하게 해석하지 않고 기존 ROAS의 측정 공백을 보완하는 의사결정 지표로 활용했습니다.

## 4. Impact & Result

- **의사결정 병목 완화:** ATT 정책 이후 불투명해진 iOS 마케팅 성과를 거시적으로 분석해 경영진의 예산 판단을 지원했습니다.
- **분석 셀프서비스 환경 구축:** 복잡한 통계 모델의 결과를 자연어와 차트로 제공해 마케터가 직접 인사이트를 확인할 수 있게 했습니다.
- **예산 최적화 근거 제공:** 매체별 증분 효율을 비교해 예산을 집중하거나 조정할 대상을 식별할 수 있는 근거를 마련했습니다.
- **Privacy-Safe Measurement:** 개인 식별 정보 없이 집계 데이터와 통계 모델을 이용하는 iOS 마케팅 측정 체계를 구축했습니다.
