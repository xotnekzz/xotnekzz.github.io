---
title: 비트망고 BI 성장기
description: BI팀 초기 멤버로서 레거시 시스템 현대화, 데이터 모델링, 예측 모델 이식까지 — 주니어 엔지니어 3년의 성장 기록
date: 2019-01-01
tags:
  - Airflow
  - MariaDB
  - Python
  - NestJS
  - Superset
  - BI
featured: false
---

> **기간:** 2019 ~ 2022 (Junior Engineer)
**핵심 역량:** Analytics Engineering, Legacy Modernization, Data Modeling, Backend Development
**기술 스택:** Apache Airflow, MariaDB, Python, NestJS, MongoDB, Apache Superset, Scikit-learn, Google Sheets API

## 1. Overview

비트망고 BI팀의 초기 멤버로서, 파편화된 레거시 시스템을 현대화하고 마케팅/게임 도메인의 의사결정을 지원하는 데이터 생태계를 구축했습니다. 단순한 인프라 관리를 넘어, 비즈니스 요구사항을 데이터 모델로 변환하고 예측 모델을 실무에 이식하는 등 조직에 성장에 기여하였습니다.

![image](https://prod-files-secure.s3.us-west-2.amazonaws.com/d4ddb94b-7c9d-46ff-ae59-4df49feee0b8/5d35c659-b78e-4bb9-8901-35002bfa22ba/BI.svg?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Content-Sha256=UNSIGNED-PAYLOAD&X-Amz-Credential=ASIAZI2LB4666YG3QLJP%2F20260313%2Fus-west-2%2Fs3%2Faws4_request&X-Amz-Date=20260313T153155Z&X-Amz-Expires=3600&X-Amz-Security-Token=IQoJb3JpZ2luX2VjEML%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FwEaCXVzLXdlc3QtMiJHMEUCIQD8IwFlrjkv4aGJgs4gLltZyWyKS2WUzkBgz7nAeO9I5wIgaFsd4RFgr0V%2Bfu80Ay0pOb2RgTeZz%2F815l%2Fy6DtToeYqiAQIi%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FARAAGgw2Mzc0MjMxODM4MDUiDNQ0oNvyiehZb3quuyrcA5D9UqiVz8Ya6hhoBEG10q4rdWy4ahWh7tB6xAB8DWI7v82%2BjMsiiaK7SROga3fsAGT17VjQgDKVIO2uo9rfE5robQhw6dYhieqGN5vfucQbRrabI7BHFltcbW2enqNy7TFq5c665MoAyPzrjXey5%2BnmZOHSEu%2Bdhf4qi9A25giGaSCOPxbl%2FDXojxjFfohcVQJogu6I5hJ9X0sjJrQEnLCggjZOvPZzxMVsykTNB31VL41FyquWzNt%2ByHRgbe4BW16Isc3sdz6rWV5LKIV7h%2FDhmXi75%2B6tdRxFfvBpWhXA6%2FoaQ%2B5FrsynbbvVootr8ng8GdX9AUQKARDC4DwzBwk7I%2FuQHbrQJXRrOZ%2FmZatYVyMvsOkryDOR4Y9vzYLTV%2FlgFt5z29hJ6k2ljJtRVEUdaEGE0vySyeO8lFtClJn5TP88c19zIexUz%2FSJYQlXyYAFA7aM2LRQKFY2UEPTYPjzxs5MTE2%2BpvtbwIZgmiH%2B5cYQ83sbakDuBRdnPbA0sFD0H5SxGYv6ewq8dpB%2BD9GUGdNcr2TCtYvTpqQ%2Bbz6rjj2MqlyJbXUXK%2F%2Bup0RziAWfBH7rOliz2EQuMqKzZQT4hNAOSKWfD61LwpQ7VUFnl2zXeHzd15AAIIkmMNa8z80GOqUBaaKrmk72B1YvurzJz98njb5D9AonEyXXF0wSuJpMfmUiiec9%2FlKY8g6iN2qdWLot%2F03y3G7UySXpTBf0ixc24H%2Fu3f9wADSaL00ee4GT8n%2BTmE4tchoJmGh5YFaxAIvMprrS5kd6%2FOoTALo%2F1pNE60KpOra7nqDGjUAE1OrY9SuAM6o%2B1a7E7rYRrQ93zD91eHBySgrFXSR9hH9grU40Xf9%2F0iOP&X-Amz-Signature=7bbacb967a5abbcfec49b138afc4afe6f40e0ac25ba352aa8422aa5a95d1356d&X-Amz-SignedHeaders=host&x-amz-checksum-mode=ENABLED&x-id=GetObject)



## 2. Key Projects & Technical Contributions

### [1] 레거시 파이프라인의 현대적 전환 (Modernization)

- **Challenges:** 초기 시스템은 **Bash CronJob** 기반의 산재된 스크립트로 관리되어 가시성이 낮고 장애 대응이 어려웠습니다.
- **Action:** **Apache Airflow**를 도입하여 100개 이상의 워크플로우를 DAG 구조로 마이그레이션했습니다.
- **Impact:** 파이프라인 종속성을 명확히 관리하고, 장애 인지 및 복구 시간을 획기적으로 단축하여 데이터 신뢰성을 확보했습니다.
### [2] 통합 마케팅 데이터 생태계 구축 (Analytics Engineering)

- **Challenges:** 6개 이상의 광고 매체와 MMP 데이터가 서로 다른 포맷으로 산재해 있어 통합 성과 분석이 불가능했습니다.
- **Action:** 매체 지출(Spend)과 인앱 이벤트 데이터를 유저/캠페인 단위로 Join 할 수 있는 **SSOT(Single Source of Truth) 마트**를 설계했습니다.
- **Impact:** 마케터가 단일 SQL 또는 BI 도구에서 전체 매체 성과를 비교 분석할 수 있는 환경을 조회 시간을 주 단위에서 실시간 수준으로 개선했습니다.
- **Mission:** 캠페인 초기(1일차) 데이터를 바탕으로 7일차 pROAS를 예측하여 마케팅 예산 배분을 최적화.
- **Collaboration:** 데이터 사이언티스트(DS)가 모델링에 집중할 수 있도록 피처 엔지니어링 파이프라인을 구축하고, 예측 결과를 매일 아침 자동 서빙하는 루프를 완성했습니다.
### [4] Engineering Agility: 게임 서버 및 소셜 기능 개발

- **Context:** 조직 내 개발 인력 부족 상황에서 데이터 엔지니어링 역량을 백엔드로 확장했습니다.
- **Task:** **NestJS**와 **MongoDB**를 기반으로 게임 소셜 서비스의 핵심 API를 개발하고 서버 성능을 최적화했습니다.
- **Result:** 데이터가 생성되는 원천(Source)부터 활용되는 지점까지의 전체 흐름을 이해함으로써 시스템 전반의 최적화를 이끌어냈습니다.
## 3. Technical Insights & Solutions

1. **지표의 표준화 (Standardization):** 매체마다 상이한 ROI/ROAS 정의를 사내 표준에 맞춰 데이터 마트 레벨에서 통일하여 지표 혼선을 원천 차단했습니다.
1. **Bash to Airflow: 오케스트레이션 전략:** 단순 실행을 넘어 상태 관리와 재시도(Retry) 로직을 포함한 **DAG** 구조를 통해 파이프라인의 견고함을 더했습니다.
1. **확장 가능한 데이터 모델링:** 새로운 매체나 이벤트가 추가되더라도 메타데이터 설정만으로 대응 가능한 유연한 스키마 구조를 유지했습니다.
## 4. Impact & Result

- 🚀 **의사결정 속도 및 문화 개선:** 사내 BI 도구 활용률을 높여 전 부서가 실무에서 실시간 지표를 기반으로 토론하는 시각화 문화를 구축했습니다.
- 💰 **마케팅 효율 최적화:** pROAS 예측 기반의 예산 배분을 통해 전사 ROAS 지표를 전년 대비 유의미하게 개선하는 데 기여했습니다.
- 🦾 **Full-stack 엔지니어링 역량:** 데이터 인프라부터 서비스 백엔드까지 폭넓은 기술 스택을 활용하여 조직의 병목 현상을 해결하고 비즈니스 연속성을 보장했습니다.
