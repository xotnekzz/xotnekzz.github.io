---
title: "[OpenMetadata 도입기] #2 OpenMetadata를 고른 이유"
date: 2026-05-13
tags:
  - DataGovernance
featured: false
draft: false
---
#### 들어가며

먼저 결론 부터 말하자면 데이터 카탈로그는 OpenMetadata로 선정하였습니다.

OpenMetadat(OM)가 무엇인지?, 어떤 아키텍처를 가졌는지?, DataHub, Amunsen, Atals 등 다른 카탈로그 도구와 어떤 차이가 있는지 왜 OM을 선택 했는지?

이야기를 나누어 보겠습니다.

#### OpenMetadata란?

OpenMetadata는 데이터 검색(Discovery), 관측성(Observability), 거버넌스(Governance)를 위한 오픈소스 통합 메타데이터 플랫폼입니다.

Apache Hadoop, Apache Atlas, Uber Databook의 창립자들이 만든 플랫폼으로,Collate 회사가 주도하여 개발하고 있습니다.

##### 핵심 기능

**데이터 검색(Discovery):** 120개 이상의 데이터 커넥처를 통해 다양한 데이터소스(데이터베이스,대시보드,파이프라인 등)의 메타데이터를 수집하고, 팀이 필요한 데이터를 쉽게 찾을 수 있도록 합니다.

**데이터 계보(Lineage):** 데이터가 어디서 왔고 어디로 흘러가는지 시각적으로 추적합니다.

**데이터 품질(Quality):** 데이터 품질을 모니터링하고 관리합니다.

**데이터 거버넌스(Governance):** 데이터 자산에 대한 정책 및 규칙을 관리합니다.

**협업(Collaboration):** 데이터 생산자와 소비자 간의 소통과 협력을 지원합니다.

##### 주요 특징
- **API 및 스키마 우선 아키텍처**로 높은 확장성과 커스터마이징 지원
- **단 4개의 시스템 컴포넌트**로 구성된 간결한 아키텍처 -> 배포 및 운영이 쉬움
- **엔지니어/비엔지니어** 모두가 사용할 수 있는 직관적인 UI
- **통합 메타데이터 그래프**로 모든 데이터 자산의 메타데이터를 중앙화

##### 커뮤니티
- GitHub 스타 13.9k
- 오픈소스 멤버 13,000명 이상
- 엔터프라이즈 배포 3,000개 이상
- 코드 컨트리뷰터 430명 이상
- 120개 이상의 데이터 커넥터 지원

#### OpenMetadata 시스템 아키텍처

**1. 시스템 컨텍스트**

![System Context](https://mintcdn.com/openmetadata/m2dVw4ye-bGbm5O_/public/images/main-concepts/high-level-design/system-context.png?w=1650&fit=max&auto=format&n=m2dVw4ye-bGbm5O_&q=85&s=7ab4ba2431668b360380ed667fce43d2)

OpenMetadata 시스템은 다섯 가지 내부 컴포넌트로 구성됩니다.

- **UI** : 사용자에게 메타데이터를 제공하는 디스커버리 중심 도구로, API로 부터 데이터를 공급받습니다.
- **API** : OpenMedata의 Backend이자 메타데이터 Entity와 상호작용하는 모든 방식을 정의한다.
- **Ingestion Framework**: Connectors & Integrations API 명세서를 기반으로 모든 커넥터의 토대를 제공하며 HTTP API로 호출합니다.
- **Entity Store**: Main Entity & Relationship storage. 모든 Enitity와 관계의 실시간 상태정보를 저장합니다.
- **Search Engine**: UI의 메타데이터 디스커버리를 지원하는 인덱싱 시스템으로, Entity Store로 부터 공급받고 UI가 Searches(검색)한다.


**2. 전체 아키텍처**

![OM-Architecture](https://mintcdn.com/openmetadata/FFPgqWxUp0cM2_kH/public/images/developers/architecture/architecture.png?w=1650&fit=max&auto=format&n=FFPgqWxUp0cM2_kH&q=85&s=9359ec18fed2ec8551f7298f26078c0a)

외부 메타데이터 소스에서 Ingestion Framework가 `Source -> Processor -> Sink`
파이프라인으로 데이터를 Pull한 뒤, HTTP API를 통핸 OpenMetadata Platform으로 Push합니다. Platform은 DropWizard기반 API Server가 중심에 있으며, UI-Auth Provider와 연결되고 Change Event Handler를 통해 MySQL과 ElasticSearch를 동기화한다. 사용자(Consumer), 외부시스템(Automated Ingestion), Ingestion Pipeline 모두 동일한 REST API로 통신합니다.


#### DataHub, Amundsen 등 다른 데이터카탈로그 도구와 비교

##### 핵심 장단점 비교표

| 항목         | OpenMetadata                         | DataHub                            | Apache Atlas           | Amundsen              |
| ---------- | ------------------------------------ | ---------------------------------- | ---------------------- | --------------------- |
| **개발 주체**  | Uber Databook / Atlas 출신 엔지니어 (2021) | LinkedIn                           | Apache 재단 (Hadoop 생태계) | Lyft                  |
| **철학**     | 통합형 올인원 플랫폼                          | 실시간·이벤트 기반·분산형                     | Hadoop 네이티브, 심층 거버넌스   | 경량, 디스커버리 중심          |
| **아키텍처**   | MySQL + Elasticsearch (단순)           | RDBMS + ES + Graph DB + Kafka (복잡) | JanusGraph + Solr      | Neo4j + Elasticsearch |
| **수집 방식**  | Pull 기반 (Airflow)                    | Stream 기반 (Kafka 실시간)              | Hook 기반 (Hadoop 네이티브)  | Pull 기반               |
| **실시간 처리** | ❌                                    | ✅                                  | 부분적                    | ❌                     |
| **배포 난이도** | 중간 (2~4주)                            | 높음 (4~8주)                          | 높음 (3~6주)              | 낮음 (1~2주)             |
| **커뮤니티**   | 빠르게 성장 중, 활발                         | 활발, 기업 지원(Acryl)                   | 성숙하나 개발 속도 느림          | 크지만 개발 둔화             |

##### 기능별 장단점

| 영역 | OpenMetadata | DataHub | Apache Atlas | Amundsen |
|------|-------------|---------|--------------|----------|
| **데이터 디스커버리** | ⭐⭐⭐⭐⭐ Elasticsearch 기반, Activity Feed | ⭐⭐⭐⭐⭐ Domains 그룹핑, 사용 이력 활용 | ⭐⭐⭐⭐ REST API + DSL 쿼리 | ⭐⭐⭐⭐⭐ PageRank 기반 "구글 같은" 검색 |
| **데이터 계보(Lineage)** | 컬럼 레벨 + 노코드 수동 보정 에디터 | 테이블·컬럼 레벨, API 자동 추출 | Hadoop 환경 내 최고 수준 | 기본 수준 지원 |
| **데이터 품질** | ⭐⭐⭐⭐⭐ 내장 프레임워크, 데이터 계약 지원(v1.8+) | ⭐⭐⭐⭐ Assertions + GE/dbt 통합 | ❌ 네이티브 미지원 | ❌ 네이티브 미지원 |
| **거버넌스/보안** | RBAC, 태깅, 비즈니스 용어집 + Importance 태그 | RBAC + Actions Framework 자동화 | ⭐⭐⭐⭐⭐ 분류 자동 전파 + Apache Ranger 통합 | 기본 수준 |
| **UI 사용성** | ⭐⭐⭐⭐⭐ 현대적, 비기술자 친화 | ⭐⭐⭐⭐ 양호 | ⭐⭐ 구식 | ⭐⭐⭐⭐⭐ 직관적 |
| **AI/ML 거버넌스** | MLflow 네이티브 통합, 모델을 1급 엔티티로 | ⭐⭐⭐⭐⭐ MCP Server (머신 대상 API) | 매우 제한적 | 매우 제한적 |

##### 종합 장단점 요약

| 플랫폼              | 👍 장점                                                          | 👎 단점                                                            |
| ---------------- | -------------------------------------------------------------- | ---------------------------------------------------------------- |
| **OpenMetadata** | 통합 플랫폼으로 단순한 아키텍처, 강력한 데이터 품질 내장, 현대적 UI, MLflow 통합, 비교적 빠른 배포 | 실시간 이벤트 처리 미지원, 머신 대상(machine-facing) API 부재, AI 워크플로우 통합은 기본 수준 |
| **DataHub**      | 실시간 이벤트 기반 거버넌스, 데이터 메시에 적합, MCP Server로 AI 에이전트 지원, 자동화 워크플로우 | 복잡한 아키텍처(Kafka/Graph DB), 운영 부담 큼, 전문 인력 필요, 인프라 비용 높음           |
| **Apache Atlas** | Hadoop 환경 최강, 정교한 분류·태그 자동 전파, Apache Ranger 연동 마스킹, 성숙한 거버넌스  | UI 노후, 데이터 품질 미지원, AI/ML 기능 부족, Hadoop 외 환경에서 부적합, 개발 속도 느림      |
| **Amundsen**     | 가장 가벼움, 빠른 배포, 직관적 검색 UX, 낮은 운영 비용, 학습 곡선 완만                   | 데이터 품질·거버넌스 기능 부재, 외부 도구 의존도 높음, AI 거버넌스 부재, 커뮤니티 활동 둔화          |


##### 조직 유형별 추천 한눈에 보기

| 조직 유형 | 1순위 추천 | 이유 |
|----------|-----------|------|
| 클라우드 네이티브 (Snowflake/BigQuery 등) | **OpenMetadata** | 통합 기능 + 단순한 아키텍처 균형 |
| 데이터 메시 도입 대기업 | **DataHub** | 실시간 자동화 + 분산 거버넌스 |
| Hadoop 중심 레거시 환경 | **Apache Atlas** | 네이티브 통합, 대안 없음 |
| 스타트업/단순 디스커버리 | **Amundsen** | 빠른 배포, 낮은 비용 |
| AI 중심 조직 | **DataHub** 또는 **OpenMetadata** | MCP Server / MLflow 통합 |

#### OpenMetadata를 고른 이유

첫째, **운영 부담이 낮고 배포가 용이**하다는 점입니다. 데이터 운영 인력이 충분하지 않은 조직 특성상, 통합형 아키텍처를 기반으로 한 OpenMetadata의 낮은 운영 난이도는 도입과 안정적 운영 측면에서 큰 이점이 됩니다.

둘째, **직관적인 UI를 통한 전사적 거버넌스 체계 구축이 가능**하다는 점입니다. 개발자와 비개발자 구분 없이 누구나 데이터 카탈로그를 조회할 수 있고, 조직·도메인·용어집·데이터 품질 규칙 등을 손쉽게 설정할 수 있어, 사용자 주도의 데이터 거버넌스 문화를 정착시키기에 적합합니다.

셋째, **AI 에이전트 활용 환경에 대한 확장성**입니다. 최근 사내에서는 누구나 데이터 분석용 AI Agent를 개발하는 흐름이 자리 잡고 있는데, OpenMetadata의 MCP 연동을 활용하면 보다 풍부하고 일관된 메타데이터를 컨텍스트로 제공할 수 있어, 신뢰할 수 있는 데이터 기반 AI 활용으로 이어질 것으로 기대됩니다.


#### 참고 문헌
- https://open-metadata.org/
- https://docs.open-metadata.org/v1.12.x/developers/architecture
- https://docs.open-metadata.org/v1.12.x/api-reference/main-concepts/high-level-design
- https://thedataguy.pro/writing/2025/08/open-source-data-governance-frameworks/