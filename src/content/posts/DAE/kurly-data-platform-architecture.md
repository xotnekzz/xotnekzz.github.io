---
title: "컬리 데이터 플랫폼: 데이터 흐름과 AX 방향"
description: "공개 기술 글을 바탕으로 컬리의 CDC·Kafka·BigQuery 흐름을 읽고, AX 데이터 플랫폼의 가능한 확장 방향을 구분해 정리합니다."
date: 2026-09-23
tags:
  - DataEngineering
  - CDC
  - Kafka
  - BigQuery
  - Architecture
featured: false
draft: true
---

> **기간:**
> **참여인원:**
> **역할:** 공개 자료 기반 아키텍처 분석
> **기술 스택:** AWS DMS, AWS MSK (Kafka), Kafka Connect JDBC, NiFi, BigQuery, Airflow, Dataflow, Gemini

컬리의 데이터 플랫폼은 운영 DB의 변경을 Kafka로 모으고, BigQuery에 변경 이력과 원본을 반영한 테이블을 구성하는 흐름으로 이해할 수 있다. 이 문서는 **공개된 기술 블로그에서 확인한 경로**와 **공개 자료를 토대로 그린 목표 아키텍처**를 분리한다. 그림의 실선은 전자, 점선은 후자다. 그림 속 점선 경로는 컬리의 현재 운영 구성을 단정하지 않는다.

![Kurly Data Platform: six swimlanes from AWS sources and CDC through Kafka to GCP BigQuery and consumers, with a dashed future AX layer](/images/kurly-data-platform-data-flow-ax.svg)

## Background & Challenges

컬리의 [BigQuery 도입기 1부](https://helloworld.kurly.com/blog/bigquery-1/)에 따르면 기존 경로는 Oracle·Aurora·DocumentDB → DMS → Kafka → S3 → Airflow 스크립트 → 기존 Data Warehouse였다. 중간 저장과 별도 적재 단계가 지연과 운영 복잡성을 만들었다. BigQuery로의 전환은 Kafka의 CDC 로그를 Streaming API로 직접 적재해 이 단계를 줄이는 선택이었다.

## Data Context: What Kurly Collects and Analyzes

컬리의 데이터 활용 맥락은 **주문을 제때 처리하고, 함께 살 만한 상품을 찾고, 고객이 남긴 신호를 상품 경험에 반영하는 것**으로 볼 수 있다. 아래는 공개 기술 글에서 입력 데이터와 분석 목적을 함께 확인할 수 있는 사례다. 각 사례의 데이터가 모두 그림의 동일한 CDC 토픽과 Final 테이블을 거친다는 뜻은 아니다.

| 수집 데이터 | 분석 질문과 활용 | 근거 |
|---|---|---|
| **주문 데이터:** 새 주문과 과거 주문 내역 | 변하는 주문량을 준실시간 수요 예측에 반영한다. BigQuery의 과거 데이터와 새로운 주문 데이터의 역할이 다르다. | [Dataflow 수요 예측](https://helloworld.kurly.com/blog/dataflow-pipeline-1/) |
| **배송·물류 데이터:** 지역별 주문량, 물류 거점의 처리 능력, 이동 시간 | 예상 주문량을 보고 물량을 어느 거점에 배분할지 최적화한다. | [배송 거점 최적화](https://helloworld.kurly.com/blog/tc-optimization/) |
| **장바구니·구매 데이터:** 함께 구매한 상품과 상품 종류 | 자주 함께 팔리는 상품 중 의미 있는 보완재 관계를 찾아 장바구니에서 추천한다. | [장바구니 추천 1부](https://helloworld.kurly.com/blog/cart-recommend-model-development/) |
| **추천 서비스 데이터:** 추천 요청과 결과 | 추천 실험의 A/B 결과를 BigQuery에서 분석하고 모델 방향을 결정한다. | [장바구니 추천 2부](https://helloworld.kurly.com/blog/cart-recommend-model-development_second/) |
| **상품 후기 데이터:** 상품명과 고객 후기 | Gemini로 후기 요약, 키워드·감성 추출, 주제 분류를 시도해 상품과 고객 경험을 이해한다. | [BigQuery와 Gemini 리뷰 분석](https://helloworld.kurly.com/blog/bigquery-gemini-review/) |

이 사례들을 데이터 플랫폼 관점에서 읽으면 `운영 데이터의 최신 상태`는 주문·상품 분석의 입력을 제공하고, `변경 이력과 서비스 로그`는 시간에 따른 수요 변화·실험 결과를 설명한다. 후기처럼 비정형 데이터는 별도의 텍스트 분석이 필요하다. **Data Marts**는 이처럼 서로 다른 원천을 분석 질문에 맞춰 묶는 논리적 위치로 그렸다. 공개 글만으로 마트별 스키마나 변환 도구는 특정할 수 없다.

### Source-to-Mart Map

![Kurly source databases mapped to confirmed or inferred business data and proposed analytical marts](/images/kurly-source-to-mart-map.svg)

앞의 플랫폼 그림에서 확인한 **원천 DB별로 어떤 업무 데이터를 담을지** 연결했다. **확인**은 컬리 기술 블로그가 DB와 데이터를 직접 연결한 사례다. **추정**은 DB가 쓰이는 서비스의 목적을 바탕으로 배치한 데이터다. 아래 마트는 모두 분석 관점의 제안으로, 컬리의 실제 테이블명이나 운영 구성을 뜻하지 않는다.

| 원천 DB | 담길 것으로 보는 업무 데이터 | 판단 근거 | 연결할 분석 마트(제안) |
|---|---|---|---|
| **Aurora (MySQL)** | **주문 데이터 — 확인.** 주문 시각·상품·수량·상태·결제 내역 같은 주문 상세 항목은 합리적인 구성이나, 공개 자료가 각각의 컬럼까지 밝히지는 않는다. **상품·장바구니·결제 데이터 — 추정.** | [서비스 구조 글](https://helloworld.kurly.com/blog/market-kurly-service-architecture/)은 결제 후 Aurora에 주문이 생성된다고 밝히고, 이커머스 백엔드에 Aurora(MySQL)를 열거한다. | **주문·매출 마트:** 주문량·상품 판매·매출. **상품 마트:** 카테고리·상품별 성과. |
| **Oracle** | **재고·입출고·피킹·포장·배송 상태 데이터 — 추정.** 물류 업무를 처리하는 관계형 테이블에 적합하지만 실제 테이블의 DB 배치는 미확인이다. | 같은 [서비스 구조 글](https://helloworld.kurly.com/blog/market-kurly-service-architecture/)은 SCM·WMS·TMS 물류 서비스와 Oracle을 함께 기술 스택에 적는다. [데이터 분석가 글](https://helloworld.kurly.com/blog/how-to-work-da/)에는 주문·출고·배송 완료·재고 분석 사례가 있다. | **재고·출고 마트:** 센터별 재고와 작업량. **배송 마트:** 지역별 배송량·지연. |
| **Aurora (PostgreSQL)** | **주문·상품 또는 물류 업무의 관계형 데이터 — 추정.** 어느 도메인의 테이블인지 확인되지 않아 특정 데이터로 단정할 수 없다. | [BigQuery 도입기 2부](https://helloworld.kurly.com/blog/bigquery-2/)는 `Aurora DB`의 CDC를 설명하지만 엔진별 업무 테이블을 공개하지 않는다. | 실제 테이블 조사 후 **주문·매출 / 재고·출고 / 배송 마트** 중 해당 도메인에 연결. |
| **DocumentDB** | **배송 완료 사진의 임베딩·주소 정보·완료 시각 — 확인된 별도 2026년 서비스 사례.** 그 밖의 CDC 대상 컬렉션의 업무 내용은 미확인이다. | [오배송 탐지 글](https://helloworld.kurly.com/blog/image-based-misdelivery-detection)은 사진 임베딩과 주소 메타데이터의 DocumentDB 저장을 밝힌다. [BigQuery 도입기 2부](https://helloworld.kurly.com/blog/bigquery-2/)는 DocumentDB Change Stream 수집을 설명하지만 **두 글이 동일 컬렉션을 말한다는 근거는 없다.** | **배송 품질 마트:** 오배송 의심 건수·확인 결과. 사진 임베딩 자체를 분석 마트로 복제한다는 뜻은 아니다. |
| **레거시 DB (binlog 접근 불가라는 가정)** | **기존 회원·상품·운영 기준 정보 — 추정.** 변경 로그를 읽을 수 없는 원천이라면 최신 상태 중심으로 수집한다. | [Kafka Connect 글](https://helloworld.kurly.com/blog/kafka-connect-pipeline/)은 JDBC 폴링의 삭제 감지 한계를 설명한다. 이 DB의 실제 도메인과 컬리 배치 여부는 확인되지 않았다. | **회원·상품 기준 마트:** 확인된 원천 테이블에 맞춰 구성. 삭제·변경 이력의 완전성은 별도 검증 필요. |

분석 마트는 DB별 복사본이 아니라 **업무 질문을 기준으로 여러 소스를 조합한 결과**다. 예를 들어 주문·매출 마트는 Aurora 주문 데이터에 상품 기준 정보를 결합하고, 배송 마트는 물류 상태와 주문 권역을 연결한다. DB별 테이블 소유권과 조인 키가 확인되기 전까지 그림의 마트 화살표는 제안으로 읽어야 한다. [데이터 분석가 글](https://helloworld.kurly.com/blog/how-to-work-da/)도 운영계 데이터를 그대로 조회하지 않고 분석용 코어 테이블로 분리한 사례를 소개한다.

AX 방향에서는 주문·추천·후기·배송 분석을 연결해 **"어떤 수요 변화가 어떤 상품 추천과 배송 용량에 영향을 주는가"** 같은 도메인 간 질문을 다룰 수 있다. 이는 이 문서의 분석 제안이며, 컬리가 이미 운영 중인 지표나 모델이라는 의미는 아니다. 이때 이벤트의 누락·중복·지연, 데이터의 소유 도메인, 분석 비용을 함께 보여주는 것이 관측성·거버넌스·FinOps 계층의 목적이다.

## Architecture: Data Flow & AX Direction

1. **Sources → CDC.** Oracle·Aurora의 변경은 AWS DMS가 캡처한다. DocumentDB는 Change Stream을 DMS가 Kafka로 전달한다. 두 경로는 [BigQuery 도입기 2부](https://helloworld.kurly.com/blog/bigquery-2/)에 설명되어 있다. 그림의 레거시 DB → Kafka Connect JDBC 경로는 [컬리의 Kafka Connect 글](https://helloworld.kurly.com/blog/kafka-connect-pipeline/)이 설명한 쿼리 기반 수집의 적용 예시이며, 특정 레거시 DB에 실제로 배치됐다는 뜻은 아니다.
2. **Streaming backbone.** [수요 예측 파이프라인 글](https://helloworld.kurly.com/blog/dataflow-pipeline-1/)은 주문 스트림이 AWS MSK(Kafka)를 거쳐 BigQuery로 적재된다고 밝힌다. [추천 시스템 글](https://helloworld.kurly.com/blog/cart-recommend-model-development_second/)에는 Kafka 로그를 NiFi가 BigQuery로 보내는 별도 사례가 있다. 그림의 `NiFi / Flink` 묶음은 스트림 처리 계층을 표현하며, Flink의 이 CDC 경로 투입은 목표 방향이다.
3. **Warehouse.** Kafka의 CDC 이벤트는 BigQuery Streaming API를 거쳐 일자 파티션 CDC 로그 테이블에 기록된다. 원본 레코드, DML 작업 유형, CDC 시각을 보관하고, 주기적인 `MERGE`가 PK·생성일자·작업 유형·CDC 시각을 사용해 원본 DB 상태를 반영하는 Final 테이블을 만든다. 따라서 Streaming API에 의한 로그 적재와 Final 테이블 갱신은 같은 시점의 처리가 아니다. 데이터 마트는 이 분석 계층의 후속 활용이다. [BigQuery 도입기 2부](https://helloworld.kurly.com/blog/bigquery-2/)
4. **Consumers.** BigQuery 기반 BI, Dataflow 수요 예측, 추천, Gemini 리뷰 분석은 각각 공개 사례가 있다. AICS와 DSP는 가능한 서비스 활용처로 그렸으며, 이 문서의 자료만으로 특정 테이블이나 파이프라인과의 연결을 확인할 수 없다. [Dataflow](https://helloworld.kurly.com/blog/dataflow-pipeline-1/) · [추천](https://helloworld.kurly.com/blog/cart-recommend-model-development_second/) · [Gemini 리뷰 분석](https://helloworld.kurly.com/blog/bigquery-gemini-review/)
5. **AX target state.** ClickHouse 서빙 저장소, 데이터 관측성, 도메인별 FinOps, 카탈로그·권한·리니지 중심 Data Mesh 거버넌스는 이 문서의 제안이다. Kafka/Flink → ClickHouse → AICS/DSP 연결도 목표 경로이며, 운영 중이라는 근거는 없다.

## Why Consider ClickHouse?

**ClickHouse 도입은 컬리의 확인된 계획이 아니라 이 문서의 아키텍처 가설이다.** 현재 공개된 [BigQuery 파이프라인](https://helloworld.kurly.com/blog/bigquery-2/)은 Kafka의 변경 로그를 스트리밍으로 적재하지만, 원천 상태를 반영한 Final 테이블은 Airflow가 주기적으로 `MERGE`한다. 긴 기간의 이력 분석·BI·모델 학습에는 BigQuery가 중심 역할을 한다. 반면 서비스 화면이나 API가 **방금 발생한 이벤트를 많은 사용자가 반복 조회**해야 한다면 별도의 빠른 조회 계층을 검토할 이유가 있다.

| 검토할 요구 | ClickHouse를 두는 이유 | 컬리에 적용한다면(가설) |
|---|---|---|
| 새 이벤트의 빠른 조회 | Kafka에서 들어온 이벤트를 분석용 열 저장소에 지속적으로 적재하고, 자주 보는 집계를 미리 계산할 수 있다. | 주문·배송 상태나 광고 노출·클릭·비용을 짧은 주기로 집계한다. |
| 사용자 화면의 반복 조회 | 여러 필터를 바꾸며 같은 지표를 높은 동시성으로 조회하는 API·대시보드에 맞춰 설계할 수 있다. | 광고주 보고서, 운영 관제 화면, AICS의 상담 현황 조회를 제공한다. |
| 대량 이벤트의 탐색 | 로그·이벤트를 시간, 서비스, 캠페인 등 여러 차원으로 좁혀 볼 수 있다. | 추천·광고·상담 서비스의 지연과 오류를 탐색한다. |

이 용도는 ClickHouse의 [실시간 분석](https://clickhouse.com/use-cases/real-time-analytics) 및 [관측성](https://clickhouse.com/cloud/clickstack) 제품 설명과 맞지만, **컬리의 실제 지연 시간·동시 조회량·광고/AICS 데이터 요구사항은 공개 자료로 확인되지 않았다.** 따라서 도입 근거는 벤치마크로 검증해야 한다. 예를 들어 화면의 p95 응답 시간, 데이터가 발생한 뒤 조회 가능해지는 시간, 동시 사용자 수, 쿼리당 운영비를 BigQuery 및 사전 집계·캐시 방안과 같은 조건에서 비교한다. ClickHouse로 CDC를 직접 받을 경우 중복 이벤트, 늦게 도착한 이벤트, Update/Delete 반영 방식도 별도로 설계해야 한다.

## Managed Cloud and Reliability Ownership

관리형 서비스를 쓴다고 데이터 엔지니어가 안정성을 덜 신경 쓰는 것은 아니다. **서비스 자체의 서버 운영 부담은 줄지만, 소스에서 분석 결과까지 데이터가 제때·빠짐없이·맞게 도착하는 책임은 남는다.** DMS·MSK·BigQuery가 실행 중이어도 CDC 커넥터 지연, 중복·누락, `MERGE` 실패, 쿼리 자원 경합은 분석 결과를 틀리거나 늦게 만들 수 있다. [BigQuery 도입기 1부](https://helloworld.kurly.com/blog/bigquery-1/)는 기존 파이프라인의 지연과 복잡성을, [2부](https://helloworld.kurly.com/blog/bigquery-2/)는 Delete 정합성과 적재·조회 자원 분리를 다룬다.

| 관리형 서비스가 줄여 주는 일 | 데이터 플랫폼 팀이 계속 살펴볼 일 |
|---|---|
| 서버 설치·기본 유지 관리, 관리형 서비스의 기반 인프라 운영 | CDC/커넥터 상태, Kafka 소비 지연, DAG 실패·재시도, BigQuery 쿼리 지연과 비용 |
| 저장·처리 자원의 확장 기능 | 주문·출고·배송 건수 대사, 누락·중복·삭제 반영, 스키마 변경 대응, 데이터 신선도 목표 |
| 일부 장애 복구 기능 | 장애 시 어느 단계부터 재처리할지, 늦게 도착한 이벤트를 어떻게 반영할지 결정 |

컬리의 [Airflow 운영 경험기](https://helloworld.kurly.com/blog/airflow-1/)는 오히려 데이터 파이프라인용 Airflow를 관리형 서비스에서 Kubernetes로 옮긴 뒤 Helm·CeleryExecutor 워커를 운영한 사례다. BigQuery 작업 지연이 Airflow 워커 대기를 유발하자 동시 처리 용량을 점검하고 워커 수를 늘렸다. [Kafka Connect 글](https://helloworld.kurly.com/blog/kafka-connect-pipeline/)도 JDBC 폴링에서 삭제·업데이트가 누락될 수 있음을 분석한다. 이 사례들은 **인프라 가용성뿐 아니라 파이프라인 처리량과 데이터 정합성까지 안정성의 범위**임을 보여준다.

## Solution & Technical Insights

### [Issue] 쿼리 기반 CDC의 삭제 누락

**[Solution]** 트랜잭션 로그에 접근할 수 있는 원천은 로그 기반 CDC를 우선한다. JDBC Source Connector는 폴링 시점의 행 상태를 읽으므로 삭제를 감지할 수 없고, 모드에 따라 업데이트나 폴링 사이의 중간 변경도 놓칠 수 있다. 레거시 원천에 적용한다면 변경 이력 전체가 필요한 테이블과 최신 스냅샷만 필요한 테이블을 구분해야 한다. [Kafka Connect 파이프라인 글](https://helloworld.kurly.com/blog/kafka-connect-pipeline/)

### [Issue] 변경 로그와 조회 테이블의 목적 차이

**[Solution]** CDC 로그 테이블은 append-only 변경 이력을 받고, Final 테이블은 주기적인 `MERGE` 뒤 원천 테이블 상태를 제공한다. CDC 로그의 이벤트 시각과 Final 테이블의 반영 시각을 분리해 읽어야 신선도 기대치를 잘못 잡지 않는다. DocumentDB 경로에는 JSON 필드 처리가 추가된다. [BigQuery 도입기 2부](https://helloworld.kurly.com/blog/bigquery-2/)

### [Issue] 분석 쿼리와 파이프라인의 자원 경합

**[Solution]** BigQuery의 파이프라인 프로젝트와 조회 프로젝트를 분리하고, 큰 스캔에는 슬롯 예약을, 작은 프로젝트에는 일일 스캔 상한을 적용했다. 이는 공개 글에 나온 운영 선택이다. AX 확장 단계에서는 비용을 프로젝트뿐 아니라 데이터 도메인과 소비 서비스 기준으로도 볼 수 있어야 한다. 후자는 제안이다. [BigQuery 도입기 1부](https://helloworld.kurly.com/blog/bigquery-1/) · [2부](https://helloworld.kurly.com/blog/bigquery-2/)

### [Issue] 여러 실행 환경의 오케스트레이션

**[Solution]** 2023년 BigQuery 도입 글의 `MERGE` 실행 주체는 **GCP Cloud Composer (Airflow)**다. 2024년 [Airflow 운영 글](https://helloworld.kurly.com/blog/airflow-1/)은 데이터 파이프라인용 Airflow를 Kubernetes에 Helm으로 배포하고 CeleryExecutor를 운영한 경험을 설명한다. 그림 하단 바는 Airflow 오케스트레이션 역량을 요약한 것이며, 모든 `MERGE`가 EKS에서 실행됐다는 의미는 아니다.

## Impact & Result

BigQuery 도입 글은 중간 S3 파일을 거치지 않는 직접 적재, `MERGE`를 통한 Insert·Update·Delete 반영, 프로젝트 분리와 비용 제어를 성과로 설명한다. 같은 글의 한 사례에서는 기존에 30분 이상 걸리던 태스크가 13초에 완료됐다고 제시하지만, 이는 **특정 태스크 사례**이며 전체 파이프라인 지연 시간으로 일반화할 수 없다. AX 계층의 지연·비용·품질 개선 효과는 아직 측정 결과가 없는 설계 목표다. [BigQuery 도입기 2부](https://helloworld.kurly.com/blog/bigquery-2/)

## Reading the Diagram

| 표기 | 의미 |
|---|---|
| 실선 | 연결 자체가 컬리 기술 블로그에서 확인된 경로 또는 운영 요소 |
| 점선 | 기술 글에서 유추한 적용 예시나 이 문서의 미래 설계 제안 |
| AWS ↔ GCP 경계 | 스트림 원천과 분석 저장소가 클라우드를 가로지르는 지점 |

**자료 기준:** 컬리 기술 블로그의 2023~2024년 데이터 플랫폼·활용 사례를 중심으로 작성했다. 이후 실제 운영 구성은 달라졌을 수 있다. 그림의 AX 항목은 채용 공고 검증 없이 설계 가설로 분류했다.

**dbt 확인 범위:** 공개된 컬리 기술 블로그와 확인 가능한 데이터 엔지니어·분석 엔지니어 채용 자료에서는 dbt의 실제 운영 사례를 확인하지 못했다. 따라서 그림의 `Final Tables → Data Marts` 구간은 변환 도구를 특정하지 않는다. dbt는 이 구간에 적용 가능한 선택지이지만, 현재 사용 중이라고 표시할 근거는 없다.
