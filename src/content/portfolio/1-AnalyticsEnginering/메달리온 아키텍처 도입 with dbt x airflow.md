---
title: 메달리온 아키텍처 도입 with dbt × Airflow
description: 파편화된 ETL과 중복 데이터를 Bronze·Silver·Gold 계층 및 dbt SQL 모델링으로 표준화
date: 2026-09-05
tags:
  - Medallion Architecture
  - dbt
  - Apache Airflow
  - Apache Doris
  - Analytics Engineering
featured: true
draft: false
---
> **기간:** 2026.3 ~ 2026.4
> **참여인원:** 3명
> **역할:** 메달리온 아키텍처 도입 제안 및 설계 참여
> **기술 스택:** Apache Airflow, dbt

## 1. Background & Challenges

엔지니어와 분석가 누구나 Airflow DAG를 개발할 수 있는 환경에서 팀과 작성자마다 ETL 구현 방식이 달라졌습니다. SQL, Python, 임시 테이블과 개별 스케줄이 DAG 내부에 혼재하면서 같은 목적의 데이터도 서로 다른 방식으로 생산됐고, 파이프라인을 수정하거나 장애 원인을 찾을 때 작성자의 구현 패턴부터 파악해야 했습니다.

- **ETL 코드 패턴 파편화:** Airflow DAG가 스케줄링뿐 아니라 데이터 변환 로직까지 각기 다른 방식으로 포함하여 유지보수 기준을 통일하기 어려웠습니다.
- **데이터 중복 생산:** 조직별로 유사한 데이터를 반복 가공하면서 테이블과 지표가 중복됐습니다.
- **신뢰할 데이터 식별의 어려움:** 원본, 정제 데이터, 리포트용 데이터의 경계가 없어 어떤 테이블이 기준 데이터인지 판단하기 어려웠습니다.
- **도메인 간 분석 제약:** Game, Marketing, LiveOps, CX 데이터가 개별 파이프라인에 흩어져 공통 정의와 결합 경로를 관리하기 어려웠습니다.

이를 해결하기 위해 Airflow는 실행 순서와 스케줄을 관리하고, 데이터 변환 로직은 dbt SQL 모델로 통합했습니다. 데이터는 Bronze·Silver·Gold 계층을 거치도록 표준화하여 원천 데이터부터 분석 리포트까지 신뢰할 수 있는 단일 경로를 만들었습니다.

## 2. Architecture: As-Is vs To-Be

### As-Is Architecture

![여러 엔지니어와 분석가가 서로 다른 Airflow DAG와 ETL 패턴으로 중복 테이블을 생산하는 기존 구조](/images/medallion-as-is-fragmented-etl.svg)

1. **데이터 수집:** 내부 로그와 외부 데이터를 파이프라인별 방식으로 수집
2. **DAG 개발:** 엔지니어와 분석가가 목적에 따라 Airflow DAG에 개별 ETL 로직 구현
3. **변환 방식 분산:** SQL·Python·임시 테이블 등 서로 다른 코드 패턴으로 데이터 가공
4. **데이터 중복:** 유사한 목적의 테이블과 지표가 여러 위치에서 반복 생산
5. **분석 활용:** 원본·정제·리포트 데이터의 구분이 없어 사용자가 기준 테이블을 직접 판단

### To-Be Architecture

![내부 로그와 외부 데이터를 Doris Bronze에 수집하고 dbt로 도메인별 Silver 및 Kimball 기반 Gold 데이터 마트를 만드는 메달리온 아키텍처](/images/medallion-to-be-dbt-airflow.svg)

1. **내부 로그 수집:** 게임 유저 로그를 Doris `fastlog`에 저장하여 Bronze 원천 계층 구성
2. **외부 데이터 수집:** Airbyte 기반 ELT로 외부 데이터 수집 방식을 표준화하고 Doris `raw`에 저장
3. **Silver 모델링:** Game, Marketing, LiveOps, CX 등 주요 업무 도메인별로 이상치·중복 제거와 필드 평탄화를 수행
4. **Gold 모델링:** Kimball Star Schema 전략에 따라 Fact와 Dimension을 구분하고 공통 분석 모델 구성
5. **데이터 마트 제공:** 리포트 목적에 맞게 역정규화한 Gold 테이블을 분석가와 BI 도구에 제공
6. **실행 및 변환 표준화:** Airflow가 실행 순서를 오케스트레이션하고, dbt는 Bronze → Silver 정제 모델과 Silver → Gold 분석 모델을 각각 실행·관리

## 3. Solution & Technical Insights

1. **Airflow와 dbt의 책임 분리**
    - **[Issue]** Airflow DAG마다 데이터 변환 로직과 구현 패턴이 달라 공통 코드 리뷰와 유지보수가 어려웠습니다.
    - **[Solution]** Airflow는 스케줄과 작업 의존성 관리에 집중하고, 변환 로직은 dbt SQL 모델로 이동했습니다. 데이터 모델링 기술 스택을 SQL로 통합하여 엔지니어와 분석가가 같은 구조와 규칙으로 코드를 작성하도록 표준화했습니다.
2. **Bronze 계층의 수집 경로 표준화**
    - **[Issue]** 내부 로그와 외부 데이터의 수집 방식 및 저장 위치가 파이프라인별로 달라 원천 데이터의 출처를 추적하기 어려웠습니다.
    - **[Solution]** 내부 게임 로그는 Doris `fastlog`, 외부 데이터는 Airbyte ELT를 거쳐 Doris `raw`에 저장했습니다. 원천 특성에 맞는 수집 방식을 유지하면서 Bronze 계층이라는 공통 진입점을 정의했습니다.
3. **업무 도메인 중심의 Silver 계층 설계**
    - **[Issue]** 여러 조직이 각자의 분석 목적에 맞춰 유사한 정제 데이터를 반복 생산해 중복과 정의 불일치가 발생했습니다.
    - **[Solution]** Game, Marketing, LiveOps, CX를 주요 업무 도메인으로 정의하고, dbt Silver 모델에서 이상치 제거·중복 제거·필드 평탄화를 공통 수행했습니다. 리포트마다 반복되던 정제 로직을 도메인 모델로 모아 재사용할 수 있게 했습니다.
4. **Kimball 기반 Gold 데이터 마트 구축**
    - **[Issue]** 리포트별 테이블이 직접 생성되어 공통 차원과 핵심 이벤트의 정의를 재사용하기 어려웠습니다.
    - **[Solution]** Kimball Star Schema에 따라 비즈니스 이벤트를 Fact, 분석 관점을 Dimension으로 구분했습니다. 이 모델을 기반으로 리포트 목적의 역정규화 테이블을 Gold 데이터 마트로 제공하여 분석 진입점을 명확히 했습니다.
5. **계층 의존성을 코드로 관리**
    - **[Issue]** 테이블 생성 순서와 상위·하위 데이터 관계가 DAG 구현에 흩어져 변경 영향 범위를 파악하기 어려웠습니다.
    - **[Solution]** Bronze를 읽어 Silver를 생성하는 dbt 모델과 Silver를 읽어 Gold를 생성하는 dbt 모델을 계층별로 분리했습니다. 각 모델은 `source()`와 `ref()`로 입력 의존성을 명시하고, Airflow가 두 dbt 작업의 실행 순서를 관리하도록 구성했습니다.

## 4. Impact & Result

- 🧩 **ETL 패턴 표준화:** 작성자마다 달랐던 데이터 변환 로직을 dbt SQL 모델로 통합하여 코드 구조와 유지보수 방식을 일관되게 만들었습니다.
- 🧭 **신뢰할 데이터 경로 확보:** Bronze 원천, Silver 정제, Gold 분석 데이터의 역할을 구분하여 사용자가 목적에 맞는 기준 데이터를 찾을 수 있게 했습니다.
- ♻️ **중복 가공 감소:** 이상치·중복 제거와 필드 평탄화 로직을 도메인별 Silver 모델로 공통화하여 리포트마다 반복되던 변환을 줄였습니다.
- ⭐ **분석 모델 재사용:** Fact·Dimension 기반의 공통 모델과 역정규화 Gold 마트를 제공하여 Game, Marketing, LiveOps, CX 분석이 같은 비즈니스 정의를 재사용할 수 있게 했습니다.
- 🤝 **협업 방식 통합:** SQL을 공통 모델링 언어로 사용하여 엔지니어와 분석가가 같은 저장소와 리뷰 흐름에서 데이터 모델을 개발할 수 있게 했습니다.
