---
title: 데이터 플랫폼 오픈소스 이론집 — 학습 순서와 역할 지도
description: 오픈소스 데이터 도구와 AWS 관리형 데이터 플랫폼 서비스의 역할·아키텍처·학습 순서를 연결합니다.
date: 2026-09-23
tags: [DataEngineering, Architecture, OpenSource]
draft: false
---

이 이론집은 도구 이름을 외우는 대신, **데이터가 어디에서 생성되고, 누가 옮기고, 누가 처리하며, 어디에 저장되고, 어떻게 조회되는지**를 따라가도록 구성했습니다. 각 장의 SVG는 설명 대상에 맞춰 제어·메타데이터 경로와 실제 데이터 경로를 구분하거나 수집·검색 흐름을 표시합니다. 점선은 제어·설정의 영향을 나타내며 데이터 자체의 이동을 뜻하지 않습니다.

| 역할 | 기술 | 먼저 이해할 질문 |
|---|---|---|
| 작업 순서 조정 | [Apache Airflow](/blog/dataplatformtheory/airflow/) | 언제 어떤 작업을 실행합니까? |
| 데이터 수집·복제 | [Airbyte](/blog/dataplatformtheory/airbyte/), [Apache NiFi](/blog/dataplatformtheory/nifi/) | 원천의 변경과 파일을 어떻게 목적지로 옮깁니까? |
| 이벤트 저장·전달 | [Apache Kafka](/blog/dataplatformtheory/kafka/) | 이벤트를 어떻게 보존하고 소비자가 재처리합니까? |
| 대규모 처리 | [Apache Spark](/blog/dataplatformtheory/spark/), [Apache Flink](/blog/dataplatformtheory/flink/) | 분산 작업과 상태를 누가 관리합니까? |
| SQL 변환 | [dbt Core](/blog/dataplatformtheory/dbt/) | 변환 의존성과 검증을 어떻게 코드로 표현합니까? |
| 분석 저장·조회 | [Apache Doris](/blog/dataplatformtheory/doris/), [DuckDB](/blog/dataplatformtheory/duckdb/) | 분산 서비스와 내장형 DB는 어떻게 다릅니까? |
| 객체·파일 저장 | [SeaweedFS](/blog/dataplatformtheory/seaweedfs/) | 파일의 경로와 실제 바이트는 어디에 있습니까? |
| 메타데이터 카탈로그·거버넌스 | [OpenMetadata](/blog/dataplatformtheory/openmetadata/) | 데이터 자산의 정의·소유자·품질·계보를 어떻게 한곳에서 찾습니까? |

## AWS 관리형 데이터 플랫폼

오픈소스 장과 구분해, AWS가 컨트롤 플레인 또는 데이터 이동 인프라를 관리하는 서비스를 별도로 살펴봅니다. 관리형이라고 해서 모든 운영 책임이 사라지는 것은 아닙니다. 사용자는 네트워크·권한·용량·데이터 모델·장애 대응 정책을 여전히 설계해야 합니다.

| 역할 | 기술 | 먼저 이해할 질문 |
|---|---|---|
| 컨테이너 플랫폼 | [Amazon EKS](/blog/dataplatformtheory/aws-eks/) | AWS가 Kubernetes에서 무엇을 관리하고, 애플리케이션 팀은 무엇을 운영합니까? |
| 데이터베이스 마이그레이션·복제 | [AWS DMS](/blog/dataplatformtheory/aws-dms/) | 기존 데이터를 옮기면서 원본 변경분을 어떻게 따라잡습니까? |
| 이벤트 스트리밍 플랫폼 | [Amazon MSK](/blog/dataplatformtheory/aws-msk/) | Kafka 호환 클러스터의 브로커 운영을 어디까지 서비스에 맡깁니까? |

세 서비스는 서로 대체재가 아닙니다. EKS는 컨테이너 워크로드를 실행할 플랫폼이고, DMS는 데이터베이스 간 초기 적재와 변경 복제를 수행하며, MSK는 이벤트 로그를 보존하고 여러 소비자에게 전달합니다. 예를 들어 DMS가 관계형 DB 변경을 Kafka 호환 MSK 토픽으로 보내고, EKS 위의 Flink 애플리케이션이 이를 처리할 수 있습니다. 이는 조합 예시이며 세 서비스를 함께 써야 하는 것은 아닙니다.

예를 들어 주문 변경 이벤트가 생기면 Kafka가 이벤트 로그를 보존하고, Flink가 지속적으로 집계하며, Doris가 결과를 빠르게 조회할 수 있게 저장합니다. Airflow는 하루 단위 검증·재처리 작업을 조정하고, dbt는 Doris 같은 SQL 엔진 안에서 분석 모델을 만들 수 있습니다. 이 조합은 **가능한 설계 예시**이며 각 제품의 필수 구성은 아닙니다.

각 장은 공식 문서에 근거한 개념 설명입니다. 배포 모드와 버전에 따라 프로세스 이름과 기능이 달라질 수 있으므로, 구현 시에는 장 끝의 공식 문서와 실제 설치 버전을 함께 확인해 주세요.

Airflow·Doris·Spark·Flink·SeaweedFS·NiFi 장에는 공식 문서의 아키텍처 그림 원본을 별도 이미지로 첨부하고 캡션에 출처 링크를 표시했습니다. 나머지 장의 SVG는 공식 구성요소 설명을 바탕으로 이론집용으로 그린 개념도입니다.

## 장을 관통하는 이론 키워드

| 질문 | 중심 개념 | 관련 장 |
|---|---|---|
| 누가 일의 순서를 정합니까? | 제어 평면과 데이터 평면, DAG·스케줄러 | Airflow, Spark, Flink |
| 데이터를 어디까지 보관합니까? | 로그 보존·Offset, 파일 바이트·경로 메타데이터 | Kafka, SeaweedFS |
| 실패 후 어디서부터 다시 합니까? | 재시도·멱등성, State·Checkpoint, WAL·Provenance | Airflow, Airbyte, Flink, NiFi |
| 한 번 처리했다는 말은 무엇입니까? | at-most-once·at-least-once·exactly-once의 보장 범위 | Kafka, Flink, NiFi, Airbyte |
| 계산은 어디에서 합니까? | 웨어하우스 내부 SQL, 로컬 벡터 엔진, 분산 클러스터 | dbt, DuckDB, Doris, Spark, Flink |
| 자산의 의미와 신뢰도를 어떻게 찾습니까? | 엔터티·관계·용어집·소유권·품질·계보 | OpenMetadata |

같은 “재시도”라는 단어도 제품 내부 상태만 복원하는 경우와 외부 목적지 효과까지 되돌리는 경우가 다릅니다. 장애 복구 설명을 읽으실 때는 **입력 재생 가능성, 중간 상태 복원, 외부 쓰기 중복 방지**를 나누어 보시면 정확히 비교할 수 있습니다.

## 실무에서는 이렇게 조합했습니다

위 표의 조합 예시와 별개로, 제가 운영하는 사내 데이터 플랫폼의 실제 구성을 각 장 끝의 **“실무 적용”** 절에 정리했습니다. 전체 흐름은 아래와 같습니다.

![사내 데이터 플랫폼의 실제 파이프라인](/images/posts/data-platform-theory/practice-pipeline.svg)

| 장 | 실무에서 맡은 역할 | 실무 적용 절의 핵심 |
|---|---|---|
| [Airflow](/blog/dataplatformtheory/airflow/) | 유일한 오케스트레이터 | Variable 기반 DAG 팩토리, Asset·partition_key 체인, 멱등성 장치 |
| [Airbyte](/blog/dataplatformtheory/airbyte/) | 외부 API 수집 | 플랫폼 없이 PyAirbyte + Declarative manifest, State 대신 구간 교체 |
| [dbt Core](/blog/dataplatformtheory/dbt/) | Doris 안의 SQL 변환 | 커스텀 swap materialization, Airflow 실행 계약, OpenMetadata DQ |
| [Doris](/blog/dataplatformtheory/doris/) | 모든 분석 계층의 저장소 | Broker·Stream Load·트랜잭션 교체, 좀비 쿼리 대응 |
| [DuckDB](/blog/dataplatformtheory/duckdb/) | 시간별 로그 ETL 엔진 | 일회성 컨테이너, gzip 병목, write-then-clear 출력 |
| [SeaweedFS](/blog/dataplatformtheory/seaweedfs/) | 데이터 레이크·공용 파일 저장소 | Filer·S3 이중 접근, 경로 규칙 = 파티션 |

여러 장을 관통하는 공통 원칙은 하나입니다. **Airflow는 “어느 날짜를 처리하는가”만 전달하고, 각 적재·변환 단계는 그 날짜 구간을 통째로 교체합니다.** Airbyte의 State, dbt의 기본 incremental처럼 도구가 제공하는 증분 메커니즘 대신 이 규칙을 택했기 때문에, 재시도와 백필은 모두 “같은 날짜를 다시 실행”으로 통일됩니다.

Kafka, Flink, Spark, NiFi와 AWS 관리형 서비스는 현재 사내 운영 파이프라인에서 쓰지 않아 이론 위주로 다룹니다. Kafka와 CDC 파이프라인은 [Data Engineering Lab](/blog/de/de-lab-6-realtime-ecommerce-cdc-pipeline/) 시리즈에서 개인 실습으로 다뤘습니다.
