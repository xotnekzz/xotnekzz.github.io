---
title: Apache Doris 이론 — FE·BE와 분산 OLAP 쿼리
description: Doris의 통합형 아키텍처, FE와 BE 역할, 적재 및 조회 흐름을 설명합니다.
date: 2026-09-23
tags: [Doris, OLAP, Architecture]
draft: false
---

Apache Doris는 분석 쿼리를 빠르게 처리하는 분산 OLAP 데이터베이스입니다. 이 장의 그림은 **스토리지·컴퓨트 통합형 배포**를 기준으로 합니다. 분리형 배포는 메타데이터·컴퓨트·스토리지 계층이 달라지므로 동일한 노드 그림으로 이해하시면 안 됩니다.

![Doris 통합형 배포에서 FE와 BE의 역할](/images/posts/data-platform-theory/doris-architecture.svg)

공식 문서의 통합형 아키텍처 그림도 함께 첨부합니다. 이 그림은 FE와 BE의 실제 클러스터 관계를 보여 주며, 위 SVG는 역할과 쿼리 흐름을 한국어로 풀어 쓴 개념도입니다.

![Apache Doris 공식 문서의 스토리지·컴퓨트 통합형 아키텍처](/images/posts/data-platform-theory/official/doris-official.jpg)

[그림 출처: Apache Doris System Architecture](https://doris.apache.org/docs/4.x/features-architecture/system-architecture/)

## FE와 BE는 무엇을 합니까?

| 구성요소 | 역할 |
|---|---|
| Frontend(FE) | MySQL 프로토콜 요청을 받고, SQL을 파싱·최적화하여 실행 계획을 만듭니다. 테이블·파티션·태블릿의 메타데이터와 클러스터 상태를 관리합니다. |
| FE 리더·팔로어 | 메타데이터의 일관성과 고가용성을 담당합니다. 읽기 요청을 받는 FE와 메타데이터 변경을 합의하는 역할을 구분해서 보셔야 합니다. |
| Backend(BE) | 태블릿 데이터를 저장하고 쿼리 계획의 조각을 병렬 실행합니다. 통합형에서는 저장과 계산이 같은 BE에 있습니다. |
| Tablet·Replica | 데이터를 나누는 기본 단위와 그 사본입니다. 복제본을 서로 다른 BE에 배치해 장애에 대응합니다. |
| Transaction | 적재 작업의 성공·실패와 데이터 가시성을 조정합니다. 파일을 썼다는 것과 쿼리에 보인다는 것은 다른 단계입니다. |

## 적재와 조회 흐름

1. 적재 요청이 들어오면 FE가 테이블 메타데이터와 적재 작업을 조정합니다. 방식에 따라 외부 파일, Kafka, 클라이언트 데이터 등이 원천이 됩니다.
2. BE가 데이터를 받아 분산 저장합니다. 논리적 테이블은 파티션과 태블릿으로 나뉘며 태블릿 복제본이 여러 BE에 놓입니다.
3. SQL 조회 시 FE가 파싱·최적화한 계획을 여러 실행 조각으로 나눕니다.
4. BE가 로컬 데이터 스캔, 필터, 집계, 조인 등을 병렬 수행하고 필요한 중간 결과를 교환합니다. 최종 결과가 FE를 거쳐 클라이언트로 돌아갑니다.

여기서 **분산 저장**과 **분산 실행**은 서로 다른 축입니다. 태블릿 배치는 데이터가 있는 위치를 정하고, 쿼리 조각 배치는 계산할 위치를 정합니다. 컬럼 단위 읽기와 사전 집계에 유리한 모델을 선택하더라도, 잘못된 파티션·키 설계나 과도한 조인은 성능을 떨어뜨릴 수 있습니다.

## 저장과 실행을 더 깊게 보겠습니다

### 파티션과 버킷은 서로 다른 분할 단계입니다

파티션은 보통 날짜나 업무 범위처럼 사용자가 정의한 큰 구간을 나눕니다. 버킷은 키 해시 등을 이용해 한 파티션 안의 데이터를 여러 Tablet으로 분산합니다. 파티션은 오래된 범위를 빠르게 정리하거나 쿼리에서 읽을 범위를 제외하는 데 도움을 주고, 버킷 수와 분포는 병렬도·데이터 균형에 영향을 줍니다. 날짜를 파티션 키로 두었다고 자동으로 균등한 해시 분산이 되는 것은 아닙니다.

### FE는 전역 계획을, BE는 병렬 실행을 담당합니다

SQL 계획은 Scan, Filter, Aggregate, Join 같은 연산자로 이루어집니다. FE는 테이블 메타데이터와 통계, 분산 배치를 이용해 어떤 Tablet을 읽고 어떤 BE에 실행을 보낼지 정합니다. BE는 자기 Tablet에서 로컬 연산을 수행하며, 여러 노드의 결과가 필요한 조인·집계에서는 네트워크로 중간 결과를 교환합니다. 이 교환 구간은 MPP 실행의 핵심이면서 네트워크·메모리 사용량이 커지는 지점입니다.

### 테이블 모델은 변경 의미를 정합니다

Doris의 Duplicate, Aggregate, Unique 계열 모델은 단순한 저장 형식 옵션이 아닙니다. 중복 행을 유지하는지, 집계 키를 어떻게 묶는지, 키가 같은 새 버전을 어떤 의미로 반영하는지 결정합니다. 특히 Unique Key 테이블은 사용자가 기대하는 변경 순서와 적재 모드를 점검해야 합니다. 엔진이 레코드 버전을 정리해도 업무적으로 늦게 도착한 이벤트의 정합성 정책까지 대신 정하지는 않습니다.

### 통합형과 분리형은 자원 경계가 다릅니다

통합형은 BE가 데이터와 계산을 함께 보유해 로컬 데이터 접근이 간단합니다. 반면 계산 자원과 저장 용량을 별도로 늘리기 어렵습니다. 분리형은 공유 스토리지와 컴퓨트 그룹을 통해 계산 자원을 독립적으로 조절할 수 있으나, 캐시·공유 스토리지·추가 메타데이터 계층을 이해해야 합니다. 한 모드의 장애·성능 모델을 다른 모드에 그대로 대입하면 안 됩니다.

## 장애를 해석하는 기준

FE 문제는 SQL 접속·계획·메타데이터에, BE 문제는 저장 사본·스캔·실행에 영향을 줍니다. 쿼리가 느리면 FE 계획과 BE 프로파일을 함께 살펴보시고, 적재 지연은 원천 입력량, 트랜잭션 상태, BE 쓰기·컴팩션 부담을 분리해 확인해 보세요.

## 실무 적용: 사내 분석 저장소의 중심

사내에서는 Doris가 raw·bronze부터 Silver, Gold 마트까지 **모든 분석 계층을 담는 단일 저장소**입니다. 7개 dbt 프로젝트가 모두 Doris를 대상 엔진으로 쓰고, 분석가와 사내 도구도 MySQL 프로토콜로 같은 Doris를 조회합니다. 적재 방식은 원천에 따라 세 가지로 나뉩니다.

| 원천 | 적재 방식 | 경로 |
|---|---|---|
| Nginx 게임 로그 (Parquet) | **Broker Load** (`WITH S3`) | fastlog-etl이 SeaweedFS S3에 쓴 Parquet 파티션을 Doris가 직접 읽음 |
| 외부 API (Airbyte) | **Stream Load** | Airflow Task가 5,000행 JSON 청크를 HTTP로 전송 |
| Silver·Gold 변환 (dbt) | **INSERT + 명시적 트랜잭션** | Doris 내부 테이블 → 테이블 |

### Label과 트랜잭션을 멱등성에 쓰기

이론에서 "파일을 썼다는 것과 쿼리에 보인다는 것은 다른 단계"라고 했습니다. 사내 적재 코드는 이 구분을 기준으로 성공을 판정합니다.

- **Broker Load**: 로그 적재 DAG는 해당 시간 슬롯(`inputdatetime`)의 기존 데이터를 먼저 지우고, 파티션 경로마다 고유 label로 Load를 제출한 뒤 `SHOW LOAD`로 완료를 기다립니다. 한 label에 여러 경로를 묶으면 SeaweedFS S3가 두 번째 경로의 서명을 거부하는 사례가 있어, 경로별 label을 순차 실행합니다.
- **Stream Load**: 응답 `Status`가 `Success`이거나 `Publish Timeout`이면 성공으로 봅니다. `Publish Timeout`은 트랜잭션은 커밋됐고 가시화만 지연된 상태라, 재시도하면 오히려 중복이 생깁니다.
- **dbt 변환**: 커스텀 materialization이 tmp 테이블을 트랜잭션 밖에서 미리 만든 뒤, 날짜별로 `BEGIN → DELETE → INSERT → COMMIT` 하거나 임시 파티션을 만들어 `REPLACE PARTITION`으로 교체합니다. 긴 계산을 트랜잭션 밖으로 빼서 트랜잭션 구간을 짧게 유지하는 것이 핵심입니다.

### 운영에서 배운 것

- 클라이언트(dbt, Airflow Worker)가 먼저 죽어도 **FE는 실행 중인 쿼리를 취소하지 않습니다.** 서버 전역 `insert_timeout`이 길면 수 시간짜리 좀비 쿼리가 BE I/O를 점유합니다. 그래서 dbt 세션에서 `query_timeout`·`insert_timeout`을 낮추고, Airflow에서도 30분 `execution_timeout`을 겁니다.
- 파티션 조건 없는 DELETE는 기본적으로 막혀 있으므로, 필요한 적재에서만 세션 변수 `delete_without_partition`을 켭니다.
- 비슷한 MPP 엔진인 StarRocks를 다룬 경험은 [StarRocks 퍼포먼스 경험기](../de/starrocks-performance-experience)에 정리했습니다.


**공식 문서:** [System Architecture](https://doris.apache.org/docs/4.x/features-architecture/system-architecture/), [Load Best Practices](https://doris.apache.org/docs/dev/data-operate/import/load-best-practices/)
