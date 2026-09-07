---
title: OpenMetadata 기반 데이터 디스커버리·거버넌스 체계 구축
description: OpenMetadata 인프라와 OpenLineage 계보를 구축하고, OpenSearch 임베딩 기반 Semantic Search로 데이터 자산 탐색을 확장
date: 2026-02-01
tags:
  - OpenMetadata
  - Apache Airflow
  - OpenLineage
  - OpenSearch
  - Data Governance
  - Lineage
featured: true
draft: false
---
> **기간:** 2026.2 ~ 현재 진행 중
> **참여인원:** 3명
> **역할:** Openmetadata 도입 및 구축
> **기술 스택:** OpenMetadata, Apache Airflow 3, OpenLineage, OpenSearch, MariaDB, Python, Data Governance Framework

## 1. Background & Challenges

마케팅, 재무, 게임 개발 등 각 부서가 독립적으로 데이터 파이프라인과 테이블을 만들면서 데이터 자산이 여러 시스템에 분산되었습니다. 3명의 데이터 엔지니어가 이를 관리해야 했고, 퇴사자가 구축한 레거시 파이프라인은 충분한 설명과 소유권 정보가 없어 구조를 파악하고 장애 원인을 찾는 데 많은 시간이 필요했습니다.

전사 AX(AI Transformation)를 지원하는 백오피스 AI 에이전트를 개발하려면 데이터의 위치만 검색하는 기능으로는 부족했습니다. 데이터가 어떤 파이프라인에서 생성되고 어디에서 사용되는지, 누가 관리하며 신뢰할 수 있는지를 함께 확인할 수 있어야 했습니다. 그러나 기존 환경에는 메타데이터, 소유권, 데이터 계보(Lineage), 품질 정보를 연결하는 공통 체계가 없었습니다.

소규모 데이터 엔지니어 팀이 모든 메타데이터를 대신 관리하는 방식은 지속하기 어렵다고 판단했습니다. 엔지니어는 신뢰성 있는 플랫폼과 자동 수집 체계를 제공하고, 각 도메인의 현업 담당자가 데이터 설명과 소유권을 관리하는 분산형 거버넌스 구조가 필요했습니다.

## 2. Architecture: As-Is vs To-Be

![OpenMetadata 서버, 전용 Ingestion Airflow, MariaDB, OpenSearch와 데이터 자산 활용 계층으로 구성한 인프라 구조](../../images/openmetadata-infra.svg)

### AS-IS: 분산된 자산과 단절된 계보

1. 데이터베이스와 Airflow DAG의 정보가 각 시스템에 흩어져 있어 데이터 탐색 경로가 표준화되지 않았습니다.
2. 테이블 설명과 담당자 정보가 없거나 최신 상태를 유지하지 못해 데이터의 의미와 책임자를 확인하기 어려웠습니다.
3. 파이프라인과 테이블 사이의 계보가 연결되지 않아 정합성 문제가 발생하면 담당자가 DAG와 SQL을 수동으로 역추적해야 했습니다.
4. Elasticsearch의 BM25 기반 키워드 검색은 정확한 용어나 자산명을 알아야 원하는 결과를 찾기 쉬웠기 때문에, 자연어 의도를 기준으로 관련 자산을 식별하는 데 한계가 있었습니다.

### TO-BE: OpenMetadata 중심의 데이터 거버넌스

1. OpenMetadata Server가 데이터 자산, 계보, 소유권, 태그와 품질 정보를 제공하고 MariaDB가 OpenMetadata의 운영 메타데이터를 저장하도록 구성했습니다.
2. OpenMetadata Ingestion 전용 Airflow를 운영 데이터 파이프라인과 분리해 데이터베이스의 기술 메타데이터 수집 작업을 독립적으로 실행하도록 구성했습니다.
3. 운영 Airflow 3에서 발생하는 실행 정보와 데이터 입출력 관계를 OpenLineage 표준으로 전달하고, OpenMetadata에서 파이프라인과 데이터 자산의 계보를 연결했습니다.
4. 검색 엔진을 OpenSearch로 변경하고 데이터 자산을 임베딩해 BM25 키워드 검색과 Semantic Search가 가능한 검색 계층을 구성했습니다.
5. 향후 MCP와 API로 들어오는 자연어 요청에서 AI가 업무 맥락에 맞는 데이터 자산을 식별할 수 있도록 검색 기반을 확장했습니다.

## 3. Solution & Technical Insights

### 3.1 소규모 팀이 운영 가능한 거버넌스 플랫폼 선택

- **[Issue]** 데이터 검색, 계보, 프로파일링, 품질 결과를 각각 다른 도구로 운영하면 플랫폼 구성 요소와 관리 지점이 늘어나 소규모 팀의 운영 부담이 커집니다.
- **[Solution]** 메타데이터 검색부터 계보, 프로파일링, 품질, 협업 기능까지 하나의 UI에서 연결할 수 있는 OpenMetadata를 선택했습니다. API 중심 구조를 활용해 사내 자동화 도구와 연동할 수 있는 확장성도 확보했습니다.

DataHub와 Amundsen도 검토했지만, 전사 확산에 필요한 기능 범위와 운영 복잡도를 함께 비교해 OpenMetadata를 도입했습니다. 데이터 소유자가 설명을 작성하고, 스레드와 태스크를 통해 담당자와 협업할 수 있다는 점도 분산형 거버넌스 운영 방식에 적합했습니다.

### 3.2 Airflow 계보 수집 구조를 OpenLineage로 표준화

![Airflow 3의 om_lineage가 OpenLineage 이벤트를 생성하고 OpenMetadata가 데이터 자산 계보로 연결하는 구조](../../images/openmetadata-openlineage.svg)

- **[Issue]** 초기에는 사내 Airflow 2.9.3과 당시 OpenMetadata 연동 모듈의 버전 충돌 때문에 공식 리니지 연동을 적용할 수 없었습니다. 이를 우회하기 위해 `@om_lineage` Decorator가 실행 컨텍스트에서 입출력 테이블을 추출하고 OpenMetadata Lineage API를 직접 호출하도록 구현했습니다. 이 방식은 빠르게 적용할 수 있었지만, 커스텀 API 연동을 계속 유지해야 하는 부담이 있었습니다.
- **[Solution]** Airflow 3 업그레이드와 함께 `om_lineage`를 OpenLineage 기반으로 변경했습니다. DAG 실행 과정에서 생성되는 데이터 입출력 관계를 OpenLineage 표준으로 전달하도록 구성해, OpenMetadata 전용 API 호출에 의존하던 리니지 수집 방식을 표준 이벤트 기반 구조로 전환했습니다.

이 전환으로 리니지 생성 책임과 OpenMetadata 적재 책임을 분리했습니다. Airflow는 파이프라인 실행과 데이터 계보 이벤트 생성에 집중하고, OpenMetadata는 수집된 계보를 데이터베이스 메타데이터와 연결해 탐색 가능한 형태로 제공합니다. `om_lineage`는 사내 DAG의 적용 방식을 유지하면서 내부 구현을 OpenLineage 표준에 맞춘 연결 지점으로 바뀌었습니다.

### 3.3 OpenSearch 기반 Semantic Search로 자산 탐색 확장

- **[Issue]** 기존 Elasticsearch 검색은 BM25 키워드 매칭을 기반으로 동작해 사용자가 정확한 테이블명이나 사내 용어를 모르면 관련 데이터 자산을 찾기 어려웠습니다. 향후 AI가 자연어 요청을 데이터 자산과 연결하려면 단어 일치뿐 아니라 설명과 업무 맥락의 의미적 유사성을 검색할 수 있어야 했습니다.
- **[Solution]** 검색 엔진을 OpenSearch로 변경하고 OpenMetadata의 자산 정보를 임베딩해 벡터 인덱스를 구성했습니다. 기존 BM25 키워드 검색과 Semantic Search를 함께 사용할 수 있도록 해, 자연어 표현과 자산 설명의 의미가 유사한 데이터셋을 검색할 수 있는 기반을 마련했습니다.

이 검색 계층은 향후 MCP와 API로 전달되는 자연어 요청을 AI가 해석할 때 후보 데이터 자산을 좁히는 데 사용합니다. AI가 임의로 테이블을 선택하는 대신 OpenMetadata의 설명, 태그, 소유권, 계보와 의미적으로 가까운 자산을 식별하도록 확장하는 것이 목표입니다.

### 3.4 사람과 자동화를 결합한 메타데이터 운영

- **[Issue]** 레거시 테이블이 많아 중앙 데이터팀이 모든 설명과 소유권을 직접 작성하고 최신 상태로 유지하기 어려웠습니다.
- **[Solution]** 스키마와 계보 같은 기술 메타데이터는 자동 수집하고, 비즈니스 의미와 소유권은 각 도메인의 담당자가 OpenMetadata에서 관리하도록 역할을 나눴습니다. 엔지니어는 수집 안정성과 표준을 관리하고, 현업은 데이터의 의미와 활용 맥락을 보완하는 운영 체계를 설계했습니다.

## 4. Impact & Result

- **통합 데이터 탐색 경로 확보:** 여러 데이터베이스와 Airflow 파이프라인의 메타데이터를 OpenMetadata에서 검색하고 연결해서 볼 수 있게 했습니다.
- **원인 분석 범위 축소:** 테이블과 상·하위 파이프라인의 계보를 따라가며 정합성 문제의 영향 범위와 원인을 확인할 수 있게 했습니다.
- **리니지 연동의 표준화:** OpenMetadata API를 직접 호출하던 커스텀 방식에서 OpenLineage 기반으로 전환해 Airflow와 메타데이터 플랫폼 사이의 결합도를 낮췄습니다.
- **자연어 기반 자산 탐색 기반 확보:** BM25 키워드 검색에 임베딩 기반 Semantic Search를 더해 정확한 자산명을 모르는 사용자와 AI도 업무 맥락으로 후보 자산을 찾을 수 있도록 했습니다.
- **거버넌스 책임 분산:** 데이터 엔지니어가 플랫폼과 자동 수집을 담당하고, 도메인 담당자가 설명과 소유권을 관리하는 협업 기반을 마련했습니다.
