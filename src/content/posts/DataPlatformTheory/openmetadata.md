---
title: OpenMetadata 이론 — 데이터 자산을 연결하는 메타데이터 플랫폼
description: OpenMetadata의 엔터티 모델, 수집 구조, 검색·계보·품질 흐름과 운영 구성요소를 설명합니다.
date: 2026-09-27
tags: [OpenMetadata, DataGovernance, DataCatalog, DataLineage, Architecture]
draft: false
---

OpenMetadata는 데이터베이스의 테이블, 파이프라인, 대시보드 같은 **데이터 자산의 설명과 관계를 모아 검색·거버넌스·계보·품질 관리에 활용하는 오픈 소스 메타데이터 플랫폼**입니다. 실제 테이블 행이나 파일을 옮겨 저장하는 데이터 웨어하우스는 아닙니다. Doris나 BigQuery의 데이터를 복사하지 않고, 해당 자산을 찾고 이해하는 데 필요한 메타데이터를 수집합니다.

![OpenMetadata의 메타데이터 수집, 저장, 검색, 계보 구조](/images/posts/data-platform-theory/openmetadata-architecture.svg)

이론집용 SVG는 공식 문서의 API·수집 프레임워크·엔터티 저장소·검색 엔진 구성을 데이터 흐름에 맞춰 다시 그린 개념도입니다. 실제 배포에서는 데이터베이스와 검색 엔진을 관리형 또는 외부 서비스로 분리할 수 있습니다. [공식 배포 아키텍처](https://docs.open-metadata.org/v1.12.x/deployment/docker)

## 어떤 문제를 해결합니까?

데이터 플랫폼에는 같은 자산이 여러 곳에 나타납니다. 물리적으로는 Doris의 테이블이고, 변환 관점에서는 dbt 모델이며, 실행 관점에서는 Airflow Task의 출력이고, 소비 관점에서는 BI 대시보드의 입력일 수 있습니다. 각 도구만 보면 설명·소유자·의존 관계가 흩어집니다.

OpenMetadata는 이런 대상을 공통 **Entity(엔터티)** 로 표현하고, 엔터티 사이의 관계를 연결합니다. 사용자는 “이 테이블의 주인은 누구인가?”, “어떤 파이프라인이 만들었나?”, “변경하면 어떤 대시보드에 영향이 있나?”를 카탈로그에서 탐색할 수 있습니다. 이때 중심이 되는 것은 실제 데이터가 아니라 데이터에 대한 설명과 관계입니다.

## 아키텍처 구성요소

| 구성요소 | 하는 일 | 이해할 점 |
|---|---|---|
| UI | 자산 검색, 상세 보기, 용어집·태그·소유자·계보·품질 정보 확인 | 사용자가 메타데이터를 탐색하고 일부를 편집하는 화면입니다. |
| API Server | 엔터티 조회·생성·수정, 관계 검증, 인증·권한 처리 | UI와 수집기, 외부 도구가 메타데이터를 읽고 쓰는 공통 인터페이스입니다. |
| Ingestion Framework | DB·BI·파이프라인 등 서비스별 Connector로 메타데이터 수집 | 원천마다 API·카탈로그·시스템 테이블에 접근하는 방식이 다르므로 Connector가 필요합니다. |
| Workflow Runner / Scheduler | 수집 Workflow를 실행하고 주기·상태·로그를 관리 | OpenMetadata 내부 Airflow, 1.12부터 제공되는 Kubernetes Orchestrator, 또는 외부 실행 환경을 선택할 수 있습니다. |
| Metadata Database | 엔터티의 속성과 관계를 저장하는 기준 저장소 | 공식 구성은 MySQL 또는 PostgreSQL을 지원합니다. |
| Search Engine | 엔터티를 색인해 전문 검색과 필터 검색을 처리 | Elasticsearch 또는 OpenSearch를 사용합니다. 기본 엔터티 저장 DB와 목적이 다릅니다. |
| OpenLineage·SDK·API 연동 | 실행 시점의 Job·Run·Dataset 계보 등 외부 메타데이터를 전달 | Connector의 주기 수집과 별개로 실행 이벤트를 직접 전송할 수 있습니다. |

API Server는 메타데이터를 검증하고 기준 저장소에 반영합니다. 검색 엔진은 UI가 빠르게 자산을 찾도록 색인을 제공합니다. 따라서 **검색 결과가 잠시 갱신되지 않는 문제와 기준 메타데이터가 저장되지 않은 문제는 구분해서 진단**해야 합니다. [High Level Design](https://docs.open-metadata.org/v1.13.x-SNAPSHOT/main-concepts/high-level-design), [Server Configuration](https://docs.open-metadata.org/v1.12.x/deployment/configuration)

## 엔터티 모델: 자산을 공통 어휘로 표현합니다

데이터베이스 자산은 보통 다음 계층으로 표현됩니다.

```text
Database Service
└── Database
    └── Schema
        └── Table
            └── Column
```

OpenMetadata에는 이 계층 외에도 Pipeline, Dashboard, Topic, API, ML Model 등의 엔터티가 있습니다. 엔터티는 고유 ID와 FQN(Fully Qualified Name)을 가지며, 소유자·설명·도메인·태그·분류·사용량·품질 정보 같은 속성과 다른 엔터티를 향한 관계를 가질 수 있습니다. 예를 들어 Table FQN은 서비스부터 테이블까지의 경로를 포함해 여러 시스템의 동명 테이블을 구분합니다.

이 공통 모델 덕분에 서로 다른 Connector가 수집한 정보를 같은 카탈로그에서 연결할 수 있습니다. Connector가 원천에서 추출한 정보를 OpenMetadata의 엔터티 모델로 변환하고 API에 보내면, API는 스키마와 관계를 검증한 뒤 저장합니다. [Metadata Schemas](https://docs.open-metadata.org/v1.12.x/api-reference/main-concepts/metadata-standard)

## 메타데이터가 들어오고 보이는 흐름

1. 관리자가 Database Service, Dashboard Service, Pipeline Service 같은 연결 정보를 등록합니다.
2. Connector가 원천 시스템의 카탈로그, 시스템 테이블, API 또는 산출물을 읽습니다.
3. Ingestion Workflow가 정보를 OpenMetadata 엔터티와 관계로 변환합니다.
4. Workflow Runner가 API로 결과를 전송하고 API Server가 검증·저장합니다.
5. 변경 이벤트를 바탕으로 검색 색인이 갱신되면 UI에서 이름·설명·태그·소유자 등으로 자산을 찾을 수 있습니다.

수집 Workflow는 메타데이터 외에도 사용량, 프로파일, 데이터 품질, 계보 등 목적에 따라 나뉩니다. 원천 Connector가 지원하는 항목만 자동 수집되므로, “서비스를 연결했다”는 사실만으로 사용량·계보·품질 정보까지 모두 채워지는 것은 아닙니다. [Metadata Ingestion Workflows](https://docs.open-metadata.org/v1.12.x/connectors/ingestion/workflows)

## 계보는 어떻게 만들어집니까?

계보(Lineage)는 테이블·파이프라인·대시보드 등의 **상류·하류 관계를 나타내는 메타데이터**입니다. 일반적인 예는 다음과 같습니다.

```text
raw.orders ──[dbt 모델]──> mart.daily_orders ──> 매출 대시보드
```

계보를 수집하는 방식은 데이터 소스와 실행 도구에 따라 다릅니다.

| 입력 정보 | 계보를 찾는 방식 | 주의점 |
|---|---|---|
| DB View 정의 | SQL을 분석해 참조 테이블과 대상 View를 찾습니다. | SQL 파서가 이해하지 못하는 문법이나 동적 SQL은 빠질 수 있습니다. |
| 쿼리 로그 | 실제 실행 쿼리에서 읽기·쓰기 테이블을 추출합니다. | DB 권한·로그 보존 기간·수집 범위의 영향을 받습니다. |
| dbt 산출물 | Manifest의 모델 의존성 등을 읽습니다. | 모델과 실제 물리 테이블을 올바르게 매핑해야 합니다. |
| Airflow·OpenLineage 이벤트 | 실행한 Job이 이번 Run에서 읽고 쓴 Dataset을 전달합니다. | Task별 추출기·Hook·명시적 입출력 설정에 따라 이벤트 내용이 달라집니다. |
| 수동 편집·API | 사람이 알고 있는 관계를 직접 추가합니다. | 실행 시점 정보가 자동으로 갱신되는지 별도 설계가 필요합니다. |

계보 수집 전에 원천 Table, Pipeline, Dashboard 등이 OpenMetadata에 엔터티로 존재해야 관계를 정확히 연결할 수 있습니다. 지원 Connector의 수집 범위도 다르므로 설정 시 해당 Connector 문서를 확인해야 합니다. [Lineage Ingestion](https://docs.open-metadata.org/v1.12.x/connectors/ingestion/lineage), [Lineage Workflow](https://docs.open-metadata.org/v1.12.x/connectors/ingestion/workflows/lineage)

Airflow 실행 계보에서는 OpenLineage 이벤트의 Job·Run·Dataset을 Airflow Provider가 만들고 Transport가 OpenMetadata로 전달합니다. OpenLineage는 계보 이벤트를 표현하는 규격이고, 이벤트를 장기간 보관해 UI로 보여 주는 카탈로그는 OpenMetadata입니다. 사내 Airflow Transport가 이전 DAG 연결을 정리하는 구체적인 동작은 [Airflow 장의 OpenLineage 절](/blog/dataplatformtheory/airflow/#xcom과-계보)에 정리했습니다.

## 품질·사용량·거버넌스는 계보와 별도 Workflow입니다

- **Profiler**는 테이블 행 수, 컬럼 분포 등 데이터 특성을 계산해 카탈로그에 연결합니다.
- **Data Quality**는 테스트 정의와 실행 결과를 자산에 연결합니다. 테스트 실행 엔진은 OpenMetadata 또는 외부 도구 구성에 따라 달라집니다.
- **Usage**는 쿼리 로그 등을 바탕으로 자산이 얼마나 사용되는지 보여 줍니다.
- **Glossary·Tags·Domains·Owners**는 기술 자산에 업무 의미와 책임 정보를 연결합니다.

이 정보들은 한 화면에 함께 보일 수 있지만 생성 경로는 서로 다릅니다. 예를 들어 테이블의 스키마를 수집하는 Metadata Workflow를 실행해도, DQ 테스트가 자동 생성되거나 실제 행 데이터가 OpenMetadata로 복사되는 것은 아닙니다. [Profiler Workflow](https://docs.open-metadata.org/v1.12.x/connectors/ingestion/workflows/profiler), [Data Quality](https://docs.open-metadata.org/v1.12.x/how-to-guides/data-quality)

## 배포와 운영에서 구분할 점

OpenMetadata Server, Metadata Database, Search Engine, Ingestion Runner는 논리적으로 다른 역할입니다. 빠른 로컬 테스트는 Docker Compose로 한 번에 올릴 수 있지만, 공식 배포 가이드는 운영 환경에서 자체 관리 데이터베이스와 검색 엔진을 사용하도록 권장합니다. Workflow는 OpenMetadata 내부 Airflow, OpenMetadata 1.12부터 제공되는 Kubernetes Orchestrator, 또는 외부 Airflow 같은 시스템에서 실행할 수 있습니다. 외부 실행을 선택하면 실행기가 원천 시스템과 OpenMetadata API 양쪽에 연결할 수 있어야 합니다. [Docker Deployment](https://docs.open-metadata.org/v1.12.x/deployment/docker), [Ingestion Deployment](https://docs.open-metadata.org/v1.12.x/deployment/ingestion), [Kubernetes Native Orchestrator](https://docs.open-metadata.org/v1.12.x/deployment/ingestion/kubernetes)

| 운영 질문 | 확인할 대상 |
|---|---|
| 자산 자체가 카탈로그에 없습니까? | Connector 연결·권한·필터·Metadata Workflow 실행 결과 |
| 자산은 있으나 검색되지 않습니까? | Search Engine 연결, 색인 갱신, 검색 필터 |
| 계보만 비어 있습니까? | 해당 Connector의 Lineage 지원, 쿼리 로그·Manifest·OpenLineage 이벤트, FQN 매핑 |
| 주기 수집이 멈췄습니까? | Workflow 스케줄러/Runner 상태, 로그, API 접근성 |
| UI에서 수정이 안 됩니까? | API Server 인증·권한·엔터티 스키마 검증 결과 |

## 한 문장으로 정리

OpenMetadata는 **데이터를 저장하고 변환하는 엔진이 아니라, 데이터 자산에 대한 여러 도구의 메타데이터를 공통 엔터티와 관계로 모아 검색·계보·거버넌스에 활용하는 플랫폼**입니다. 자산을 설명하는 정보와 실제 데이터 바이트를 분리해 생각하면, Connector·API·DB·검색 엔진·OpenLineage의 역할을 혼동하지 않게 됩니다.

**공식 문서:** [System Architecture](https://docs.open-metadata.org/v1.11.x/developers/architecture), [High Level Design](https://docs.open-metadata.org/main-concepts/high-level-design), [Metadata Standard](https://docs.open-metadata.org/v1.12.x/api-reference/main-concepts/metadata-standard), [Metadata Ingestion Workflows](https://docs.open-metadata.org/v1.12.x/connectors/ingestion/workflows), [Lineage Ingestion](https://docs.open-metadata.org/v1.12.x/connectors/ingestion/lineage), [Server Configuration](https://docs.open-metadata.org/v1.12.x/deployment/configuration), [Docker Deployment](https://docs.open-metadata.org/v1.12.x/deployment/docker), [Kubernetes Native Orchestrator](https://docs.open-metadata.org/v1.12.x/deployment/ingestion/kubernetes)
