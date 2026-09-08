---
title: CMDB와 관측 데이터를 기반으로 장애를 분석하는 AI 에이전트
description: OpenMetadata CMDB 온톨로지와 관측 Skill·MCP를 결합해 장애 영향 범위와 원인을 자율 분석하는 에이전트
date: 2026-09-08
tags:
  - AI Agent
  - Incident Response
  - OpenMetadata
  - Ontology as Code
  - Observability
featured: true
draft: false
---
> **기간:** 2026.7~8
> **참여인원:** 2명
> **역할:** CMDB 온톨로지 및 장애 분석 에이전트 설계·개발
> **기술 스택:** Hermes Agent, OpenMetadata, Python, YAML, Agent Skills, MCP, Prometheus, Elasticsearch, LibreNMS, Slack API

## 1. Background & Challenges

장애 알림은 Slack과 메일로 전달됐지만 이후의 원인 분석은 담당자의 경험에 의존했습니다. 하드웨어 장비와 네트워크 구성, 서비스 흐름 정보가 여러 시스템에 흩어져 있어 **어디까지 영향을 받는지, 무엇부터 확인해야 하는지 판단하는 과정**을 매번 반복했습니다.

에이전트가 자율적으로 조사하려면 실제 인프라 관계를 탐색할 수 있는 CMDB 지도와 각 리소스의 현재 상태를 확인할 도구가 함께 필요했습니다.

## 2. Architecture: As-Is vs To-Be

### AS-IS: 담당자 중심의 수동 조사

1. 담당자가 장애 알림을 확인합니다.
2. 장비·네트워크·서비스 정보를 여러 데이터 소스에서 찾습니다.
3. 영향 범위를 추정하고 모니터링 지표와 로그를 직접 조회합니다.
4. 경험과 플레이북을 바탕으로 원인과 조치 방법을 판단합니다.

### TO-BE: CMDB 온톨로지를 탐색하는 장애 분석 에이전트

![하드웨어·네트워크·서비스 흐름을 YAML Ontology as Code로 모델링해 OpenMetadata CMDB를 갱신하고, 장애 발생 시 Hermes Agent가 CMDB 관계와 관측 Skill·MCP를 반복 탐색하여 영향 범위와 원인을 분석하는 흐름](/images/incident-agent-ontology-sequence.svg)

CMDB 갱신 흐름과 장애 분석 흐름을 분리했습니다. 하드웨어 서버 장비, 네트워크 구성, 서비스 흐름 데이터를 YAML 온톨로지로 모델링해 OpenMetadata 용어집에 지속 반영합니다. 장애가 발생하면 에이전트가 이 관계도를 따라 영향 범위와 조사 대상을 정한 뒤, 대상별 관측 도구를 호출해 원인을 좁힙니다.

## 3. Solution & Technical Insights

### 3.1 OpenMetadata 용어집 기반 CMDB 온톨로지

- **[Issue]** 단순 장비 목록으로는 서버, 네트워크와 서비스 사이의 관계를 표현할 수 없어 장애 전파 범위를 탐색하기 어려웠습니다.
- **[Solution]** 하드웨어 장비, 네트워크 구성, 서비스 흐름을 OpenMetadata 용어집 온톨로지로 통합했습니다. 에이전트는 장애 지점에서 상·하류 관계를 따라가며 영향받을 가능성이 있는 리소스와 조사 순서를 찾습니다.

### 3.2 Ontology as Code로 지속적인 CMDB 갱신

- **[Issue]** 사람이 CMDB를 직접 수정하면 실제 구성과 문서 사이에 차이가 생기고 변경 이력을 검토하기 어렵습니다.
- **[Solution]** 인프라 개념과 관계를 YAML로 정의했습니다. 여러 데이터 소스에서 수집한 정보를 검증한 뒤 OpenMetadata 용어집에 반영해, 온톨로지 변경을 코드처럼 리뷰하고 지속적으로 갱신할 수 있도록 구성했습니다.

### 3.3 관계 탐색과 관측 도구를 결합한 자율 진단

- **[Issue]** 장애 알림이나 단일 지표만으로는 원인과 영향 범위를 함께 판단할 수 없습니다.
- **[Solution]** Hermes Agent가 CMDB 온톨로지에서 조사 대상을 먼저 좁히고, 각 리소스에 맞는 Skill·MCP를 선택하도록 설계했습니다. Prometheus 지표와 Elasticsearch 로그, LibreNMS 네트워크 상태 등 실제 관측 근거를 관계 정보와 함께 분석해 다음 조사 단계와 원인을 자율적으로 추론합니다.

처방전에는 담당자가 바로 검토할 수 있도록 **조치 대상, 원인, 영향 범위, 핵심 근거와 출처, 확신도**를 포함했습니다. 에이전트가 조사와 추론을 수행하고 최종 조치는 사람이 판단합니다.

## 4. Impact & Result

- 분산된 인프라 정보를 OpenMetadata 기반 CMDB 온톨로지로 통합했습니다.
- 장애 지점에서 관계를 따라 영향 범위와 확인할 리소스를 찾을 수 있게 했습니다.
- CMDB 탐색과 관측 Skill·MCP를 연결해 근거 수집부터 원인 추론까지 하나의 흐름으로 구성했습니다.
- YAML 기반 Ontology as Code로 인프라 관계 모델을 지속적으로 갱신하고 리뷰할 수 있게 했습니다.

## 5. Lessons Learned

장애 분석 에이전트의 핵심은 모델 자체보다 **탐색 가능한 인프라 관계와 검증 가능한 관측 근거**였습니다. OpenMetadata 온톨로지가 조사 범위를 제시하고 Skill·MCP가 현재 상태를 확인하면서, 에이전트가 실제 구성과 데이터에 따라 다음 조사 단계를 선택할 수 있었습니다.
